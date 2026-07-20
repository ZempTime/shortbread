# frozen_string_literal: true

class CreateGrants < ActiveRecord::Migration[8.1]
  def change
    create_table :grants do |t|
      t.references :site, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.boolean :offline_allowed, null: false, default: false
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :grants, [ :site_id, :person_id ], unique: true
  end
end
