defmodule StreamflixWebWeb.PlatformDashboardSecurityTest do
  use StreamflixWebWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias StreamflixCore.{Platform, Teams}

  defp register(name) do
    {:ok, user, _} =
      StreamflixAccounts.register_user(%{
        email: "#{name}#{System.unique_integer([:positive])}@example.com",
        password: "SecurePass123!",
        name: "Security User"
      })

    user
  end

  defp login(conn, user) do
    {:ok, token, claims} = StreamflixAccounts.generate_token(user)
    {:ok, _} = StreamflixAccounts.create_session(user.id, claims["jti"])

    Phoenix.ConnTest.init_test_session(conn, %{
      user_token: token,
      current_jti: claims["jti"],
      remember_me: true
    })
  end

  defp add_member(project, user, role) do
    {:ok, member} = Teams.invite_member(project.id, user.id, role)
    {:ok, member} = Teams.accept_invitation(member.id)
    member
  end

  setup %{conn: conn} do
    owner = register("owner")
    project = insert(:project, user_id: owner.id)
    %{conn: conn, owner: owner, project: project}
  end

  describe "invite_member" do
    test "an editor cannot invite an owner or an editor", %{conn: conn, project: project} do
      editor = register("editor")
      add_member(project, editor, "editor")
      target = register("target")

      {:ok, view, _} = live(login(conn, editor), "/platform?project=#{project.id}")

      render_hook(view, "invite_member", %{"email" => target.email, "role" => "owner"})
      assert is_nil(Teams.get_member_role(project.id, target.id))

      html = render_hook(view, "invite_member", %{"email" => target.email, "role" => "editor"})
      assert html =~ "Only the project owner can invite editors"
      assert is_nil(Teams.get_member_role(project.id, target.id))

      render_hook(view, "invite_member", %{"email" => target.email, "role" => "viewer"})
      assert Teams.get_member_role(project.id, target.id) == "viewer"
    end

    test "even the owner cannot invite an owner", %{conn: conn, owner: owner, project: project} do
      target = register("target")
      {:ok, view, _} = live(login(conn, owner), "/platform?project=#{project.id}")

      render_hook(view, "invite_member", %{"email" => target.email, "role" => "owner"})
      assert is_nil(Teams.get_member_role(project.id, target.id))
    end

    test "unknown and existing emails get the same reply", %{
      conn: conn,
      owner: owner,
      project: project
    } do
      target = register("target")
      {:ok, view, _} = live(login(conn, owner), "/platform?project=#{project.id}")

      missing =
        render_hook(view, "invite_member", %{
          "email" => "nobody#{System.unique_integer()}@example.com",
          "role" => "viewer"
        })

      assert missing =~ "If the email belongs to an account, the invitation was sent."

      existing =
        render_hook(view, "invite_member", %{"email" => target.email, "role" => "viewer"})

      assert existing =~ "If the email belongs to an account, the invitation was sent."
    end
  end

  describe "stale permissions" do
    test "a removed editor loses write access without reconnecting", %{
      conn: conn,
      project: project
    } do
      editor = register("editor")
      member = add_member(project, editor, "editor")

      {:ok, view, _} = live(login(conn, editor), "/platform?project=#{project.id}")
      {:ok, _} = Teams.remove_member(member.id)

      render_hook(view, "send_test", %{"topic" => "stale.check", "payload" => "{}"})
      assert Platform.list_events(project.id, limit: 5) == []
    end

    test "a demoted editor cannot write", %{conn: conn, project: project} do
      editor = register("editor")
      member = add_member(project, editor, "editor")

      {:ok, view, _} = live(login(conn, editor), "/platform?project=#{project.id}")
      {:ok, _} = Teams.update_member_role(member.id, "viewer")

      html = render_hook(view, "send_test", %{"topic" => "stale.check", "payload" => "{}"})
      assert html =~ "permission for this action"
      assert Platform.list_events(project.id, limit: 5) == []
    end
  end

  describe "delete_project" do
    test "remounts so the role is recomputed for the next project", %{
      conn: conn,
      owner: owner,
      project: project
    } do
      other_owner = register("other")
      other = insert(:project, user_id: other_owner.id)
      add_member(other, owner, "viewer")
      {:ok, _key, _raw} = Platform.ApiKeys.create_api_key(other.id)
      key_before = Platform.get_api_key_for_project(other.id)

      conn = login(conn, owner)
      {:ok, view, _} = live(conn, "/platform?project=#{project.id}")

      assert {:error, {:live_redirect, %{to: "/platform"}}} =
               render_hook(view, "delete_project", %{"id" => project.id})

      {:ok, view, _} = live(conn, "/platform?project=#{other.id}")
      html = render_hook(view, "regenerate_token", %{})
      assert html =~ "Only the project owner can do this."
      assert Platform.get_api_key_for_project(other.id).prefix == key_before.prefix
    end
  end

  describe "payload size and throttling" do
    setup do
      previous = Application.get_env(:streamflix_web, :live_throttle_per_minute)
      Application.put_env(:streamflix_web, :live_throttle_per_minute, 2)

      on_exit(fn ->
        if previous,
          do: Application.put_env(:streamflix_web, :live_throttle_per_minute, previous),
          else: Application.delete_env(:streamflix_web, :live_throttle_per_minute)
      end)
    end

    test "test events over 256KB are rejected", %{conn: conn, owner: owner, project: project} do
      {:ok, view, _} = live(login(conn, owner), "/platform?project=#{project.id}")
      big = Jason.encode!(%{"data" => String.duplicate("a", 300_000)})

      html = render_hook(view, "send_test", %{"topic" => "big", "payload" => big})
      assert html =~ "The payload is too large"
      assert Platform.list_events(project.id, limit: 5) == []

      html = render_hook(view, "simulate_event", %{"topic" => "big", "payload" => big})
      assert html =~ "The payload is too large"
    end

    test "send_test is throttled per user", %{conn: conn, owner: owner, project: project} do
      {:ok, view, _} = live(login(conn, owner), "/platform?project=#{project.id}")

      for i <- 1..2 do
        render_hook(view, "send_test", %{"topic" => "t#{i}", "payload" => "{}"})
      end

      html = render_hook(view, "send_test", %{"topic" => "t3", "payload" => "{}"})
      assert html =~ "Too many requests"
      assert length(Platform.list_events(project.id, limit: 10)) == 2
    end
  end

  describe "send_webhook_test" do
    test "the result is shown when the background task reports back", %{
      conn: conn,
      owner: owner,
      project: project
    } do
      {:ok, view, _} = live(login(conn, owner), "/platform?project=#{project.id}")

      send(
        view.pid,
        {:webhook_test_result, Ecto.UUID.generate(), {:ok, %{status: 204, latency_ms: 12}}}
      )

      assert render(view) =~ "Status: 204"
    end
  end
end
