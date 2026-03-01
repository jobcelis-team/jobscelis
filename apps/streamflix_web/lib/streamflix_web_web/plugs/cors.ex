defmodule StreamflixWebWeb.Plugs.CORS do
  @moduledoc """
  CORS plug: allows any origin for /api/* routes (API key auth protects them).
  Restricts browser routes to configured allowed origins.
  """
  import Plug.Conn

  @allowed_origins [
    "https://jobcelis.com",
    "https://www.jobcelis.com",
    "http://localhost:4000",
    "http://localhost:4001"
  ]

  def init(opts), do: opts

  def call(conn, _opts) do
    origin = get_origin(conn)

    allowed_origin =
      cond do
        api_route?(conn.request_path) ->
          origin || "*"

        origin in @allowed_origins ->
          origin

        true ->
          nil
      end

    conn =
      if allowed_origin do
        conn
        |> put_resp_header("access-control-allow-origin", allowed_origin)
        |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
        |> put_resp_header("access-control-allow-headers", "Authorization, X-Api-Key, Content-Type, Accept")
        |> put_resp_header("access-control-max-age", "86400")
        |> maybe_vary_origin()
      else
        conn
      end

    if conn.method == "OPTIONS" do
      conn |> send_resp(200, "") |> halt()
    else
      conn
    end
  end

  defp get_origin(conn) do
    case get_req_header(conn, "origin") do
      [origin | _] -> origin
      _ -> nil
    end
  end

  defp api_route?("/api/" <> _), do: true
  defp api_route?("/sandbox/" <> _), do: true
  defp api_route?(_), do: false

  defp maybe_vary_origin(conn) do
    if get_resp_header(conn, "access-control-allow-origin") != ["*"] do
      put_resp_header(conn, "vary", "Origin")
    else
      conn
    end
  end
end
