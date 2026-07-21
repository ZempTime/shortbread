# frozen_string_literal: true

require "test_helper"

require "digest"
require "securerandom"

class ReleasesHistoryConcurrencyTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  setup do
    clear_records
    @previous_token = ENV["SHORTBREAD_BOOTSTRAP_TOKEN"]
    @token = SecureRandom.urlsafe_base64(32)
    ENV["SHORTBREAD_BOOTSTRAP_TOKEN"] = @token
  end

  teardown do
    ENV["SHORTBREAD_BOOTSTRAP_TOKEN"] = @previous_token
    clear_records
  end

  test "history waits for a concurrent current pointer transaction and returns one coherent snapshot" do
    site = Site.create!(slug: "first-site", name: "First Site")
    first = assembled_release(site:, number: 1, marker: "first")
    second = assembled_release(site:, number: 2, marker: "second")
    site.update!(current_release: first)
    started = Queue.new
    response = Queue.new
    reader = nil

    Site.transaction do
      locked_site = Site.lock.find(site.id)
      reader = Thread.new do
        session = ActionDispatch::Integration::Session.new(Rails.application)
        session.host! "localhost"
        started << true
        session.get(
          "/api/v1/sites/#{site.slug}/releases",
          headers: { "Authorization" => "Bearer #{@token}" },
          as: :json
        )
        response << [ session.response.status, session.response.parsed_body ]
      end
      started.pop
      sleep 0.05
      assert_predicate response, :empty?, "history must wait on the Site lock"
      locked_site.update!(current_release: second)
    end
    reader.value

    status, payload = response.pop
    assert_equal 200, status
    assert_equal 2, payload.dig("site", "current_release_number")
    assert_equal [ 2, 1 ], payload.fetch("releases").pluck("number")
    assert_equal [ true, false ], payload.fetch("releases").pluck("current")
  ensure
    if reader&.alive?
      reader.kill
      reader.join
    end
  end

  private

  def assembled_release(site:, number:, marker:)
    digest = Digest::SHA256.hexdigest(marker)
    blob = Blob.create!(sha256: digest, byte_size: marker.bytesize, storage_key: digest)
    assemble_test_release!(
      site:, number:, manifest_sha256: Digest::SHA256.hexdigest("manifest-#{marker}"), finalized_at: Time.current,
      entries: [ {
        blob:, path: "index.html", byte_size: marker.bytesize, content_type: "text/html", offline_policy: "required"
      } ]
    )
  end

  def clear_records
    ActiveRecord::Base.connection.execute(<<~SQL)
      TRUNCATE TABLE release_rollbacks, publish_plans, manifest_entries, releases, blobs, grants, invitations, sites
      RESTART IDENTITY CASCADE
    SQL
  end
end
