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

ActiveRecord::Schema[8.1].define(version: 2026_07_20_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_idempotency_records", force: :cascade do |t|
    t.bigint "api_token_id", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key_digest", limit: 64, null: false
    t.string "operation", limit: 64, null: false
    t.string "request_fingerprint", limit: 64, null: false
    t.jsonb "response_body", null: false
    t.integer "response_status", null: false
    t.datetime "updated_at", null: false
    t.index ["api_token_id", "key_digest"], name: "index_api_idempotency_records_on_api_token_id_and_key_digest", unique: true
    t.index ["api_token_id"], name: "index_api_idempotency_records_on_api_token_id"
    t.check_constraint "key_digest::text ~ '^[0-9a-f]{64}$'::text AND request_fingerprint::text ~ '^[0-9a-f]{64}$'::text", name: "api_idempotency_records_digest_format"
    t.check_constraint "operation::text = ANY (ARRAY['sites:create'::character varying, 'people:create'::character varying, 'grants:create'::character varying, 'invitations:create'::character varying, 'releases:rollback'::character varying]::text[])", name: "api_idempotency_records_safe_operation"
    t.check_constraint "response_status >= 200 AND response_status <= 599", name: "api_idempotency_records_response_status"
  end

  create_table "api_rate_limit_buckets", force: :cascade do |t|
    t.datetime "bucket_started_at", null: false
    t.datetime "created_at", null: false
    t.string "identity_digest", limit: 64, null: false
    t.integer "request_count", default: 0, null: false
    t.string "route_key", limit: 100, null: false
    t.datetime "updated_at", null: false
    t.index ["identity_digest", "route_key", "bucket_started_at"], name: "index_api_rate_limit_buckets_on_identity_route_bucket", unique: true
    t.check_constraint "identity_digest::text ~ '^[0-9a-f]{64}$'::text", name: "api_rate_limit_buckets_identity_digest_format"
    t.check_constraint "request_count >= 0", name: "api_rate_limit_buckets_request_count_nonnegative"
  end

  create_table "api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "kind", null: false
    t.string "label", null: false
    t.datetime "last_used_at"
    t.bigint "owner_id", null: false
    t.datetime "revoked_at"
    t.jsonb "scopes", null: false
    t.string "token_digest", limit: 64, null: false
    t.string "token_hint", limit: 16, null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_api_tokens_on_owner_id"
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
    t.check_constraint "jsonb_typeof(scopes) = 'array'::text AND scopes <@ '[\"access:read\", \"access:write\", \"feedback:read\", \"invitations:read\", \"invitations:write\", \"people:read\", \"people:write\", \"publish:write\", \"receipts:read\", \"releases:read\", \"releases:rollback\", \"sites:read\", \"sites:write\"]'::jsonb AND jsonb_array_length(scopes) >= 1 AND jsonb_array_length(scopes) <= 13", name: "api_tokens_scopes_array"
    t.check_constraint "kind::text = ANY (ARRAY['interactive'::character varying, 'automation'::character varying]::text[])", name: "api_tokens_kind"
    t.check_constraint "octet_length(label::text) >= 1 AND octet_length(label::text) <= 100 AND octet_length(token_hint::text) >= 4 AND octet_length(token_hint::text) <= 16", name: "api_tokens_display_fields_length"
    t.check_constraint "token_digest::text ~ '^[0-9a-f]{64}$'::text", name: "api_tokens_token_digest_format"
  end

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

  create_table "device_authorizations", force: :cascade do |t|
    t.bigint "api_token_id"
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.datetime "denied_at"
    t.string "device_code_digest", limit: 64, null: false
    t.datetime "expires_at", null: false
    t.bigint "owner_id"
    t.string "profile_name", limit: 64, null: false
    t.string "proof_challenge", limit: 43, null: false
    t.datetime "redeemed_at"
    t.jsonb "scopes", null: false
    t.string "state", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.string "user_code_digest", limit: 64, null: false
    t.index ["api_token_id"], name: "index_device_authorizations_on_api_token_id"
    t.index ["device_code_digest"], name: "index_device_authorizations_on_device_code_digest", unique: true
    t.index ["owner_id"], name: "index_device_authorizations_on_owner_id"
    t.index ["user_code_digest"], name: "index_device_authorizations_on_user_code_digest", unique: true
    t.check_constraint "device_code_digest::text ~ '^[0-9a-f]{64}$'::text AND user_code_digest::text ~ '^[0-9a-f]{64}$'::text", name: "device_authorizations_digest_format"
    t.check_constraint "jsonb_typeof(scopes) = 'array'::text AND scopes <@ '[\"access:read\", \"access:write\", \"feedback:read\", \"invitations:read\", \"invitations:write\", \"people:read\", \"people:write\", \"publish:write\", \"receipts:read\", \"releases:read\", \"releases:rollback\", \"sites:read\", \"sites:write\"]'::jsonb AND jsonb_array_length(scopes) >= 1 AND jsonb_array_length(scopes) <= 13", name: "device_authorizations_scopes_array"
    t.check_constraint "profile_name::text ~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'::text", name: "device_authorizations_profile_name_format"
    t.check_constraint "proof_challenge::text ~ '^[A-Za-z0-9_-]{43}$'::text", name: "device_authorizations_proof_challenge_format"
    t.check_constraint "state::text = 'pending'::text AND owner_id IS NULL AND api_token_id IS NULL AND approved_at IS NULL AND redeemed_at IS NULL AND denied_at IS NULL OR state::text = 'approved'::text AND owner_id IS NOT NULL AND api_token_id IS NULL AND approved_at IS NOT NULL AND redeemed_at IS NULL AND denied_at IS NULL OR state::text = 'redeemed'::text AND owner_id IS NOT NULL AND api_token_id IS NOT NULL AND approved_at IS NOT NULL AND redeemed_at IS NOT NULL AND denied_at IS NULL OR state::text = 'denied'::text AND api_token_id IS NULL AND redeemed_at IS NULL AND denied_at IS NOT NULL", name: "device_authorizations_state_shape"
    t.check_constraint "state::text = ANY (ARRAY['pending'::character varying, 'approved'::character varying, 'redeemed'::character varying, 'denied'::character varying]::text[])", name: "device_authorizations_state"
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
    t.check_constraint "offline_policy::text = ANY (ARRAY['required'::character varying, 'optional'::character varying, 'download'::character varying]::text[])", name: "manifest_entries_offline_policy"
  end

  create_table "owner_ceremonies", force: :cascade do |t|
    t.string "authority", null: false
    t.string "challenge", limit: 512
    t.datetime "consumed_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "origin", limit: 512
    t.bigint "owner_id"
    t.string "purpose", null: false
    t.string "rp_id", limit: 253
    t.string "secret_digest", limit: 64, null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_owner_ceremonies_on_owner_id"
    t.index ["secret_digest"], name: "index_owner_ceremonies_on_secret_digest", unique: true
    t.check_constraint "authority::text = ANY (ARRAY['deployment'::character varying, 'owner_session'::character varying]::text[])", name: "owner_ceremonies_authority"
    t.check_constraint "challenge IS NULL AND origin IS NULL AND rp_id IS NULL OR challenge IS NOT NULL AND origin IS NOT NULL AND rp_id IS NOT NULL", name: "owner_ceremonies_webauthn_shape"
    t.check_constraint "challenge IS NULL OR octet_length(challenge::text) >= 16 AND octet_length(challenge::text) <= 512", name: "owner_ceremonies_challenge_length"
    t.check_constraint "purpose::text = 'bootstrap'::text AND owner_id IS NULL AND authority::text = 'deployment'::text OR purpose::text = 'recovery'::text AND owner_id IS NOT NULL AND authority::text = 'deployment'::text OR purpose::text = 'registration'::text AND owner_id IS NOT NULL AND authority::text = 'owner_session'::text", name: "owner_ceremonies_authority_shape"
    t.check_constraint "purpose::text = ANY (ARRAY['bootstrap'::character varying, 'recovery'::character varying, 'registration'::character varying]::text[])", name: "owner_ceremonies_purpose"
    t.check_constraint "secret_digest::text ~ '^[0-9a-f]{64}$'::text", name: "owner_ceremonies_secret_digest_format"
  end

  create_table "owner_credentials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "credential_id", null: false
    t.string "label", null: false
    t.datetime "last_used_at"
    t.bigint "owner_id", null: false
    t.text "public_key", null: false
    t.datetime "revoked_at"
    t.bigint "sign_count", default: 0, null: false
    t.jsonb "transports", default: [], null: false
    t.datetime "updated_at", null: false
    t.index ["credential_id"], name: "index_owner_credentials_on_credential_id", unique: true
    t.index ["owner_id"], name: "index_owner_credentials_on_owner_id"
    t.check_constraint "jsonb_typeof(transports) = 'array'::text AND transports <@ '[\"ble\", \"hybrid\", \"internal\", \"nfc\", \"smart-card\", \"usb\"]'::jsonb AND jsonb_array_length(transports) <= 6", name: "owner_credentials_transports_array"
    t.check_constraint "octet_length(credential_id) >= 1 AND octet_length(credential_id) <= 1024 AND octet_length(public_key) >= 1 AND octet_length(public_key) <= 16384", name: "owner_credentials_material_length"
    t.check_constraint "octet_length(label::text) >= 1 AND octet_length(label::text) <= 100", name: "owner_credentials_label_length"
    t.check_constraint "sign_count >= 0", name: "owner_credentials_sign_count_nonnegative"
  end

  create_table "owners", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "singleton_key", default: true, null: false
    t.datetime "updated_at", null: false
    t.string "webauthn_id", null: false
    t.index ["singleton_key"], name: "index_owners_on_singleton_key", unique: true
    t.index ["webauthn_id"], name: "index_owners_on_webauthn_id", unique: true
    t.check_constraint "octet_length(webauthn_id::text) >= 16 AND octet_length(webauthn_id::text) <= 255", name: "owners_webauthn_id_length"
    t.check_constraint "singleton_key = true", name: "owners_singleton_key_true"
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
    t.check_constraint "state::text = ANY (ARRAY['open'::character varying, 'finalized'::character varying]::text[])", name: "publish_plans_state"
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

  add_foreign_key "api_idempotency_records", "api_tokens"
  add_foreign_key "api_tokens", "owners"
  add_foreign_key "device_authorizations", "api_tokens"
  add_foreign_key "device_authorizations", "owners"
  add_foreign_key "grants", "people"
  add_foreign_key "grants", "sites"
  add_foreign_key "invitations", "grants"
  add_foreign_key "manifest_entries", "blobs"
  add_foreign_key "manifest_entries", "releases"
  add_foreign_key "owner_ceremonies", "owners"
  add_foreign_key "owner_credentials", "owners"
  add_foreign_key "publish_plans", "releases"
  add_foreign_key "publish_plans", "releases", column: "base_release_id"
  add_foreign_key "publish_plans", "sites"
  add_foreign_key "releases", "sites"
  add_foreign_key "site_handoffs", "grants"
  add_foreign_key "site_handoffs", "invitations"
  add_foreign_key "sites", "releases", column: "current_release_id"
end
