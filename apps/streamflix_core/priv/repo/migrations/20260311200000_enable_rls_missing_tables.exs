defmodule StreamflixCore.Repo.Migrations.EnableRlsMissingTables do
  use Ecto.Migration

  @doc """
  Enable RLS on 4 tables created after the initial Supabase hardening (2026-03-02).
  Also revoke anon/authenticated permissions on them and create an auto-RLS trigger
  for any future tables created in the public schema.

  Safe for both Supabase (has anon/authenticated roles) and plain PostgreSQL (CI/Docker).
  """

  def up do
    # ── 1. Enable RLS on missing tables ──────────────────────────────
    for table <- ~w(consents password_history uptime_checks user_sessions) do
      execute("ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY")
    end

    # ── 2. Revoke anon/authenticated access (Supabase only) ──────────
    # These roles only exist in Supabase. In CI/Docker (plain PostgreSQL)
    # they don't exist, so we check before revoking.
    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        REVOKE ALL ON consents FROM anon;
        REVOKE ALL ON password_history FROM anon;
        REVOKE ALL ON uptime_checks FROM anon;
        REVOKE ALL ON user_sessions FROM anon;
      END IF;

      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        REVOKE ALL ON consents FROM authenticated;
        REVOKE ALL ON password_history FROM authenticated;
        REVOKE ALL ON uptime_checks FROM authenticated;
        REVOKE ALL ON user_sessions FROM authenticated;
      END IF;
    END
    $$
    """)

    # ── 3. Auto-RLS trigger for future tables ────────────────────────
    # Creates a function + event trigger that automatically enables RLS
    # and revokes anon/authenticated permissions on any new table in public schema.
    # The REVOKE inside the function also checks for role existence.
    execute("""
    CREATE OR REPLACE FUNCTION public.auto_enable_rls()
    RETURNS event_trigger
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    DECLARE
      obj record;
    BEGIN
      FOR obj IN SELECT * FROM pg_event_trigger_ddl_commands()
        WHERE command_tag = 'CREATE TABLE'
          AND schema_name = 'public'
      LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', obj.object_identity);

        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
          EXECUTE format('REVOKE ALL ON %I FROM anon', obj.object_identity);
        END IF;

        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
          EXECUTE format('REVOKE ALL ON %I FROM authenticated', obj.object_identity);
        END IF;
      END LOOP;
    END;
    $$
    """)

    execute("DROP EVENT TRIGGER IF EXISTS ensure_rls_on_new_tables")

    execute("""
    CREATE EVENT TRIGGER ensure_rls_on_new_tables
    ON ddl_command_end
    WHEN TAG IN ('CREATE TABLE')
    EXECUTE FUNCTION public.auto_enable_rls()
    """)
  end

  def down do
    execute("DROP EVENT TRIGGER IF EXISTS ensure_rls_on_new_tables")
    execute("DROP FUNCTION IF EXISTS public.auto_enable_rls()")

    for table <- ~w(consents password_history uptime_checks user_sessions) do
      execute("ALTER TABLE #{table} DISABLE ROW LEVEL SECURITY")
    end
  end
end
