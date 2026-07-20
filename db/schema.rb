# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_19_145000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.datetime "created_at", null: false
    t.string "sha256", limit: 64, null: false
    t.string "storage_key", null: false
    t.datetime "updated_at", null: false
    t.index ["sha256"], name: "index_blobs_on_sha256", unique: true
    t.index ["storage_key"], name: "index_blobs_on_storage_key", unique: true
    t.check_constraint "byte_size >= 0", name: "blobs_byte_size_nonnegative"
    t.check_constraint "sha256::text ~ '^[0-9a-f]{64}$'::text", name: "blobs_sha256_format"
  end

  create_table "grants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "offline_allowed", default: false, null: false
    t.bigint "person_id", null: false
    t.datetime "revoked_at"
    t.bigint "site_id", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_grants_on_person_id"
    t.index ["site_id", "person_id"], name: "index_grants_on_site_id_and_person_id", unique: true
    t.index ["site_id"], name: "index_grants_on_site_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "grant_id", null: false
    t.string "locator", null: false
    t.datetime "revoked_at"
    t.string "secret_digest", limit: 64, null: false
    t.datetime "updated_at", null: false
    t.index ["grant_id"], name: "index_invitations_on_grant_id"
    t.index ["locator"], name: "index_invitations_on_locator", unique: true
    t.index ["secret_digest"], name: "index_invitations_on_secret_digest", unique: true
    t.check_constraint "secret_digest::text ~ '^[0-9a-f]{64}$'::text", name: "invitations_secret_digest_format"
  end

  create_table "manifest_entries", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.bigint "byte_size", null: false
    t.string "content_type", null: false
    t.datetime "created_at", null: false
    t.string "offline_policy", null: false
    t.string "path", null: false
    t.bigint "release_id", null: false
    t.datetime "updated_at", null: false
    t.index ["blob_id"], name: "index_manifest_entries_on_blob_id"
    t.index ["release_id", "path"], name: "index_manifest_entries_on_release_id_and_path", unique: true
    t.index ["release_id"], name: "index_manifest_entries_on_release_id"
    t.check_constraint "byte_size >= 0", name: "manifest_entries_byte_size_nonnegative"
    t.check_constraint "offline_policy::text = ANY (ARRAY['required'::character varying::text, 'optional'::character varying::text, 'download'::character varying::text])", name: "manifest_entries_offline_policy"
  end

  create_table "people", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "first_name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "publish_plans", force: :cascade do |t|
    t.bigint "base_release_id"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "finalized_at"
    t.string "idempotency_key_digest", limit: 64, null: false
    t.jsonb "manifest", null: false
    t.string "manifest_sha256", limit: 64, null: false
    t.bigint "release_id"
    t.bigint "site_id", null: false
    t.string "state", null: false
    t.datetime "updated_at", null: false
    t.index ["base_release_id"], name: "index_publish_plans_on_base_release_id"
    t.index ["release_id"], name: "index_publish_plans_on_release_id", unique: true
    t.index ["site_id", "idempotency_key_digest"], name: "index_publish_plans_on_site_id_and_idempotency_key_digest", unique: true
    t.index ["site_id"], name: "index_publish_plans_on_site_id"
    t.check_constraint "idempotency_key_digest::text ~ '^[0-9a-f]{64}$'::text", name: "publish_plans_idempotency_key_digest_format"
    t.check_constraint "manifest_sha256::text ~ '^[0-9a-f]{64}$'::text", name: "publish_plans_manifest_sha256_format"
    t.check_constraint "state::text = ANY (ARRAY['open'::character varying::text, 'finalized'::character varying::text])", name: "publish_plans_state"
  end

  create_table "releases", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "finalized_at", null: false
    t.string "manifest_sha256", limit: 64, null: false
    t.bigint "number", null: false
    t.bigint "site_id", null: false
    t.datetime "updated_at", null: false
    t.index ["site_id", "number"], name: "index_releases_on_site_id_and_number", unique: true
    t.index ["site_id"], name: "index_releases_on_site_id"
    t.check_constraint "manifest_sha256::text ~ '^[0-9a-f]{64}$'::text", name: "releases_manifest_sha256_format"
    t.check_constraint "number > 0", name: "releases_number_positive"
  end

  create_table "site_handoffs", force: :cascade do |t|
    t.string "audience", null: false
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "grant_id", null: false
    t.bigint "invitation_id", null: false
    t.string "nonce_digest", limit: 64, null: false
    t.datetime "updated_at", null: false
    t.index ["grant_id"], name: "index_site_handoffs_on_grant_id"
    t.index ["invitation_id"], name: "index_site_handoffs_on_invitation_id", unique: true
    t.index ["nonce_digest"], name: "index_site_handoffs_on_nonce_digest", unique: true
    t.check_constraint "nonce_digest::text ~ '^[0-9a-f]{64}$'::text", name: "site_handoffs_nonce_digest_format"
  end

  create_table "sites", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_release_id"
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["current_release_id"], name: "index_sites_on_current_release_id"
    t.index ["slug"], name: "index_sites_on_slug", unique: true
  end

  add_foreign_key "grants", "people"
  add_foreign_key "grants", "sites"
  add_foreign_key "invitations", "grants"
  add_foreign_key "manifest_entries", "blobs"
  add_foreign_key "manifest_entries", "releases"
  add_foreign_key "publish_plans", "releases"
  add_foreign_key "publish_plans", "releases", column: "base_release_id"
  add_foreign_key "publish_plans", "sites"
  add_foreign_key "releases", "sites"
  add_foreign_key "site_handoffs", "grants"
  add_foreign_key "site_handoffs", "invitations"
  add_foreign_key "sites", "releases", column: "current_release_id"
end
