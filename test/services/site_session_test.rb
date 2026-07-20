# frozen_string_literal: true

require "test_helper"

class SiteSessionTest < ActiveSupport::TestCase
  AUDIENCE = "first-site.sites.localhost"

  test "an active persisted Grant receives an audience-bound 30-day Site session" do
    grant = create_grant
    now = Time.current

    issued = SiteSession.issue(grant:, audience: AUDIENCE, now:)
    authenticated_grant = SiteSession.authenticate(
      token: issued.token,
      audience: AUDIENCE,
      site: grant.site,
      now:
    )

    assert_equal grant, authenticated_grant
    assert_equal now + 30.days, issued.expires_at
    assert issued.token.present?
    assert_not_includes issued.token, AUDIENCE
  end

  test "cookie policy is host-only and uses the secure prefix only for HTTPS" do
    expires_at = 30.days.from_now

    assert_equal "__Host-shortbread_site", SiteSession.cookie_name(secure: true)
    assert_equal "shortbread_site", SiteSession.cookie_name(secure: false)
    assert_equal(
      {
        secure: true,
        httponly: true,
        path: "/",
        same_site: :lax,
        expires: expires_at
      },
      SiteSession.cookie_options(secure: true, expires_at:)
    )
    assert_equal false, SiteSession.cookie_options(secure: false, expires_at:)[:secure]
    assert_not SiteSession.cookie_options(secure: true, expires_at:).key?(:domain)
  end

  test "issuing requires a persisted active Grant and a nonblank exact audience" do
    grant = create_grant
    now = Time.current

    assert_rejected { SiteSession.issue(grant: Grant.new, audience: AUDIENCE, now:) }
    assert_rejected { SiteSession.issue(grant:, audience: "   ", now:) }

    grant.update!(revoked_at: now)
    assert_rejected { SiteSession.issue(grant:, audience: AUDIENCE, now:) }
  end

  test "tampering and exact audience or Site mismatches always reject generically" do
    grant = create_grant
    now = Time.current
    issued = SiteSession.issue(grant:, audience: AUDIENCE, now:)
    other_site = Site.create!(slug: "other-site", name: "Other Site")

    assert_rejected do
      SiteSession.authenticate(
        token: "#{issued.token}tampered",
        audience: AUDIENCE,
        site: grant.site,
        now:
      )
    end
    assert_rejected do
      SiteSession.authenticate(
        token: issued.token,
        audience: "wrong.sites.localhost",
        site: grant.site,
        now:
      )
    end
    assert_rejected do
      SiteSession.authenticate(
        token: issued.token,
        audience: AUDIENCE,
        site: other_site,
        now:
      )
    end
  end

  test "authentication re-queries the Grant and enforces the exact expiry" do
    grant = create_grant
    now = Time.current
    issued = SiteSession.issue(grant:, audience: AUDIENCE, now:)

    assert_equal grant, SiteSession.authenticate(
      token: issued.token,
      audience: AUDIENCE,
      site: grant.site,
      now: issued.expires_at - 1.second
    )
    assert_rejected do
      SiteSession.authenticate(
        token: issued.token,
        audience: AUDIENCE,
        site: grant.site,
        now: issued.expires_at
      )
    end

    grant.update!(revoked_at: now)
    assert_rejected do
      SiteSession.authenticate(
        token: issued.token,
        audience: AUDIENCE,
        site: grant.site,
        now:
      )
    end
  end

  test "the injected clock governs issue and authentication" do
    grant = create_grant
    now = Time.utc(2000, 1, 1)
    issued = SiteSession.issue(grant:, audience: AUDIENCE, now:)

    assert_equal grant, SiteSession.authenticate(
      token: issued.token,
      audience: AUDIENCE,
      site: grant.site,
      now: now + 1.day
    )
  end

  private

  def assert_rejected(&)
    error = assert_raises(SiteSession::Rejected, &)
    assert_equal SiteSession::Rejected::MESSAGE, error.message
  end

  def create_grant
    site = Site.create!(slug: "first-site", name: "First Site")
    person = Person.create!(first_name: "Avery")
    Grant.create!(site:, person:)
  end
end
