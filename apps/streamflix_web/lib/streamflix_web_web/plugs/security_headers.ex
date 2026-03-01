defmodule StreamflixWebWeb.Plugs.SecurityHeaders do
  @moduledoc """
  Añade cabeceras HTTP de seguridad para mitigar XSS, clickjacking, MIME sniffing y fugas de referrer.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-xss-protection", "1; mode=block")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", "geolocation=(), microphone=(), camera=()")
    |> put_content_security_policy()
  end

  defp put_content_security_policy(%{request_path: "/api/swaggerui"} = conn) do
    # CSP relajada para Swagger UI: permite CDN de cdnjs.cloudflare.com y scripts inline.
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

  defp put_content_security_policy(conn) do
    # CSP: restringe orígenes de script, estilo e imágenes. Ajusta si usas CDN o inline.
    csp =
      [
        "default-src 'self'",
        "script-src 'self'",
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
end
