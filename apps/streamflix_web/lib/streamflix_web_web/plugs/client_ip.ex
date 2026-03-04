defmodule StreamflixWebWeb.Plugs.ClientIp do
  @moduledoc """
  Extracts the real client IP from the connection.
  Checks X-Forwarded-For header first (for reverse proxies), then falls back to conn.remote_ip.
  Strips port numbers if present (e.g. "45.71.114.31:53421" → "45.71.114.31").
  """

  @doc "Returns the real client IP as a string, without port."
  def get_client_ip(conn) do
    raw_ip =
      case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
        [forwarded | _] ->
          forwarded |> String.split(",") |> List.first() |> String.trim()

        _ ->
          conn.remote_ip |> :inet.ntoa() |> to_string()
      end

    strip_port(raw_ip)
  end

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
