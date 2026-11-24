defmodule StreamflixWebWeb.SdkCompatTest do
  @moduledoc """
  The published SDKs send these request shapes; the server accepts them so
  existing SDK versions keep working.
  """
  use StreamflixWebWeb.ConnCase, async: false

  alias StreamflixCore.{Platform, Repo, Teams}

  setup do
    {:ok, owner, _} =
      StreamflixAccounts.register_user(%{
        email: "sdk#{System.unique_integer([:positive])}@example.com",
        password: "SecurePass123!",
        name: "SDK"
      })

    project = insert(:project, user_id: owner.id)
    {:ok, _key, raw} = Platform.ApiKeys.create_api_key(project.id)
    {:ok, token, claims} = StreamflixAccounts.generate_token(owner)
    {:ok, _} = StreamflixAccounts.create_session(owner.id, claims["jti"])
    %{owner: owner, project: project, raw: raw, jwt: token}
  end

  defp key_conn(raw), do: build_conn() |> put_req_header("x-api-key", raw)

  test "X-Api-Key wins when a JWT Bearer is also sent", %{raw: raw, jwt: jwt} do
    assert raw
           |> key_conn()
           |> put_req_header("authorization", "Bearer " <> jwt)
           |> get("/api/v1/events")
           |> json_response(200)
  end

  test "PATCH /retention accepts the policy at the top level", %{raw: raw, project: project} do
    raw |> key_conn() |> patch("/api/v1/retention", %{events_days: 30}) |> json_response(200)
    assert Repo.reload(project).retention_policy == %{"events_days" => 30}
  end

  test "pipeline test accepts the sample payload as the whole body", %{
    raw: raw,
    project: project
  } do
    {:ok, wh} =
      Platform.Webhooks.create_webhook(project.id, %{"url" => "https://example.com/h"})

    pipeline =
      raw
      |> key_conn()
      |> post("/api/v1/pipelines", %{name: "p", topics: ["order.*"], webhook_id: wh.id, steps: []})
      |> json_response(201)

    resp =
      raw
      |> key_conn()
      |> post("/api/v1/pipelines/#{pipeline["data"]["id"]}/test", %{amount: 500})
      |> json_response(200)

    assert resp["input"] == %{"amount" => 500}
  end

  test "role \"member\" means viewer", %{project: project, jwt: jwt} do
    {:ok, other, _} =
      StreamflixAccounts.register_user(%{
        email: "m#{System.unique_integer([:positive])}@example.com",
        password: "SecurePass123!",
        name: "M"
      })

    build_conn()
    |> put_req_header("authorization", "Bearer " <> jwt)
    |> post("/api/v1/projects/#{project.id}/members", %{user_id: other.id, role: "member"})
    |> json_response(201)

    assert Teams.get_member_role(project.id, other.id) == "viewer"
  end

  test "POST with X-HTTP-Method-Override: PATCH updates (Java SDK)", %{
    raw: raw,
    project: project
  } do
    {:ok, wh} =
      Platform.Webhooks.create_webhook(project.id, %{"url" => "https://example.com/h"})

    raw
    |> key_conn()
    |> put_req_header("x-http-method-override", "PATCH")
    |> post("/api/v1/webhooks/#{wh.id}", %{topics: ["order.created"]})
    |> json_response(200)

    assert Repo.reload(wh).topics == ["order.created"]
  end
end
