defmodule StreamflixWebWeb.Plugs.CORSTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn
  alias StreamflixWebWeb.Plugs.CORS

  defp preflight(path, origin) do
    conn(:options, path)
    |> put_req_header("origin", origin)
    |> put_req_header("access-control-request-method", "GET")
    |> CORS.call([])
  end

  test "the embed portal can send its token header from a customer's site" do
    conn = preflight("/api/v1/embed/webhooks", "https://shop.example")

    assert conn.halted
    assert get_resp_header(conn, "access-control-allow-origin") == ["https://shop.example"]
    [allowed] = get_resp_header(conn, "access-control-allow-headers")
    assert "x-embed-token" in (allowed |> String.downcase() |> String.split(", "))
  end

  test "browser clients can send idempotency keys and read Retry-After" do
    conn = preflight("/api/v1/events", "https://app.example")

    [allowed] = get_resp_header(conn, "access-control-allow-headers")
    assert "x-idempotency-key" in (allowed |> String.downcase() |> String.split(", "))

    [exposed] = get_resp_header(conn, "access-control-expose-headers")
    assert "retry-after" in (exposed |> String.downcase() |> String.split(", "))
  end

  test "browser routes only allow configured origins" do
    conn = preflight("/platform", "https://evil.example")
    assert get_resp_header(conn, "access-control-allow-origin") == []
  end
end
