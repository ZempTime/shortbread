ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "digest"
require "securerandom"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def assemble_test_release!(site:, number:, manifest_sha256:, finalized_at:, entries:)
      manifest = entries.map do |entry|
        {
          "path" => entry.fetch(:path),
          "sha256" => entry.fetch(:blob).sha256,
          "size" => entry.fetch(:byte_size),
          "content_type" => entry.fetch(:content_type),
          "offline_policy" => entry.fetch(:offline_policy)
        }
      end
      plan = site.publish_plans.create!(
        base_release: site.current_release,
        idempotency_key_digest: ::Digest::SHA256.hexdigest(SecureRandom.urlsafe_base64(32, false)),
        manifest_sha256:,
        manifest: { "entries" => manifest },
        state: "open",
        expires_at: 1.hour.from_now
      )
      release = site.releases.create!(number:, manifest_sha256:)
      plan.update!(release:)
      entries.each { |entry| release.manifest_entries.create!(**entry) }
      release.update!(finalized_at:)
      plan.update!(state: "finalized", finalized_at:)
      release
    end
  end
end
