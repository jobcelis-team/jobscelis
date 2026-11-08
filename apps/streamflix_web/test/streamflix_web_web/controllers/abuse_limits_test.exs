defmodule StreamflixWebWeb.AbuseLimitsTest do
  @moduledoc """
  Event rate limit, batch size, sandbox caps, embed rate limit, WebSocket IP
  allowlist, SSE limits and streamed exports.
  """
  use StreamflixWebWeb.ConnCase, async: false

  alias StreamflixCore.Platform
  alias StreamflixWebWeb.Api.V1.PlatformSSEController

  defp api_conn(conn, project_attrs \\ []) do
    project = insert(:project, project_attrs)
    {:ok, api_key, raw_key} = Platform.ApiKeys.create_api_key(project.id)
    %{conn: put_req_header(conn, "x-api-key", raw_key), project: project, api_key: api_key}
  end

  describe "events per minute" do
    test "batch items count against the limit, 429 with Retry-After", %{conn: conn} do
      %{conn: conn} = api_conn(conn, rate_limit_events_per_minute: 3)

      events = for n <- 1..4, do: %{"topic" => "t", "n" => n}
      resp = post(conn, "/api/v1/events/batch", %{"events" => events})
      assert %{"error" => "event_rate_limit_exceeded", "limit" => 3} = json_response(resp, 429)
      assert [retry] = get_resp_header(resp, "retry-after")
      assert String.to_integer(retry) in 1..60

      # The rejected batch consumed nothing
      ok = post(conn, "/api/v1/events/batch", %{"events" => Enum.take(events, 3)})
      assert %{"accepted" => 3} = json_response(ok, 202)

      single = post(conn, "/api/v1/events", %{"topic" => "t"})
      assert json_response(single, 429)
    end

    test "batches above the maximum are rejected", %{conn: conn} do
      %{conn: conn} = api_conn(conn)
      events = for _ <- 1..501, do: %{"topic" => "t"}
      resp = post(conn, "/api/v1/events/batch", %{"events" => events})
      assert %{"error" => "Batch too large, maximum 500 events"} = json_response(resp, 422)
    end
  end

  describe "quotas through the API" do
    test "a clear error is returned when the limit is reached", %{conn: conn} do
      previous = Application.get_env(:streamflix_core, :quotas)
      Application.put_env(:streamflix_core, :quotas, sandbox_endpoints_per_project: 1)
      on_exit(fn -> Application.put_env(:streamflix_core, :quotas, previous) end)

      %{conn: conn} = api_conn(conn)
      assert json_response(post(conn, "/api/v1/sandbox-endpoints", %{}), 201)

      assert %{"error" => "limit reached: maximum 1 sandbox endpoints per project"} =
               json_response(post(conn, "/api/v1/sandbox-endpoints", %{}), 422)
    end
  end

  describe "public sandbox receiver" do
    setup do
      project = insert(:project)
      %{endpoint: insert(:sandbox_endpoint, project_id: project.id)}
    end

    test "bodies over 256 KB get 413", %{conn: conn, endpoint: endpoint} do
      resp =
        conn
        |> put_req_header("content-type", "application/octet-stream")
        |> put_req_header("x-forwarded-for", "203.0.113.10")
        |> post("/sandbox/#{endpoint.slug}", :binary.copy("a", 300_000))

      assert json_response(resp, 413)
      assert Platform.list_sandbox_requests(endpoint.id) == []
    end

    test "is rate limited per IP", %{endpoint: endpoint} do
      ip = "198.51.100.#{:rand.uniform(200)}"

      statuses =
        for _ <- 1..61 do
          build_conn()
          |> put_req_header("x-forwarded-for", ip)
          |> put_req_header("content-type", "text/plain")
          |> post("/sandbox/#{endpoint.slug}", "x")
          |> Map.get(:status)
        end

      assert Enum.count(statuses, &(&1 == 200)) == 60
      assert List.last(statuses) == 429
    end
  end

  describe "embed portal" do
    test "embed routes are subject to the project rate limit", %{conn: conn} do
      project = insert(:project)
      {:ok, raw, _} = StreamflixCore.EmbedTokens.create(project.id, %{name: "t"})

      resp =
        conn
        |> put_req_header("authorization", "Bearer " <> raw)
        |> get("/api/v1/embed/webhooks")

      assert json_response(resp, 200)
      assert [limit] = get_resp_header(resp, "x-ratelimit-limit")
      assert limit == Integer.to_string(project.rate_limit_api_calls_per_minute)
    end
  end

  describe "WebSocket IP allowlist" do
    alias StreamflixWebWeb.UserSocket

    defp socket_connect(token, connect_info) do
      UserSocket.connect(%{"token" => token}, %Phoenix.Socket{}, connect_info)
    end

    test "keys with an allowlist only connect from allowed IPs" do
      project = insert(:project)

      {:ok, _, raw} =
        Platform.ApiKeys.create_api_key(project.id, %{allowed_ips: ["203.0.113.5"]})

      assert {:ok, _} = socket_connect(raw, %{peer_data: %{address: {203, 0, 113, 5}}})
      assert :error = socket_connect(raw, %{peer_data: %{address: {198, 51, 100, 1}}})

      # Behind the proxy the right-most X-Forwarded-For entry is used
      assert {:ok, _} =
               socket_connect(raw, %{
                 peer_data: %{address: {10, 0, 0, 1}},
                 x_headers: [{"x-forwarded-for", "1.2.3.4, 203.0.113.5:4433"}]
               })

      # Unknown client IP: fail closed
      assert :error = socket_connect(raw, %{})
    end

    test "keys without an allowlist connect as before" do
      project = insert(:project)
      {:ok, _, raw} = Platform.ApiKeys.create_api_key(project.id)
      assert {:ok, _} = socket_connect(raw, %{})
    end
  end

  describe "SSE stream" do
    setup do
      previous = Application.get_env(:streamflix_web, :sse)
      on_exit(fn -> Application.put_env(:streamflix_web, :sse, previous) end)
      project = insert(:project)
      {:ok, api_key, _raw} = Platform.ApiKeys.create_api_key(project.id)
      %{project: project, api_key: Platform.get_active_api_key(api_key.id)}
    end

    defp sse_conn(project, api_key) do
      build_conn(:get, "/api/v1/stream")
      |> Plug.Conn.assign(:current_project, project)
      |> Plug.Conn.assign(:current_api_key, api_key)
      |> PlatformSSEController.call(PlatformSSEController.init(:stream))
    end

    test "ends after the max lifetime", %{project: project, api_key: api_key} do
      Application.put_env(:streamflix_web, :sse,
        max_lifetime_ms: 100,
        keepalive_ms: 10_000,
        max_connections_per_project: 5
      )

      conn = sse_conn(project, api_key)
      assert conn.status == 200
      assert conn.resp_body =~ ~s("type":"connected")
      assert conn.resp_body =~ ~s("reason":"stream_expired")
      assert Registry.count_match(StreamflixWebWeb.SSERegistry, project.id, :_) == 0
    end

    test "a revoked key is disconnected at the next keepalive", %{
      project: project,
      api_key: api_key
    } do
      Application.put_env(:streamflix_web, :sse,
        max_lifetime_ms: 5_000,
        keepalive_ms: 50,
        max_connections_per_project: 5
      )

      api_key |> Ecto.Changeset.change(status: "inactive") |> StreamflixCore.Repo.update!()

      started = System.monotonic_time(:millisecond)
      conn = sse_conn(project, api_key)
      assert conn.resp_body =~ ~s("reason":"unauthorized")
      assert System.monotonic_time(:millisecond) - started < 2_000
    end

    test "concurrent streams per project are capped", %{project: project, api_key: api_key} do
      Application.put_env(:streamflix_web, :sse,
        max_lifetime_ms: 100,
        keepalive_ms: 10_000,
        max_connections_per_project: 1
      )

      # Another open stream of the same project
      test_pid = self()

      holder =
        spawn(fn ->
          Registry.register(StreamflixWebWeb.SSERegistry, project.id, nil)
          send(test_pid, :registered)
          Process.sleep(:infinity)
        end)

      assert_receive :registered
      conn = sse_conn(project, api_key)
      assert conn.status == 429
      assert %{"error" => "too_many_streams"} = Jason.decode!(conn.resp_body)
      Process.exit(holder, :kill)
    end
  end

  describe "streamed exports" do
    test "JSON keeps the {data, total} shape and CSV the header line", %{conn: conn} do
      %{conn: conn, project: project} = api_conn(conn)
      for n <- 1..3, do: insert(:webhook_event, project_id: project.id, payload: %{"n" => n})

      json = conn |> get("/api/v1/export/events") |> json_response(200)
      assert json["total"] == 3
      assert length(json["data"]) == 3
      assert %{"payload" => _, "topic" => _, "id" => _} = hd(json["data"])

      csv = conn |> get("/api/v1/export/events?format=csv") |> response(200)
      [header | rows] = String.split(csv, "\n")
      assert header == "id,topic,status,occurred_at,payload,payload_hash"
      assert length(rows) == 3

      empty = conn |> get("/api/v1/export/deliveries") |> json_response(200)
      assert empty == %{"data" => [], "total" => 0}
    end
  end
end
