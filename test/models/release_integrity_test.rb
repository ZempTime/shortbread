# frozen_string_literal: true

require "test_helper"

class ReleaseIntegrityTest < ActiveSupport::TestCase
  test "PostgreSQL rejects direct mutation of historical Release content" do
    site = Site.create!(slug: "first-site", name: "First Site")
    blob = Blob.create!(sha256: "c" * 64, byte_size: 4, storage_key: "c" * 64)
    release = site.releases.create!(number: 1, manifest_sha256: "a" * 64, finalized_at: Time.current)
    entry = release.manifest_entries.create!(
      blob:,
      path: "index.html",
      byte_size: 4,
      content_type: "text/html",
      offline_policy: "required"
    )

    assert_database_rejects(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.execute(
        "UPDATE releases SET manifest_sha256 = '#{"b" * 64}' WHERE id = #{release.id}"
      )
    end
    assert_database_rejects(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.execute(
        "UPDATE manifest_entries SET path = 'changed.html' WHERE id = #{entry.id}"
      )
    end

    assert_equal "a" * 64, release.reload.manifest_sha256
    assert_equal "index.html", entry.reload.path
  end

  test "PostgreSQL rejects cross-Site current, plan, and rollback Release references" do
    first_site = Site.create!(slug: "first-site", name: "First Site")
    second_site = Site.create!(slug: "second-site", name: "Second Site")
    first_release = first_site.releases.create!(number: 1, manifest_sha256: "a" * 64, finalized_at: Time.current)
    second_release = second_site.releases.create!(number: 1, manifest_sha256: "b" * 64, finalized_at: Time.current)

    assert_database_rejects(ActiveRecord::InvalidForeignKey) do
      Site.where(id: first_site.id).update_all(current_release_id: second_release.id)
    end
    assert_database_rejects(ActiveRecord::InvalidForeignKey) do
      PublishPlan.insert!({
        site_id: first_site.id,
        base_release_id: second_release.id,
        idempotency_key_digest: "c" * 64,
        manifest_sha256: "d" * 64,
        manifest: { entries: [] },
        state: "open",
        expires_at: 1.hour.from_now,
        created_at: Time.current,
        updated_at: Time.current
      })
    end
    assert_database_rejects(ActiveRecord::InvalidForeignKey) do
      ReleaseRollback.insert!({
        site_id: first_site.id,
        from_release_id: first_release.id,
        to_release_id: second_release.id,
        idempotency_key_digest: "e" * 64,
        created_at: Time.current,
        updated_at: Time.current
      })
    end

    assert_nil first_site.reload.current_release
  end

  private

  def assert_database_rejects(error_class, &)
    assert_raises(error_class) do
      ApplicationRecord.transaction(requires_new: true, &)
    end
  end
end
