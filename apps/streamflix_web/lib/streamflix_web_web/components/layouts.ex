defmodule StreamflixWebWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use StreamflixWebWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Toggle de idioma: enlaces a ES / EN. El idioma actual se muestra resaltado.
  """
  attr :locale, :string, required: true, doc: "locale actual (es/en)"
  attr :class, :string, default: nil

  def locale_toggle(assigns) do
    ~H"""
    <span class={["flex items-center gap-1 text-sm", @class]} role="group" aria-label={gettext("Selección de idioma")}>
      <a
        href="/locale/es"
        data-locale="es"
        onclick="localStorage.setItem('locale','es');document.cookie='locale=es;path=/;max-age=31536000';"
        class={["font-medium transition rounded px-1", @locale == "es" && "text-slate-900 underline" || "text-slate-500 hover:text-slate-700"]}
        aria-current={@locale == "es" && "page"}
      >
        ES
      </a>
      <span class="text-slate-300" aria-hidden="true">|</span>
      <a
        href="/locale/en"
        data-locale="en"
        onclick="localStorage.setItem('locale','en');document.cookie='locale=en;path=/;max-age=31536000';"
        class={["font-medium transition rounded px-1", @locale == "en" && "text-slate-900 underline" || "text-slate-500 hover:text-slate-700"]}
        aria-current={@locale == "en" && "page"}
      >
        EN
      </a>
    </span>
    """
  end

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :any,
    default: nil,
    doc: "current scope (:account, :platform, etc.)"

  attr :current_user, :any, default: nil, doc: "logged-in user (for showing Admin link if admin/superadmin)"
  attr :locale, :string, default: "en", doc: "current locale (en/es)"
  attr :main_class, :string, default: nil, doc: "optional class for main (e.g. wider max-width for account page)"

  slot :inner_block, required: true

  def app(assigns) do
    legal = Application.get_env(:streamflix_web, :legal, []) |> Enum.into(%{})
    assigns = assign(assigns, :legal, legal)

    ~H"""
    <div class="min-h-screen bg-slate-50 relative flex flex-col">
      <a href="#main-content" class="skip-link"><%= gettext("Saltar al contenido") %></a>
      <header class="bg-white border-b border-slate-200">
        <div class="max-w-6xl mx-auto px-4 sm:px-6 flex items-center justify-between h-14">
          <a href="/" class="text-lg font-bold text-slate-900 rounded focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600" aria-label={gettext("Jobcelis - Ir al inicio")}>Jobcelis</a>
          <nav class="flex items-center gap-6" aria-label={gettext("Navegación principal")}>
            <.locale_toggle locale={@locale} class="flex items-center gap-1" />
            <a href="/docs" class="text-slate-600 hover:text-slate-900 font-medium text-sm rounded focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"><%= gettext("Documentación") %></a>
            <a href="/pricing" class="text-emerald-600 hover:text-emerald-700 font-medium text-sm rounded focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"><%= gettext("Apoyar el proyecto") %></a>
            <.link navigate="/platform" class="text-slate-600 hover:text-slate-900 font-medium text-sm rounded focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"><%= gettext("Dashboard") %></.link>
            <.link navigate="/account" class="text-slate-600 hover:text-slate-900 font-medium text-sm rounded focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"><%= gettext("Cuenta") %></.link>
            <%= if @current_user && @current_user.role in ["admin", "superadmin"] do %>
              <a href="/admin" class="text-amber-600 hover:text-amber-700 font-medium text-sm rounded focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"><%= gettext("Admin") %></a>
            <% end %>
            <a href="/logout" class="text-slate-600 hover:text-slate-900 font-medium text-sm rounded focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"><%= gettext("Cerrar sesión") %></a>
          </nav>
        </div>
      </header>

      <main id="main-content" class={@main_class || "max-w-6xl mx-auto px-4 sm:px-6 py-8 flex-1"} role="main">
        {render_slot(@inner_block)}
      </main>

      <footer class="border-t border-slate-200 py-4 bg-white mt-auto" role="contentinfo">
        <div class="max-w-6xl mx-auto px-4 flex flex-col sm:flex-row items-center justify-between gap-2 text-sm text-slate-500">
          <span>© <%= Date.utc_today().year %> <%= Map.get(@legal, :owner, "Jobcelis") %>. <%= gettext("Todos los derechos reservados.") %></span>
          <nav class="flex items-center gap-4 flex-wrap justify-center sm:justify-end" aria-label={gettext("Enlaces legales y de ayuda")}>
            <a href="/docs" class="hover:text-slate-700 rounded focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"><%= gettext("Documentación") %></a>
            <a href="/faq" class="hover:text-slate-700 rounded focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"><%= gettext("FAQ") %></a>
            <a href="/about" class="hover:text-slate-700 rounded focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"><%= gettext("Sobre nosotros") %></a>
            <a href="/contact" class="hover:text-slate-700 rounded focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"><%= gettext("Contacto") %></a>
            <a href="/pricing" class="hover:text-slate-700 rounded focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"><%= gettext("Planes") %></a>
            <a href="/terms" class="hover:text-slate-700 rounded focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"><%= gettext("Términos") %></a>
            <a href="/privacy" class="hover:text-slate-700 rounded focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"><%= gettext("Privacidad") %></a>
            <a href="/cookies" class="hover:text-slate-700 rounded focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"><%= gettext("Cookies") %></a>
            <a href="/changelog" class="hover:text-slate-700 rounded focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"><%= gettext("Changelog") %></a>
          </nav>
        </div>
      </footer>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
