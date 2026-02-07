# Script for populating the database with initial data.
# Run after migrations. Usage: mix run apps/streamflix_core/priv/repo/seeds.exs
#
# Creates one admin user (and its default project + API key) for the Webhooks platform.

alias StreamflixCore.Repo
alias StreamflixAccounts

IO.puts("Seeding Webhooks platform...")

# Create admin if not already present (by email)
admin_email = System.get_env("ADMIN_EMAIL") || "admin@example.com"
admin_password = System.get_env("ADMIN_PASSWORD") || "admin123456"

case StreamflixAccounts.get_user_by_email(admin_email) do
  nil ->
    case StreamflixAccounts.create_admin(%{
           email: admin_email,
           password: admin_password,
           name: "Admin"
         }) do
      {:ok, user, opts} ->
        IO.puts("  Admin user created: #{user.email}")
        if raw = Keyword.get(opts, :api_key), do: IO.puts("  API key (save it): #{raw}")
      {:error, changeset} ->
        IO.puts("  Failed to create admin: #{inspect(changeset.errors)}")
    end
  _ ->
    IO.puts("  Admin already exists: #{admin_email}")
end

IO.puts("Seeding complete.")
IO.puts("Start server: mix phx.server")
IO.puts("Login: #{admin_email} / #{admin_password}")
IO.puts("")
IO.puts("To create another admin: mix run scripts/create_admin.exs")
IO.puts("")
