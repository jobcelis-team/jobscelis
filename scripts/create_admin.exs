# Script para crear usuario administrador
# Uso: mix run scripts/create_admin.exs
# O con datos: mix run scripts/create_admin_quick.exs

alias StreamflixCore.Repo
alias StreamflixAccounts
alias StreamflixAccounts.Schemas.User

# Verificar conexión a BD primero
IO.puts("=== Verificando conexión a base de datos ===")
case Repo.query("SELECT 1") do
  {:ok, _} ->
    IO.puts("✓ Conexión OK")
  {:error, error} ->
    IO.puts("✗ Error de conexión a la base de datos")
    IO.puts("")
    IO.puts("Asegúrate de que:")
    IO.puts("1. La base de datos esté corriendo y accesible")
    IO.puts("2. El archivo .env esté configurado correctamente")
    IO.puts("3. Has ejecutado las migraciones: mix ecto.migrate")
    IO.puts("")
    IO.puts("Error: #{inspect(error)}")
    System.halt(1)
end

IO.puts("")
IO.puts("=== Crear Usuario Administrador ===")
IO.puts("")

email = IO.gets("Email: ") |> String.trim()
name = IO.gets("Nombre: ") |> String.trim()
password = IO.gets("Contraseña: ") |> String.trim()

if email == "" or password == "" do
  IO.puts("Error: Email y contraseña son requeridos")
  System.halt(1)
end

# Verificar si el usuario ya existe
existing_user = StreamflixAccounts.get_user_by_email(email)

if existing_user do
  IO.puts("El usuario ya existe. ¿Promover a admin? (s/n): ")
  response = IO.gets("") |> String.trim() |> String.downcase()
  
  if response == "s" do
    case StreamflixAccounts.promote_to_admin(existing_user.id) do
      {:ok, user} ->
        IO.puts("✓ Usuario promovido a administrador exitosamente")
        IO.puts("  Email: #{user.email}")
        IO.puts("  Role: #{user.role}")
      {:error, changeset} ->
        IO.puts("Error al promover usuario:")
        IO.inspect(changeset.errors)
        System.halt(1)
    end
  else
    IO.puts("Operación cancelada")
  end
else
  # Crear nuevo admin
  attrs = %{
    email: email,
    password: password,
    name: name || "Administrator",
    role: "admin"
  }

  case StreamflixAccounts.create_admin(attrs) do
    {:ok, user} ->
      IO.puts("")
      IO.puts("✓ Usuario administrador creado exitosamente")
      IO.puts("  Email: #{user.email}")
      IO.puts("  Nombre: #{user.name}")
      IO.puts("  Role: #{user.role}")
      IO.puts("")
      IO.puts("═══════════════════════════════════════")
      IO.puts("  CREDENCIALES DE ACCESO")
      IO.puts("═══════════════════════════════════════")
      IO.puts("  Email: #{user.email}")
      IO.puts("  Contraseña: #{password}")
      IO.puts("")
      IO.puts("Ahora puedes iniciar sesión en:")
      IO.puts("  http://localhost:4000/login")
      IO.puts("")
      IO.puts("Serás redirigido automáticamente a /admin")
      
    {:error, changeset} ->
      IO.puts("Error al crear usuario:")
      IO.inspect(changeset.errors)
      System.halt(1)
  end
end
