defmodule StreamflixWebWeb.Plugs.ClientIpTest do
  use ExUnit.Case, async: true

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
end
