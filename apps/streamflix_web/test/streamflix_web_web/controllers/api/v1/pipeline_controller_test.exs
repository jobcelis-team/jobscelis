defmodule StreamflixWebWeb.Api.V1.PipelineControllerTest do
  use StreamflixWebWeb.ConnCase, async: false

  alias StreamflixCore.Platform

  defp api_conn(conn, project, scopes) do
    {:ok, _api_key, raw_key} = Platform.ApiKeys.create_api_key(project.id, %{scopes: scopes})
    put_req_header(conn, "x-api-key", raw_key)
  end

  setup %{conn: conn} do
    project = insert(:project)
    webhook = insert(:webhook, project_id: project.id)
    %{conn: api_conn(conn, project, ["*"]), project: project, webhook: webhook}
  end

  test "creates and lists pipelines for the API key's project", %{conn: conn, webhook: webhook} do
    attrs = %{
      "name" => "Paid",
      "topics" => ["order.#"],
      "webhook_id" => webhook.id,
      "steps" => []
    }

    resp = conn |> post("/api/v1/pipelines", attrs) |> json_response(201)
    assert resp["data"]["webhook_id"] == webhook.id

    listed = conn |> get("/api/v1/pipelines") |> json_response(200)
    assert [%{"name" => "Paid"}] = listed["data"]
  end

  test "pipelines of another project are not reachable", %{conn: conn} do
    other = insert(:project)
    other_webhook = insert(:webhook, project_id: other.id)

    {:ok, pipeline} =
      Platform.create_pipeline(other.id, %{"name" => "Theirs", "webhook_id" => other_webhook.id})

    assert conn |> get("/api/v1/pipelines/#{pipeline.id}") |> json_response(404)

    assert conn
           |> patch("/api/v1/pipelines/#{pipeline.id}", %{"name" => "x"})
           |> json_response(404)

    assert conn |> delete("/api/v1/pipelines/#{pipeline.id}") |> json_response(404)
    assert conn |> post("/api/v1/pipelines/#{pipeline.id}/test", %{}) |> json_response(404)
    assert Platform.get_pipeline(pipeline.id).name == "Theirs"
  end

  test "read-only keys cannot create pipelines", %{project: project, webhook: webhook} do
    conn = api_conn(build_conn(), project, ["pipelines:read"])
    attrs = %{"name" => "Paid", "webhook_id" => webhook.id}

    assert conn |> post("/api/v1/pipelines", attrs) |> json_response(403)
    assert conn |> get("/api/v1/pipelines") |> json_response(200)
  end
end
