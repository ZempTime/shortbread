# frozen_string_literal: true

require "test_helper"

require "digest"
require "securerandom"

class ReleaseRollbacksTest < ActiveSupport::TestCase
  test "rollback requires an idempotency key and a target Release from the Site" do
    site, first_release, second_release = site_with_two_releases("first-site")
    other_site, = site_with_two_releases("other-site")
    site.update!(current_release: second_release)

    assert_raises(ReleaseRollbacks::IdempotencyKeyRequired) do
      ReleaseRollbacks.perform(site:, release_number: first_release.number, idempotency_key: "")
    end
    assert_raises(ReleaseRollbacks::ReleaseNotFound) do
      ReleaseRollbacks.perform(
        site: other_site,
        release_number: 99,
        idempotency_key: SecureRandom.urlsafe_base64(32, false)
      )
    end

    assert_equal second_release, site.reload.current_release
    assert_equal 0, ReleaseRollback.count
  end

  test "rollback is pointer-only and replays its exact result or rejects conflicting key reuse" do
    site, first_release, second_release = site_with_two_releases("first-site")
    site.update!(current_release: second_release)
    key = "synthetic-private-rollback-key"

    result = ReleaseRollbacks.perform(site:, release_number: first_release.number, idempotency_key: key)

    assert_predicate result, :created
    assert_predicate result, :changed
    assert_equal second_release, result.from_release
    assert_equal first_release, result.to_release
    assert_equal first_release, site.reload.current_release
    assert_equal [ 1, 2 ], site.releases.order(:number).pluck(:number)
    assert_equal 1, ReleaseRollback.count
    refute_includes ReleaseRollback.sole.attributes.to_json, key

    site.update!(current_release: second_release)
    replay = ReleaseRollbacks.perform(site:, release_number: first_release.number, idempotency_key: key)
    assert_not replay.created
    assert_predicate replay, :changed
    assert_equal result.rollback.id, replay.rollback.id
    assert_equal second_release, replay.from_release
    assert_equal first_release, replay.to_release
    assert_equal second_release, site.reload.current_release,
      "an exact replay reports the recorded result and must not reapply it"

    assert_raises(ReleaseRollbacks::IdempotencyConflict) do
      ReleaseRollbacks.perform(site:, release_number: second_release.number, idempotency_key: key)
    end
    assert_equal second_release, site.reload.current_release
    assert_equal 1, ReleaseRollback.count
  end

  test "rolling back to the current Release records a precise no-op" do
    site, _first_release, second_release = site_with_two_releases("first-site")
    site.update!(current_release: second_release)

    result = ReleaseRollbacks.perform(
      site:,
      release_number: second_release.number,
      idempotency_key: SecureRandom.urlsafe_base64(32, false)
    )

    assert_predicate result, :created
    assert_not result.changed
    assert_equal second_release, result.from_release
    assert_equal second_release, result.to_release
    assert_equal second_release, site.reload.current_release
  end

  private

  def site_with_two_releases(slug)
    site = Site.create!(slug:, name: slug.titleize)
    first = assembled_release(site:, number: 1, manifest_sha256: "a" * 64, finalized_at: 2.minutes.ago)
    second = assembled_release(site:, number: 2, manifest_sha256: "b" * 64, finalized_at: 1.minute.ago)
    [ site, first, second ]
  end

  def assembled_release(site:, number:, manifest_sha256:, finalized_at:)
    digest = Digest::SHA256.hexdigest("#{site.slug}:#{number}")
    blob = Blob.create!(sha256: digest, byte_size: 1, storage_key: digest)
    assemble_test_release!(
      site:, number:, manifest_sha256:, finalized_at:,
      entries: [ {
        blob:, path: "index.html", byte_size: 1, content_type: "text/html", offline_policy: "required"
      } ]
    )
  end
end
