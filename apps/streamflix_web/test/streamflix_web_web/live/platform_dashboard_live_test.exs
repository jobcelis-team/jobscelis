defmodule StreamflixWebWeb.PlatformDashboardLiveTest do
  use StreamflixWebWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    {:ok, user, _} =
      StreamflixAccounts.register_user(%{
        email: "dash#{System.unique_integer([:positive])}@example.com",
        password: "SecurePass123!",
        name: "Dashboard User"
      })

    project = insert(:project, user_id: user.id)
    {:ok, token, claims} = StreamflixAccounts.generate_token(user)
    {:ok, _} = StreamflixAccounts.create_session(user.id, claims["jti"])

    conn =
      init_test_session(conn, %{user_token: token, current_jti: claims["jti"], remember_me: true})

    %{conn: conn, project: project}
  end

  describe "external alerts" do
    test "the form shows the saved channel after a page load", %{conn: conn, project: project} do
      {:ok, _} =
        StreamflixCore.NotificationChannels.upsert(project.id, %{
          meta_webhook_enabled: true,
          meta_webhook_url: "https://alerts.example.com/jobcelis",
          event_types: ["dlq_entry"]
        })

      {:ok, view, _html} = live(conn, "/platform?project=#{project.id}")
      html = view |> element("button[phx-click*=switch_tab]", "Settings") |> render_click()

      assert html =~ "https://alerts.example.com/jobcelis"
      assert view |> element("input[name=meta_webhook_enabled][checked]") |> has_element?()

      assert view
             |> element("input[name='event_types[]'][value=dlq_entry][checked]")
             |> has_element?()

      assert view |> element("button[phx-click=test_notification_channel]") |> has_element?()
    end
  end

  describe "API token restrictions" do
    test "an owner restricts the key to scopes and IPs", %{conn: conn, project: project} do
      {:ok, _key, _raw} = StreamflixCore.Platform.ApiKeys.create_api_key(project.id)
      {:ok, view, _html} = live(conn, "/platform?project=#{project.id}")

      view |> element("button[phx-click=edit_key_restrictions]") |> render_click()

      html =
        view
        |> form("#key-restrictions-form", %{
          "scopes" => ["events:read", "events:write"],
          "allowed_ips" => "10.0.0.1\n10.0.0.2"
        })
        |> render_submit()

      key = StreamflixCore.Platform.get_api_key_for_project(project.id)
      assert key.scopes == ["events:read", "events:write"]
      assert key.allowed_ips == ["10.0.0.1", "10.0.0.2"]
      assert html =~ "10.0.0.2"
    end

    test "shows the error for an invalid IP and keeps the key unchanged", %{
      conn: conn,
      project: project
    } do
      {:ok, _key, _raw} = StreamflixCore.Platform.ApiKeys.create_api_key(project.id)
      {:ok, view, _html} = live(conn, "/platform?project=#{project.id}")

      view |> element("button[phx-click=edit_key_restrictions]") |> render_click()

      html =
        view
        |> form("#key-restrictions-form", %{"scopes" => ["*"], "allowed_ips" => "999.1.1.1"})
        |> render_submit()

      assert html =~ "invalid IP"
      assert StreamflixCore.Platform.get_api_key_for_project(project.id).allowed_ips == []
    end
  end
end
