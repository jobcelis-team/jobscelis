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
        do_register_success(conn, user)

      {:ok, user, _opts} ->
        do_register_success(conn, user)

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
  def login(conn, %{"email" => email, "password" => password} = params) do
    remember = Map.get(params, "remember") == "on"

    case StreamflixAccounts.authenticate(email, password) do
      {:ok, user} ->
        {:ok, token, _claims} = StreamflixAccounts.generate_token(user)

        # Update last login
        StreamflixAccounts.update_user(user, %{last_login_at: DateTime.utc_now()})

        conn =
          conn
          |> put_session(:user_token, token)
          |> put_session(:user_id, user.id)
          |> put_flash(:info, "Bienvenido, #{user.name}.")

        # If "remember me" is checked, set longer session expiration
        conn = if remember do
          # Set session to expire in 30 days
          put_session(conn, :remember_me, true)
        else
          conn
        end

        redirect_to = if user.role == "admin" do
          "/admin"
        else
          "/platform"
        end

        redirect(conn, to: redirect_to)

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, "Email o contraseña incorrectos")
        |> redirect(to: "/login")

      {:error, :account_inactive} ->
        conn
        |> put_flash(:error, "Tu cuenta está inactiva. Contacta al soporte.")
        |> redirect(to: "/login")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Error al iniciar sesión")
        |> redirect(to: "/login")
    end
  end

  @doc """
  Handles user logout.
  """
  def logout(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "Has cerrado sesión correctamente")
    |> redirect(to: "/")
  end

  defp do_register_success(conn, user) do
    {:ok, token, _claims} = StreamflixAccounts.generate_token(user)

    conn
    |> put_session(:user_token, token)
    |> put_session(:user_id, user.id)
    |> put_flash(:info, "Cuenta creada. Bienvenido.")
    |> redirect(to: ~p"/platform")
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
