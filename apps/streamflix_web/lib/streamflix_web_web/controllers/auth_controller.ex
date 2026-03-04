defmodule StreamflixWebWeb.AuthController do
  use StreamflixWebWeb, :controller

  alias StreamflixAccounts
  alias StreamflixWebWeb.Workers.ObanEmailWorker

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
    opts = conn_audit_opts(conn, "web")

    case StreamflixAccounts.authenticate(email, password, opts) do
      {:ok, user} ->
        if user.mfa_enabled do
          # MFA required — store user ID in session for verification step
          conn
          |> put_session(:mfa_user_id, user.id)
          |> put_session(:mfa_remember, remember)
          |> put_session(:mfa_started_at, System.system_time(:second))
          |> redirect(to: "/mfa/verify")
        else
          complete_login(conn, user, remember)
        end

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, gettext("Email o contraseña incorrectos"))
        |> redirect(to: "/login")

      {:error, :account_locked} ->
        conn
        |> put_flash(
          :error,
          gettext(
            "Tu cuenta ha sido bloqueada temporalmente por múltiples intentos fallidos. Intenta de nuevo en %{minutes} minutos.",
            minutes: 15
          )
        )
        |> redirect(to: "/login")

      {:error, :account_inactive} ->
        conn
        |> put_flash(:error, gettext("Tu cuenta está inactiva. Contacta al soporte."))
        |> redirect(to: "/login")
    end
  end

  @doc false
  def complete_login(conn, user, remember) do
    {:ok, token, claims} = StreamflixAccounts.generate_token(user)
    jti = claims["jti"]

    # Create session record (must be sync — needed for session validity)
    audit_opts = conn_audit_opts(conn, "web")

    StreamflixAccounts.create_session(user.id, jti,
      ip_address: audit_opts[:ip_address],
      user_agent: audit_opts[:user_agent]
    )

    # Pre-warm caches so GET /platform has instant cache hits
    Cachex.put(:platform_cache, {:auth_user, user.id}, user, ttl: :timer.seconds(60))
    Cachex.put(:platform_cache, {:session_revoked, jti}, false, ttl: :timer.seconds(120))

    # Update last_login_at async — non-critical, shouldn't block redirect
    Task.Supervisor.start_child(StreamflixCore.TaskSupervisor, fn ->
      StreamflixAccounts.update_user(user, %{last_login_at: DateTime.utc_now()})
    end)

    conn =
      conn
      |> delete_session(:mfa_user_id)
      |> delete_session(:mfa_remember)
      |> delete_session(:mfa_started_at)
      |> put_session(:user_token, token)
      |> put_session(:user_id, user.id)
      |> put_session(:current_jti, jti)
      |> put_session(:last_activity_at, System.system_time(:second))
      |> put_flash(:info, gettext("Bienvenido, %{name}.", name: user.name || user.email))

    conn =
      if remember do
        put_session(conn, :remember_me, true)
      else
        conn
      end

    redirect_to =
      if user.role in ["admin", "superadmin"] do
        "/admin"
      else
        "/platform"
      end

    redirect(conn, to: redirect_to)
  end

  defp conn_audit_opts(conn, method) do
    ip = StreamflixWebWeb.Plugs.ClientIp.get_client_ip(conn)

    user_agent =
      case Plug.Conn.get_req_header(conn, "user-agent") do
        [ua | _] -> ua
        _ -> nil
      end

    [ip_address: ip, user_agent: user_agent, method: method]
  end

  @doc """
  Handles user logout.
  """
  def logout(conn, _params) do
    user_id = get_session(conn, :user_id)
    current_jti = get_session(conn, :current_jti)

    if user_id && current_jti do
      StreamflixAccounts.revoke_session_by_jti(user_id, current_jti)
    end

    conn
    |> clear_session()
    |> put_flash(:info, gettext("Has cerrado sesión correctamente"))
    |> redirect(to: "/")
  end

  # ---------- PASSWORD RESET ----------

  def forgot_password(conn, %{"email" => email}) when is_binary(email) and email != "" do
    case StreamflixAccounts.generate_reset_password_token(String.trim(email)) do
      {:ok, token, user} ->
        url = build_url(conn, "/reset-password/#{token}")
        locale = conn.assigns[:locale] || "es"

        ObanEmailWorker.new(%{
          "type" => "reset_password",
          "email" => user.email,
          "url" => url,
          "locale" => locale
        })
        |> Oban.insert()

        conn
        |> put_flash(
          :info,
          gettext(
            "Si tu correo está registrado, recibirás un enlace para restablecer tu contraseña."
          )
        )
        |> redirect(to: "/login")

      {:error, _} ->
        # Don't reveal whether email exists
        conn
        |> put_flash(
          :info,
          gettext(
            "Si tu correo está registrado, recibirás un enlace para restablecer tu contraseña."
          )
        )
        |> redirect(to: "/login")
    end
  end

  def forgot_password(conn, _params) do
    conn
    |> put_flash(:error, gettext("Ingresa tu correo electrónico."))
    |> redirect(to: "/forgot-password")
  end

  def reset_password(conn, %{
        "token" => token,
        "password" => password,
        "password_confirm" => confirm
      })
      when is_binary(password) do
    cond do
      String.length(password) < 8 ->
        conn
        |> put_flash(:error, gettext("La contraseña debe tener al menos 8 caracteres"))
        |> redirect(to: "/reset-password/#{token}")

      password != confirm ->
        conn
        |> put_flash(:error, gettext("Las contraseñas no coinciden."))
        |> redirect(to: "/reset-password/#{token}")

      true ->
        case StreamflixAccounts.reset_user_password(token, password) do
          {:ok, _user} ->
            conn
            |> put_flash(:info, gettext("Contraseña restablecida. Ya puedes iniciar sesión."))
            |> redirect(to: "/login")

          {:error, :invalid_token} ->
            conn
            |> put_flash(:error, gettext("El enlace ha expirado o no es válido."))
            |> redirect(to: "/forgot-password")

          {:error, :password_recently_used} ->
            conn
            |> put_flash(
              :error,
              gettext("Esta contraseña fue usada recientemente. Elige una diferente.")
            )
            |> redirect(to: "/reset-password/#{token}")

          {:error, %Ecto.Changeset{} = changeset} ->
            errors = format_errors(changeset)

            conn
            |> put_flash(
              :error,
              gettext("Error al cambiar contraseña: %{details}", details: errors)
            )
            |> redirect(to: "/reset-password/#{token}")
        end
    end
  end

  def reset_password(conn, %{"token" => token}) do
    conn
    |> put_flash(:error, gettext("Ingresa una contraseña válida."))
    |> redirect(to: "/reset-password/#{token}")
  end

  # ---------- EMAIL VERIFICATION ----------

  def confirm_email(conn, %{"token" => token}) do
    case StreamflixAccounts.confirm_user_email(token) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, gettext("Correo verificado correctamente."))
        |> redirect(to: "/login")

      {:error, _} ->
        conn
        |> put_flash(:error, gettext("El enlace de verificación ha expirado o no es válido."))
        |> redirect(to: "/login")
    end
  end

  defp build_url(conn, path) do
    scheme = if conn.scheme == :https, do: "https", else: "http"
    port = conn.port

    port_str =
      if (scheme == "https" and port == 443) or (scheme == "http" and port == 80),
        do: "",
        else: ":#{port}"

    "#{scheme}://#{conn.host}#{port_str}#{path}"
  end

  defp do_register_success(conn, user) do
    do_register_success(conn, user, [])
  end

  defp do_register_success(conn, user, opts) do
    {:ok, token, claims} = StreamflixAccounts.generate_token(user)
    jti = claims["jti"]

    # Create session record
    audit_opts = conn_audit_opts(conn, "web")

    StreamflixAccounts.create_session(user.id, jti,
      ip_address: audit_opts[:ip_address],
      user_agent: audit_opts[:user_agent]
    )

    # Send email verification asynchronously via Oban
    case StreamflixAccounts.generate_email_confirmation_token(user) do
      {:ok, confirm_token} ->
        url = build_url(conn, "/confirm-email/#{confirm_token}")
        locale = conn.assigns[:locale] || "es"

        ObanEmailWorker.new(%{
          "type" => "email_confirmation",
          "email" => user.email,
          "url" => url,
          "locale" => locale
        })
        |> Oban.insert()

      _ ->
        :ok
    end

    conn =
      conn
      |> put_session(:user_token, token)
      |> put_session(:user_id, user.id)
      |> put_session(:current_jti, jti)
      |> put_flash(:info, gettext("Cuenta creada. Revisa tu correo para verificar tu email."))

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

    name =
      params["name"] && params["name"] |> to_string() |> String.trim() |> String.slice(0, 255)

    cond do
      not (is_binary(email) and is_binary(password)) ->
        {:error, gettext("Faltan email o contraseña")}

      byte_size(email) > 254 ->
        {:error, gettext("Email demasiado largo")}

      byte_size(password) < 8 ->
        {:error, gettext("La contraseña debe tener al menos 8 caracteres")}

      byte_size(password) > 72 ->
        {:error, gettext("Contraseña demasiado larga")}

      not String.match?(email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/) or String.length(email) < 3 ->
        {:error, gettext("Email no válido")}

      true ->
        {:ok, email, password, name}
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
    |> Enum.map_join("; ", fn {field, errors} ->
      field_label = translate_field(field)
      "#{field_label}: #{Enum.join(errors, ", ")}"
    end)
  end

  defp translate_field(:email), do: gettext("correo electrónico")
  defp translate_field(:password), do: gettext("contraseña")
  defp translate_field(:name), do: gettext("nombre")
  defp translate_field(field), do: to_string(field)
end
