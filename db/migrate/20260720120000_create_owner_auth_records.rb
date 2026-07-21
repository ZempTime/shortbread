# frozen_string_literal: true

class CreateOwnerAuthRecords < ActiveRecord::Migration[8.1]
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
      "octet_length(credential_id) BETWEEN 1 AND 1366 AND octet_length(public_key) BETWEEN 1 AND 16384",
      name: "owner_credentials_material_length"
    add_check_constraint :owner_credentials,
      "octet_length(label) BETWEEN 1 AND 100",
      name: "owner_credentials_label_length"
    add_check_constraint :owner_credentials,
      "jsonb_typeof(transports) = 'array' AND transports <@ '#{TRANSPORTS.to_json}'::jsonb " \
      "AND jsonb_array_length(transports) <= #{TRANSPORTS.length}",
      name: "owner_credentials_transports_array"

    create_table :owner_ceremonies do |t|
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
      "purpose = 'bootstrap'",
      name: "owner_ceremonies_purpose"
    add_check_constraint :owner_ceremonies,
      "authority = 'deployment'",
      name: "owner_ceremonies_authority"
    add_check_constraint :owner_ceremonies,
      "secret_digest ~ '^[0-9a-f]{64}$'",
      name: "owner_ceremonies_secret_digest_format"
    add_check_constraint :owner_ceremonies,
      "purpose = 'bootstrap' AND authority = 'deployment'",
      name: "owner_ceremonies_authority_shape"
    add_check_constraint :owner_ceremonies,
      "(challenge IS NULL AND origin IS NULL AND rp_id IS NULL) OR " \
      "(challenge IS NOT NULL AND origin IS NOT NULL AND rp_id IS NOT NULL)",
      name: "owner_ceremonies_webauthn_shape"
    add_check_constraint :owner_ceremonies,
      "challenge IS NULL OR octet_length(challenge) BETWEEN 16 AND 512",
      name: "owner_ceremonies_challenge_length"
  end
end
