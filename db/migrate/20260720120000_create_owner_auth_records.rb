# frozen_string_literal: true

class CreateOwnerAuthRecords < ActiveRecord::Migration[8.1]
  API_SCOPES = %w[
    access:read access:write feedback:read invitations:read invitations:write
    people:read people:write publish:write receipts:read releases:read
    releases:rollback sites:read sites:write
  ].freeze
  TRANSPORTS = %w[ble hybrid internal nfc smart-card usb].freeze

  def change
    create_table :owners do |t|
      t.boolean :singleton_key, null: false, default: true
      t.string :webauthn_id, null: false
      t.timestamps
    end
    add_index :owners, :singleton_key, unique: true
    add_index :owners, :webauthn_id, unique: true
    add_check_constraint :owners, "singleton_key = TRUE", name: "owners_singleton_key_true"
    add_check_constraint :owners,
      "octet_length(webauthn_id) BETWEEN 16 AND 255",
      name: "owners_webauthn_id_length"

    create_table :owner_credentials do |t|
      t.references :owner, null: false, foreign_key: true
      t.text :credential_id, null: false
      t.text :public_key, null: false
      t.bigint :sign_count, null: false, default: 0
      t.string :label, null: false
      t.jsonb :transports, null: false, default: []
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :owner_credentials, :credential_id, unique: true
    add_check_constraint :owner_credentials, "sign_count >= 0", name: "owner_credentials_sign_count_nonnegative"
    add_check_constraint :owner_credentials,
      "octet_length(credential_id) BETWEEN 1 AND 1024 AND octet_length(public_key) BETWEEN 1 AND 16384",
      name: "owner_credentials_material_length"
    add_check_constraint :owner_credentials,
      "octet_length(label) BETWEEN 1 AND 100",
      name: "owner_credentials_label_length"
    add_check_constraint :owner_credentials,
      "jsonb_typeof(transports) = 'array' AND transports <@ '#{TRANSPORTS.to_json}'::jsonb " \
      "AND jsonb_array_length(transports) <= #{TRANSPORTS.length}",
      name: "owner_credentials_transports_array"

    create_table :owner_ceremonies do |t|
      t.references :owner, foreign_key: true
      t.string :purpose, null: false
      t.string :authority, null: false
      t.string :secret_digest, limit: 64, null: false
      t.string :challenge, limit: 512
      t.string :origin, limit: 512
      t.string :rp_id, limit: 253
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps
    end
    add_index :owner_ceremonies, :secret_digest, unique: true
    add_check_constraint :owner_ceremonies,
      "purpose IN ('bootstrap', 'recovery', 'registration')",
      name: "owner_ceremonies_purpose"
    add_check_constraint :owner_ceremonies,
      "authority IN ('deployment', 'owner_session')",
      name: "owner_ceremonies_authority"
    add_check_constraint :owner_ceremonies,
      "secret_digest ~ '^[0-9a-f]{64}$'",
      name: "owner_ceremonies_secret_digest_format"
    add_check_constraint :owner_ceremonies,
      "(purpose = 'bootstrap' AND owner_id IS NULL AND authority = 'deployment') OR " \
      "(purpose = 'recovery' AND owner_id IS NOT NULL AND authority = 'deployment') OR " \
      "(purpose = 'registration' AND owner_id IS NOT NULL AND authority = 'owner_session')",
      name: "owner_ceremonies_authority_shape"
    add_check_constraint :owner_ceremonies,
      "(challenge IS NULL AND origin IS NULL AND rp_id IS NULL) OR " \
      "(challenge IS NOT NULL AND origin IS NOT NULL AND rp_id IS NOT NULL)",
      name: "owner_ceremonies_webauthn_shape"
    add_check_constraint :owner_ceremonies,
      "challenge IS NULL OR octet_length(challenge) BETWEEN 16 AND 512",
      name: "owner_ceremonies_challenge_length"

    create_table :api_tokens do |t|
      t.references :owner, null: false, foreign_key: true
      t.string :token_digest, limit: 64, null: false
      t.string :token_hint, limit: 16, null: false
      t.string :kind, null: false
      t.string :label, null: false
      t.jsonb :scopes, null: false
      t.datetime :expires_at
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :api_tokens, :token_digest, unique: true
    add_check_constraint :api_tokens,
      "token_digest ~ '^[0-9a-f]{64}$'",
      name: "api_tokens_token_digest_format"
    add_check_constraint :api_tokens, "kind IN ('interactive', 'automation')", name: "api_tokens_kind"
    add_check_constraint :api_tokens,
      "octet_length(label) BETWEEN 1 AND 100 AND octet_length(token_hint) BETWEEN 4 AND 16",
      name: "api_tokens_display_fields_length"
    add_check_constraint :api_tokens, scope_constraint, name: "api_tokens_scopes_array"

    create_table :device_authorizations do |t|
      t.references :owner, foreign_key: true
      t.references :api_token, foreign_key: true
      t.string :device_code_digest, limit: 64, null: false
      t.string :user_code_digest, limit: 64, null: false
      t.string :proof_challenge, limit: 43, null: false
      t.string :profile_name, limit: 64, null: false
      t.jsonb :scopes, null: false
      t.string :state, null: false, default: "pending"
      t.datetime :expires_at, null: false
      t.datetime :approved_at
      t.datetime :redeemed_at
      t.datetime :denied_at
      t.timestamps
    end
    add_index :device_authorizations, :device_code_digest, unique: true
    add_index :device_authorizations, :user_code_digest, unique: true
    add_check_constraint :device_authorizations,
      "device_code_digest ~ '^[0-9a-f]{64}$' AND user_code_digest ~ '^[0-9a-f]{64}$'",
      name: "device_authorizations_digest_format"
    add_check_constraint :device_authorizations,
      "proof_challenge ~ '^[A-Za-z0-9_-]{43}$'",
      name: "device_authorizations_proof_challenge_format"
    add_check_constraint :device_authorizations,
      scope_constraint,
      name: "device_authorizations_scopes_array"
    add_check_constraint :device_authorizations,
      "profile_name ~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'",
      name: "device_authorizations_profile_name_format"
    add_check_constraint :device_authorizations,
      "state IN ('pending', 'approved', 'redeemed', 'denied')",
      name: "device_authorizations_state"
    add_check_constraint :device_authorizations,
      "(state = 'pending' AND owner_id IS NULL AND api_token_id IS NULL AND approved_at IS NULL AND redeemed_at IS NULL AND denied_at IS NULL) OR " \
      "(state = 'approved' AND owner_id IS NOT NULL AND api_token_id IS NULL AND approved_at IS NOT NULL AND redeemed_at IS NULL AND denied_at IS NULL) OR " \
      "(state = 'redeemed' AND owner_id IS NOT NULL AND api_token_id IS NOT NULL AND approved_at IS NOT NULL AND redeemed_at IS NOT NULL AND denied_at IS NULL) OR " \
      "(state = 'denied' AND api_token_id IS NULL AND redeemed_at IS NULL AND denied_at IS NOT NULL)",
      name: "device_authorizations_state_shape"

    create_table :api_idempotency_records do |t|
      t.references :api_token, null: false, foreign_key: true
      t.string :operation, limit: 64, null: false
      t.string :key_digest, limit: 64, null: false
      t.string :request_fingerprint, limit: 64, null: false
      t.integer :response_status, null: false
      t.jsonb :response_body, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :api_idempotency_records, [ :api_token_id, :key_digest ], unique: true
    add_check_constraint :api_idempotency_records,
      "key_digest ~ '^[0-9a-f]{64}$' AND request_fingerprint ~ '^[0-9a-f]{64}$'",
      name: "api_idempotency_records_digest_format"
    add_check_constraint :api_idempotency_records,
      "response_status BETWEEN 200 AND 599",
      name: "api_idempotency_records_response_status"
    add_check_constraint :api_idempotency_records,
      "operation IN ('sites:create', 'people:create', 'grants:create', 'invitations:create', 'releases:rollback')",
      name: "api_idempotency_records_safe_operation"

    create_table :api_rate_limit_buckets do |t|
      t.string :identity_digest, limit: 64, null: false
      t.string :route_key, limit: 100, null: false
      t.datetime :bucket_started_at, null: false
      t.integer :request_count, null: false, default: 0
      t.timestamps
    end
    add_index :api_rate_limit_buckets,
      [ :identity_digest, :route_key, :bucket_started_at ],
      unique: true,
      name: "index_api_rate_limit_buckets_on_identity_route_bucket"
    add_check_constraint :api_rate_limit_buckets,
      "identity_digest ~ '^[0-9a-f]{64}$'",
      name: "api_rate_limit_buckets_identity_digest_format"
    add_check_constraint :api_rate_limit_buckets,
      "request_count >= 0",
      name: "api_rate_limit_buckets_request_count_nonnegative"
  end

  private

  def scope_constraint
    "jsonb_typeof(scopes) = 'array' AND scopes <@ '#{API_SCOPES.to_json}'::jsonb " \
      "AND jsonb_array_length(scopes) BETWEEN 1 AND #{API_SCOPES.length}"
  end
end
