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
          |> Enum.reject(fn {name, _} -> proxy_header?(name) end)
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

  # Headers added by our own reverse proxy / hosting front end, not by the sender.
  # They repeat the client IP and expose internal hosting details, so they are not
  # shown as part of the captured request (the sender IP is kept in its own field).
  @proxy_headers ~w(client-ip x-client-ip x-forwarded-for x-forwarded-host x-forwarded-proto
                    x-forwarded-port x-forwarded-tlsversion x-original-url x-real-ip
                    disguised-host was-default-hostname max-forwards x-site-deployment-id)
  @proxy_header_prefixes ~w(x-arr- x-appservice- x-waws- x-ms- x-azure-)

  defp proxy_header?(name) do
    name in @proxy_headers or String.starts_with?(name, @proxy_header_prefixes)
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
