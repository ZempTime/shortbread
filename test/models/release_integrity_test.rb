# frozen_string_literal: true

require "test_helper"

require "digest"

class ReleaseIntegrityTest < ActiveSupport::TestCase
  test "PostgreSQL rejects direct mutation of historical Release content" do
    site = Site.create!(slug: "first-site", name: "First Site")
    blob = Blob.create!(sha256: "c" * 64, byte_size: 4, storage_key: "c" * 64)
    release = assemble_test_release!(
      site:, number: 1, manifest_sha256: "a" * 64, finalized_at: Time.current,
      entries: [ { blob:, path: "index.html", byte_size: 4, content_type: "text/html", offline_policy: "required" } ]
    )
    entry = release.manifest_entries.sole

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

  test "PostgreSQL rejects deleting content from an immutable Release" do
    site = Site.create!(slug: "first-site", name: "First Site")
    blob = Blob.create!(sha256: "c" * 64, byte_size: 4, storage_key: "c" * 64)
    release = assemble_test_release!(
      site:, number: 1, manifest_sha256: "a" * 64, finalized_at: Time.current,
      entries: [ { blob:, path: "index.html", byte_size: 4, content_type: "text/html", offline_policy: "required" } ]
    )
    entry = release.manifest_entries.sole

    assert_database_rejects(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.execute("DELETE FROM manifest_entries WHERE id = #{entry.id}")
    end

    assert_equal [ "index.html" ], release.reload.manifest_entries.pluck(:path)
  end

  test "PostgreSQL rejects appending content after Release finalization" do
    site = Site.create!(slug: "first-site", name: "First Site")
    blob = Blob.create!(sha256: "c" * 64, byte_size: 4, storage_key: "c" * 64)
    release = assemble_test_release!(
      site:, number: 1, manifest_sha256: "a" * 64, finalized_at: Time.current,
      entries: [ { blob:, path: "index.html", byte_size: 4, content_type: "text/html", offline_policy: "required" } ]
    )

    assert_database_rejects(ActiveRecord::StatementInvalid) do
      release.manifest_entries.create!(
        blob:,
        path: "late.html",
        byte_size: 4,
        content_type: "text/html",
        offline_policy: "required"
      )
    end

    assert_equal [ "index.html" ], release.reload.manifest_entries.pluck(:path)
  end

  test "PostgreSQL rejects pre-finalized insertion and empty finalization" do
    site = Site.create!(slug: "first-site", name: "First Site")

    assert_database_rejects(ActiveRecord::StatementInvalid) do
      site.releases.create!(number: 1, manifest_sha256: "a" * 64, finalized_at: Time.current)
    end
    release = site.releases.create!(number: 1, manifest_sha256: "a" * 64)
    assert_database_rejects(ActiveRecord::StatementInvalid) do
      release.update!(finalized_at: Time.current)
    end

    assert_nil release.reload.finalized_at
    assert_nil site.reload.current_release_id
  end

  test "PostgreSQL rejects finalization through malformed or duplicate Publish Plan entries" do
    site = Site.create!(slug: "first-site", name: "First Site")
    first_blob = Blob.create!(sha256: "a" * 64, byte_size: 1, storage_key: "a" * 64)
    second_blob = Blob.create!(sha256: "b" * 64, byte_size: 1, storage_key: "b" * 64)

    malformed_plan = site.publish_plans.create!(
      idempotency_key_digest: "c" * 64,
      manifest_sha256: "d" * 64,
      manifest: { "entries" => [ { "path" => "index.html" } ] },
      state: "open",
      expires_at: 1.hour.from_now
    )
    malformed_release = site.releases.create!(number: 1, manifest_sha256: "d" * 64)
    malformed_plan.update!(release: malformed_release)
    malformed_release.manifest_entries.create!(
      blob: first_blob, path: "index.html", byte_size: 1, content_type: "text/html", offline_policy: "required"
    )

    assert_database_rejects(ActiveRecord::StatementInvalid) do
      malformed_release.update!(finalized_at: Time.current)
    end

    duplicate_entry = {
      "path" => "index.html", "sha256" => first_blob.sha256, "size" => 1,
      "content_type" => "text/html", "offline_policy" => "required"
    }
    duplicate_plan = site.publish_plans.create!(
      idempotency_key_digest: "e" * 64,
      manifest_sha256: "f" * 64,
      manifest: { "entries" => [ duplicate_entry, duplicate_entry ] },
      state: "open",
      expires_at: 1.hour.from_now
    )
    duplicate_release = site.releases.create!(number: 2, manifest_sha256: "f" * 64)
    duplicate_plan.update!(release: duplicate_release)
    duplicate_release.manifest_entries.create!(
      blob: first_blob, path: "index.html", byte_size: 1, content_type: "text/html", offline_policy: "required"
    )
    duplicate_release.manifest_entries.create!(
      blob: second_blob, path: "extra.txt", byte_size: 1, content_type: "text/plain", offline_policy: "download"
    )

    assert_database_rejects(ActiveRecord::StatementInvalid) do
      duplicate_release.update!(finalized_at: Time.current)
    end
  end

  test "PostgreSQL rejects finalization through empty or non-index Publish Plans" do
    site = Site.create!(slug: "first-site", name: "First Site")
    empty_plan = site.publish_plans.create!(
      idempotency_key_digest: "a" * 64,
      manifest_sha256: "b" * 64,
      manifest: { "entries" => [] },
      state: "open",
      expires_at: 1.hour.from_now
    )
    empty_release = site.releases.create!(number: 1, manifest_sha256: "b" * 64)
    empty_plan.update!(release: empty_release)

    assert_database_rejects(ActiveRecord::StatementInvalid) do
      empty_release.update!(finalized_at: Time.current)
    end

    blob = Blob.create!(sha256: "c" * 64, byte_size: 1, storage_key: "c" * 64)
    non_index_entry = {
      "path" => "foo.txt", "sha256" => blob.sha256, "size" => 1,
      "content_type" => "text/plain", "offline_policy" => "download"
    }
    non_index_plan = site.publish_plans.create!(
      idempotency_key_digest: "d" * 64,
      manifest_sha256: "e" * 64,
      manifest: { "entries" => [ non_index_entry ] },
      state: "open",
      expires_at: 1.hour.from_now
    )
    non_index_release = site.releases.create!(number: 2, manifest_sha256: "e" * 64)
    non_index_plan.update!(release: non_index_release)
    non_index_release.manifest_entries.create!(
      blob:, path: "foo.txt", byte_size: 1, content_type: "text/plain", offline_policy: "download"
    )

    assert_database_rejects(ActiveRecord::StatementInvalid) do
      non_index_release.update!(finalized_at: Time.current)
    end

    assert_nil site.reload.current_release_id
  end

  test "PostgreSQL rejects exposing a finalized Release while its Publish Plan remains open" do
    site = Site.create!(slug: "first-site", name: "First Site")
    blob = Blob.create!(sha256: "a" * 64, byte_size: 1, storage_key: "a" * 64)
    entry = {
      "path" => "index.html", "sha256" => blob.sha256, "size" => 1,
      "content_type" => "text/html", "offline_policy" => "required"
    }
    plan = site.publish_plans.create!(
      idempotency_key_digest: "c" * 64,
      manifest_sha256: "d" * 64,
      manifest: { "entries" => [ entry ] },
      state: "open",
      expires_at: 1.hour.from_now
    )
    release = site.releases.create!(number: 1, manifest_sha256: "d" * 64)
    plan.update!(release:)
    release.manifest_entries.create!(
      blob:, path: "index.html", byte_size: 1, content_type: "text/html", offline_policy: "required"
    )
    release.update!(finalized_at: Time.current)

    assert_database_rejects(ActiveRecord::StatementInvalid) do
      site.update!(current_release: release)
    end

    assert_nil site.reload.current_release_id
    assert_predicate plan.reload, :open?
  end

  test "PostgreSQL retains finalized publish and rollback idempotency rows" do
    site = Site.create!(slug: "first-site", name: "First Site")
    first = assemble_release(site:, number: 1, manifest_sha256: "a" * 64, finalized_at: 2.minutes.ago)
    second = assemble_release(site:, number: 2, manifest_sha256: "b" * 64, finalized_at: 1.minute.ago)
    plan = PublishPlan.find_by!(release: second)
    rollback = site.release_rollbacks.create!(
      from_release: second,
      to_release: first,
      idempotency_key_digest: "e" * 64
    )

    assert_database_rejects(ActiveRecord::StatementInvalid) { plan.delete }
    assert_database_rejects(ActiveRecord::StatementInvalid) { rollback.delete }
    assert_equal [ plan.id ], PublishPlan.where(id: plan.id).pluck(:id)
    assert_equal [ rollback.id ], ReleaseRollback.where(id: rollback.id).pluck(:id)
  end

  test "PostgreSQL rejects an incompatible Release and a pre-finalized Publish Plan" do
    site = Site.create!(slug: "first-site", name: "First Site")
    release = assemble_release(site:, number: 1, manifest_sha256: "a" * 64, finalized_at: Time.current)
    plan = site.publish_plans.create!(
      idempotency_key_digest: "c" * 64,
      manifest_sha256: "d" * 64,
      manifest: { "entries" => [ { "path" => "index.html" } ] },
      state: "open",
      expires_at: 1.hour.from_now
    )

    assert_database_rejects(ActiveRecord::StatementInvalid) do
      plan.update!(release:, state: "finalized", finalized_at: Time.current)
    end
    assert_database_rejects(ActiveRecord::StatementInvalid) do
      PublishPlan.insert!({
        site_id: site.id,
        release_id: release.id,
        idempotency_key_digest: "e" * 64,
        manifest_sha256: release.manifest_sha256,
        manifest: { "entries" => [ { "path" => "index.html" } ] },
        state: "finalized",
        expires_at: 1.hour.from_now,
        finalized_at: Time.current,
        created_at: Time.current,
        updated_at: Time.current
      })
    end
    assert_predicate plan.reload, :open?
    assert_nil plan.release_id
  end

  test "PostgreSQL rejects Publish Plan input mutation and an unfinalized current pointer" do
    site = Site.create!(slug: "first-site", name: "First Site")
    plan = site.publish_plans.create!(
      idempotency_key_digest: "c" * 64,
      manifest_sha256: "d" * 64,
      manifest: { "entries" => [ { "path" => "index.html" } ] },
      state: "open",
      expires_at: 1.hour.from_now
    )
    release = site.releases.create!(number: 1, manifest_sha256: "a" * 64)

    assert_database_rejects(ActiveRecord::StatementInvalid) do
      PublishPlan.where(id: plan.id).update_all(manifest_sha256: "f" * 64)
    end
    assert_database_rejects(ActiveRecord::StatementInvalid) do
      Site.where(id: site.id).update_all(current_release_id: release.id)
    end

    assert_equal "d" * 64, plan.reload.manifest_sha256
    assert_nil site.reload.current_release_id
  end

  test "PostgreSQL rejects cross-Site current, plan, and rollback Release references" do
    first_site = Site.create!(slug: "first-site", name: "First Site")
    second_site = Site.create!(slug: "second-site", name: "Second Site")
    first_release = assemble_release(site: first_site, number: 1, manifest_sha256: "a" * 64, finalized_at: Time.current)
    second_release = assemble_release(site: second_site, number: 1, manifest_sha256: "b" * 64, finalized_at: Time.current)

    assert_database_rejects(ActiveRecord::StatementInvalid) do
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

  def assemble_release(site:, number:, manifest_sha256:, finalized_at:)
    blob_digest = Digest::SHA256.hexdigest("#{site.slug}:#{number}")
    blob = Blob.find_or_create_by!(sha256: blob_digest) do |record|
      record.byte_size = 1
      record.storage_key = blob_digest
    end
    assemble_test_release!(
      site:, number:, manifest_sha256:, finalized_at:,
      entries: [ {
        blob:, path: "index.html", byte_size: 1, content_type: "text/html", offline_policy: "required"
      } ]
    )
  end

  def assert_database_rejects(error_class, &)
    assert_raises(error_class) do
      ApplicationRecord.transaction(requires_new: true, &)
    end
  end
end
