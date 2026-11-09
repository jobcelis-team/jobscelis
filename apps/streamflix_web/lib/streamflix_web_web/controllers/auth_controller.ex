defmodule StreamflixWebWeb.AuthController do
  use StreamflixWebWeb, :controller

  require Logger

  alias StreamflixAccounts
  alias StreamflixWebWeb.Workers.ObanEmailWorker

  @doc """
  Handles user registration from web form.
  """
  # Honeypot: "website" is hidden from people in the signup form, so only bots fill
  # it. They get the generic error, with nothing hinting at the reason.
  def register(conn, %{"website" => trap} = params) when is_binary(trap) and trap != "" do
    Logger.info("[Auth] Signup rejected: honeypot field filled")
    signup_error(conn, gettext("Error al crear cuenta"), signup_plan(params), params)
  end

  def register(conn, params) do
    plan = signup_plan(params)

    case validate_auth_params(params) do
      {:ok, email, password, name} ->
        do_register(conn, email, password, name, plan, params)

      {:error, msg} ->
        signup_error(conn, msg, plan, params)
    end
  end

  defp do_register(conn, email, password, name, plan, params) do
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
        signup_error(
          conn,
          gettext("Este correo ya está registrado. Usa otro o inicia sesión."),
          plan,
          params
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = format_errors(changeset)

        signup_error(
          conn,
          gettext("Error al crear cuenta: %{details}", details: errors),
          plan,
          params
        )

      {:error, _reason} ->
        signup_error(conn, gettext("Error al crear cuenta"), plan, params)
    end
  end

  # Keep what the user typed (never the password) so a validation error does
  # not wipe the form. Stored in the session, not the URL, to keep the email
  # out of logs and browser history.
  defp signup_error(conn, message, plan, params) do
    prefill = %{
      "name" => params["name"] |> prefill_string() |> String.slice(0, 255),
      "email" => params["email"] |> prefill_string() |> String.slice(0, 254)
    }

    conn
    |> put_session(:signup_prefill, prefill)
    |> put_flash(:error, message)
    |> redirect(to: ~p"/signup?plan=#{plan}")
  end

  defp signup_plan(%{"plan" => plan}) when is_binary(plan) and plan != "", do: plan
  defp signup_plan(_params), do: "standard"

  defp prefill_string(value) when is_binary(value), do: value
  defp prefill_string(_), do: ""

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
          conn
          |> put_session(:mfa_user_id, user.id)
          |> put_session(:mfa_remember, remember)
          |> put_session(:mfa_started_at, System.system_time(:second))
          |> redirect(to: "/mfa/verify")
        else
          complete_login(conn, user, remember)
        end

      # A locked account gets the same answer as a wrong password: a distinct
      # message would tell anyone which emails are registered.
      {:error, reason} when reason in [:invalid_credentials, :account_locked] ->
        conn
        |> put_flash(:error, gettext("Email o contraseña incorrectos"))
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

    audit_opts = conn_audit_opts(conn, "web")

    StreamflixAccounts.create_session(user.id, jti,
      ip_address: audit_opts[:ip_address],
      user_agent: audit_opts[:user_agent]
    )

    Cachex.put(:platform_cache, {:auth_user, user.id}, user, expire: :timer.seconds(60))
    Cachex.put(:platform_cache, {:session_revoked, jti}, false, expire: :timer.seconds(120))

    # Update last_login_at async — non-critical, shouldn't block redirect
    Task.Supervisor.start_child(StreamflixCore.TaskSupervisor, fn ->
      StreamflixAccounts.update_user(user, %{last_login_at: DateTime.utc_now()})
    end)

    conn =
      conn
      |> delete_session(:mfa_user_id)
      |> delete_session(:mfa_remember)
      |> delete_session(:mfa_started_at)
      |> configure_session(renew: true)
      |> put_session(:user_token, token)
      |> put_session(:user_id, user.id)
      |> put_session(:current_jti, jti)
      |> put_session(:live_socket_id, StreamflixWebWeb.SessionRevocation.socket_id(jti))
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
  GET /logout, used by the logout links. Same as `logout/2`, which ignores
  the request when another site triggers it (image tag, link).
  """
  def logout_link(conn, params), do: logout(conn, params)

  @doc """
  Handles user logout.
  """
  def logout(conn, params) do
    if cross_site_get?(conn) do
      # GET /logout requested by another site (image tag, link): ignore it,
      # logging users out must not be triggerable cross-site.
      redirect(conn, to: "/")
    else
      user_id = get_session(conn, :user_id)
      current_jti = get_session(conn, :current_jti)

      if user_id && current_jti do
        StreamflixAccounts.revoke_session_by_jti(user_id, current_jti)
      end

      message =
        if params["reason"] == "account_deleted",
          do: gettext("Cuenta eliminada correctamente."),
          else: gettext("Has cerrado sesión correctamente")

      conn
      |> clear_session()
      |> configure_session(renew: true)
      |> put_flash(:info, message)
      |> redirect(to: "/")
    end
  end

  @doc """
  POST /session/keepalive — called by the browser while the user is active, so
  long LiveView-only sessions are not ended by the inactivity timeout (the
  SessionTimeout plug records the activity). 204, or 401 when not logged in.
  """
  def keepalive(conn, _params) do
    status = if get_session(conn, :user_token), do: 204, else: 401
    send_resp(conn, status, "")
  end

  defp cross_site_get?(conn) do
    conn.method == "GET" and get_req_header(conn, "sec-fetch-site") == ["cross-site"]
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

      # Same cap as signup/login: no Argon2 work on oversized input
      byte_size(password) > 72 ->
        conn
        |> put_flash(:error, gettext("Contraseña demasiado larga"))
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

  # Links sent by email always use the configured public URL, never the
  # request's Host header (a forged Host would send the token elsewhere).
  defp build_url(_conn, path), do: StreamflixWebWeb.Endpoint.url() <> path

  defp do_register_success(conn, user) do
    do_register_success(conn, user, [])
  end

  defp do_register_success(conn, user, opts) do
    {:ok, token, claims} = StreamflixAccounts.generate_token(user)
    jti = claims["jti"]

    audit_opts = conn_audit_opts(conn, "web")

    StreamflixAccounts.create_session(user.id, jti,
      ip_address: audit_opts[:ip_address],
      user_agent: audit_opts[:user_agent]
    )

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
      |> configure_session(renew: true)
      |> put_session(:user_token, token)
      |> put_session(:user_id, user.id)
      |> put_session(:current_jti, jti)
      |> put_session(:live_socket_id, StreamflixWebWeb.SessionRevocation.socket_id(jti))
      |> put_session(:last_activity_at, System.system_time(:second))
      |> put_flash(:info, gettext("Cuenta creada. Revisa tu correo para verificar tu email."))

    # Shown once on the dashboard, never stored in the session cookie
    StreamflixWebWeb.FreshApiKey.put(user.id, Keyword.get(opts, :api_key))

    redirect(conn, to: ~p"/platform")
  end

  # Email 3-254 chars, password 8-72 chars, name optional max 255. Trims and downcases email.
  # Only plain strings are accepted: nested params (maps/lists) get the normal
  # validation error instead of crashing on to_string/1.
  defp validate_auth_params(%{"email" => email, "password" => password} = params)
       when is_binary(email) and is_binary(password) do
    email = email |> String.trim() |> String.downcase()

    name =
      case params["name"] do
        name when is_binary(name) -> name |> String.trim() |> String.slice(0, 255)
        _ -> nil
      end

    cond do
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

  defp validate_auth_params(_), do: {:error, gettext("Faltan email o contraseña")}

  # Changeset messages from StreamflixAccounts, translated in format_errors/1;
  # listed here so `mix gettext.extract` keeps them in the .po files
  @doc false
  def translatable_changeset_errors do
    [
      gettext_noop("cannot contain links or HTML"),
      gettext_noop("temporary email addresses are not allowed")
    ]
  end

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
