defmodule StreamflixWebWeb.Plugs.ClientIp do
  @moduledoc """
  Extracts the real client IP from the connection.

  Behind the Azure front end, X-Forwarded-For arrives as "<client-supplied>, ...,
  <real client ip:port>": the proxy APPENDS the address it saw. Only the
  right-most entry is trustworthy — the left-most can be forged by the client,
  which would defeat per-IP rate limits and API key IP allowlists. Falls back to
  conn.remote_ip when there is no proxy header.
  Strips port numbers if present (e.g. "45.71.114.31:53421" → "45.71.114.31").
  """

  @doc "Returns the real client IP as a string, without port."
  def get_client_ip(conn) do
    from_parts(Plug.Conn.get_req_header(conn, "x-forwarded-for"), conn.remote_ip)
  end

  @doc """
  Same as `get_client_ip/1` for a socket's `connect_info` (needs the socket to be
  declared with `connect_info: [:peer_data, :x_headers]`). Returns nil when that
  information is not available.
  """
  def from_connect_info(connect_info) when is_map(connect_info) do
    forwarded =
      for {name, value} <- Map.get(connect_info, :x_headers) || [],
          String.downcase(name) == "x-forwarded-for",
          do: value

    case Map.get(connect_info, :peer_data) do
      %{address: address} -> from_parts(forwarded, address)
      _ when forwarded != [] -> from_parts(forwarded, nil)
      _ -> nil
    end
  end

  def from_connect_info(_), do: nil

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
