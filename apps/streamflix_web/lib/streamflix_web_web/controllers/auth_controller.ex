defmodule StreamflixWebWeb.AuthController do
  use StreamflixWebWeb, :controller

  alias StreamflixAccounts

  @doc """
  Handles user registration from web form.
  """
  def register(conn, %{"email" => email, "password" => password} = params) do
    attrs = %{
      email: email,
      password: password,
      name: params["name"],
      plan: params["plan"] || "basic"
    }

    case StreamflixAccounts.register_user(attrs) do
      {:ok, user} ->
        {:ok, token, _claims} = StreamflixAccounts.generate_token(user)

        conn
        |> put_session(:user_token, token)
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "¡Cuenta creada exitosamente! Bienvenido a StreamFlix.")
        |> redirect(to: ~p"/browse")

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = format_errors(changeset)
        
        conn
        |> put_flash(:error, "Error al crear cuenta: #{errors}")
        |> redirect(to: ~p"/signup?plan=#{params["plan"] || "basic"}")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Error: #{inspect(reason)}")
        |> redirect(to: ~p"/signup")
    end
  end

  @doc """
  Handles user login from web form.
  """
  def login(conn, %{"email" => email, "password" => password}) do
    case StreamflixAccounts.authenticate(email, password) do
      {:ok, user} ->
        {:ok, token, _claims} = StreamflixAccounts.generate_token(user)

        # Update last login
        StreamflixAccounts.update_user(user, %{last_login_at: DateTime.utc_now()})

        conn
        |> put_session(:user_token, token)
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "¡Bienvenido de vuelta, #{user.name}!")
        |> redirect(to: ~p"/browse")

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, "Email o contraseña incorrectos")
        |> redirect(to: ~p"/login")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Error al iniciar sesión")
        |> redirect(to: ~p"/login")
    end
  end

  @doc """
  Handles user logout.
  """
  def logout(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "Has cerrado sesión correctamente")
    |> redirect(to: ~p"/")
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end
end
