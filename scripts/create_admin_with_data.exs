# Script para crear usuario administrador con datos directos
# Uso: mix run scripts/create_admin_with_data.exs email nombre password
# O: mix run scripts/create_admin_with_data.exs

alias StreamflixCore.Repo
alias StreamflixAccounts
alias StreamflixAccounts.Schemas.User

# Obtener datos de argumentos o entrada interactiva
{email, name, password} = case System.argv() do
  [e, n, p] -> {e, n, p}
  _ ->
    IO.puts("=== Crear Usuario Administrador ===")
    IO.puts("")
    e = IO.gets("Email: ") |> String.trim()
    n = IO.gets("Nombre: ") |> String.trim()
    p = IO.gets("Contraseña: ") |> String.trim()
    {e, n, p}
end

if email == "" or password == "" do
  IO.puts("Error: Email y contraseña son requeridos")
  System.halt(1)
end

# Verificar si el usuario ya existe
existing_user = StreamflixAccounts.get_user_by_email(email)

if existing_user do
  IO.puts("El usuario ya existe. Promoviendo a admin...")
  
  case StreamflixAccounts.promote_to_admin(existing_user.id) do
    {:ok, user} ->
      IO.puts("✓ Usuario promovido a administrador exitosamente")
      IO.puts("  Email: #{user.email}")
      IO.puts("  Nombre: #{user.name}")
      IO.puts("  Role: #{user.role}")
    {:error, changeset} ->
      IO.puts("Error al promover usuario:")
      IO.inspect(changeset.errors)
      System.halt(1)
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
      IO.puts("✓ Usuario administrador creado exitosamente")
      IO.puts("  Email: #{user.email}")
      IO.puts("  Nombre: #{user.name}")
      IO.puts("  Role: #{user.role}")
      IO.puts("")
      IO.puts("Ahora puedes iniciar sesión en /login con estas credenciales")
      
    {:error, changeset} ->
      IO.puts("Error al crear usuario:")
      IO.inspect(changeset.errors)
      System.halt(1)
  end
end
