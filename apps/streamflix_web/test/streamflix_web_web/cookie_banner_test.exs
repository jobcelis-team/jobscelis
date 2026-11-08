defmodule StreamflixWebWeb.CookieBannerTest do
  use StreamflixWebWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # The banner's visibility lives on <html data-cookie-notice> (set by an inline
  # script before the first paint), never on the banner element: LiveView
  # patches restore the element's server-rendered attributes, which made the
  # banner flicker and come back after it was dismissed.
  test "dead views render the banner without client-side visibility state", %{conn: conn} do
    html = conn |> get("/") |> html_response(200)

    assert html =~ ~s(id="cookie-banner")
    assert html =~ "data-cookie-accept"
    assert html =~ "cookie_notice=1"
    refute html =~ ~s(phx-hook="CookieBanner")
    refute banner_tag(html) =~ "hidden"
  end

  test "LiveView pages render the same banner", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/docs")

    assert html =~ ~s(id="cookie-banner")
    refute html =~ ~s(phx-hook="CookieBanner")
    refute banner_tag(html) =~ "hidden"
  end

  defp banner_tag(html) do
    [tag] = Regex.run(~r/<div[^>]*id="cookie-banner"[^>]*>/s, html)
    tag
  end
end
