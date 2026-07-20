# frozen_string_literal: true

class CreateSites < ActiveRecord::Migration[8.1]
  def change
    create_table :sites do |t|
      t.string :slug, null: false
      t.string :name, null: false
      t.timestamps
    end

    add_index :sites, :slug, unique: true
  end
end
