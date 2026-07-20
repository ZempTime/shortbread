# frozen_string_literal: true

class CreateReleaseRollbacksAndHardenReleaseIntegrity < ActiveRecord::Migration[8.1]
  def up
    add_index :releases, %i[id site_id], unique: true, name: "index_releases_on_id_and_site_id"

    create_table :release_rollbacks do |t|
      t.references :site, null: false, foreign_key: true
      t.bigint :from_release_id, null: false
      t.bigint :to_release_id, null: false
      t.string :idempotency_key_digest, limit: 64, null: false
      t.timestamps
    end
    add_index :release_rollbacks, :from_release_id
    add_index :release_rollbacks, :to_release_id
    add_index :release_rollbacks,
      %i[site_id idempotency_key_digest],
      unique: true,
      name: "index_release_rollbacks_on_site_and_key_digest"
    add_check_constraint :release_rollbacks,
      "idempotency_key_digest ~ '^[0-9a-f]{64}$'",
      name: "release_rollbacks_idempotency_key_digest_format"

    add_same_site_foreign_keys
    add_immutable_update_guards
    add_monotonic_release_number_guard
  end

  def down
    execute "DROP TRIGGER IF EXISTS shortbread_monotonic_release_number ON releases"
    execute "DROP FUNCTION IF EXISTS shortbread_enforce_monotonic_release_number()"

    %w[release_rollbacks manifest_entries releases].each do |table|
      execute "DROP TRIGGER IF EXISTS shortbread_immutable_update ON #{quote_table_name(table)}"
    end
    execute "DROP FUNCTION IF EXISTS shortbread_reject_immutable_row_update()"

    remove_foreign_key :publish_plans, name: "fk_publish_plans_release_same_site"
    remove_foreign_key :publish_plans, name: "fk_publish_plans_base_release_same_site"
    remove_foreign_key :sites, name: "fk_sites_current_release_same_site"
    drop_table :release_rollbacks
    remove_index :releases, name: "index_releases_on_id_and_site_id"
  end

  private

  def add_same_site_foreign_keys
    add_foreign_key :sites,
      :releases,
      column: %i[current_release_id id],
      primary_key: %i[id site_id],
      name: "fk_sites_current_release_same_site"
    add_foreign_key :publish_plans,
      :releases,
      column: %i[base_release_id site_id],
      primary_key: %i[id site_id],
      name: "fk_publish_plans_base_release_same_site"
    add_foreign_key :publish_plans,
      :releases,
      column: %i[release_id site_id],
      primary_key: %i[id site_id],
      name: "fk_publish_plans_release_same_site"
    add_foreign_key :release_rollbacks,
      :releases,
      column: %i[from_release_id site_id],
      primary_key: %i[id site_id],
      name: "fk_release_rollbacks_from_same_site"
    add_foreign_key :release_rollbacks,
      :releases,
      column: %i[to_release_id site_id],
      primary_key: %i[id site_id],
      name: "fk_release_rollbacks_to_same_site"
  end

  def add_immutable_update_guards
    execute <<~SQL
      CREATE FUNCTION shortbread_reject_immutable_row_update()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'Shortbread immutable % rows cannot be updated', TG_TABLE_NAME
          USING ERRCODE = '55000';
      END;
      $$
    SQL

    %w[releases manifest_entries release_rollbacks].each do |table|
      execute <<~SQL
        CREATE TRIGGER shortbread_immutable_update
        BEFORE UPDATE ON #{quote_table_name(table)}
        FOR EACH ROW
        EXECUTE FUNCTION shortbread_reject_immutable_row_update()
      SQL
    end
  end

  def add_monotonic_release_number_guard
    execute <<~SQL
      CREATE FUNCTION shortbread_enforce_monotonic_release_number()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        expected_number bigint;
      BEGIN
        PERFORM 1 FROM sites WHERE id = NEW.site_id FOR UPDATE;
        SELECT COALESCE(MAX(number), 0) + 1
          INTO expected_number
          FROM releases
          WHERE site_id = NEW.site_id;

        IF NEW.number <> expected_number THEN
          RAISE EXCEPTION 'Release number must be the next monotonic number for its Site'
            USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END;
      $$
    SQL
    execute <<~SQL
      CREATE TRIGGER shortbread_monotonic_release_number
      BEFORE INSERT ON releases
      FOR EACH ROW
      EXECUTE FUNCTION shortbread_enforce_monotonic_release_number()
    SQL
  end
end
