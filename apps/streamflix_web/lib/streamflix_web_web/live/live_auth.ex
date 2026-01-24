defmodule StreamflixWebWeb.LiveAuth do
  @moduledoc """
  LiveView authentication hooks.
  """

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
        {:halt, redirect(socket, to: "/") |> put_flash(:error, "Acceso denegado. Se requieren permisos de administrador.")}
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
            socket
            |> assign(:current_user, user)
            |> assign(:current_profile, get_profile_from_session(session))

          {:error, _reason} ->
            assign(socket, :current_user, nil)
        end
    end
  end

  defp get_profile_from_session(session) do
    case session["profile_id"] do
      nil -> nil
      id -> StreamflixAccounts.get_profile(id)
    end
  end

  defp check_admin(user) do
    # Check if user has admin role
    user.role == "admin"
  end
end
