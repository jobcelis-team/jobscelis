defmodule StreamflixWebWeb.Api.V1.PlatformWebhooksControllerTest do
  @moduledoc """
  Tests for the Platform Webhooks API controller.
  """
  use StreamflixWebWeb.ConnCase, async: false

  defp setup_api_auth(%{conn: conn}) do
    user = create_test_user()
    project = insert(:project, user_id: user.id)
    {:ok, _api_key, raw_key} = StreamflixCore.Platform.ApiKeys.create_api_key(project.id)
    conn = put_req_header(conn, "x-api-key", raw_key)
    %{conn: conn, project: project, user: user}
  end

  describe "GET /api/v1/webhooks" do
    setup [:setup_api_auth]

    test "lists webhooks for project", %{conn: conn, project: project} do
      insert(:webhook, project_id: project.id, status: "active")

      conn = get(conn, "/api/v1/webhooks")
      resp = json_response(conn, 200)
      assert length(resp["webhooks"]) >= 1
    end
  end

  describe "POST /api/v1/webhooks" do
    setup [:setup_api_auth]

    test "creates webhook with url and topics", %{conn: conn} do
      attrs = %{
        "url" => "https://example.com/hook",
        "topics" => ["user.created", "order.*"]
      }

      conn = post(conn, "/api/v1/webhooks", attrs)
      resp = json_response(conn, 201)
      assert resp["url"] == "https://example.com/hook"
      assert resp["topics"] == ["user.created", "order.*"]
    end

    test "returns 422 for missing url", %{conn: conn} do
      conn = post(conn, "/api/v1/webhooks", %{"topics" => ["test"]})
      assert json_response(conn, 422)
    end
  end

  describe "GET /api/v1/webhooks/:id" do
    setup [:setup_api_auth]

    test "shows webhook details", %{conn: conn, project: project} do
      webhook = insert(:webhook, project_id: project.id)

      conn = get(conn, "/api/v1/webhooks/#{webhook.id}")
      resp = json_response(conn, 200)
      assert resp["id"] == webhook.id
    end

    test "returns 404 for other project's webhook", %{conn: conn} do
      other = insert(:project)
      webhook = insert(:webhook, project_id: other.id)

      conn = get(conn, "/api/v1/webhooks/#{webhook.id}")
      assert conn.status == 404
    end
  end

  describe "PATCH /api/v1/webhooks/:id" do
    setup [:setup_api_auth]

    test "updates webhook", %{conn: conn, project: project} do
      webhook = insert(:webhook, project_id: project.id)

      conn =
        patch(conn, "/api/v1/webhooks/#{webhook.id}", %{"url" => "https://new.example.com/hook"})

      resp = json_response(conn, 200)
      assert resp["url"] == "https://new.example.com/hook"
    end
  end

  describe "DELETE /api/v1/webhooks/:id" do
    setup [:setup_api_auth]

    test "soft deletes webhook", %{conn: conn, project: project} do
      webhook = insert(:webhook, project_id: project.id)

      conn = delete(conn, "/api/v1/webhooks/#{webhook.id}")
      assert conn.status == 200
      assert %{"status" => "inactive"} = Jason.decode!(conn.resp_body)
    end
  end

  describe "GET /api/v1/webhooks/:id/health" do
    setup [:setup_api_auth]

    test "returns health data", %{conn: conn, project: project} do
      webhook = insert(:webhook, project_id: project.id)

      conn = get(conn, "/api/v1/webhooks/#{webhook.id}/health")
      resp = json_response(conn, 200)
      assert resp["webhook_id"] == webhook.id
      assert is_map(resp["health"])
    end
  end

  describe "GET /api/v1/webhooks/templates" do
    setup [:setup_api_auth]

    test "returns webhook templates", %{conn: conn} do
      conn = get(conn, "/api/v1/webhooks/templates")
      resp = json_response(conn, 200)
      assert is_list(resp["templates"])
      assert length(resp["templates"]) > 0
    end
  end
end
