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
        body = captured_body(conn)

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

  # Plug.Parsers (in the :api pipeline) already consumed JSON / urlencoded /
  # multipart bodies, so read_body/1 returns "" for them. Rebuild the body from
  # the parsed params in that case; other content types still arrive raw.
  defp captured_body(conn) do
    case read_body(conn) do
      {:ok, raw, _conn} when raw != "" ->
        raw

      _ ->
        case conn.body_params do
          %Plug.Conn.Unfetched{} -> nil
          params when params == %{} -> nil
          params -> encode_params(conn, params)
        end
    end
  end

  # Parsers wrap non-object JSON (arrays, scalars) under "_json"
  defp encode_params(conn, %{"_json" => value}) when map_size(conn.body_params) == 1,
    do: Jason.encode!(value)

  defp encode_params(_conn, params) do
    case Jason.encode(params) do
      {:ok, json} -> json
      _ -> inspect(params)
    end
  end
end
