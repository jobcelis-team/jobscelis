defmodule StreamflixWebWeb.Plugs.RedirectIfAuthenticated do
  @moduledoc """
  Redirects to /platform (or /admin) if the user is already authenticated.
  Used on public pages like home, login, signup.
  """

  import Plug.Conn
  import Phoenix.Controller
  alias StreamflixAccounts

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :user_token) do
      nil ->
        conn

      token ->
        case StreamflixAccounts.verify_token(token) do
          {:ok, user, _claims} ->
            redirect_to =
              if user.role in ["admin", "superadmin"] do
                "/admin"
              else
                "/platform"
              end

            conn
            |> redirect(to: redirect_to)
            |> halt()

          {:error, _reason} ->
            # Invalid token, clear session
            conn
            |> delete_session(:user_id)
            |> delete_session(:user_token)
        end
    end
  end
end
