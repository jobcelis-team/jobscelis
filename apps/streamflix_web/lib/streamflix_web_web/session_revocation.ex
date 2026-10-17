defmodule StreamflixWebWeb.SessionRevocation do
  @moduledoc """
  Disconnects live LiveView sockets of revoked sessions.

  Each browser session carries `live_socket_id = "user_sessions:<jti>"` (set at
  login), so LiveViews already connected are dropped as soon as the session is
  revoked (logout elsewhere, password change, deactivation, "close session").
  Called by StreamflixAccounts through the `:on_sessions_revoked` hook.
  """

  @doc "LiveView socket id for a session token jti."
  def socket_id(jti), do: "user_sessions:#{jti}"

  @doc false
  def disconnect(jtis) do
    Enum.each(jtis, fn jti ->
      StreamflixWebWeb.Endpoint.broadcast(socket_id(jti), "disconnect", %{})
    end)
  end
end
