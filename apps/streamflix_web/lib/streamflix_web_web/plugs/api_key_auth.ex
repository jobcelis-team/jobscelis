defmodule StreamflixWebWeb.Plugs.ApiKeyAuth do
  @moduledoc """
  Authenticates API requests using API Key (Bearer or X-Api-Key).
  Assigns current_project and current_api_key when valid.
  Also checks IP allowlist if configured on the API key.
  """
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    with token when is_binary(token) and token != "" <- get_api_key(conn),
         api_key when not is_nil(api_key) <- StreamflixCore.Platform.verify_api_key("", token),
         :ok <- check_ip_allowlist(conn, api_key) do
      conn
      |> assign(:current_project, api_key.project)
      |> assign(:current_api_key, api_key)
    else
      :ip_not_allowed ->
        conn
        |> put_status(:forbidden)
        |> put_view(json: StreamflixWebWeb.ErrorJSON)
        |> json(%{error: "IP not allowed"})
        |> halt()

      _ ->
        conn
        |> put_status(:unauthorized)
        |> put_view(json: StreamflixWebWeb.ErrorJSON)
        |> render(:"401")
        |> halt()
    end
  end

  # X-Api-Key first: the SDKs send it on every request and, once a user has
  # logged in, also a JWT as "Authorization: Bearer". Reading the Bearer first
  # treated that JWT as the API key and every project route returned 401.
  defp get_api_key(conn) do
    case {get_req_header(conn, "x-api-key"), get_req_header(conn, "authorization")} do
      {[token | _], _} ->
        token

      {_, ["Bearer " <> token | _]} ->
        token

      _ ->
        # Fallback: check query param for browser-initiated requests (export downloads)
        conn.query_params["api_key"]
    end
  end

  defp check_ip_allowlist(conn, api_key) do
    if ip_allowed?(api_key, StreamflixWebWeb.Plugs.ClientIp.get_client_ip(conn)),
      do: :ok,
      else: :ip_not_allowed
  end

  @doc """
  True when the API key has no IP allowlist or `client_ip` is in it. A nil
  (unknown) client IP is never allowed for a key that has an allowlist.
  Shared by the HTTP API, the WebSocket and the SSE stream.
  """
  def ip_allowed?(api_key, client_ip) do
    case api_key.allowed_ips || [] do
      [] -> true
      allowed -> is_binary(client_ip) and client_ip in allowed
    end
  end
end
