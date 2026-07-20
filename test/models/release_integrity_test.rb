# frozen_string_literal: true

require "test_helper"

class ReleaseIntegrityTest < ActiveSupport::TestCase
  test "PostgreSQL rejects deleting content from an immutable Release" do
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

    assert_raises(ActiveRecord::StatementInvalid) do
      ApplicationRecord.transaction(requires_new: true) do
        ActiveRecord::Base.connection.execute("DELETE FROM manifest_entries WHERE id = #{entry.id}")
      end
    end

    assert_equal [ "index.html" ], release.reload.manifest_entries.pluck(:path)
  end
end
