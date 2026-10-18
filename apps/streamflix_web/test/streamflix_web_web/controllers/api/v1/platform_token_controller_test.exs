defmodule StreamflixWebWeb.Api.V1.PlatformTokenControllerTest do
  use StreamflixWebWeb.ConnCase, async: false

  defp with_key(raw_key), do: build_conn() |> put_req_header("x-api-key", raw_key)

  setup do
    project = insert(:project)
    {:ok, _api_key, raw_key} = StreamflixCore.Platform.ApiKeys.create_api_key(project.id)
    %{raw_key: raw_key}
  end

  describe "PATCH /api/v1/token" do
    test "restricts scopes, and the key is limited right away", %{raw_key: raw_key} do
      resp =
        with_key(raw_key)
        |> patch("/api/v1/token", %{scopes: ["events:read"]})
        |> json_response(200)

      assert resp["scopes"] == ["events:read"]

      assert with_key(raw_key) |> get("/api/v1/events") |> json_response(200)
      assert with_key(raw_key) |> get("/api/v1/webhooks") |> json_response(403)
    end

    test "restricts client IPs", %{raw_key: raw_key} do
      resp =
        with_key(raw_key)
        |> patch("/api/v1/token", %{allowed_ips: ["10.0.0.1"]})
        |> json_response(200)

      assert resp["allowed_ips"] == ["10.0.0.1"]

      assert with_key(raw_key) |> get("/api/v1/events") |> json_response(403)
    end

    test "GET /token shows the restrictions", %{raw_key: raw_key} do
      with_key(raw_key)
      |> patch("/api/v1/token", %{scopes: ["*"], allowed_ips: ["127.0.0.1"]})
      |> json_response(200)

      resp = with_key(raw_key) |> get("/api/v1/token") |> json_response(200)
      assert resp["allowed_ips"] == ["127.0.0.1"]
      assert resp["scopes"] == ["*"]
    end

    test "rejects invalid IPs and unknown or empty scopes", %{raw_key: raw_key} do
      assert with_key(raw_key)
             |> patch("/api/v1/token", %{allowed_ips: ["not-an-ip"]})
             |> json_response(422)

      assert with_key(raw_key)
             |> patch("/api/v1/token", %{scopes: ["root"]})
             |> json_response(422)

      assert with_key(raw_key) |> patch("/api/v1/token", %{scopes: []}) |> json_response(422)
    end
  end
end
