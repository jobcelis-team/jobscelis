defmodule StreamflixWebWeb.DocsLiveTest do
  use StreamflixWebWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias StreamflixWebWeb.SdkCatalog

  test "lists every SDK and tool from the catalog", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/docs")

    for entry <- SdkCatalog.entries(),
        do: assert(html =~ entry["url"], "missing #{entry["label"]}")

    assert html =~ ~s(id="terraform")
    assert html =~ ~s(id="github-action")
    assert html =~ "jobcelis-team/jobscelis/sdks/github-action@main"
    assert html =~ "com.jobcelis:jobcelis-kotlin:#{SdkCatalog.version("kotlin")}"
    assert html =~ "go get github.com/jobcelis-team/go-jobcelis"
  end
end
