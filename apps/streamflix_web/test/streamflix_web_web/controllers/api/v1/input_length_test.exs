defmodule StreamflixWebWeb.Api.V1.InputLengthTest do
  @moduledoc """
  Input longer than a varchar(255) column used to reach the database and come
  back as a 500. It must be rejected by validation with a 422.
  """
  use StreamflixWebWeb.ConnCase, async: false

  @long String.duplicate("a", 300)

  setup %{conn: conn} do
    user = create_test_user()
    project = insert(:project, user_id: user.id)
    {:ok, _api_key, raw_key} = StreamflixCore.Platform.ApiKeys.create_api_key(project.id)
    %{conn: put_req_header(conn, "x-api-key", raw_key)}
  end

  test "sandbox name", %{conn: conn} do
    assert json_response(post(conn, "/api/v1/sandbox-endpoints", %{name: @long}), 422)
  end

  test "event topic and idempotency key, single and batch", %{conn: conn} do
    assert json_response(post(conn, "/api/v1/send", %{topic: "t." <> @long, x: 1}), 422)

    assert json_response(
             post(conn, "/api/v1/send", %{topic: "t.k", idempotency_key: @long, x: 1}),
             422
           )

    # A batch reports invalid events as rejected instead of failing
    batch = %{events: [%{topic: "t." <> @long, payload: %{}}, %{topic: "t.ok", payload: %{}}]}

    assert %{"accepted" => 1, "rejected" => 1} =
             json_response(post(conn, "/api/v1/events/batch", batch), 202)
  end

  test "event schema topic", %{conn: conn} do
    body = %{topic: "t." <> @long, schema: %{"type" => "object"}}
    assert json_response(post(conn, "/api/v1/event-schemas", body), 422)
  end

  test "webhook URLs up to 2048 characters are accepted, longer ones rejected", %{conn: conn} do
    long_ok = "https://example.com/hook?sig=" <> String.duplicate("b", 400)
    assert json_response(post(conn, "/api/v1/webhooks", %{url: long_ok, topics: ["t.x"]}), 201)

    too_long = "https://example.com/" <> String.duplicate("c", 2100)

    assert %{"errors" => %{"url" => [_]}} =
             json_response(post(conn, "/api/v1/webhooks", %{url: too_long, topics: ["t.x"]}), 422)
  end

  test "a non-http URL gets one error, not two", %{conn: conn} do
    assert %{"errors" => %{"url" => [_single]}} =
             json_response(post(conn, "/api/v1/webhooks", %{url: "file:///etc/passwd"}), 422)
  end
end
