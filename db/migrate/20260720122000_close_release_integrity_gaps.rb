# frozen_string_literal: true

class CloseReleaseIntegrityGaps < ActiveRecord::Migration[8.1]
  def up
    change_column_null :releases, :finalized_at, true

    %w[releases manifest_entries release_rollbacks].each do |table|
      execute "DROP TRIGGER IF EXISTS shortbread_immutable_update ON #{quote_table_name(table)}"
    end
    execute "DROP FUNCTION IF EXISTS shortbread_reject_immutable_row_update()"

    execute <<~SQL
      CREATE FUNCTION shortbread_guard_release_lifecycle()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          RAISE EXCEPTION 'Shortbread immutable Release rows cannot be deleted' USING ERRCODE = '55000';
        END IF;
        IF OLD.finalized_at IS NULL
          AND NEW.finalized_at IS NOT NULL
          AND OLD.site_id IS NOT DISTINCT FROM NEW.site_id
          AND OLD.number IS NOT DISTINCT FROM NEW.number
          AND OLD.manifest_sha256 IS NOT DISTINCT FROM NEW.manifest_sha256 THEN
          RETURN NEW;
        END IF;
        RAISE EXCEPTION 'Shortbread immutable Release rows cannot be updated' USING ERRCODE = '55000';
      END;
      $$
    SQL
    execute <<~SQL
      CREATE TRIGGER shortbread_release_lifecycle
      BEFORE UPDATE OR DELETE ON releases
      FOR EACH ROW
      EXECUTE FUNCTION shortbread_guard_release_lifecycle()
    SQL

    execute <<~SQL
      CREATE FUNCTION shortbread_guard_manifest_entry_membership()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        parent_finalized_at timestamp(6);
      BEGIN
        IF TG_OP <> 'INSERT' THEN
          RAISE EXCEPTION 'Shortbread immutable Manifest Entry rows cannot be changed' USING ERRCODE = '55000';
        END IF;
        SELECT finalized_at INTO parent_finalized_at FROM releases WHERE id = NEW.release_id;
        IF parent_finalized_at IS NOT NULL THEN
          RAISE EXCEPTION 'Manifest Entries cannot be added to a finalized Release' USING ERRCODE = '55000';
        END IF;
        RETURN NEW;
      END;
      $$
    SQL
    execute <<~SQL
      CREATE TRIGGER shortbread_manifest_entry_membership
      BEFORE INSERT OR UPDATE OR DELETE ON manifest_entries
      FOR EACH ROW
      EXECUTE FUNCTION shortbread_guard_manifest_entry_membership()
    SQL

    execute <<~SQL
      CREATE FUNCTION shortbread_guard_publish_plan_lifecycle()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF TG_OP = 'DELETE' THEN
          RAISE EXCEPTION 'Publish Plan idempotency rows cannot be deleted' USING ERRCODE = '55000';
        END IF;
        IF OLD.state = 'open'
          AND NEW.state = 'finalized'
          AND OLD.release_id IS NULL
          AND NEW.release_id IS NOT NULL
          AND OLD.finalized_at IS NULL
          AND NEW.finalized_at IS NOT NULL
          AND OLD.site_id IS NOT DISTINCT FROM NEW.site_id
          AND OLD.base_release_id IS NOT DISTINCT FROM NEW.base_release_id
          AND OLD.idempotency_key_digest IS NOT DISTINCT FROM NEW.idempotency_key_digest
          AND OLD.manifest_sha256 IS NOT DISTINCT FROM NEW.manifest_sha256
          AND OLD.manifest IS NOT DISTINCT FROM NEW.manifest
          AND OLD.expires_at IS NOT DISTINCT FROM NEW.expires_at THEN
          RETURN NEW;
        END IF;
        RAISE EXCEPTION 'Publish Plan rows permit only exact finalization' USING ERRCODE = '55000';
      END;
      $$
    SQL
    execute <<~SQL
      CREATE TRIGGER shortbread_publish_plan_lifecycle
      BEFORE UPDATE OR DELETE ON publish_plans
      FOR EACH ROW
      EXECUTE FUNCTION shortbread_guard_publish_plan_lifecycle()
    SQL

    execute <<~SQL
      CREATE FUNCTION shortbread_require_finalized_current_release()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF NEW.current_release_id IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM releases
          WHERE id = NEW.current_release_id AND site_id = NEW.id AND finalized_at IS NOT NULL
        ) THEN
          RAISE EXCEPTION 'A Site current pointer must select its finalized Release' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
      END;
      $$
    SQL
    execute <<~SQL
      CREATE TRIGGER shortbread_finalized_current_release
      BEFORE INSERT OR UPDATE OF current_release_id ON sites
      FOR EACH ROW
      EXECUTE FUNCTION shortbread_require_finalized_current_release()
    SQL

    execute <<~SQL
      CREATE FUNCTION shortbread_reject_immutable_row_change()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'Shortbread immutable % rows cannot be changed', TG_TABLE_NAME USING ERRCODE = '55000';
      END;
      $$
    SQL
    execute <<~SQL
      CREATE TRIGGER shortbread_immutable_change
      BEFORE UPDATE OR DELETE ON release_rollbacks
      FOR EACH ROW
      EXECUTE FUNCTION shortbread_reject_immutable_row_change()
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS shortbread_immutable_change ON release_rollbacks"
    execute "DROP FUNCTION IF EXISTS shortbread_reject_immutable_row_change()"
    execute "DROP TRIGGER IF EXISTS shortbread_finalized_current_release ON sites"
    execute "DROP FUNCTION IF EXISTS shortbread_require_finalized_current_release()"
    execute "DROP TRIGGER IF EXISTS shortbread_publish_plan_lifecycle ON publish_plans"
    execute "DROP FUNCTION IF EXISTS shortbread_guard_publish_plan_lifecycle()"
    execute "DROP TRIGGER IF EXISTS shortbread_manifest_entry_membership ON manifest_entries"
    execute "DROP FUNCTION IF EXISTS shortbread_guard_manifest_entry_membership()"
    execute "DROP TRIGGER IF EXISTS shortbread_release_lifecycle ON releases"
    execute "DROP FUNCTION IF EXISTS shortbread_guard_release_lifecycle()"
    change_column_null :releases, :finalized_at, false
  end
end
