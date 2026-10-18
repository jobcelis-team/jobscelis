defmodule StreamflixWebWeb.Api.V1.ListEnvelopeTest do
  @moduledoc """
  Every list endpoint returns its items under "data" (what the SDKs read), keeping
  the resource-named key some endpoints already had for existing clients.
  """
  use StreamflixWebWeb.ConnCase, async: false

  setup %{conn: conn} do
    project = insert(:project)
    {:ok, _api_key, raw_key} = StreamflixCore.Platform.ApiKeys.create_api_key(project.id)
    webhook = insert(:webhook, project_id: project.id)
    event = insert(:webhook_event, project_id: project.id)
    insert(:delivery, webhook_id: webhook.id, event_id: event.id)
    job = insert(:job, project_id: project.id)
    %{conn: put_req_header(conn, "x-api-key", raw_key), job: job}
  end

  for {path, key} <- [
        {"/api/v1/events", "events"},
        {"/api/v1/deliveries", "deliveries"},
        {"/api/v1/webhooks", "webhooks"},
        {"/api/v1/jobs", "jobs"},
        {"/api/v1/dead-letters", "dead_letters"}
      ] do
    test "GET #{path} returns data and #{key}", %{conn: conn} do
      resp = conn |> get(unquote(path)) |> json_response(200)
      assert is_list(resp["data"])
      assert resp["data"] == resp[unquote(key)]
    end
  end

  test "GET /api/v1/jobs/:id/runs returns data and runs", %{conn: conn, job: job} do
    resp = conn |> get("/api/v1/jobs/#{job.id}/runs") |> json_response(200)
    assert is_list(resp["data"])
    assert resp["data"] == resp["runs"]
  end
end
