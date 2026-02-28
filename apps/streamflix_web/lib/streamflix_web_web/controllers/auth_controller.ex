defmodule StreamflixWebWeb.AuthController do
  use StreamflixWebWeb, :controller

  alias StreamflixAccounts

  @doc """
  Handles user registration from web form.
  """
  def register(conn, params) do
    case validate_auth_params(params) do
      {:ok, email, password, name} ->
        do_register(conn, email, password, name, params["plan"] || "basic")

      {:error, msg} ->
        conn
        |> put_flash(:error, msg)
        |> redirect(to: ~p"/signup?plan=#{params["plan"] || "basic"}")
    end
  end

  defp do_register(conn, email, password, name, plan) do
    attrs = %{
      email: email,
      password: password,
      name: name,
      plan: plan
    }

    case StreamflixAccounts.register_user(attrs) do
      {:ok, user} ->
        do_register_success(conn, user)

      {:ok, user, opts} ->
        do_register_success(conn, user, opts)

      {:error, :email_already_registered} ->
        conn
        |> put_flash(:error, gettext("Este correo ya está registrado. Usa otro o inicia sesión."))
        |> redirect(to: ~p"/signup?plan=#{plan}")

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = format_errors(changeset)

        conn
        |> put_flash(:error, gettext("Error al crear cuenta: %{details}", details: errors))
        |> redirect(to: ~p"/signup?plan=#{plan}")

      {:error, _reason} ->
        conn
        |> put_flash(:error, gettext("Error al crear cuenta"))
        |> redirect(to: ~p"/signup")
    end
  end

  @doc """
  Handles user login from web form.
  """
  def login(conn, params) do
    case validate_auth_params(params) do
      {:ok, email, password, _name} ->
        do_login(conn, email, password, Map.get(params, "remember") == "on")

      {:error, msg} ->
        conn
        |> put_flash(:error, msg)
        |> redirect(to: "/login")
    end
  end

  defp do_login(conn, email, password, remember) do
    case StreamflixAccounts.authenticate(email, password) do
      {:ok, user} ->
        {:ok, token, _claims} = StreamflixAccounts.generate_token(user)

        # Update last login
        StreamflixAccounts.update_user(user, %{last_login_at: DateTime.utc_now()})

        conn =
          conn
          |> put_session(:user_token, token)
          |> put_session(:user_id, user.id)
          |> put_flash(:info, gettext("Bienvenido, %{name}.", name: user.name || user.email))

        # If "remember me" is checked, set longer session expiration
        conn = if remember do
          # Set session to expire in 30 days
          put_session(conn, :remember_me, true)
        else
          conn
        end

        redirect_to = if user.role in ["admin", "superadmin"] do
          "/admin"
        else
          "/platform"
        end

        redirect(conn, to: redirect_to)

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, gettext("Email o contraseña incorrectos"))
        |> redirect(to: "/login")

      {:error, :account_inactive} ->
        conn
        |> put_flash(:error, gettext("Tu cuenta está inactiva. Contacta al soporte."))
        |> redirect(to: "/login")
    end
  end

  @doc """
  Handles user logout.
  """
  def logout(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, gettext("Has cerrado sesión correctamente"))
    |> redirect(to: "/")
  end

  defp do_register_success(conn, user) do
    do_register_success(conn, user, [])
  end

  defp do_register_success(conn, user, opts) do
    {:ok, token, _claims} = StreamflixAccounts.generate_token(user)

    conn =
      conn
      |> put_session(:user_token, token)
      |> put_session(:user_id, user.id)
      |> put_flash(:info, gettext("Cuenta creada. Bienvenido."))

    conn =
      case Keyword.get(opts, :api_key) do
        raw_key when is_binary(raw_key) and raw_key != "" ->
          put_session(conn, :fresh_api_key, raw_key)

        _ ->
          conn
      end

    redirect(conn, to: ~p"/platform")
  end

  # Email 3-254 chars, password 8-72 chars, name opcional max 255. Sanitiza trim y downcase email.
  defp validate_auth_params(params) when is_map(params) do
    email = params["email"] && to_string(params["email"]) |> String.trim() |> String.downcase()
    password = params["password"] && to_string(params["password"])
    name = params["name"] && (params["name"] |> to_string() |> String.trim() |> String.slice(0, 255))

    cond do
      not (is_binary(email) and is_binary(password)) -> {:error, gettext("Faltan email o contraseña")}
      byte_size(email) > 254 -> {:error, gettext("Email demasiado largo")}
      byte_size(password) < 8 -> {:error, gettext("La contraseña debe tener al menos 8 caracteres")}
      byte_size(password) > 72 -> {:error, gettext("Contraseña demasiado larga")}
      not String.match?(email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/) or String.length(email) < 3 -> {:error, gettext("Email no válido")}
      true -> {:ok, email, password, name}
    end
  end

  defp validate_auth_params(_), do: {:error, gettext("Datos inválidos")}

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      translated = Gettext.gettext(StreamflixWebWeb.Gettext, msg)
      Regex.replace(~r"%{(\w+)}", translated, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {field, errors} ->
      field_label = translate_field(field)
      "#{field_label}: #{Enum.join(errors, ", ")}"
    end)
    |> Enum.join("; ")
  end

  defp translate_field(:email), do: gettext("email")
  defp translate_field(:password), do: gettext("password")
  defp translate_field(:name), do: gettext("name")
  defp translate_field(field), do: to_string(field)
end
