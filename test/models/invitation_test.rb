# frozen_string_literal: true

require "test_helper"

require "digest"

class InvitationTest < ActiveSupport::TestCase
  test "issuance retries a locator collision without changing the commitment" do
    grant = create_grant
    existing_locator = "a" * 32
    Invitation.create!(
      grant:,
      locator: existing_locator,
      secret_digest: Digest::SHA256.hexdigest("existing secret"),
      expires_at: 1.hour.from_now
    )
    locators = [ existing_locator, "b" * 32 ]

    invitation = SecureRandom.stub(:urlsafe_base64, ->(_bytes, _padding) { locators.shift }) do
      Invitation.issue!(
        grant:,
        secret_digest: Digest::SHA256.hexdigest("new secret")
      )
    end

    assert_equal "b" * 32, invitation.locator
    assert invitation.pending?
  end

  test "an Invitation is pending only while its Grant and one-time window are live" do
    grant = create_grant
    invitation = Invitation.issue!(
      grant:,
      secret_digest: Digest::SHA256.hexdigest("synthetic secret")
    )
    assert invitation.pending?

    invitation.update!(accepted_at: Time.current)
    refute invitation.pending?
    invitation.update!(accepted_at: nil, revoked_at: Time.current)
    refute invitation.pending?
    invitation.update!(revoked_at: nil)
    grant.update!(revoked_at: Time.current)
    refute invitation.pending?
  end

  private

  def create_grant
    site = Site.create!(slug: "first-site", name: "First Site")
    person = Person.create!(first_name: "Avery")
    Grant.create!(site:, person:)
  end
end

class InvitationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup { clear_invitation_records }
  teardown { clear_invitation_records }

  test "a concurrent duplicate commitment leaves one Invitation and a usable connection" do
    site = Site.create!(slug: "first-site", name: "First Site")
    grants = 2.times.map do |index|
      person = Person.create!(first_name: "Viewer #{index}")
      Grant.create!(site:, person:)
    end
    secret_digest = Digest::SHA256.hexdigest("shared synthetic secret")
    ready = Queue.new
    start = Queue.new
    results = Queue.new

    threads = grants.map do |grant|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          concurrent_grant = Grant.find(grant.id)
          ready << true
          start.pop
          result = Invitation.issue!(grant: concurrent_grant, secret_digest:)
          results << result
        rescue StandardError => error
          results << error
        end
      end
    end
    2.times { ready.pop }
    2.times { start << true }
    threads.each(&:join)
    outcomes = 2.times.map { results.pop }

    assert_equal 1, Invitation.where(secret_digest:).count
    assert_equal 1, outcomes.count { |outcome| outcome.is_a?(Invitation) }
    assert_equal 1, outcomes.count { |outcome| outcome.is_a?(Invitation::DuplicateSecretDigest) }
    assert_equal 1, ActiveRecord::Base.connection.select_value("SELECT 1")
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
  end

  private

  def clear_invitation_records
    Invitation.delete_all
    Grant.delete_all
    Person.delete_all
    Site.delete_all
  end
end
