defmodule StreamflixWebWeb.Plugs.RedirectIfAuthenticated do
  @moduledoc """
  Plug que redirige a /platform (o /admin) si el usuario ya está autenticado.
  Útil para páginas públicas como home, login, signup.
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
              if user.role == "admin" do
                "/admin"
              else
                "/platform"
              end

            conn
            |> redirect(to: redirect_to)
            |> halt()

          {:error, _reason} ->
            # Token inválido, limpiar sesión
            conn
            |> delete_session(:user_id)
            |> delete_session(:user_token)
        end
    end
  end
end
