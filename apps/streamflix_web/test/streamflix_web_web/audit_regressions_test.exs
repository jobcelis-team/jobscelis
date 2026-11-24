defmodule StreamflixWebWeb.AuditRegressionsTest do
  @moduledoc "Regression tests for findings of the 2026-11 security audit (web layer)."
  use StreamflixWebWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias StreamflixCore.{Platform, Repo, Teams}

  @password "SecurePass123!"

  defp register(name) do
    {:ok, user, _} =
      StreamflixAccounts.register_user(%{
        email: "#{name}#{System.unique_integer([:positive])}@example.com",
        password: @password,
        name: "Audit"
      })

    user
  end

  defp jwt(user) do
    {:ok, token, claims} = StreamflixAccounts.generate_token(user)
    {:ok, _} = StreamflixAccounts.create_session(user.id, claims["jti"])
    build_conn() |> put_req_header("authorization", "Bearer " <> token)
  end

  defp login(conn, user) do
    {:ok, token, claims} = StreamflixAccounts.generate_token(user)
    {:ok, _} = StreamflixAccounts.create_session(user.id, claims["jti"])
    init_test_session(conn, %{user_token: token, current_jti: claims["jti"], remember_me: true})
  end

  defp member!(project, user, role) do
    {:ok, m} = Teams.invite_member(project.id, user.id, role)
    {:ok, m} = Teams.accept_invitation(m.id)
    m
  end

  defp key_conn(raw), do: build_conn() |> put_req_header("x-api-key", raw)

  describe "PATCH /api/v1/projects/:id/default" do
    test "cannot target another user's project or an invalid id" do
      a = register("a")
      other = insert(:project, user_id: register("b").id, name: "Not yours")

      assert jwt(a) |> patch("/api/v1/projects/#{other.id}/default") |> json_response(404)
      assert jwt(a) |> patch("/api/v1/projects/not-a-uuid/default") |> json_response(404)
      refute Repo.reload(other).is_default
    end
  end

  describe "PATCH /api/v1/token" do
    setup do
      project = insert(:project)
      {:ok, _key, raw} = Platform.ApiKeys.create_api_key(project.id)
      %{raw: raw}
    end

    test "a restricted key cannot lift its own scopes or IP list", %{raw: raw} do
      key_conn(raw)
      |> patch("/api/v1/token", %{
        scopes: ["project:write", "events:read"],
        allowed_ips: ["127.0.0.1"]
      })
      |> json_response(200)

      assert key_conn(raw) |> patch("/api/v1/token", %{scopes: ["*"]}) |> json_response(403)

      assert key_conn(raw)
             |> patch("/api/v1/token", %{scopes: ["project:write", "webhooks:write"]})
             |> json_response(403)

      assert key_conn(raw) |> patch("/api/v1/token", %{allowed_ips: []}) |> json_response(403)

      assert key_conn(raw)
             |> patch("/api/v1/token", %{allowed_ips: ["10.0.0.1"]})
             |> json_response(403)
    end

    test "a restricted key can still narrow itself", %{raw: raw} do
      key_conn(raw)
      |> patch("/api/v1/token", %{scopes: ["project:write", "events:read"]})
      |> json_response(200)

      resp =
        key_conn(raw)
        |> patch("/api/v1/token", %{scopes: ["project:write"]})
        |> json_response(200)

      assert resp["scopes"] == ["project:write"]
    end
  end

  describe "team members API" do
    setup do
      owner = register("owner")
      project = insert(:project, user_id: owner.id)
      editor = register("editor")
      member!(project, editor, "editor")
      %{owner: owner, project: project, editor: editor}
    end

    test "an editor cannot demote or remove another editor", %{project: project, editor: editor} do
      other = member!(project, register("editor2"), "editor")

      assert jwt(editor)
             |> patch("/api/v1/projects/#{project.id}/members/#{other.id}", %{role: "viewer"})
             |> json_response(403)

      assert jwt(editor)
             |> delete("/api/v1/projects/#{project.id}/members/#{other.id}")
             |> json_response(403)

      assert Repo.reload(other).role == "editor"
    end

    test "an editor cannot promote a viewer to editor", %{project: project, editor: editor} do
      viewer = member!(project, register("viewer"), "viewer")

      assert jwt(editor)
             |> patch("/api/v1/projects/#{project.id}/members/#{viewer.id}", %{role: "editor"})
             |> json_response(403)
    end

    test "an editor can remove a viewer and the owner can manage editors", %{
      owner: owner,
      project: project,
      editor: editor
    } do
      viewer = member!(project, register("viewer"), "viewer")

      assert jwt(editor)
             |> delete("/api/v1/projects/#{project.id}/members/#{viewer.id}")
             |> json_response(200)

      other = member!(project, register("editor2"), "editor")

      assert jwt(owner)
             |> patch("/api/v1/projects/#{project.id}/members/#{other.id}", %{role: "viewer"})
             |> json_response(200)
    end

    test "a non-UUID project id is a 403, not a 500", %{editor: editor} do
      assert jwt(editor) |> get("/api/v1/projects/abc/members") |> json_response(403)
    end
  end

  describe "PATCH /api/v1/project" do
    test "ignores retention_policy (validated only by PATCH /retention)" do
      project = insert(:project)
      {:ok, _key, raw} = Platform.ApiKeys.create_api_key(project.id)

      key_conn(raw)
      |> patch("/api/v1/project", %{name: "Renamed", retention_policy: %{events_days: "30"}})
      |> json_response(200)

      reloaded = Repo.reload(project)
      assert reloaded.name == "Renamed"
      assert reloaded.retention_policy in [nil, %{}]
    end
  end

  describe "embed tokens" do
    test "stop working once the project is deleted" do
      project = insert(:project)
      {:ok, raw, _token} = StreamflixCore.EmbedTokens.create(project.id)

      assert build_conn()
             |> put_req_header("x-embed-token", raw)
             |> get("/api/v1/embed/webhooks")
             |> json_response(200)

      {:ok, _} = Platform.delete_project(project)

      assert build_conn()
             |> put_req_header("x-embed-token", raw)
             |> get("/api/v1/embed/webhooks")
             |> json_response(401)
    end

    test "an invalid expires_at is rejected instead of creating a token that never expires" do
      project = insert(:project)
      {:ok, _key, raw} = Platform.ApiKeys.create_api_key(project.id)

      assert key_conn(raw)
             |> post("/api/v1/embed/tokens", %{name: "portal", expires_at: "next tuesday"})
             |> json_response(422)
    end
  end

  describe "dead letters API" do
    test "a second retry of the same dead letter is a 409" do
      project = insert(:project)
      {:ok, _key, raw} = Platform.ApiKeys.create_api_key(project.id)
      webhook = insert(:webhook, project_id: project.id)
      event = insert(:webhook_event, project_id: project.id)

      dl =
        insert(:dead_letter, project_id: project.id, webhook_id: webhook.id, event_id: event.id)

      assert key_conn(raw) |> post("/api/v1/dead-letters/#{dl.id}/retry") |> json_response(200)
      assert key_conn(raw) |> post("/api/v1/dead-letters/#{dl.id}/retry") |> json_response(409)
    end
  end

  describe "MFA enrollment" do
    test "cannot be redone while MFA is enabled", %{conn: conn} do
      user = register("mfa")
      {:ok, secret, _} = StreamflixAccounts.setup_mfa(user)

      {:ok, user, _} =
        StreamflixAccounts.enable_mfa(user, secret, NimbleTOTP.verification_code(secret))

      {:ok, other_secret, _} = StreamflixAccounts.setup_mfa(user)

      assert {:error, :already_enabled} =
               StreamflixAccounts.enable_mfa(
                 user,
                 other_secret,
                 NimbleTOTP.verification_code(other_secret)
               )

      {:ok, view, _} = live(login(conn, user), "/account")
      render_hook(view, "start_mfa_setup", %{})
      render_hook(view, "confirm_mfa_setup", %{"code" => "123456"})

      assert StreamflixAccounts.get_user(user.id).mfa_secret == secret
    end

    test "confirming without starting does not crash the page", %{conn: conn} do
      user = register("mfa2")
      {:ok, view, _} = live(login(conn, user), "/account")

      render_hook(view, "confirm_mfa_setup", %{"code" => "123456"})
      assert render(view)
    end
  end

  describe "dashboard after removal from a project" do
    test "a removed member is sent away on the next refresh", %{conn: conn} do
      owner = register("owner")
      project = insert(:project, user_id: owner.id)
      viewer = register("viewer")
      membership = member!(project, viewer, "viewer")

      {:ok, view, _} = live(login(conn, viewer), "/platform?project=#{project.id}")

      {:ok, _} = Teams.remove_member(membership.id)
      send(view.pid, :live_refresh)

      assert_redirect(view, "/platform")
    end
  end

  describe "notification channel test" do
    test "can be sent once a minute per project" do
      project = insert(:project)
      {:ok, _key, raw} = Platform.ApiKeys.create_api_key(project.id)

      {:ok, _} =
        StreamflixCore.NotificationChannels.upsert(project.id, %{
          email_enabled: true,
          email_address: "alerts@example.com"
        })

      assert key_conn(raw) |> post("/api/v1/notification-channels/test") |> json_response(200)
      assert key_conn(raw) |> post("/api/v1/notification-channels/test") |> json_response(429)
    end
  end
end
