defmodule StreamflixWebWeb.Api.V1.PlatformEventsControllerTest do
  @moduledoc """
  Tests for the Platform Events API controller.
  """
  use StreamflixWebWeb.ConnCase, async: false

  defp setup_api_auth(%{conn: conn}) do
    user = create_test_user()
    project = insert(:project, user_id: user.id)
    {:ok, _api_key, raw_key} = StreamflixCore.Platform.ApiKeys.create_api_key(project.id)
    conn = put_req_header(conn, "x-api-key", raw_key)
    %{conn: conn, project: project, user: user}
  end

  describe "POST /api/v1/events" do
    setup [:setup_api_auth]

    test "creates event and returns 202", %{conn: conn} do
      conn = post(conn, "/api/v1/events", %{"topic" => "user.created", "name" => "John"})
      assert %{"event_id" => id} = json_response(conn, 202)
      assert is_binary(id)
    end

    test "returns 401 without API key", %{conn: _conn} do
      conn = build_conn() |> put_req_header("content-type", "application/json")
      conn = post(conn, "/api/v1/events", %{"topic" => "test"})
      assert json_response(conn, 401)
    end
  end

  describe "POST /api/v1/events/batch" do
    setup [:setup_api_auth]

    test "batch creates events", %{conn: conn} do
      events = [
        %{"topic" => "user.created", "name" => "Alice"},
        %{"topic" => "user.updated", "name" => "Bob"}
      ]

      conn = post(conn, "/api/v1/events/batch", %{"events" => events})
      resp = json_response(conn, 202)
      assert resp["accepted"] == 2
      assert resp["rejected"] == 0
    end

    test "rejects non-array body", %{conn: conn} do
      conn = post(conn, "/api/v1/events/batch", %{"not_events" => "bad"})
      assert json_response(conn, 422)
    end
  end

  describe "GET /api/v1/events" do
    setup [:setup_api_auth]

    test "lists events for project", %{conn: conn, project: project} do
      insert(:webhook_event, project_id: project.id, topic: "test.event")

      conn = get(conn, "/api/v1/events")
      resp = json_response(conn, 200)
      assert is_list(resp["events"])
      assert length(resp["events"]) >= 1
    end
  end

  describe "GET /api/v1/events/:id" do
    setup [:setup_api_auth]

    test "shows event details", %{conn: conn, project: project} do
      event = insert(:webhook_event, project_id: project.id, topic: "test.show")

      conn = get(conn, "/api/v1/events/#{event.id}")
      resp = json_response(conn, 200)
      assert resp["id"] == event.id
      assert resp["topic"] == "test.show"
    end

    test "returns 404 for other project's event", %{conn: conn} do
      other_project = insert(:project)
      event = insert(:webhook_event, project_id: other_project.id)

      conn = get(conn, "/api/v1/events/#{event.id}")
      assert conn.status == 404
    end
  end

  describe "DELETE /api/v1/events/:id" do
    setup [:setup_api_auth]

    test "soft deletes event", %{conn: conn, project: project} do
      event = insert(:webhook_event, project_id: project.id)

      conn = delete(conn, "/api/v1/events/#{event.id}")
      assert conn.status == 200
      assert %{"status" => "inactive"} = Jason.decode!(conn.resp_body)
    end
  end

  describe "POST /api/v1/simulate" do
    setup [:setup_api_auth]

    test "simulates event matching", %{conn: conn, project: project} do
      insert(:webhook, project_id: project.id, status: "active", topics: ["user.*"])

      conn = post(conn, "/api/v1/simulate", %{"topic" => "user.created", "data" => "test"})
      resp = json_response(conn, 200)
      assert resp["simulation"] == true
      assert is_integer(resp["matching_webhooks"])
    end
  end
end
