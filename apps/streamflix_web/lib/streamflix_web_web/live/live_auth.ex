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
      # Check if user is admin (for now, check if email contains "admin" or has role field)
      # TODO: Add proper role field to User schema
      is_admin = check_admin(socket.assigns.current_user)
      
      if is_admin do
        {:cont, socket}
      else
        {:halt, redirect(socket, to: "/") |> put_flash(:error, gettext("Acceso denegado. Se requieren permisos de administrador."))}
      end
    end
  end

  defp mount_current_user(socket, session) do
    case session["user_token"] do
      nil ->
        assign(socket, :current_user, nil)

      token ->
        case StreamflixAccounts.verify_token(token) do
          {:ok, user, _claims} ->
            assign(socket, :current_user, user)

          {:error, _reason} ->
            assign(socket, :current_user, nil)
        end
    end
  end

  defp check_admin(user) do
    user.role in ["admin", "superadmin"]
  end
end
