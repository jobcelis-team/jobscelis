defmodule StreamflixWebWeb.Plugs.SecurityHeaders do
  @moduledoc """
  Adds HTTP security headers to mitigate XSS, clickjacking, MIME sniffing and referrer leaks.
  Uses per-request CSP nonces for inline scripts (no unsafe-inline needed).
  """
  import Plug.Conn

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
        "script-src 'self' 'nonce-#{nonce}'",
        "style-src 'self' 'unsafe-inline'",
        "img-src 'self' data: https:",
        "font-src 'self'",
        "connect-src 'self' wss: ws:",
        "frame-ancestors 'none'",
        "base-uri 'self'",
        "form-action 'self'"
      ]
      |> Enum.join("; ")

    put_resp_header(conn, "content-security-policy", csp)
  end

  defp generate_nonce do
    16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end
