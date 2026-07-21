# frozen_string_literal: true

require "test_helper"

require "digest"
require "securerandom"
require "stringio"
require "tmpdir"

class PublishingConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup { clear_publishing_records }
  teardown { clear_publishing_records }

  test "simultaneous complete plans publish exactly one current Release" do
    site = Site.create!(slug: "first-site", name: "First Site")
    content = "shared immutable bytes"
    sha256 = Digest::SHA256.hexdigest(content)
    manifest = {
      entries: [ {
        path: "index.html",
        sha256:,
        size: content.bytesize,
        content_type: "text/html",
        offline_policy: "required"
      } ]
    }

    Dir.mktmpdir("shortbread-publish-race") do |root|
      store = LocalBlobStore.new(root:)
      store.put_verified(io: StringIO.new(content), sha256:, byte_size: content.bytesize)
      Blob.create!(sha256:, byte_size: content.bytesize, storage_key: sha256)
      plans = 2.times.map do
        Publishing.plan(
          site:,
          idempotency_key: SecureRandom.urlsafe_base64(32, false),
          manifest:
        ).publish_plan
      end

      ready = Queue.new
      start = Queue.new
      results = Queue.new
      gated_store = GatedBlobStore.new(delegate: store, ready:, start:)

      threads = plans.map do |plan|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            concurrent_plan = PublishPlan.find(plan.id)
            results << Publishing.finalize(publish_plan: concurrent_plan, blob_store: gated_store)
          rescue StandardError => error
            results << error
          end
        end
      end

      2.times { ready.pop }
      2.times { start << true }
      threads.each(&:join)
      outcomes = 2.times.map { results.pop }

      assert_equal 1, outcomes.count { |outcome| outcome.is_a?(Publishing::FinalizeResult) && outcome.created }
      assert_equal 1, outcomes.count { |outcome| outcome.is_a?(Publishing::StalePublishPlan) }
      assert_equal 1, Release.count
      assert_equal 1, ManifestEntry.count
      assert_equal Release.sole, site.reload.current_release
      assert_equal 1, ActiveRecord::Base.connection.select_value("SELECT 1")
    ensure
      threads&.each { |thread| thread.kill if thread.alive? }
    end
  end

  test "Release finalization serializes a concurrent late Manifest Entry" do
    site = Site.create!(slug: "first-site", name: "First Site")
    first_blob = Blob.create!(sha256: "a" * 64, byte_size: 1, storage_key: "a" * 64)
    late_blob = Blob.create!(sha256: "b" * 64, byte_size: 1, storage_key: "b" * 64)
    plan = site.publish_plans.create!(
      idempotency_key_digest: "d" * 64,
      manifest_sha256: "c" * 64,
      manifest: { "entries" => [ {
        "path" => "index.html", "sha256" => first_blob.sha256, "size" => 1,
        "content_type" => "text/html", "offline_policy" => "required"
      } ] },
      state: "open",
      expires_at: 1.hour.from_now
    )
    release = site.releases.create!(number: 1, manifest_sha256: "c" * 64)
    plan.update!(release:)
    release.manifest_entries.create!(
      blob: first_blob, path: "index.html", byte_size: 1, content_type: "text/html", offline_policy: "required"
    )
    finalized = Queue.new
    commit = Queue.new
    result = Queue.new

    finalizer = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        Release.transaction do
          Release.find(release.id).update!(finalized_at: Time.current)
          PublishPlan.find(plan.id).update!(state: "finalized", finalized_at: Time.current)
          finalized << true
          commit.pop
        end
      end
    end
    finalized.pop
    inserter = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        result << begin
          ManifestEntry.create!(
            release_id: release.id,
            blob: late_blob,
            path: "late.txt",
            byte_size: 1,
            content_type: "text/plain",
            offline_policy: "download"
          )
        rescue StandardError => error
          error
        end
      end
    end
    commit << true
    finalizer.join
    inserter.join

    assert_instance_of ActiveRecord::StatementInvalid, result.pop
    assert_equal [ "index.html" ], release.reload.manifest_entries.pluck(:path)
    assert_predicate release.finalized_at, :present?
  ensure
    commit << true if finalizer&.alive?
    finalizer&.kill
    inserter&.kill
  end

  private

  GatedBlobStore = Data.define(:delegate, :ready, :start) do
    def verified?(**)
      ready << true
      start.pop
      delegate.verified?(**)
    end
  end

  def clear_publishing_records
    ActiveRecord::Base.connection.execute(<<~SQL)
      TRUNCATE TABLE release_rollbacks, publish_plans, manifest_entries, releases, blobs, grants, invitations, sites
      RESTART IDENTITY CASCADE
    SQL
  end
end
