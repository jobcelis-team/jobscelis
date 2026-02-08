defmodule StreamflixWebWeb.PageController do
  use StreamflixWebWeb, :controller

  def home(conn, _params) do
    legal = Application.get_env(:streamflix_web, :legal, []) |> Enum.into(%{})
    pricing = %{
      basic: 0,
      standard: 0,
      premium: 0
    }
    render(conn, :home, pricing: pricing, legal: legal)
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
    base_url = build_base_url(conn)
    current_user = current_user_from_session(conn)
    render(conn, :docs, base_url: base_url, current_user: current_user)
  end

  def terms(conn, _params) do
    legal = Application.get_env(:streamflix_web, :legal, []) |> Enum.into(%{})
    locale = get_session(conn, :locale) || "es"
    render(conn, :terms, legal: legal, locale: locale)
  end

  def privacy(conn, _params) do
    legal = Application.get_env(:streamflix_web, :legal, []) |> Enum.into(%{})
    locale = get_session(conn, :locale) || "es"
    render(conn, :privacy, legal: legal, locale: locale)
  end

  def set_locale(conn, %{"locale" => locale}) do
    locale = if locale in ["es", "en"], do: locale, else: "es"
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
    port_str = if (scheme == "https" and port == 443) or (scheme == "http" and port == 80), do: "", else: ":#{port}"
    "#{scheme}://#{conn.host}#{port_str}"
  end

  defp current_user_from_session(conn) do
    case get_session(conn, :user_token) do
      nil -> nil
      token ->
        case StreamflixAccounts.verify_token(token) do
          {:ok, user, _claims} -> user
          {:error, _} -> nil
        end
    end
  end
end
