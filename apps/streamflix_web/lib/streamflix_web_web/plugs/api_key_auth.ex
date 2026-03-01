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

  defp get_api_key(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        token

      _ ->
        case get_req_header(conn, "x-api-key") do
          [token] -> token
          _ -> nil
        end
    end
  end

  defp check_ip_allowlist(conn, api_key) do
    allowed = api_key.allowed_ips || []

    if allowed == [] do
      :ok
    else
      client_ip = get_client_ip(conn)

      if client_ip in allowed do
        :ok
      else
        :ip_not_allowed
      end
    end
  end

  defp get_client_ip(conn) do
    # Check X-Forwarded-For first (for reverse proxies)
    case get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        forwarded |> String.split(",") |> List.first() |> String.trim()

      _ ->
        conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end
end
