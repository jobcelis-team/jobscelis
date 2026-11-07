defmodule StreamflixCore.Repo.Migrations.HardenAutoEnableRlsFunction do
  use Ecto.Migration

  @doc """
  Fix the warnings of the Supabase security advisor:

  - pin the search_path of the auto-RLS event trigger function (it is SECURITY DEFINER,
    so an unpinned path could be hijacked)
  - revoke EXECUTE on it from PUBLIC, anon and authenticated: the event trigger still
    fires for every CREATE TABLE, nobody needs to call the function directly
  - revoke anon/authenticated access to every table and sequence in public. The app
    connects as the table owner and never uses those roles; with the grants, the tables
    were visible in the GraphQL schema to anyone holding the public anon key. Production
    had them revoked by hand, staging did not: this makes both match.

  Safe for both managed PostgreSQL (with anon/authenticated roles) and plain PostgreSQL (CI/Docker).
  """

  def up do
    execute("ALTER FUNCTION public.auto_enable_rls() SET search_path = pg_catalog, public")
    execute("REVOKE EXECUTE ON FUNCTION public.auto_enable_rls() FROM PUBLIC")

    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        REVOKE EXECUTE ON FUNCTION public.auto_enable_rls() FROM anon;
        REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
        REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;
      END IF;

      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        REVOKE EXECUTE ON FUNCTION public.auto_enable_rls() FROM authenticated;
        REVOKE ALL ON ALL TABLES IN SCHEMA public FROM authenticated;
        REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM authenticated;
      END IF;
    END
    $$
    """)
  end

  # The table and sequence revokes are not undone: granting them back would
  # re-expose the tables.
  def down do
    execute("ALTER FUNCTION public.auto_enable_rls() RESET search_path")
    execute("GRANT EXECUTE ON FUNCTION public.auto_enable_rls() TO PUBLIC")
  end
end
