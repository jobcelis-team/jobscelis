defmodule StreamflixWebWeb.MfaController do
  use StreamflixWebWeb, :controller

  alias StreamflixAccounts
  alias StreamflixCore.Audit

  @mfa_timeout_seconds 300

  @doc "GET /mfa/verify — render the MFA code entry form."
  def show(conn, _params) do
    case validate_mfa_session(conn) do
      {:ok, _user_id} ->
        render(conn, :mfa_verify, layout: false)

      :expired ->
        conn
        |> clear_mfa_session()
        |> put_flash(:error, gettext("La sesión MFA ha expirado. Inicia sesión nuevamente."))
        |> redirect(to: "/login")

      :missing ->
        redirect(conn, to: "/login")
    end
  end

  @doc "POST /mfa/verify — validate a 6-digit TOTP code."
  def verify(conn, %{"code" => code}) do
    case validate_mfa_session(conn) do
      {:ok, user_id} ->
        user = StreamflixAccounts.get_user(user_id)

        if user && StreamflixAccounts.verify_mfa_code(user, String.trim(code)) do
          Audit.record("user.mfa_verified",
            user_id: user.id,
            resource_type: "user",
            resource_id: user.id,
            metadata: %{method: "totp"}
          )

          remember = get_session(conn, :mfa_remember) || false
          StreamflixWebWeb.AuthController.complete_login(conn, user, remember)
        else
          if user do
            Audit.record("user.mfa_failed",
              user_id: user.id,
              resource_type: "user",
              resource_id: user.id,
              metadata: %{method: "totp"}
            )
          end

          conn
          |> put_flash(:error, gettext("Código incorrecto. Inténtalo de nuevo."))
          |> redirect(to: "/mfa/verify")
        end

      :expired ->
        conn
        |> clear_mfa_session()
        |> put_flash(:error, gettext("La sesión MFA ha expirado. Inicia sesión nuevamente."))
        |> redirect(to: "/login")

      :missing ->
        redirect(conn, to: "/login")
    end
  end

  def verify(conn, _params) do
    conn
    |> put_flash(:error, gettext("Ingresa el código de verificación."))
    |> redirect(to: "/mfa/verify")
  end

  @doc "POST /mfa/verify-backup — validate a backup code."
  def verify_backup(conn, %{"code" => code}) do
    case validate_mfa_session(conn) do
      {:ok, user_id} ->
        user = StreamflixAccounts.get_user(user_id)

        case user && StreamflixAccounts.verify_mfa_backup_code(user, String.trim(code)) do
          {:ok, _updated_user} ->
            remember = get_session(conn, :mfa_remember) || false
            # Re-fetch user after backup code consumption
            user = StreamflixAccounts.get_user(user_id)
            StreamflixWebWeb.AuthController.complete_login(conn, user, remember)

          _ ->
            if user do
              Audit.record("user.mfa_failed",
                user_id: user.id,
                resource_type: "user",
                resource_id: user.id,
                metadata: %{method: "backup_code"}
              )
            end

            conn
            |> put_flash(:error, gettext("Código de recuperación incorrecto."))
            |> redirect(to: "/mfa/verify")
        end

      :expired ->
        conn
        |> clear_mfa_session()
        |> put_flash(:error, gettext("La sesión MFA ha expirado. Inicia sesión nuevamente."))
        |> redirect(to: "/login")

      :missing ->
        redirect(conn, to: "/login")
    end
  end

  def verify_backup(conn, _params) do
    conn
    |> put_flash(:error, gettext("Ingresa el código de recuperación."))
    |> redirect(to: "/mfa/verify")
  end

  # ── Helpers ────────────────────────────────────────────────────────

  defp validate_mfa_session(conn) do
    user_id = get_session(conn, :mfa_user_id)
    started_at = get_session(conn, :mfa_started_at)

    cond do
      is_nil(user_id) -> :missing
      is_nil(started_at) -> :missing
      System.system_time(:second) - started_at > @mfa_timeout_seconds -> :expired
      true -> {:ok, user_id}
    end
  end

  defp clear_mfa_session(conn) do
    conn
    |> delete_session(:mfa_user_id)
    |> delete_session(:mfa_remember)
    |> delete_session(:mfa_started_at)
  end
end
