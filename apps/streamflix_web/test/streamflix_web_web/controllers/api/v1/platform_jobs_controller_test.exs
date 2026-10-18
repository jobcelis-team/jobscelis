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

  describe "POST /api/v1/jobs with SDK / CLI / Terraform shorthand" do
    setup [:setup_api_auth]

    test "Python, Go and Terraform: queue + cron_expression", %{conn: conn} do
      job =
        conn
        |> post("/api/v1/jobs", %{name: "tf", queue: "default", cron_expression: "0 9 * * *"})
        |> json_response(201)

      assert job["schedule_type"] == "cron"
      assert job["schedule_config"] == %{"expr" => "0 9 * * *"}
    end

    test "CLI: --cron", %{conn: conn} do
      job =
        conn
        |> post("/api/v1/jobs", %{name: "cli", queue: "q", cron: "*/5 * * * *"})
        |> json_response(201)

      assert job["schedule_config"] == %{"expr" => "*/5 * * * *"}
    end

    test "Node: schedule + topic + payload", %{conn: conn} do
      job =
        conn
        |> post("/api/v1/jobs", %{
          name: "node",
          schedule: "0 9 * * 1",
          topic: "report.generate",
          payload: %{"type" => "weekly"}
        })
        |> json_response(201)

      assert job["schedule_type"] == "cron"
      assert job["action_type"] == "emit_event"

      assert job["action_config"] == %{
               "topic" => "report.generate",
               "payload" => %{"type" => "weekly"}
             }
    end

    test "canonical fields win over shorthand", %{conn: conn} do
      job =
        conn
        |> post("/api/v1/jobs", %{
          name: "canon",
          schedule_type: "weekly",
          schedule_config: %{"day_of_week" => 1, "hour" => 9, "minute" => 0},
          cron: "* * * * *"
        })
        |> json_response(201)

      assert job["schedule_type"] == "weekly"
    end

    test "an invalid cron is rejected instead of becoming a daily job", %{conn: conn} do
      assert conn
             |> post("/api/v1/jobs", %{name: "bad", cron_expression: "not a cron"})
             |> json_response(422)
    end
  end
end
