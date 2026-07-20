# frozen_string_literal: true

class CreateSiteHandoffs < ActiveRecord::Migration[8.1]
  def change
    create_table :site_handoffs do |t|
      t.references :grant, null: false, foreign_key: true
      t.references :invitation, null: false, foreign_key: true, index: { unique: true }
      t.string :audience, null: false
      t.string :nonce_digest, limit: 64, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps
    end

    add_index :site_handoffs, :nonce_digest, unique: true
    add_check_constraint :site_handoffs,
      "nonce_digest ~ '^[0-9a-f]{64}$'",
      name: "site_handoffs_nonce_digest_format"
  end
end
