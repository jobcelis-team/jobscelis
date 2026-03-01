defmodule StreamflixWebWeb.Api.V1.HealthControllerTest do
  use StreamflixWebWeb.ConnCase, async: true

  test "GET /health returns healthy status", %{conn: conn} do
    conn = get(conn, "/health")
    assert %{"status" => "healthy", "database" => "ok"} = json_response(conn, 200)
  end
end
