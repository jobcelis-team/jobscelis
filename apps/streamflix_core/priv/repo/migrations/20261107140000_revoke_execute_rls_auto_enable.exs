defmodule StreamflixCore.Repo.Migrations.RevokeExecuteRlsAutoEnable do
  use Ecto.Migration

  @doc """
  Revoke EXECUTE on public.rls_auto_enable() from PUBLIC, anon and authenticated.

  The staging Supabase project has this SECURITY DEFINER event trigger function
  (created outside these migrations) and the security advisor flags it as callable
  by anyone. Its event trigger keeps firing without callers holding EXECUTE.
  Does nothing where the function or the roles do not exist.
  """

  def up do
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'rls_auto_enable' AND p.pronargs = 0
      ) THEN
        REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM PUBLIC;

        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
          REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM anon;
        END IF;

        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
          REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM authenticated;
        END IF;
      END IF;
    END
    $$
    """)
  end

  def down, do: :ok
end
