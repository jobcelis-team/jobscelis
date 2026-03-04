defmodule StreamflixWebWeb.SandboxController do
  @moduledoc """
  Catch-all controller that receives HTTP requests for sandbox endpoints.
  Any method (GET, POST, PUT, PATCH, DELETE) to /sandbox/:slug is captured.
  """
  use StreamflixWebWeb, :controller
  alias StreamflixCore.Platform

  def receive(conn, %{"slug" => slug} = params) do
    case Platform.get_sandbox_by_slug(slug) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Sandbox endpoint not found or expired"})

      endpoint ->
        {:ok, body, conn} = read_body(conn)

        headers =
          conn.req_headers
          |> Enum.into(%{})

        attrs = %{
          method: conn.method,
          path: params["path"] |> List.wrap() |> Enum.join("/"),
          headers: headers,
          body: body,
          query_params: conn.query_params,
          ip: StreamflixWebWeb.Plugs.ClientIp.get_client_ip(conn)
        }

        Platform.record_sandbox_request(endpoint.id, attrs)

        conn
        |> put_status(:ok)
        |> json(%{status: "received", endpoint: slug})
    end
  end
end
