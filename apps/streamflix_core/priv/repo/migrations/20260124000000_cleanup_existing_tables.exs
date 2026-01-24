defmodule StreamflixCore.Repo.Migrations.CleanupExistingTables do
  use Ecto.Migration

  @moduledoc """
  Migration to clean up all existing tables before creating StreamFlix schema.
  This allows using the same Supabase database as other projects.

  WARNING: This will DROP all existing tables!
  """

  def up do
    # Disable foreign key checks temporarily
    execute "SET session_replication_role = 'replica';"

    # Get all tables in public schema (excluding Supabase system tables)
    tables_to_drop = """
    SELECT tablename FROM pg_tables
    WHERE schemaname = 'public'
    AND tablename NOT LIKE 'pg_%'
    AND tablename NOT LIKE '_supabase_%'
    AND tablename NOT IN ('schema_migrations', 'spatial_ref_sys', 'geography_columns', 'geometry_columns')
    """

    # Drop all existing tables
    execute """
    DO $$
    DECLARE
        r RECORD;
    BEGIN
        -- Drop all tables in public schema
        FOR r IN (#{tables_to_drop}) LOOP
            EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(r.tablename) || ' CASCADE';
            RAISE NOTICE 'Dropped table: %', r.tablename;
        END LOOP;

        -- Drop all custom types
        FOR r IN (SELECT typname FROM pg_type WHERE typnamespace = 'public'::regnamespace AND typtype = 'e') LOOP
            EXECUTE 'DROP TYPE IF EXISTS public.' || quote_ident(r.typname) || ' CASCADE';
            RAISE NOTICE 'Dropped type: %', r.typname;
        END LOOP;

        -- Drop all sequences
        FOR r IN (SELECT sequencename FROM pg_sequences WHERE schemaname = 'public') LOOP
            EXECUTE 'DROP SEQUENCE IF EXISTS public.' || quote_ident(r.sequencename) || ' CASCADE';
            RAISE NOTICE 'Dropped sequence: %', r.sequencename;
        END LOOP;
    END $$;
    """

    # Re-enable foreign key checks
    execute "SET session_replication_role = 'origin';"

    # Clean up the schema_migrations table to start fresh
    # (Keep only this migration)
    execute """
    DELETE FROM schema_migrations WHERE version != '20260124000000';
    """
  end

  def down do
    # This migration cannot be reversed
    # The previous state is lost
    raise Ecto.MigrationError,
      message: "This migration cannot be reversed. Previous database state is lost."
  end
end
