defmodule StreamflixWebWeb.Plugs.CORS do
  @moduledoc """
  Plug CORS para la API: permite que cualquier origen (cualquier dominio del cliente)
  pueda llamar a /api/v1/* desde el navegador.

  Cada cliente usa su propio dominio (misfactura.com, www.ejemplo.com, etc.);
  no dañamos la app: todos pueden hacer peticiones cross-origin a la API.
  La seguridad la da el **token del proyecto**: solo las peticiones con
  Authorization: Bearer <token> o X-Api-Key: <token> válido son aceptadas (ApiKeyAuth).
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> put_resp_header("access-control-allow-methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
    |> put_resp_header("access-control-allow-headers", "Authorization, X-Api-Key, Content-Type, Accept")
    |> put_resp_header("access-control-max-age", "86400")
    |> maybe_handle_options()
  end

  defp maybe_handle_options(conn) do
    if conn.method == "OPTIONS" do
      conn |> send_resp(200, "") |> halt()
    else
      conn
    end
  end
end
