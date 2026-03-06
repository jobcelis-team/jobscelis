defmodule StreamflixWebWeb.Plugs.ApiVersionTest do
  use StreamflixWebWeb.ConnCase, async: true

  test "adds X-API-Version header to API v1 responses", %{conn: conn} do
    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/api/v1/auth/login", %{email: "test@test.com", password: "test"})

    assert get_resp_header(conn, "x-api-version") == ["1"]
  end

  test "does not add X-API-Version header to non-API routes", %{conn: conn} do
    conn = get(conn, "/health")
    assert get_resp_header(conn, "x-api-version") == []
  end
end
