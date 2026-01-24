defmodule StreamflixWebWeb.Plugs.Auth do
  @moduledoc """
  Authentication plug for API requests.
  """

  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_token(conn) do
      nil ->
        unauthorized(conn)

      token ->
        case StreamflixAccounts.verify_token(token) do
          {:ok, user, _claims} ->
            conn
            |> assign(:current_user, user)
            |> assign(:token, token)

          {:error, _reason} ->
            unauthorized(conn)
        end
    end
  end

  defp get_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> nil
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Unauthorized", message: "Invalid or missing authentication token"})
    |> halt()
  end
end
