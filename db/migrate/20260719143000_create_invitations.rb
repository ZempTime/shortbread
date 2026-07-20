# frozen_string_literal: true

class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations do |t|
      t.references :grant, null: false, foreign_key: true
      t.string :locator, null: false
      t.string :secret_digest, limit: 64, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :invitations, :locator, unique: true
    add_index :invitations, :secret_digest, unique: true
    add_check_constraint :invitations,
      "secret_digest ~ '^[0-9a-f]{64}$'",
      name: "invitations_secret_digest_format"
  end
end
