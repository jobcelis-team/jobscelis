defmodule StreamflixWebWeb.PageController do
  use StreamflixWebWeb, :controller

  def home(conn, _params) do
    render(conn, :home,
      active_page: :home,
      meta_description:
        gettext(
          "Infraestructura de eventos para developers. Envía eventos con un POST, configura webhooks con filtros, programa jobs. 12 SDKs + CLI, replay, DLQ, pipelines. Gratis."
        )
    )
  end

  def login(conn, _params), do: render(conn, :login)

  def signup(conn, params) do
    plan = Map.get(params, "plan", "standard")
    email = Map.get(params, "email", "")
    render(conn, :signup, plan: plan, email: email)
  end

  def terms(conn, _params) do
    render(conn, :terms,
      active_page: :terms,
      meta_description: gettext("Términos y condiciones de uso de Jobcelis.")
    )
  end

  def privacy(conn, _params) do
    render(conn, :privacy,
      active_page: :privacy,
      meta_description: gettext("Política de privacidad y protección de datos de Jobcelis.")
    )
  end

  def faq(conn, _params) do
    render(conn, :faq,
      active_page: :faq,
      meta_description:
        gettext(
          "Preguntas frecuentes sobre Jobcelis: eventos, webhooks, API keys, reintentos y más."
        )
    )
  end

  def about(conn, _params) do
    render(conn, :about,
      active_page: :about,
      meta_description:
        gettext(
          "Sobre Jobcelis: plataforma open-source de infraestructura de eventos construida con Elixir y Phoenix."
        )
    )
  end

  def contact(conn, _params) do
    render(conn, :contact,
      active_page: :contact,
      meta_description: gettext("Contacta con el equipo de Jobcelis para soporte o consultas.")
    )
  end

  def pricing(conn, _params) do
    render(conn, :pricing,
      active_page: :pricing,
      meta_description:
        gettext(
          "Jobcelis es gratis. Sin planes, sin límites. Eventos ilimitados, 12 SDKs + CLI, replay, pipelines y más."
        )
    )
  end

  def cookies(conn, _params) do
    render(conn, :cookies,
      active_page: :cookies,
      meta_description:
        gettext("Política de cookies de Jobcelis. Solo cookies técnicas esenciales.")
    )
  end

  def changelog(conn, _params) do
    render(conn, :changelog,
      active_page: :changelog,
      meta_description:
        gettext("Historial de cambios, nuevas features y correcciones de Jobcelis.")
    )
  end

  def forgot_password(conn, _params), do: render(conn, :forgot_password)
  def reset_password(conn, %{"token" => token}), do: render(conn, :reset_password, token: token)

  def set_locale(conn, %{"locale" => locale}) do
    locale = if locale in ["es", "en"], do: locale, else: "en"
    referer = get_req_header(conn, "referer") |> List.first()
    path = path_from_referer(referer, conn)
    # Cookie ensures locale is available before session loads on next request
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
