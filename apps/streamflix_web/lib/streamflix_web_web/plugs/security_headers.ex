defmodule StreamflixWebWeb.Plugs.SecurityHeaders do
  @moduledoc """
  Adds HTTP security headers to mitigate XSS, clickjacking, MIME sniffing and referrer leaks.
  Uses per-request CSP nonces for inline scripts (no unsafe-inline needed).
  """
  import Plug.Conn

  @chart_js_origin "https://cdn.jsdelivr.net/npm/chart.js@4.4.7/"

  def init(opts), do: opts

  def call(%{request_path: "/api/" <> _} = conn, _opts) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
  end

  def call(conn, _opts) do
    nonce = generate_nonce()

    conn
    |> assign(:csp_nonce, nonce)
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-xss-protection", "0")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", "geolocation=(), microphone=(), camera=()")
    |> put_content_security_policy(nonce)
  end

  defp put_content_security_policy(%{request_path: "/api/swaggerui"} = conn, _nonce) do
    csp =
      [
        "default-src 'self'",
        "script-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com",
        "style-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com",
        "img-src 'self' data: https:",
        "font-src 'self' https://cdnjs.cloudflare.com",
        "connect-src 'self' wss: ws:",
        "frame-ancestors 'none'",
        "base-uri 'self'",
        "form-action 'self'"
      ]
      |> Enum.join("; ")

    put_resp_header(conn, "content-security-policy", csp)
  end

  defp put_content_security_policy(conn, nonce) do
    csp =
      [
        "default-src 'self'",
        # Only the pinned Chart.js build, not every package on the CDN
        "script-src 'self' 'nonce-#{nonce}' #{@chart_js_origin}",
        "style-src 'self' 'unsafe-inline'",
        "img-src 'self' data: https:",
        "font-src 'self'",
        "connect-src 'self' #{socket_origin()}",
        "frame-ancestors 'none'",
        "base-uri 'self'",
        "form-action 'self'"
      ]
      |> Enum.join("; ")

    put_resp_header(conn, "content-security-policy", csp)
  end

  # LiveView socket on this app's own host only (was any ws:/wss: origin)
  defp socket_origin do
    StreamflixWebWeb.Endpoint.url()
    |> String.replace_prefix("https://", "wss://")
    |> String.replace_prefix("http://", "ws://")
  end

  defp generate_nonce do
    16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end
