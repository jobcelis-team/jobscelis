defmodule StreamflixWebWeb.Plugs.LoggerMetadata do
  @moduledoc """
  Attaches structured Logger metadata to every request:
  request_id, method, path, and client IP.
  """
  @behaviour Plug

  require Logger

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    request_id = Plug.Conn.get_resp_header(conn, "x-request-id") |> List.first()

    Logger.metadata(
      request_id: request_id,
      method: conn.method,
      path: conn.request_path
    )

    conn
  end
end
