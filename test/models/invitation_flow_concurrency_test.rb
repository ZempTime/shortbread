# frozen_string_literal: true

require "test_helper"

require "digest"
require "securerandom"

class InvitationFlowConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  AUDIENCE = "https://first-site.sites.localhost"

  setup { clear_invitation_flow_records }
  teardown { clear_invitation_flow_records }

  test "simultaneous acceptance consumes an Invitation exactly once" do
    site = Site.create!(slug: "first-site", name: "First Site")
    person = Person.create!(first_name: "Avery")
    grant = Grant.create!(site:, person:)
    secret = SecureRandom.urlsafe_base64(32, false)
    invitation = Invitation.issue!(grant:, secret_digest: Digest::SHA256.hexdigest(secret))

    outcomes = race do
      InvitationFlow.accept!(locator: invitation.locator, secret:, audience: AUDIENCE)
    end

    assert_equal 1, outcomes.count { |outcome| outcome.is_a?(InvitationFlow::Acceptance) }
    assert_equal 1, outcomes.count { |outcome| outcome.is_a?(InvitationFlow::Rejected) }
    assert_not_nil invitation.reload.accepted_at
    assert_equal 1, SiteHandoff.where(invitation:).count
    assert_equal 1, ActiveRecord::Base.connection.select_value("SELECT 1")
  end

  test "simultaneous exchange consumes a handoff exactly once" do
    site = Site.create!(slug: "first-site", name: "First Site")
    person = Person.create!(first_name: "Avery")
    grant = Grant.create!(site:, person:)
    secret = SecureRandom.urlsafe_base64(32, false)
    invitation = Invitation.issue!(grant:, secret_digest: Digest::SHA256.hexdigest(secret))
    acceptance = InvitationFlow.accept!(locator: invitation.locator, secret:, audience: AUDIENCE)

    outcomes = race do
      InvitationFlow.exchange!(
        token: acceptance.token,
        audience: AUDIENCE,
        site: Site.find(site.id)
      )
    end

    assert_equal 1, outcomes.count { |outcome| outcome.is_a?(Grant) && outcome.id == grant.id }
    assert_equal 1, outcomes.count { |outcome| outcome.is_a?(InvitationFlow::Rejected) }
    assert_not_nil invitation.site_handoff.reload.consumed_at
    assert_equal 1, ActiveRecord::Base.connection.select_value("SELECT 1")
  end

  private

  def race
    ready = Queue.new
    start = Queue.new
    results = Queue.new
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          results << yield
        rescue StandardError => error
          results << error
        end
      end
    end

    2.times { ready.pop }
    2.times { start << true }
    threads.each(&:join)
    2.times.map { results.pop }
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
  end

  def clear_invitation_flow_records
    SiteHandoff.delete_all
    Invitation.delete_all
    Grant.delete_all
    Person.delete_all
    Site.delete_all
  end
end
