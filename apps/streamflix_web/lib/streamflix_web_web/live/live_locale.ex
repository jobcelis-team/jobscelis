defmodule StreamflixWebWeb.LiveLocale do
  @moduledoc """
  Assigns the locale from session to socket and sets Gettext for LiveViews.
  """
  import Phoenix.Component

  def on_mount(:set, _params, session, socket) do
    locale = session["locale"] || "en"
    locale = if locale in ["es", "en"], do: locale, else: "en"
    Gettext.put_locale(StreamflixWebWeb.Gettext, locale)
    {:cont, assign(socket, :locale, locale)}
  end
end
