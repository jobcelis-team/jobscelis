defmodule StreamflixWebWeb.Plugs.MaybeLoadCurrentUser do
  @moduledoc """
  Optionally loads the current user from the session token and assigns
  `@current_user` (user struct or nil) and `@legal` (app config map).

  Never redirects — just assigns. Safe to use on every browser route.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    current_user =
      case get_session(conn, :user_token) do
        nil ->
          nil

        token ->
          case StreamflixAccounts.verify_token(token) do
            {:ok, user, _claims} -> user
            {:error, _} -> nil
          end
      end

    legal = Application.get_env(:streamflix_web, :legal, []) |> Enum.into(%{})

    conn
    |> assign(:current_user, current_user)
    |> assign(:legal, legal)
  end
end
