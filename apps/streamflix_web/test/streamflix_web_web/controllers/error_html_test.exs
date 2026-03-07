defmodule StreamflixWebWeb.ErrorHTMLTest do
  use StreamflixWebWeb.ConnCase, async: true

  import Phoenix.Template, only: [render_to_string: 4]

  test "renders 404.html" do
    conn = build_conn()
    html = render_to_string(StreamflixWebWeb.ErrorHTML, "404", "html", conn: conn)
    assert html =~ "404"
    assert html =~ "Page not found"
  end

  test "renders 500.html" do
    conn = build_conn()
    html = render_to_string(StreamflixWebWeb.ErrorHTML, "500", "html", conn: conn)
    assert html =~ "500"
    assert html =~ "Internal server error"
  end

  test "renders 404 in Spanish when locale cookie is es" do
    conn = build_conn() |> put_req_header("cookie", "locale=es")
    html = render_to_string(StreamflixWebWeb.ErrorHTML, "404", "html", conn: conn)
    assert html =~ "Página no encontrada"
  end

  test "renders 500 in Spanish when locale cookie is es" do
    conn = build_conn() |> put_req_header("cookie", "locale=es")
    html = render_to_string(StreamflixWebWeb.ErrorHTML, "500", "html", conn: conn)
    assert html =~ "Error interno del servidor"
  end
end
