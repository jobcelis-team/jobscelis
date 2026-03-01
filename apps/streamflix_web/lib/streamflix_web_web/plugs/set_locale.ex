defmodule StreamflixWebWeb.Plugs.SetLocale do
  @moduledoc """
  Reads locale from cookie or session. Sets Gettext and conn.assigns.locale.
  Values: "en", "es". Default: "en".
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    locale = get_locale(conn) |> validate_locale()
    Gettext.put_locale(StreamflixWebWeb.Gettext, locale)

    conn
    |> put_session("locale", locale)
    |> assign(:locale, locale)
  end

  # Cookie primero (rápido, sin esperar sesión); luego sesión
  defp get_locale(conn) do
    get_cookie(conn, "locale") ||
      get_session(conn, "locale") ||
      get_session(conn, :locale)
  end

  defp get_cookie(conn, name) do
    conn
    |> get_req_header("cookie")
    |> List.first()
    |> parse_cookie(name)
  end

  defp parse_cookie(nil, _), do: nil

  defp parse_cookie(cookie_str, name) do
    cookie_str
    |> String.split(";")
    |> Enum.find_value(fn part ->
      [k | v] = String.split(part, "=", parts: 2)
      if String.trim(k) == name, do: String.trim(List.first(v) || "")
    end)
  end

  defp validate_locale(nil), do: "en"
  defp validate_locale("en"), do: "en"
  defp validate_locale("es"), do: "es"
  defp validate_locale(_), do: "en"
end
