defmodule StreamflixWebWeb.LiveAuth do
  @moduledoc """
  LiveView authentication hooks.
  """

  import Phoenix.Component

  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
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
end
