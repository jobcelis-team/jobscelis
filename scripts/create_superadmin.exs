# Script para crear o promover usuario a Superadmin
# Uso: mix run scripts/create_superadmin.exs
#
# El superadmin puede acceder a /admin y asignar roles admin/superadmin a otros usuarios.

alias StreamflixCore.Repo
alias StreamflixAccounts

IO.puts("=== Crear Superadmin ===")
IO.puts("")

# Verificar conexión a BD
case Repo.query("SELECT 1") do
  {:ok, _} -> :ok
  {:error, error} ->
    IO.puts("Error de conexión a la base de datos: #{inspect(error)}")
    IO.puts("Ejecuta: mix ecto.migrate y comprueba tu configuración.")
    System.halt(1)
end

email = IO.gets("Email: ") |> String.trim()
name = IO.gets("Nombre: ") |> String.trim()
IO.puts("Contraseña (mín. 8 caracteres, al menos una mayúscula, una minúscula y un número):")
password = IO.gets("Contraseña: ") |> String.trim()

if email == "" or password == "" do
  IO.puts("Error: Email y contraseña son requeridos.")
  System.halt(1)
end

existing = StreamflixAccounts.get_user_by_email(email)

if existing do
  IO.puts("El usuario ya existe. ¿Promover a superadmin? (s/n): ")
  response = IO.gets("") |> String.trim() |> String.downcase()

  if response == "s" do
    case StreamflixAccounts.promote_to_superadmin(existing.id) do
      {:ok, user} ->
        IO.puts("")
        IO.puts("✓ Usuario promovido a superadmin.")
        IO.puts("  Email: #{user.email}")
        IO.puts("  Rol: #{user.role}")
      {:error, _} ->
        IO.puts("Error al actualizar el usuario.")
        System.halt(1)
    end
  else
    IO.puts("Operación cancelada.")
  end
else
  attrs = %{
    email: email,
    password: password,
    name: name || "Super Administrator"
  }

  case StreamflixAccounts.create_superadmin(attrs) do
    {:ok, user, opts} ->
      IO.puts("")
      IO.puts("✓ Superadmin creado correctamente.")
      IO.puts("  Email: #{user.email}")
      IO.puts("  Nombre: #{user.name}")
      IO.puts("  Rol: #{user.role}")
      if raw = Keyword.get(opts, :api_key), do: IO.puts("  API key (guárdala): #{raw}")
      IO.puts("")
      IO.puts("Inicia sesión en /login y accede a /admin")
    {:ok, user} ->
      IO.puts("")
      IO.puts("✓ Superadmin creado correctamente.")
      IO.puts("  Email: #{user.email}")
      IO.puts("Inicia sesión en /login y accede a /admin")
    {:error, changeset} ->
      IO.puts("Error al crear superadmin.")
      if Keyword.has_key?(changeset.errors, :password) do
        IO.puts("")
        IO.puts("Requisitos de contraseña:")
        IO.puts("  - Mínimo 8 caracteres")
        IO.puts("  - Al menos una letra mayúscula (A-Z)")
        IO.puts("  - Al menos una letra minúscula (a-z)")
        IO.puts("  - Al menos un número (0-9)")
        IO.puts("")
        IO.puts("Ejemplo válido: Root12345")
      else
        IO.inspect(changeset.errors)
      end
      System.halt(1)
  end
end
