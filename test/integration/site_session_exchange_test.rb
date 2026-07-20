# frozen_string_literal: true

require "test_helper"

require "digest"
require "securerandom"

class SiteSessionExchangeTest < ActionDispatch::IntegrationTest
  test "a valid local handoff becomes a host-only Site session and a credential-free relative redirect" do
    site, grant, handoff = issue_handoff

    post "/_shortbread/session",
      params: { handoff: handoff },
      headers: site_headers

    assert_equal 303, response.status
    assert_equal "/", response.headers["Location"]
    refute_includes response.headers["Location"], handoff

    set_cookie = response.headers.fetch("Set-Cookie")
    assert_match(/\Ashortbread_site=/, set_cookie)
    assert_match(/;\s*Path=\//i, set_cookie)
    assert_match(/;\s*HttpOnly/i, set_cookie)
    assert_match(/;\s*SameSite=Lax/i, set_cookie)
    refute_match(/;\s*Secure(?:;|\z)/i, set_cookie)
    refute_match(/;\s*Domain=/i, set_cookie)

    assert_equal grant, SiteSession.authenticate(
      token: cookies["shortbread_site"],
      audience: site_origin,
      site:,
      now: Time.current
    )
    assert_not_nil SiteHandoff.find_by!(grant:).consumed_at
  end

  test "an HTTPS handoff uses the Secure __Host Site session cookie" do
    https!
    site, grant, handoff = issue_handoff(scheme: "https")

    post "/_shortbread/session",
      params: { handoff: },
      headers: site_headers(scheme: "https")

    assert_equal 303, response.status
    assert_equal "/", response.headers["Location"]
    set_cookie = response.headers.fetch("Set-Cookie")
    assert_match(/\A__Host-shortbread_site=/, set_cookie)
    assert_match(/;\s*Path=\//i, set_cookie)
    assert_match(/;\s*HttpOnly/i, set_cookie)
    assert_match(/;\s*SameSite=Lax/i, set_cookie)
    assert_match(/;\s*Secure(?:;|\z)/i, set_cookie)
    refute_match(/;\s*Domain=/i, set_cookie)

    assert_equal grant, SiteSession.authenticate(
      token: cookies["__Host-shortbread_site"],
      audience: site_origin(scheme: "https"),
      site:,
      now: Time.current
    )
  end

  test "tamper, request-policy failure, wrong Site, and revocation fail identically without consuming the handoff" do
    _site, grant, handoff = issue_handoff
    persisted_handoff = SiteHandoff.find_by!(grant:)
    Site.create!(slug: "other-site", name: "Other Site")
    valid_headers = site_headers
    attempts = [
      { token: "", headers: valid_headers },
      { token: "#{handoff}tampered", headers: valid_headers },
      { token: handoff, headers: valid_headers.merge("Host" => "localhost") },
      { token: handoff, headers: valid_headers.merge("Origin" => "http://wrong.example") },
      { token: handoff, headers: valid_headers.except("Origin") },
      { token: handoff, headers: valid_headers.merge("Sec-Fetch-Site" => "cross-site") },
      { token: handoff, headers: valid_headers.merge("Sec-Fetch-Mode" => "cors") },
      { token: handoff, headers: valid_headers.merge("Sec-Fetch-Dest" => "empty") },
      { token: handoff, headers: site_headers(slug: "other-site") }
    ]

    attempts.each do |attempt|
      post "/_shortbread/session",
        params: { handoff: attempt.fetch(:token) },
        headers: attempt.fetch(:headers)

      assert_generic_rejection(persisted_handoff)
    end

    grant.update!(revoked_at: Time.current)
    post "/_shortbread/session", params: { handoff: }, headers: valid_headers

    assert_generic_rejection(persisted_handoff)
  end

  test "a successful handoff cannot be replayed" do
    _site, grant, handoff = issue_handoff

    post "/_shortbread/session", params: { handoff: }, headers: site_headers
    assert_equal 303, response.status
    consumed_state = handoff_state(grant)

    post "/_shortbread/session", params: { handoff: }, headers: site_headers

    assert_response :not_found
    assert_empty response.body
    assert_nil response.headers["Set-Cookie"]
    assert_equal consumed_state, handoff_state(grant)
  end

  test "an expired handoff fails generically without being consumed" do
    _site, grant, handoff = issue_handoff
    persisted_handoff = SiteHandoff.find_by!(grant:)

    travel InvitationFlow::HANDOFF_LIFETIME + 1.second do
      post "/_shortbread/session", params: { handoff: }, headers: site_headers

      assert_generic_rejection(persisted_handoff)
    end
  end

  private

  def issue_handoff(slug: "first-site", scheme: "http")
    site = Site.create!(slug:, name: slug.titleize)
    person = Person.create!(first_name: "Avery")
    grant = Grant.create!(site:, person:)
    secret = SecureRandom.urlsafe_base64(32, false)
    invitation = Invitation.issue!(grant:, secret_digest: Digest::SHA256.hexdigest(secret))
    audience = "#{scheme}://#{slug}.sites.localhost"
    acceptance = InvitationFlow.accept!(locator: invitation.locator, secret:, audience:)

    [ site, grant, acceptance.token ]
  end

  def site_headers(slug: "first-site", scheme: "http")
    {
      "Host" => "#{slug}.sites.localhost",
      "Origin" => "#{scheme}://localhost",
      "Sec-Fetch-Site" => "same-site",
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document"
    }
  end

  def site_origin(slug: "first-site", scheme: "http")
    "#{scheme}://#{slug}.sites.localhost"
  end

  def assert_generic_rejection(handoff)
    assert_response :not_found
    assert_empty response.body
    assert_nil response.headers["Set-Cookie"]
    assert_nil handoff.reload.consumed_at
  end

  def handoff_state(grant)
    handoff = SiteHandoff.find_by!(grant:)
    [ handoff.consumed_at, handoff.updated_at ]
  end
end
