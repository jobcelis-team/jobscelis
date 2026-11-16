defmodule StreamflixWebWeb.Plugs.ClientIpTest do
  # Not async: the trusted proxy tests change application env
  use ExUnit.Case, async: false

  import Plug.Test
  import Plug.Conn
  alias StreamflixWebWeb.Plugs.ClientIp

  test "uses the right-most X-Forwarded-For entry (the one the proxy appended)" do
    conn =
      conn(:get, "/")
      |> put_req_header("x-forwarded-for", "6.6.6.6, 45.71.114.31:53421")

    assert ClientIp.get_client_ip(conn) == "45.71.114.31"
  end

  test "a forged single entry is still the client-supplied one only without a proxy" do
    conn = conn(:get, "/") |> put_req_header("x-forwarded-for", "203.0.113.9")
    assert ClientIp.get_client_ip(conn) == "203.0.113.9"
  end

  test "falls back to the socket address" do
    assert ClientIp.get_client_ip(conn(:get, "/")) == "127.0.0.1"
  end

  test "handles IPv6 with port" do
    conn = conn(:get, "/") |> put_req_header("x-forwarded-for", "1.1.1.1, [2001:db8::1]:443")
    assert ClientIp.get_client_ip(conn) == "2001:db8::1"
  end

  describe "behind the trusted proxy" do
    setup do
      Application.put_env(:streamflix_web, :trusted_proxy_secret, "s3cret")
      on_exit(fn -> Application.delete_env(:streamflix_web, :trusted_proxy_secret) end)
    end

    defp proxied(secret, ip) do
      conn(:get, "/")
      |> put_req_header("x-forwarded-for", "45.71.114.31, 172.70.1.1")
      |> put_req_header("x-jobcelis-proxy-secret", secret)
      |> put_req_header("x-jobcelis-client-ip", ip)
    end

    test "uses the forwarded client IP when the secret matches" do
      assert ClientIp.get_client_ip(proxied("s3cret", "45.71.114.31")) == "45.71.114.31"
      assert ClientIp.get_client_ip(proxied("s3cret", "2001:db8::7")) == "2001:db8::7"
    end

    test "ignores the forwarded IP when the secret is wrong" do
      assert ClientIp.get_client_ip(proxied("guess", "1.2.3.4")) == "172.70.1.1"
    end

    test "ignores a forwarded value that is not an IP" do
      assert ClientIp.get_client_ip(proxied("s3cret", "not-an-ip")) == "172.70.1.1"
    end

    test "works for socket connect_info" do
      info = %{
        x_headers: [
          {"x-jobcelis-proxy-secret", "s3cret"},
          {"x-jobcelis-client-ip", "45.71.114.31"},
          {"x-forwarded-for", "172.70.1.1"}
        ],
        peer_data: %{address: {10, 0, 0, 1}}
      }

      assert ClientIp.from_connect_info(info) == "45.71.114.31"
    end
  end

  test "ignores proxy headers when no secret is configured" do
    conn =
      conn(:get, "/")
      |> put_req_header("x-jobcelis-proxy-secret", "")
      |> put_req_header("x-jobcelis-client-ip", "1.2.3.4")

    assert ClientIp.get_client_ip(conn) == "127.0.0.1"
  end
end
