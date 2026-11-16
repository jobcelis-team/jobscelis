defmodule StreamflixWebWeb.Plugs.ClientIp do
  @moduledoc """
  Extracts the real client IP from the connection.

  Behind the Azure front end, X-Forwarded-For arrives as "<client-supplied>, ...,
  <real client ip:port>": the proxy APPENDS the address it saw. Only the
  right-most entry is trustworthy — the left-most can be forged by the client,
  which would defeat per-IP rate limits and API key IP allowlists. Falls back to
  conn.remote_ip when there is no proxy header.
  Strips port numbers if present (e.g. "45.71.114.31:53421" → "45.71.114.31").

  Behind the Cloudflare Worker that fails over between hosts, every hop appends
  a Cloudflare address, so X-Forwarded-For no longer ends with the client. The
  Worker sends the client IP in `x-jobcelis-client-ip` together with the shared
  secret in `x-jobcelis-proxy-secret`; that IP is used only when the secret
  matches `:trusted_proxy_secret` (env TRUSTED_PROXY_SECRET), so a client that
  reaches the host directly cannot choose its own IP.
  """

  @client_ip_header "x-jobcelis-client-ip"
  @proxy_secret_header "x-jobcelis-proxy-secret"

  @doc "Returns the real client IP as a string, without port."
  def get_client_ip(conn) do
    trusted_proxy_ip(&Plug.Conn.get_req_header(conn, &1)) ||
      from_parts(Plug.Conn.get_req_header(conn, "x-forwarded-for"), conn.remote_ip)
  end

  @doc """
  Same as `get_client_ip/1` for a socket's `connect_info` (needs the socket to be
  declared with `connect_info: [:peer_data, :x_headers]`). Returns nil when that
  information is not available.
  """
  def from_connect_info(connect_info) when is_map(connect_info) do
    x_headers = Map.get(connect_info, :x_headers) || []

    header_values = fn wanted ->
      for {name, value} <- x_headers, String.downcase(name) == wanted, do: value
    end

    forwarded = header_values.("x-forwarded-for")

    trusted_proxy_ip(header_values) ||
      case Map.get(connect_info, :peer_data) do
        %{address: address} -> from_parts(forwarded, address)
        _ when forwarded != [] -> from_parts(forwarded, nil)
        _ -> nil
      end
  end

  def from_connect_info(_), do: nil

  # The IP sent by our own proxy, when it proved itself with the shared secret
  defp trusted_proxy_ip(header_values) do
    with secret when is_binary(secret) and secret != "" <-
           Application.get_env(:streamflix_web, :trusted_proxy_secret),
         [sent_secret | _] <- header_values.(@proxy_secret_header),
         true <- Plug.Crypto.secure_compare(sent_secret, secret),
         [ip | _] <- header_values.(@client_ip_header),
         ip = ip |> String.trim() |> strip_port(),
         {:ok, _} <- :inet.parse_address(String.to_charlist(ip)) do
      ip
    else
      _ -> nil
    end
  end

  defp from_parts([_ | _] = values, _remote_ip) do
    # Several headers are treated as one comma-separated list
    values |> Enum.join(",") |> String.split(",") |> List.last() |> String.trim() |> strip_port()
  end

  defp from_parts(_, remote_ip) when is_tuple(remote_ip),
    do: remote_ip |> :inet.ntoa() |> to_string() |> strip_port()

  defp from_parts(_, _), do: nil

  defp strip_port(ip) do
    # IPv6 in brackets: [::1]:port → ::1
    case Regex.run(~r/^\[(.+)\](?::\d+)?$/, ip) do
      [_, v6] -> v6
      nil -> strip_v4_port(ip)
    end
  end

  defp strip_v4_port(ip) do
    # IPv4 with port: 1.2.3.4:8080 → 1.2.3.4
    # But plain IPv6 like ::1 has colons too, so only strip if it looks like ip:port
    case String.split(ip, ":") do
      # Exactly 2 parts = IPv4:port
      [v4, _port] -> v4
      # 1 part = plain IPv4
      [v4] -> v4
      # More than 2 = IPv6 address, return as-is
      _ -> ip
    end
  end
end
