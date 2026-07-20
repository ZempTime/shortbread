# frozen_string_literal: true

require "test_helper"

require "digest"
require "securerandom"

class InvitationAcceptanceTest < ActionDispatch::IntegrationTest
  APEX_HEADERS = {
    "Host" => "localhost",
    "Origin" => "http://localhost",
    "Sec-Fetch-Site" => "same-origin",
    "Sec-Fetch-Mode" => "navigate",
    "Sec-Fetch-Dest" => "document"
  }.freeze

  test "invalid host, request policy, locator, and secret fail identically without mutation" do
    invitation, secret = issue_invitation
    before_state = invitation_state(invitation)
    path = "/invitations/#{invitation.locator}/accept"
    unknown_path = "/invitations/#{"z" * 32}/accept"
    wrong_secret = SecureRandom.urlsafe_base64(32, false)
    attempts = [
      { path:, headers: APEX_HEADERS.merge("Host" => "first-site.sites.localhost"), secret: },
      { path:, headers: APEX_HEADERS.merge("Origin" => "http://wrong.example"), secret: },
      { path:, headers: APEX_HEADERS.except("Origin"), secret: },
      { path:, headers: APEX_HEADERS.merge("Sec-Fetch-Site" => "cross-site"), secret: },
      { path:, headers: APEX_HEADERS.merge("Sec-Fetch-Mode" => "cors"), secret: },
      { path:, headers: APEX_HEADERS.merge("Sec-Fetch-Dest" => "empty"), secret: },
      { path: "/invitations/invalid/accept", headers: APEX_HEADERS, secret: },
      { path: unknown_path, headers: APEX_HEADERS, secret: },
      { path:, headers: APEX_HEADERS, secret: wrong_secret }
    ]

    attempts.each do |attempt|
      post attempt.fetch(:path),
        params: { invitation_secret: attempt.fetch(:secret) },
        headers: attempt.fetch(:headers)

      assert_response :not_found
      assert_empty response.body
      assert_nil response.headers["Set-Cookie"]
      assert_equal before_state, invitation_state(invitation)
    end
  end

  test "explicit acceptance consumes the Invitation and posts one handoff only to its Site origin" do
    invitation, secret = issue_invitation

    post "/invitations/#{invitation.locator}/accept",
      params: { invitation_secret: secret },
      headers: APEX_HEADERS

    assert_response :ok
    assert_not_nil invitation.reload.accepted_at
    handoff = SiteHandoff.find_by!(invitation:)
    site_origin = "http://first-site.sites.localhost"
    assert_equal site_origin, handoff.audience
    assert_equal 1, SiteHandoff.where(invitation:).count
    assert_nil response.headers["Set-Cookie"]
    assert_success_headers(site_origin:)
    assert_includes response.body, %(<form id="site-handoff" hidden method="post" action="#{site_origin}/_shortbread/session">)
    assert_includes response.body, %(type="hidden" name="handoff")
    assert_equal 1, response.body.scan(/<form\b/i).size
    assert_equal 1, response.body.scan(/<input\b/i).size
    assert_equal 1, response.body.scan(/<script\b/i).size
    assert_operator response.body.index("<script"), :<, response.body.index("<form")
    assert_includes response.body, 'document.getElementById("site-handoff").submit()'
    refute_includes response.body, invitation.locator
    refute_includes response.body, secret
    refute_includes response.body, invitation.secret_digest
  end

  test "replay receives the same generic failure without changing accepted state" do
    invitation, secret = issue_invitation
    path = "/invitations/#{invitation.locator}/accept"
    post path, params: { invitation_secret: secret }, headers: APEX_HEADERS
    assert_response :ok
    accepted_state = invitation_state(invitation)

    post path, params: { invitation_secret: secret }, headers: APEX_HEADERS

    assert_response :not_found
    assert_empty response.body
    assert_nil response.headers["Set-Cookie"]
    assert_equal accepted_state, invitation_state(invitation)
    refute_includes response.body, invitation.locator
    refute_includes response.body, secret
    refute_includes response.body, invitation.secret_digest
  end

  test "expired, revoked, and inactive-Grant Invitations fail identically without acceptance" do
    expired, expired_secret = issue_invitation(slug: "expired-site")
    travel Invitation::DEFAULT_LIFETIME + 1.second do
      assert_acceptance_rejected_without_mutation(expired, expired_secret)
    end

    revoked, revoked_secret = issue_invitation(slug: "revoked-site")
    revoked.update!(revoked_at: Time.current)
    assert_acceptance_rejected_without_mutation(revoked, revoked_secret)

    inactive, inactive_secret = issue_invitation(slug: "inactive-site")
    inactive.grant.update!(revoked_at: Time.current)
    assert_acceptance_rejected_without_mutation(inactive, inactive_secret)
  end

  private

  def issue_invitation(slug: "first-site")
    site = Site.create!(slug:, name: slug.titleize)
    person = Person.create!(first_name: "Avery")
    grant = Grant.create!(site:, person:)
    secret = SecureRandom.urlsafe_base64(32, false)
    invitation = Invitation.issue!(grant:, secret_digest: Digest::SHA256.hexdigest(secret))
    [ invitation, secret ]
  end

  def invitation_state(invitation)
    [ Invitation.count, SiteHandoff.count, invitation.reload.accepted_at, invitation.updated_at ]
  end

  def assert_acceptance_rejected_without_mutation(invitation, secret)
    before_state = invitation_state(invitation)
    post "/invitations/#{invitation.locator}/accept",
      params: { invitation_secret: secret },
      headers: APEX_HEADERS

    assert_response :not_found
    assert_empty response.body
    assert_nil response.headers["Set-Cookie"]
    assert_equal before_state, invitation_state(invitation)
    refute_includes response.body, invitation.locator
    refute_includes response.body, secret
  end

  def assert_success_headers(site_origin:)
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "origin", response.headers["Referrer-Policy"]
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    policy = response.headers.fetch("Content-Security-Policy")
    nonce = policy.match(/script-src 'nonce-([^']+)'/)&.[](1)
    assert nonce
    assert_includes response.body, %(nonce="#{nonce}")
    assert_includes policy, "default-src 'none'"
    assert_includes policy, "form-action #{site_origin}"
    assert_includes policy, "frame-ancestors 'none'"
  end
end
