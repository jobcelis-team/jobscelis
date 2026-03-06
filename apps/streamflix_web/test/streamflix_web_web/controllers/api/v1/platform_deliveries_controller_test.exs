defmodule StreamflixWebWeb.Api.V1.PlatformDeliveriesControllerTest do
  @moduledoc """
  Tests for the Platform Deliveries API controller.
  """
  use StreamflixWebWeb.ConnCase, async: false

  defp setup_api_auth(%{conn: conn}) do
    user = create_test_user()
    project = insert(:project, user_id: user.id)
    {:ok, _api_key, raw_key} = StreamflixCore.Platform.ApiKeys.create_api_key(project.id)
    conn = put_req_header(conn, "x-api-key", raw_key)
    %{conn: conn, project: project, user: user}
  end

  describe "GET /api/v1/deliveries" do
    setup [:setup_api_auth]

    test "lists deliveries for project", %{conn: conn, project: project} do
      webhook = insert(:webhook, project_id: project.id)
      event = insert(:webhook_event, project_id: project.id)
      insert(:delivery, webhook_id: webhook.id, event_id: event.id)

      conn = get(conn, "/api/v1/deliveries")
      resp = json_response(conn, 200)
      assert is_list(resp["deliveries"])
    end
  end

  describe "POST /api/v1/deliveries/:id/retry" do
    setup [:setup_api_auth]

    test "retries a delivery", %{conn: conn, project: project} do
      webhook = insert(:webhook, project_id: project.id)
      event = insert(:webhook_event, project_id: project.id)
      delivery = insert(:delivery, webhook_id: webhook.id, event_id: event.id, status: "failed")

      Oban.Testing.with_testing_mode(:manual, fn ->
        conn = post(conn, "/api/v1/deliveries/#{delivery.id}/retry")
        resp = json_response(conn, 200)
        assert resp["status"] == "retry_queued"
      end)
    end

    test "returns 404 for non-existent delivery", %{conn: conn} do
      Oban.Testing.with_testing_mode(:manual, fn ->
        conn = post(conn, "/api/v1/deliveries/#{Ecto.UUID.generate()}/retry")
        assert json_response(conn, 404)
      end)
    end
  end
end
