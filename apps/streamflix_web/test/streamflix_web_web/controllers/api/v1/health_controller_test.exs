defmodule StreamflixWebWeb.Api.V1.HealthControllerTest do
  use StreamflixWebWeb.ConnCase, async: true

  test "GET /health returns healthy status without internal details", %{conn: conn} do
    conn = get(conn, "/health")
    response = json_response(conn, 200)

    assert response["status"] in ["healthy", "degraded"]
    assert is_binary(response["timestamp"])
    refute Map.has_key?(response, "checks")
  end
end
