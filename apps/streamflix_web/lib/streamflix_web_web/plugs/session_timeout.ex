defmodule StreamflixWebWeb.Plugs.SessionTimeout do
  @moduledoc """
  Plug that enforces session inactivity timeout.
  Clears session and redirects to /login if the user has been inactive
  for longer than the configured timeout (default 30 minutes).
  """
  import Plug.Conn
  use Gettext, backend: StreamflixWebWeb.Gettext

  def init(opts), do: opts

  def call(conn, _opts) do
    # Skip if no user session
    if get_session(conn, :user_token) do
      check_timeout(conn)
    else
      conn
    end
  end

  defp check_timeout(conn) do
    last_activity = get_session(conn, :last_activity_at)
    timeout = Application.get_env(:streamflix_web, :session_timeout_seconds, 1800)

    cond do
      is_nil(last_activity) ->
        # Session exists but no timestamp — set it now (backwards compat)
        put_session(conn, :last_activity_at, System.system_time(:second))

      System.system_time(:second) - last_activity > timeout ->
        # Session expired
        conn
        |> configure_session(drop: true)
        |> Phoenix.Controller.put_flash(
          :error,
          gettext("Tu sesión ha expirado por inactividad. Inicia sesión de nuevo.")
        )
        |> Phoenix.Controller.redirect(to: "/login")
        |> halt()

      true ->
        # Session still valid — only update timestamp if >60s elapsed to reduce cookie writes
        now = System.system_time(:second)

        if now - last_activity > 60 do
          put_session(conn, :last_activity_at, now)
        else
          conn
        end
    end
  end
end
