defmodule StreamflixWebWeb.PlatformDashboardFormsTest do
  use StreamflixWebWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias StreamflixCore.Platform
  alias StreamflixWebWeb.FreshApiKey

  @password "SecurePass123!"

  defp login(conn, user) do
    {:ok, token, claims} = StreamflixAccounts.generate_token(user)
    {:ok, _} = StreamflixAccounts.create_session(user.id, claims["jti"])
    init_test_session(conn, %{user_token: token, current_jti: claims["jti"], remember_me: true})
  end

  defp register do
    {:ok, user, _} =
      StreamflixAccounts.register_user(%{
        email: "forms#{System.unique_integer([:positive])}@example.com",
        password: @password,
        name: "Forms User"
      })

    user
  end

  defp assigns(view), do: :sys.get_state(view.pid).socket.assigns

  describe "API key created at sign-up" do
    test "is not kept in the session and is shown only once", %{conn: conn} do
      email = "once#{System.unique_integer([:positive])}@example.com"

      conn =
        conn
        |> Map.put(:remote_ip, {10, 1, 0, Enum.random(1..250)})
        |> post("/signup", %{"name" => "Ana", "email" => email, "password" => @password})

      assert redirected_to(conn) =~ "/platform"
      refute get_session(conn, :fresh_api_key)

      user = StreamflixAccounts.get_user_by_email(email)
      raw = FreshApiKey.get(user.id, take: false)
      assert is_binary(raw)

      [project | _] = StreamflixCore.Teams.list_all_accessible_projects(user.id)
      authed = login(build_conn(), user)

      {:ok, _view, html} = live(authed, "/platform?project=#{project.id}")
      assert html =~ raw

      assert FreshApiKey.get(user.id, take: false) == nil
      {:ok, _view, html} = live(authed, "/platform?project=#{project.id}")
      refute html =~ raw
    end
  end

  describe "webhook form" do
    setup %{conn: conn} do
      user = register()
      project = insert(:project, user_id: user.id)
      %{conn: login(conn, user), project: project}
    end

    test "an invalid URL keeps the form on step 1 with its error", %{conn: conn, project: project} do
      {:ok, view, _} = live(conn, "/platform?project=#{project.id}")
      render_click(view, "switch_tab", %{"tab" => "webhooks"})
      render_click(view, "new_webhook", %{})

      render_change(view, "webhook_form_change", %{
        "webhook" => %{"url" => "admin@example.comhttp://receiver.example.com/hook"}
      })

      html = render_click(view, "webhook_step", %{"step" => "2"})

      assert assigns(view).webhook_step == 1
      assert html =~ "The URL must start with http:// or https://"
    end

    test "accepts http URLs like the API does and creates the webhook", %{
      conn: conn,
      project: project
    } do
      {:ok, view, _} = live(conn, "/platform?project=#{project.id}")
      render_click(view, "switch_tab", %{"tab" => "webhooks"})
      render_click(view, "new_webhook", %{})
      url = "http://receiver.example.com/hook"

      render_change(view, "webhook_form_change", %{"webhook" => %{"url" => url}})
      render_click(view, "webhook_step", %{"step" => "2"})
      assert assigns(view).webhook_step == 2

      render_submit(view, "save_webhook", %{
        "webhook" => %{"url" => url, "topics" => "order.*", "secret" => ""}
      })

      assert [%{url: ^url, topics: ["order.*"]}] = Platform.list_webhooks(project.id)
    end
  end

  describe "send test event" do
    test "the new event is listed once", %{conn: conn} do
      user = register()
      project = insert(:project, user_id: user.id)
      {:ok, view, _} = live(login(conn, user), "/platform?project=#{project.id}")

      render_hook(view, "send_test", %{"topic" => "order.created", "payload" => "{}"})

      [event] = Platform.list_events(project.id, limit: 5)
      assert Enum.count(assigns(view).events, &(&1.id == event.id)) == 1
    end
  end
end
