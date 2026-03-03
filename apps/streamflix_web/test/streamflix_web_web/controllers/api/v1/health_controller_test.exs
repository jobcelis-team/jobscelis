defmodule StreamflixWebWeb.Api.V1.HealthControllerTest do
  use StreamflixWebWeb.ConnCase, async: true

  test "GET /health returns healthy status with checks", %{conn: conn} do
    conn = get(conn, "/health")
    response = json_response(conn, 200)

    assert response["status"] in ["healthy", "degraded"]
    assert is_map(response["checks"])
    assert response["checks"]["database"] == "ok"
    assert response["checks"]["oban"] in ["ok", "error"]
    assert response["checks"]["cache"] in ["ok", "error"]
    assert is_binary(response["checks"]["backup"])
    assert is_binary(response["timestamp"])
  end
end
