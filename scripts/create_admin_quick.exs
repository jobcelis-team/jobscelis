# Script rápido para crear usuario administrador
# Este script crea un admin directamente sin verificar BD primero
# Uso: mix run scripts/create_admin_quick.exs

alias StreamflixCore.Repo
alias StreamflixAccounts
alias StreamflixAccounts.Schemas.User

# Datos del administrador
email = "admin@streamflix.com"
name = "Administrador"
password = "Admin12345"

IO.puts("=== Creando Usuario Administrador ===")
IO.puts("Email: #{email}")
IO.puts("Nombre: #{name}")
IO.puts("")

# Verificar conexión a BD
case Repo.query("SELECT 1") do
  {:ok, _} ->
    IO.puts("✓ Conexión a BD OK")
  {:error, error} ->
    IO.puts("✗ Error de conexión a BD:")
    IO.inspect(error)
    IO.puts("")
    IO.puts("Asegúrate de que:")
    IO.puts("1. La base de datos esté corriendo")
    IO.puts("2. Las credenciales en .env sean correctas")
    IO.puts("3. Has ejecutado las migraciones: mix ecto.migrate")
    System.halt(1)
end

# Verificar si el usuario ya existe
existing_user = case StreamflixAccounts.get_user_by_email(email) do
  nil -> nil
  user -> user
end

if existing_user do
  IO.puts("El usuario ya existe. Promoviendo a admin...")
  
  case StreamflixAccounts.promote_to_admin(existing_user.id) do
    {:ok, user} ->
      IO.puts("✓ Usuario promovido a administrador exitosamente")
      IO.puts("  Email: #{user.email}")
      IO.puts("  Nombre: #{user.name}")
      IO.puts("  Role: #{user.role}")
    {:error, changeset} ->
      IO.puts("✗ Error al promover usuario:")
      IO.inspect(changeset.errors)
      System.halt(1)
  end
else
  # Crear nuevo admin
  attrs = %{
    email: email,
    password: password,
    name: name,
    role: "admin"
  }

  IO.puts("Creando nuevo usuario administrador...")
  
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
      IO.puts("✗ Error al crear usuario:")
      IO.inspect(changeset.errors)
      System.halt(1)
  end
end
