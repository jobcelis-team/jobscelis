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

# Optional: create superadmin via env (e.g. SUPERADMIN_EMAIL / SUPERADMIN_PASSWORD)
superadmin_email = System.get_env("SUPERADMIN_EMAIL")
superadmin_password = System.get_env("SUPERADMIN_PASSWORD")
if superadmin_email != nil and superadmin_email != "" and superadmin_password != nil and superadmin_password != "" do
  case StreamflixAccounts.get_user_by_email(superadmin_email) do
    nil ->
      case StreamflixAccounts.create_superadmin(%{
             email: superadmin_email,
             password: superadmin_password,
             name: "Super Administrator"
           }) do
        {:ok, user, opts} ->
          IO.puts("  Superadmin created: #{user.email}")
          if raw = Keyword.get(opts, :api_key), do: IO.puts("  API key (save it): #{raw}")
        {:error, changeset} ->
          IO.puts("  Failed to create superadmin: #{inspect(changeset.errors)}")
      end
    existing ->
      case StreamflixAccounts.promote_to_superadmin(existing.id) do
        {:ok, _} -> IO.puts("  User promoted to superadmin: #{superadmin_email}")
        {:error, _} -> IO.puts("  Failed to promote to superadmin")
      end
  end
end

IO.puts("Seeding complete.")
IO.puts("Start server: mix phx.server")
IO.puts("Login: #{admin_email} / #{admin_password}")
IO.puts("")
IO.puts("To create another admin: mix run scripts/create_admin.exs")
IO.puts("To create superadmin: mix run scripts/create_superadmin.exs")
IO.puts("")
