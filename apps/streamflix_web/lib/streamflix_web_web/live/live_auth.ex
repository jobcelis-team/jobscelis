defmodule StreamflixWebWeb.LiveAuth do
  @moduledoc """
  LiveView authentication hooks.
  """
  use Gettext, backend: StreamflixWebWeb.Gettext

  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:mount_current_user, _params, session, socket) do
    socket = mount_current_user(socket, session)

    # Redirect to login if not authenticated
    if is_nil(socket.assigns.current_user) do
      {:halt, redirect(socket, to: "/login")}
    else
      {:cont, socket}
    end
  end

  def on_mount(:mount_current_user_optional, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  def on_mount(:mount_admin_user, _params, session, socket) do
    socket = mount_current_user(socket, session)

    # Check if user is authenticated
    if is_nil(socket.assigns.current_user) do
      {:halt, redirect(socket, to: "/login")}
    else
      is_admin = check_admin(socket.assigns.current_user)

      if is_admin do
        {:cont, attach_hook(socket, :admin_recheck, :handle_event, &recheck_admin/3)}
      else
        {:halt,
         redirect(socket, to: "/")
         |> put_flash(:error, gettext("Acceso denegado. Se requieren permisos de administrador."))}
      end
    end
  end

  defp mount_current_user(socket, session) do
    case session["user_token"] do
      nil ->
        assign(socket, :current_user, nil)

      token ->
        if session_expired?(session) do
          assign(socket, :current_user, nil)
        else
          case StreamflixAccounts.verify_token(token) do
            {:ok, user, _claims} ->
              assign(socket, :current_user, user)

            {:error, _reason} ->
              assign(socket, :current_user, nil)
          end
        end
    end
  end

  # The session map here is the one captured when the socket connected, so its
  # last_activity_at can be stale while the user keeps working in LiveView.
  # Use the most recent of it and the server-side session activity.
  defp session_expired?(session) do
    if session["remember_me"] == true do
      false
    else
      timeout = Application.get_env(:streamflix_web, :session_timeout_seconds, 1800)

      last_activity =
        [
          session["last_activity_at"],
          StreamflixAccounts.session_last_activity(session["current_jti"])
        ]
        |> Enum.filter(&is_integer/1)
        |> Enum.max(fn -> nil end)

      is_integer(last_activity) and System.system_time(:second) - last_activity > timeout
    end
  end

  # The role checked at mount can be stale: every admin action re-reads the
  # user, so a demoted or deactivated admin cannot keep acting.
  defp recheck_admin(_event, _params, socket) do
    case StreamflixAccounts.get_user(socket.assigns.current_user.id) do
      %{status: "active"} = fresh ->
        if check_admin(fresh) do
          {:cont,
           socket
           |> assign(:current_user, fresh)
           |> assign(:current_user_role, fresh.role)}
        else
          deny_admin(socket)
        end

      _ ->
        deny_admin(socket)
    end
  end

  defp deny_admin(socket) do
    {:halt,
     socket
     |> put_flash(:error, gettext("Acceso denegado. Se requieren permisos de administrador."))
     |> redirect(to: "/")}
  end

  defp check_admin(user) do
    user.role in ["admin", "superadmin"]
  end
end
