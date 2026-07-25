# frozen_string_literal: true

class CreateComments < ActiveRecord::Migration[8.1]
  def up
    create_table :comments do |t|
      t.references :site, null: false, foreign_key: true
      t.bigint :release_id, null: false
      t.references :person, null: false, foreign_key: true
      t.references :grant, null: false, foreign_key: true
      t.text :body, null: false

      # The Anchor composite. Optional as a whole so a Site-level Comment carries no selection,
      # and all-or-nothing so a partially recorded Anchor cannot exist.
      t.string :path
      t.text :quote
      t.text :prefix
      t.text :suffix
      t.bigint :start_offset
      t.bigint :block_index
      t.bigint :block_offset

      t.timestamps
    end

    add_index :comments, :release_id
    add_index :comments, %i[site_id created_at]

    add_foreign_key :comments,
      :releases,
      column: %i[release_id site_id],
      primary_key: %i[id site_id],
      name: "fk_comments_release_same_site"

    add_check_constraint :comments, "btrim(body) <> ''", name: "comments_body_present"
    add_check_constraint :comments,
      "start_offset IS NULL OR start_offset >= 0",
      name: "comments_start_offset_non_negative"
    add_check_constraint :comments, <<~SQL.squish, name: "comments_anchor_all_or_nothing"
      (path IS NULL AND quote IS NULL AND prefix IS NULL AND suffix IS NULL
        AND start_offset IS NULL AND block_index IS NULL AND block_offset IS NULL)
      OR
      (path IS NOT NULL AND quote IS NOT NULL AND prefix IS NOT NULL AND suffix IS NOT NULL
        AND start_offset IS NOT NULL)
    SQL

    # Comments are append-only, using the immutability guard the Release tables already share.
    # UPDATE only: a Comment is never edited, but deleting a Site removes its Comments with it.
    execute <<~SQL
      CREATE TRIGGER shortbread_immutable_change
      BEFORE UPDATE ON #{quote_table_name("comments")}
      FOR EACH ROW
      EXECUTE FUNCTION shortbread_reject_immutable_row_change()
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS shortbread_immutable_change ON comments"
    drop_table :comments
  end
end
