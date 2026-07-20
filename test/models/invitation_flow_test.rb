# frozen_string_literal: true

require "test_helper"

require "digest"
require "securerandom"

class InvitationFlowTest < ActiveSupport::TestCase
  AUDIENCE = "first-site.sites.localhost"

  test "a wrong secret rejects without accepting the Invitation or creating a handoff" do
    invitation, = issue_invitation

    assert_rejected do
      InvitationFlow.accept!(
        locator: invitation.locator,
        secret: invitation_secret,
        audience: AUDIENCE
      )
    end

    assert_nil invitation.reload.accepted_at
    assert_not SiteHandoff.exists?(invitation:)
  end

  test "an Invitation can be accepted only once" do
    invitation, secret = issue_invitation

    InvitationFlow.accept!(locator: invitation.locator, secret:, audience: AUDIENCE)

    assert_rejected do
      InvitationFlow.accept!(locator: invitation.locator, secret:, audience: AUDIENCE)
    end
    assert_equal 1, SiteHandoff.where(invitation:).count
  end

  test "a handoff rejects tampering and exact audience or Site mismatches without being consumed" do
    invitation, secret = issue_invitation
    acceptance = InvitationFlow.accept!(locator: invitation.locator, secret:, audience: AUDIENCE)
    other_site = Site.create!(slug: "other-site", name: "Other Site")

    assert_rejected do
      InvitationFlow.exchange!(token: "#{acceptance.token}tampered", audience: AUDIENCE, site: acceptance.site)
    end
    assert_rejected do
      InvitationFlow.exchange!(token: acceptance.token, audience: "wrong.sites.localhost", site: acceptance.site)
    end
    assert_rejected do
      InvitationFlow.exchange!(token: acceptance.token, audience: AUDIENCE, site: other_site)
    end

    assert_nil invitation.site_handoff.reload.consumed_at
  end

  test "a matching handoff exchanges once for its active Grant" do
    invitation, secret = issue_invitation
    acceptance = InvitationFlow.accept!(locator: invitation.locator, secret:, audience: AUDIENCE)

    grant = InvitationFlow.exchange!(token: acceptance.token, audience: AUDIENCE, site: acceptance.site)

    assert_equal invitation.grant, grant
    assert_not_nil invitation.site_handoff.reload.consumed_at
    assert_rejected do
      InvitationFlow.exchange!(token: acceptance.token, audience: AUDIENCE, site: acceptance.site)
    end
  end

  test "a revoked Grant rejects an otherwise valid handoff" do
    invitation, secret = issue_invitation
    acceptance = InvitationFlow.accept!(locator: invitation.locator, secret:, audience: AUDIENCE)
    invitation.grant.update!(revoked_at: Time.current)

    assert_rejected do
      InvitationFlow.exchange!(token: acceptance.token, audience: AUDIENCE, site: acceptance.site)
    end
    assert_nil invitation.site_handoff.reload.consumed_at
  end

  test "a maximum-length valid Site origin can be accepted and exchanged" do
    apex_host = [ "a" * 63, "b" * 63, "c" * 55 ].join(".")
    slug = "s" * 63
    site_host = "#{slug}.sites.#{apex_host}"
    parsed_host = Shortbread::Hosts.parse(
      host: site_host,
      scheme: "https",
      port: 65_535,
      apex_host:
    )
    audience = parsed_host.site_origin
    assert_equal 267, audience.bytesize

    site = Site.create!(slug:, name: "Maximum Site")
    person = Person.create!(first_name: "Avery")
    grant = Grant.create!(site:, person:)
    secret = invitation_secret
    invitation = Invitation.issue!(grant:, secret_digest: Digest::SHA256.hexdigest(secret))

    acceptance = InvitationFlow.accept!(locator: invitation.locator, secret:, audience:)

    assert_equal audience, invitation.site_handoff.audience
    assert_equal grant, InvitationFlow.exchange!(token: acceptance.token, audience:, site:)
  end

  private

  def assert_rejected(&)
    error = assert_raises(InvitationFlow::Rejected, &)
    assert_equal InvitationFlow::Rejected::MESSAGE, error.message
  end

  def issue_invitation
    site = Site.create!(slug: "first-site", name: "First Site")
    person = Person.create!(first_name: "Avery")
    grant = Grant.create!(site:, person:)
    secret = invitation_secret
    invitation = Invitation.issue!(grant:, secret_digest: Digest::SHA256.hexdigest(secret))
    [ invitation, secret ]
  end

  def invitation_secret
    SecureRandom.urlsafe_base64(32, false)
  end
end
