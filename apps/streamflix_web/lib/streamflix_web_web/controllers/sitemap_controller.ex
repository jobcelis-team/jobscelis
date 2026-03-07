defmodule StreamflixWebWeb.SitemapController do
  use StreamflixWebWeb, :controller

  @moduledoc """
  Sirve sitemap.xml para SEO (Google Search Console, etc.).
  """

  def index(conn, _params) do
    base_url = build_base_url(conn)

    # Páginas públicas que quieres que Google indexe (sin login/signup)
    paths = [
      "/",
      "/docs",
      "/status",
      "/faq",
      "/about",
      "/contact",
      "/pricing",
      "/terms",
      "/privacy",
      "/cookies",
      "/changelog"
    ]

    xml = build_sitemap_xml(base_url, paths)

    conn
    |> put_resp_content_type("application/xml")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, xml)
  end

  defp build_base_url(conn) do
    scheme = if conn.scheme == :https, do: "https", else: "http"
    port = conn.port

    port_str =
      if (scheme == "https" and port == 443) or (scheme == "http" and port == 80),
        do: "",
        else: ":#{port}"

    "#{scheme}://#{conn.host}#{port_str}"
  end

  defp build_sitemap_xml(base_url, paths) do
    today = Date.utc_today() |> Date.to_iso8601()

    url_entries =
      Enum.map_join(paths, "\n", fn path ->
        loc = if path == "/", do: base_url, else: base_url <> path

        """
        <url>
          <loc>#{escape_xml(loc)}</loc>
          <lastmod>#{today}</lastmod>
          <changefreq>weekly</changefreq>
          <priority>#{if path == "/", do: "1.0", else: "0.8"}</priority>
        </url>
        """
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{url_entries}
    </urlset>
    """
    |> String.trim()
  end

  defp escape_xml(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
