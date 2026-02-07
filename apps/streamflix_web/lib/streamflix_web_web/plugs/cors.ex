defmodule StreamflixWebWeb.Plugs.CORS do
  @moduledoc """
  Plug CORS: permite que cualquier origen consuma la API (ideal para que
  frontends en distintos dominios puedan llamar a /api/v1/*).
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn =
      conn
      |> put_resp_header("access-control-allow-origin", "*")
      |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
      |> put_resp_header("access-control-allow-headers", "Authorization, X-Api-Key, Content-Type, Accept")
      |> put_resp_header("access-control-max-age", "86400")

    if conn.method == "OPTIONS" do
      conn |> send_resp(200, "") |> halt()
    else
      conn
    end
  end
end
