defmodule StreamflixWebWeb.DeployNoticeTest do
  use StreamflixWebWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias StreamflixWebWeb.DeployNotice

  test "announces the restart when it is shut down" do
    Phoenix.PubSub.subscribe(StreamflixCore.PubSub, DeployNotice.topic())
    start_supervised!({DeployNotice, flush_ms: 10})

    stop_supervised!(DeployNotice)

    assert_receive {:deploy_notice, :restarting}
  end

  test "open LiveView pages receive the notice; the page has it translated", %{conn: conn} do
    {:ok, view, html} = live(conn, "/docs")
    assert html =~ ~s(id="deploy-notice")
    assert html =~ "Estamos mejorando Jobcelis" or html =~ "We are improving Jobcelis"

    Phoenix.PubSub.broadcast(
      StreamflixCore.PubSub,
      DeployNotice.topic(),
      {:deploy_notice, :restarting}
    )

    assert_push_event(view, "deploy-notice", %{})
  end

  test "other messages still reach the LiveView", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/docs")
    send(view.pid, :unrelated)
    assert render(view) =~ "SDKs"
  end
end
