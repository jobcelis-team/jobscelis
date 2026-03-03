IO.puts("Truncating all tables...")

sql = """
DO $$ DECLARE r RECORD;
BEGIN
  FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename NOT IN ('schema_migrations', 'oban_jobs', 'oban_peers'))
  LOOP
    EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.tablename) || ' CASCADE';
  END LOOP;
END $$;
"""

StreamflixCore.Repo.query!(sql)
IO.puts("All tables truncated!")

# Also clean Oban jobs
StreamflixCore.Repo.query!("TRUNCATE TABLE oban_jobs CASCADE")
StreamflixCore.Repo.query!("TRUNCATE TABLE oban_peers CASCADE")
IO.puts("Oban tables cleaned!")

IO.puts("\nCreating superadmin...")

case StreamflixAccounts.create_superadmin(%{
  email: "bladimirtutoriales@gmail.com",
  password: "Test1454ddfa1@@33#32",
  name: "Super Administrator"
}) do
  {:ok, user, _opts} ->
    IO.puts("Superadmin created!")
    IO.puts("  ID:    #{user.id}")
    IO.puts("  Email: #{user.email}")
    IO.puts("  Role:  #{user.role}")

  {:ok, user} ->
    IO.puts("Superadmin created!")
    IO.puts("  ID:    #{user.id}")
    IO.puts("  Email: #{user.email}")
    IO.puts("  Role:  #{user.role}")

  {:error, reason} ->
    IO.puts("ERROR: #{inspect(reason)}")
end
