defmodule StreamflixCore.Repo.Migrations.HardenAutoEnableRlsFunction do
  use Ecto.Migration

  @doc """
  Harden the auto-RLS event trigger function flagged by the Supabase security advisor:

  - pin its search_path (it is SECURITY DEFINER, so an unpinned path could be hijacked)
  - revoke EXECUTE from PUBLIC, anon and authenticated: the event trigger still fires
    for every CREATE TABLE, nobody needs to call the function directly

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
      END IF;

      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        REVOKE EXECUTE ON FUNCTION public.auto_enable_rls() FROM authenticated;
      END IF;
    END
    $$
    """)
  end

  def down do
    execute("ALTER FUNCTION public.auto_enable_rls() RESET search_path")
    execute("GRANT EXECUTE ON FUNCTION public.auto_enable_rls() TO PUBLIC")
  end
end
