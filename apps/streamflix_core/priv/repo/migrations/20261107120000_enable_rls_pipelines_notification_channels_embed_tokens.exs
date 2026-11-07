defmodule StreamflixCore.Repo.Migrations.EnableRlsPipelinesNotificationChannelsEmbedTokens do
  use Ecto.Migration

  @doc """
  Enable RLS on the 3 tables whose create migrations disabled the auto-RLS trigger,
  revoke anon/authenticated permissions on them, and fix the trigger so new tables
  no longer need it disabled.

  The trigger passed `object_identity` (already schema-qualified and quoted, e.g.
  `public.pipelines`) through `%I`, which quoted it again as one identifier
  (`"public.pipelines"`), so every CREATE TABLE failed with "relation does not exist".

  Safe for both managed PostgreSQL (with anon/authenticated roles) and plain PostgreSQL (CI/Docker).
  """

  @tables ~w(pipelines notification_channels embed_tokens)

  def up do
    # ── 1. Enable RLS ────────────────────────────────────────────────
    for table <- @tables do
      execute("ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY")
    end

    # ── 2. Revoke anon/authenticated access (managed DB only) ────────
    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        REVOKE ALL ON pipelines FROM anon;
        REVOKE ALL ON notification_channels FROM anon;
        REVOKE ALL ON embed_tokens FROM anon;
      END IF;

      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        REVOKE ALL ON pipelines FROM authenticated;
        REVOKE ALL ON notification_channels FROM authenticated;
        REVOKE ALL ON embed_tokens FROM authenticated;
      END IF;
    END
    $$
    """)

    # ── 3. Fix the auto-RLS trigger function ─────────────────────────
    # object_identity is already quoted and schema-qualified: use %s, not %I.
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
        EXECUTE format('ALTER TABLE %s ENABLE ROW LEVEL SECURITY', obj.object_identity);

        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
          EXECUTE format('REVOKE ALL ON %s FROM anon', obj.object_identity);
        END IF;

        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
          EXECUTE format('REVOKE ALL ON %s FROM authenticated', obj.object_identity);
        END IF;
      END LOOP;
    END;
    $$
    """)

    # ── 4. Make sure the trigger is enabled ──────────────────────────
    execute("""
    DO $$ BEGIN
      IF EXISTS (SELECT 1 FROM pg_event_trigger WHERE evtname = 'ensure_rls_on_new_tables') THEN
        ALTER EVENT TRIGGER ensure_rls_on_new_tables ENABLE;
      END IF;
    END $$;
    """)
  end

  def down do
    # The trigger function fix is kept: the previous version made CREATE TABLE fail.
    for table <- @tables do
      execute("ALTER TABLE #{table} DISABLE ROW LEVEL SECURITY")
    end
  end
end
