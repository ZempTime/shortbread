# frozen_string_literal: true

class CreatePublishingRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :blobs do |t|
      t.string :sha256, limit: 64, null: false
      t.bigint :byte_size, null: false
      t.string :storage_key, null: false
      t.timestamps
    end
    add_index :blobs, :sha256, unique: true
    add_index :blobs, :storage_key, unique: true
    add_check_constraint :blobs, "sha256 ~ '^[0-9a-f]{64}$'", name: "blobs_sha256_format"
    add_check_constraint :blobs, "byte_size >= 0", name: "blobs_byte_size_nonnegative"

    create_table :releases do |t|
      t.references :site, null: false, foreign_key: true
      t.bigint :number, null: false
      t.string :manifest_sha256, limit: 64, null: false
      t.datetime :finalized_at, null: false
      t.timestamps
    end
    add_index :releases, [ :site_id, :number ], unique: true
    add_check_constraint :releases, "number > 0", name: "releases_number_positive"
    add_check_constraint :releases,
      "manifest_sha256 ~ '^[0-9a-f]{64}$'",
      name: "releases_manifest_sha256_format"

    add_reference :sites, :current_release, foreign_key: { to_table: :releases }

    create_table :manifest_entries do |t|
      t.references :release, null: false, foreign_key: true
      t.references :blob, null: false, foreign_key: true
      t.string :path, null: false
      t.bigint :byte_size, null: false
      t.string :content_type, null: false
      t.string :offline_policy, null: false
      t.timestamps
    end
    add_index :manifest_entries, [ :release_id, :path ], unique: true
    add_check_constraint :manifest_entries,
      "byte_size >= 0",
      name: "manifest_entries_byte_size_nonnegative"
    add_check_constraint :manifest_entries,
      "offline_policy IN ('required', 'optional', 'download')",
      name: "manifest_entries_offline_policy"

    create_table :publish_plans do |t|
      t.references :site, null: false, foreign_key: true
      t.references :base_release, foreign_key: { to_table: :releases }
      t.references :release, foreign_key: true, index: { unique: true }
      t.string :idempotency_key_digest, limit: 64, null: false
      t.string :manifest_sha256, limit: 64, null: false
      t.jsonb :manifest, null: false
      t.string :state, null: false
      t.datetime :expires_at, null: false
      t.datetime :finalized_at
      t.timestamps
    end
    add_index :publish_plans, [ :site_id, :idempotency_key_digest ], unique: true
    add_check_constraint :publish_plans,
      "idempotency_key_digest ~ '^[0-9a-f]{64}$'",
      name: "publish_plans_idempotency_key_digest_format"
    add_check_constraint :publish_plans,
      "manifest_sha256 ~ '^[0-9a-f]{64}$'",
      name: "publish_plans_manifest_sha256_format"
    add_check_constraint :publish_plans,
      "state IN ('open', 'finalized')",
      name: "publish_plans_state"
  end
end
