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

  test "browser routes only allow configured origins" do
    conn = preflight("/platform", "https://evil.example")
    assert get_resp_header(conn, "access-control-allow-origin") == []
  end
end
