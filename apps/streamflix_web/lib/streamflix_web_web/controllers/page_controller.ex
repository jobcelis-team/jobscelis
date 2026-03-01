defmodule StreamflixWebWeb.PageController do
  use StreamflixWebWeb, :controller

  def home(conn, _params) do
    render(conn, :home, active_page: :home)
  end

  def login(conn, _params) do
    render(conn, :login)
  end

  def signup(conn, params) do
    plan = Map.get(params, "plan", "standard")
    email = Map.get(params, "email", "")
    render(conn, :signup, plan: plan, email: email)
  end

  def docs(conn, _params) do
    render(conn, :docs, active_page: :docs, base_url: build_base_url(conn))
  end

  def terms(conn, _params), do: render(conn, :terms, active_page: :terms)
  def privacy(conn, _params), do: render(conn, :privacy, active_page: :privacy)
  def faq(conn, _params), do: render(conn, :faq, active_page: :faq)
  def about(conn, _params), do: render(conn, :about, active_page: :about)
  def contact(conn, _params), do: render(conn, :contact, active_page: :contact)
  def pricing(conn, _params), do: render(conn, :pricing, active_page: :pricing)
  def cookies(conn, _params), do: render(conn, :cookies, active_page: :cookies)
  def changelog(conn, _params), do: render(conn, :changelog, active_page: :changelog)
  def forgot_password(conn, _params), do: render(conn, :forgot_password)
  def reset_password(conn, %{"token" => token}), do: render(conn, :reset_password, token: token)

  def set_locale(conn, %{"locale" => locale}) do
    locale = if locale in ["es", "en"], do: locale, else: "en"
    referer = get_req_header(conn, "referer") |> List.first()
    path = path_from_referer(referer, conn)
    # Cookie para que el siguiente request tenga el idioma sin depender de sesión (más rápido)
    conn
    |> put_resp_cookie("locale", locale, path: "/", max_age: 365 * 24 * 60 * 60)
    |> put_session("locale", locale)
    |> redirect(to: path)
  end

  def set_locale(conn, _params), do: redirect(conn, to: "/")

  defp path_from_referer(nil, _conn), do: "/"

  defp path_from_referer(referer, conn) do
    base = build_base_url(conn)

    if String.starts_with?(referer, base) do
      uri = URI.parse(referer)
      path = uri.path || "/"
      if uri.query, do: path <> "?" <> uri.query, else: path
    else
      "/"
    end
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
end
