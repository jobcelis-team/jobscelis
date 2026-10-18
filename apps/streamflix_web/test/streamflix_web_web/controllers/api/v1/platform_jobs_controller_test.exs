defmodule StreamflixWebWeb.Api.V1.PlatformJobsControllerTest do
  @moduledoc """
  Tests for the Platform Jobs API controller.
  """
  use StreamflixWebWeb.ConnCase, async: false

  defp setup_api_auth(%{conn: conn}) do
    user = create_test_user()
    project = insert(:project, user_id: user.id)
    {:ok, _api_key, raw_key} = StreamflixCore.Platform.ApiKeys.create_api_key(project.id)
    conn = put_req_header(conn, "x-api-key", raw_key)
    %{conn: conn, project: project, user: user}
  end

  describe "GET /api/v1/jobs/cron-preview" do
    setup [:setup_api_auth]

    test "returns 5 executions by default", %{conn: conn} do
      conn = get(conn, "/api/v1/jobs/cron-preview", %{"expression" => "0 9 * * 1"})
      resp = json_response(conn, 200)
      assert resp["expression"] == "0 9 * * 1"
      assert length(resp["next_executions"]) == 5
    end

    test "honors the count parameter", %{conn: conn} do
      conn =
        get(conn, "/api/v1/jobs/cron-preview", %{"expression" => "0 9 * * 1", "count" => "3"})

      assert length(json_response(conn, 200)["next_executions"]) == 3
    end

    test "caps count at 50", %{conn: conn} do
      conn =
        get(conn, "/api/v1/jobs/cron-preview", %{"expression" => "* * * * *", "count" => "500"})

      assert length(json_response(conn, 200)["next_executions"]) == 50
    end

    test "returns 422 without expression", %{conn: conn} do
      conn = get(conn, "/api/v1/jobs/cron-preview")
      assert json_response(conn, 422)["error"]
    end
  end
end
