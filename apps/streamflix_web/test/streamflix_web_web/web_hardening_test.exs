defmodule StreamflixWebWeb.WebHardeningTest do
  use StreamflixWebWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias StreamflixCore.{Platform, Repo}

  defp register(role \\ "user") do
    {:ok, user, _} =
      StreamflixAccounts.register_user(%{
        email: "hard#{System.unique_integer([:positive])}@example.com",
        password: "SecurePass123!",
        name: "Hardening"
      })

    user
    |> Ecto.Changeset.change(%{
      role: role,
      email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update!()
  end

  defp login(conn, user) do
    {:ok, token, claims} = StreamflixAccounts.generate_token(user)
    {:ok, _} = StreamflixAccounts.create_session(user.id, claims["jti"])
    init_test_session(conn, %{user_token: token, current_jti: claims["jti"], remember_me: true})
  end

  defp api_conn(conn, project) do
    {:ok, _key, raw_key} = Platform.ApiKeys.create_api_key(project.id)

    conn
    |> put_req_header("x-api-key", raw_key)
    |> put_req_header("content-type", "application/json")
  end

  describe "event bodies" do
    setup %{conn: conn} do
      project = insert(:project, user_id: register().id)
      %{conn: api_conn(conn, project), project: project}
    end

    test "a JSON array is rejected instead of stored as an event", %{conn: conn, project: project} do
      for path <- ["/api/v1/events", "/api/v1/send", "/api/v1/simulate"] do
        resp = conn |> post(path, ~s([{"topic": "a"}])) |> json_response(422)
        assert resp["error"] == "Body must be a JSON object"
      end

      assert Platform.list_events(project.id, limit: 5) == []
    end

    test "a JSON object is still accepted", %{conn: conn} do
      assert %{"id" => _} =
               conn |> post("/api/v1/events", ~s({"topic": "a"})) |> json_response(202)
    end
  end

  test "a large CORS response keeps Vary: Origin", %{conn: conn} do
    project = insert(:project, user_id: register().id)

    for n <- 1..60,
        do:
          insert(:webhook_event,
            project_id: project.id,
            payload: %{"n" => n, "pad" => String.duplicate("x", 200)}
          )

    conn =
      conn
      |> api_conn(project)
      |> put_req_header("origin", "https://app.example.com")
      |> put_req_header("accept-encoding", "gzip")
      |> get("/api/v1/events?limit=100")

    assert conn.status == 200
    assert byte_size(conn.resp_body) > 10_000
    assert "Origin" in get_resp_header(conn, "vary")
    # Compression is left to the HTTP server, which appends to Vary
    assert get_resp_header(conn, "content-encoding") == []
  end

  test "/health shares its database check for a few seconds", %{conn: conn} do
    Cachex.del(:platform_cache, :health_db_check)

    assert %{"status" => status} = conn |> get("/health") |> json_response(200)
    # Oban queues do not run in tests, so "degraded" is expected here
    assert status in ["healthy", "degraded"]
    assert {:ok, "ok"} = Cachex.get(:platform_cache, :health_db_check)
    assert {:ok, ttl} = Cachex.ttl(:platform_cache, :health_db_check)
    assert ttl > 0 and ttl <= 5_000
  end

  test "the dashboard picks up a webhook created through the API", %{conn: conn} do
    user = register()
    project = insert(:project, user_id: user.id)
    {:ok, view, _} = live(login(conn, user), "/platform?project=#{project.id}")
    assert :sys.get_state(view.pid).socket.assigns.webhooks == []

    {:ok, _} = Platform.create_webhook(project.id, %{"url" => "https://receiver.example.com/h"})

    Process.sleep(1_200)

    assert [%{url: "https://receiver.example.com/h"}] =
             :sys.get_state(view.pid).socket.assigns.webhooks
  end

  test "admin project pages show translated statuses", %{conn: conn} do
    admin = register("superadmin")
    owner = register()
    project = insert(:project, user_id: owner.id, status: "active")

    {:ok, view, _html} = live(login(conn, admin), "/admin/projects")
    html = render(view)
    assert html =~ ~r/>\s*Active\s*</
    refute html =~ ~r/>\s*active\s*</

    {:ok, view, _html} = live(login(build_conn(), admin), "/admin/projects/#{project.id}")
    html = render(view)
    assert html =~ ~r/Status: Active/
    refute html =~ ~r/Status: active/
  end

  describe "admin notifications" do
    alias StreamflixWebWeb.PlatformDashboard.Helpers

    test "security anomalies read as text, not as data structures" do
      notif = %{
        type: "security_anomaly",
        title: "Security anomaly detected",
        message: "raw",
        metadata: %{
          "anomalies" => [
            %{"type" => "account_lockout"},
            %{"type" => "account_lockout"},
            %{"type" => "brute_force_ip"}
          ]
        }
      }

      Gettext.put_locale(StreamflixWebWeb.Gettext, "es")
      assert Helpers.notification_title(notif) == "Anomalía de seguridad detectada"
      message = Helpers.notification_message(notif)
      assert message =~ "Cuenta bloqueada (2)"
      assert message =~ "Intentos de acceso repetidos desde una IP (1)"
      refute message =~ "%{"

      Gettext.put_locale(StreamflixWebWeb.Gettext, "en")
      assert Helpers.notification_title(notif) == "Security anomaly detected"
      assert Helpers.notification_message(notif) =~ "Account locked (2)"
    end

    test "system health lists the failing components" do
      notif = %{
        type: "system_health",
        title: "System status: degraded",
        message: "raw",
        metadata: %{"status" => "degraded", "checks" => %{"database" => "ok", "oban" => "error"}}
      }

      Gettext.put_locale(StreamflixWebWeb.Gettext, "en")
      assert Helpers.notification_title(notif) == "System status: Degraded"
      assert Helpers.notification_message(notif) == "Components with issues: oban"
    end
  end
end
