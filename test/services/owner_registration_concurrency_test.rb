# frozen_string_literal: true

require "test_helper"

require "securerandom"
require "webauthn/fake_client"

class OwnerRegistrationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup { clear_owner_auth_records }
  teardown { clear_owner_auth_records }

  test "simultaneous completion consumes one ceremony and creates exactly one Owner credential" do
    secret = SecureRandom.urlsafe_base64(32, false)
    ceremony = OwnerCeremony.issue_bootstrap!(secret:)
    public_key = OwnerRegistration.options!(secret:, webauthn: webauthn)
    credential = WebAuthn::FakeClient
      .new("http://localhost")
      .create(challenge: public_key.fetch(:challenge), rp_id: "localhost", user_verified: true)

    outcomes = race do
      OwnerRegistration.complete!(
        secret:,
        label: "Primary passkey",
        public_key_credential: credential.deep_dup,
        webauthn: webauthn
      )
    end

    assert_equal 1, outcomes.count { |outcome| outcome.is_a?(OwnerRegistration::Result) }
    assert_equal 1, outcomes.count { |outcome| outcome.is_a?(OwnerRegistration::Rejected) }
    assert_equal 1, Owner.count
    assert_equal 1, OwnerCredential.count
    assert_not_nil ceremony.reload.consumed_at
    assert_equal 1, ActiveRecord::Base.connection.select_value("SELECT 1")
  ensure
    secret&.clear
  end

  private

  def webauthn
    OwnerWebAuthn.new(
      apex_host: "localhost",
      rp_id: "localhost",
      origin: "http://localhost",
      local_environment: true
    )
  end

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

  def clear_owner_auth_records
    OwnerCredential.delete_all
    OwnerCeremony.delete_all
    Owner.delete_all
  end
end
