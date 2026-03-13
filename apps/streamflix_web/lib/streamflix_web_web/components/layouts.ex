defmodule StreamflixWebWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use StreamflixWebWeb, :html

  embed_templates "layouts/*"

  @doc """
  Toggle de idioma: enlaces a ES / EN. El idioma actual se muestra resaltado.
  """
  attr :locale, :string, required: true, doc: "locale actual (es/en)"
  attr :class, :string, default: nil

  def locale_toggle(assigns) do
    ~H"""
    <span
      class={["flex items-center gap-1 text-sm", @class]}
      role="group"
      aria-label={gettext("Selección de idioma")}
    >
      <a
        href="/locale/es"
        data-locale="es"
        onclick="localStorage.setItem('locale','es');document.cookie='locale=es;path=/;max-age=31536000;SameSite=Lax;Secure';"
        class={[
          "font-medium transition rounded px-1",
          (@locale == "es" && "text-slate-900 dark:text-slate-100 underline") ||
            "text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200"
        ]}
        aria-current={@locale == "es" && "page"}
      >
        ES
      </a>
      <span class="text-slate-300 dark:text-slate-600" aria-hidden="true">|</span>
      <a
        href="/locale/en"
        data-locale="en"
        onclick="localStorage.setItem('locale','en');document.cookie='locale=en;path=/;max-age=31536000;SameSite=Lax;Secure';"
        class={[
          "font-medium transition rounded px-1",
          (@locale == "en" && "text-slate-900 dark:text-slate-100 underline") ||
            "text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200"
        ]}
        aria-current={@locale == "en" && "page"}
      >
        EN
      </a>
    </span>
    """
  end

  # ── Unified site navbar ──────────────────────────────────────────────

  @doc """
  Unified navbar used across ALL pages (public + authenticated).
  Auth-aware: shows Login/Signup for guests, Dashboard/Account/Logout for users.
  Mobile-responsive with hamburger menu.
  """
  attr :current_user, :any, default: nil
  attr :locale, :string, default: "en"
  attr :active_page, :atom, default: nil
  attr :sticky, :boolean, default: true

  def site_navbar(assigns) do
    ~H"""
    <header class={[
      "bg-white/95 dark:bg-slate-900/95 border-b border-slate-200/80 dark:border-slate-700/80 backdrop-blur-sm z-30",
      @sticky && "sticky top-0"
    ]}>
      <nav
        class="max-w-[1920px] mx-auto px-4 sm:px-6 lg:px-10 xl:px-16 flex items-center justify-between h-16"
        aria-label={gettext("Navegación principal")}
      >
        <%!-- Logo --%>
        <a
          href="/"
          class="flex items-center gap-2 text-xl font-bold text-slate-900 dark:text-white tracking-tight rounded shrink-0 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
          aria-label={gettext("Jobcelis - Ir al inicio")}
        >
          <img src={~p"/images/logo.png"} alt="" class="h-8 w-auto" width="32" height="32" /> Jobcelis
        </a>
        <%!-- Desktop links --%>
        <div class="hidden lg:flex items-center gap-3 xl:gap-5 whitespace-nowrap">
          <a
            href="/docs"
            class={[
              "font-medium text-sm transition rounded inline-flex items-center gap-1.5 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2",
              (@active_page == :docs && "text-indigo-600 dark:text-indigo-400") ||
                "text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200"
            ]}
          >
            <.icon name="hero-book-open" class="w-4 h-4" /> {gettext("Documentación")}
          </a>
          <a
            href="/faq"
            class={[
              "font-medium text-sm transition rounded inline-flex items-center gap-1.5 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2",
              (@active_page == :faq && "text-indigo-600 dark:text-indigo-400") ||
                "text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200"
            ]}
          >
            <.icon name="hero-question-mark-circle" class="w-4 h-4" /> {gettext("FAQ")}
          </a>
          <a
            href="/pricing"
            class={[
              "font-medium text-sm transition rounded inline-flex items-center gap-1.5 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2",
              (@active_page == :pricing && "text-indigo-600 dark:text-indigo-400") ||
                "text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200"
            ]}
          >
            <.icon name="hero-heart" class="w-4 h-4" /> {gettext("Apoyar el proyecto")}
          </a>
          <.theme_toggle />
          <.locale_toggle locale={@locale} class="flex items-center gap-1" />
          <%= if @current_user do %>
            <.link
              navigate="/platform"
              class={[
                "font-medium text-sm transition rounded inline-flex items-center gap-1.5 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2",
                (@active_page == :dashboard && "text-indigo-600 dark:text-indigo-400") ||
                  "text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200"
              ]}
            >
              <.icon name="hero-squares-2x2" class="w-4 h-4" /> {gettext("Dashboard")}
            </.link>
            <.link
              navigate="/account"
              class={[
                "font-medium text-sm transition rounded inline-flex items-center gap-1.5 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2",
                (@active_page == :account && "text-indigo-600 dark:text-indigo-400") ||
                  "text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200"
              ]}
            >
              <.icon name="hero-user-circle" class="w-4 h-4" /> {gettext("Cuenta")}
            </.link>
            <%= if @current_user.role in ["admin", "superadmin"] do %>
              <a
                href="/admin"
                class="text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200 font-medium text-sm rounded inline-flex items-center gap-1.5 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"
              >
                <.icon name="hero-shield-check" class="w-4 h-4" /> {gettext("Admin")}
              </a>
            <% end %>

            <a
              href="/logout"
              class="text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200 font-medium text-sm rounded inline-flex items-center gap-1.5 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"
            >
              <.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4" /> {gettext("Cerrar sesión")}
            </a>
          <% else %>
            <a
              href="/login"
              class="text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200 font-medium text-sm transition rounded focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"
            >
              {gettext("Iniciar sesión")}
            </a>
            <a
              href="/signup"
              class="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-lg font-medium text-sm transition shadow-sm hover:shadow focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white"
            >
              {gettext("Registrarse")}
            </a>
          <% end %>
        </div>
        <%!-- Mobile hamburger --%>
        <button
          type="button"
          class="lg:hidden p-2 rounded-lg text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2"
          aria-label={gettext("Abrir menú")}
          phx-click={
            JS.toggle(to: "#mobile-menu-panel")
            |> JS.toggle(to: "#menu-icon-open")
            |> JS.toggle(to: "#menu-icon-close")
          }
        >
          <span id="menu-icon-open"><.icon name="hero-bars-3" class="w-6 h-6" /></span>
          <span id="menu-icon-close" class="hidden">
            <.icon name="hero-x-mark" class="w-6 h-6" />
          </span>
        </button>
      </nav>
      <%!-- Mobile menu panel --%>
      <div
        class="lg:hidden hidden border-t border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900"
        id="mobile-menu-panel"
      >
        <div class="px-4 py-4 space-y-1">
          <a
            href="/docs"
            class={[
              "flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition",
              (@active_page == :docs &&
                 "bg-indigo-50 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400") ||
                "text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800"
            ]}
          >
            <.icon name="hero-book-open" class="w-5 h-5" /> {gettext("Documentación")}
          </a>
          <a
            href="/faq"
            class={[
              "flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition",
              (@active_page == :faq &&
                 "bg-indigo-50 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400") ||
                "text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800"
            ]}
          >
            <.icon name="hero-question-mark-circle" class="w-5 h-5" /> {gettext("FAQ")}
          </a>
          <a
            href="/pricing"
            class={[
              "flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition",
              (@active_page == :pricing &&
                 "bg-indigo-50 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400") ||
                "text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800"
            ]}
          >
            <.icon name="hero-heart" class="w-5 h-5" /> {gettext("Apoyar el proyecto")}
          </a>
          <div class="border-t border-slate-100 dark:border-slate-700 my-2"></div>

          <div class="flex items-center gap-3 px-3 py-2">
            <.theme_toggle />
            <.locale_toggle locale={@locale} />
          </div>

          <div class="border-t border-slate-100 dark:border-slate-700 my-2"></div>

          <%= if @current_user do %>
            <.link
              navigate="/platform"
              class={[
                "flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition",
                (@active_page == :dashboard &&
                   "bg-indigo-50 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400") ||
                  "text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800"
              ]}
            >
              <.icon name="hero-squares-2x2" class="w-5 h-5" /> {gettext("Dashboard")}
            </.link>
            <.link
              navigate="/account"
              class={[
                "flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition",
                (@active_page == :account &&
                   "bg-indigo-50 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400") ||
                  "text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800"
              ]}
            >
              <.icon name="hero-user-circle" class="w-5 h-5" /> {gettext("Cuenta")}
            </.link>
            <%= if @current_user.role in ["admin", "superadmin"] do %>
              <a
                href="/admin"
                class="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-slate-700 hover:bg-slate-50 transition"
              >
                <.icon name="hero-shield-check" class="w-5 h-5" /> {gettext("Admin")}
              </a>
            <% end %>

            <a
              href="/logout"
              class="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-slate-700 hover:bg-slate-50 transition"
            >
              <.icon name="hero-arrow-right-on-rectangle" class="w-5 h-5" /> {gettext("Cerrar sesión")}
            </a>
          <% else %>
            <a
              href="/login"
              class="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-slate-700 hover:bg-slate-50 transition"
            >
              {gettext("Iniciar sesión")}
            </a>
            <a
              href="/signup"
              class="flex items-center justify-center gap-2 px-3 py-2.5 rounded-lg text-sm font-medium bg-indigo-600 text-white hover:bg-indigo-700 transition"
            >
              {gettext("Registrarse")}
            </a>
          <% end %>
        </div>
      </div>
    </header>
    """
  end

  # ── Unified site footer ──────────────────────────────────────────────

  @doc """
  Unified footer used across ALL pages (public + authenticated).
  Compact 2-row layout: links row + copyright/legal row.
  """
  attr :locale, :string, default: "en"
  attr :legal, :map, default: %{}

  def site_footer(assigns) do
    ~H"""
    <footer
      class="border-t border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 mt-auto"
      role="contentinfo"
    >
      <div class="max-w-[1920px] mx-auto px-4 sm:px-6 lg:px-10 xl:px-16 py-6">
        <%!-- Row 1: Brand + links --%>
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <a
            href="/"
            class="flex items-center gap-2 text-base font-bold text-slate-900 dark:text-white"
          >
            <img src={~p"/images/logo.png"} alt="" class="h-5 w-auto" width="20" height="20" />
            Jobcelis
          </a>

          <nav class="flex flex-wrap items-center gap-x-5 gap-y-1 text-sm">
            <a
              href="/changelog"
              class="text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200 transition"
            >
              Changelog
            </a>
            <a
              href="/about"
              class="text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200 transition"
            >
              {gettext("Sobre nosotros")}
            </a>
            <a
              href="/contact"
              class="text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200 transition"
            >
              {gettext("Contacto")}
            </a>
            <a
              href="/status"
              class="text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200 transition"
            >
              Status
            </a>
            <a
              href="https://github.com/jobcelis-team/jobscelis"
              target="_blank"
              rel="noopener noreferrer"
              class="text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-200 transition"
            >
              GitHub
            </a>
          </nav>
        </div>
        <%!-- Row 2: Copyright + legal links --%>
        <div class="mt-4 pt-4 border-t border-slate-100 dark:border-slate-800 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 text-xs text-slate-400 dark:text-slate-500">
          <p>
            &copy; {Date.utc_today().year} {Map.get(@legal, :owner, "Jobcelis")}. {gettext(
              "Todos los derechos reservados."
            )}
          </p>
          <nav class="flex items-center gap-3">
            <a href="/terms" class="hover:text-slate-600 dark:hover:text-slate-300 transition">
              {gettext("Términos")}
            </a>
            <span class="text-slate-300 dark:text-slate-600">&middot;</span>
            <a href="/privacy" class="hover:text-slate-600 dark:hover:text-slate-300 transition">
              {gettext("Privacidad")}
            </a>
            <span class="text-slate-300 dark:text-slate-600">&middot;</span>
            <a href="/cookies" class="hover:text-slate-600 dark:hover:text-slate-300 transition">
              Cookies
            </a>
          </nav>
        </div>
      </div>
    </footer>
    """
  end

  # ── Cookie consent banner ────────────────────────────────────────

  @doc """
  Informative cookie banner for technical-only cookies (session + locale).
  Uses localStorage to persist dismissal. No opt-in needed (ePrivacy exempt).
  """
  def cookie_banner(assigns) do
    ~H"""
    <div
      id="cookie-banner"
      phx-hook="CookieBanner"
      class="fixed bottom-0 inset-x-0 z-50 hidden"
      role="alert"
      aria-live="polite"
    >
      <div class="bg-slate-900 border-t border-slate-700 shadow-lg">
        <div class="max-w-5xl mx-auto px-3 sm:px-6 py-3 sm:py-4 flex flex-col sm:flex-row items-start sm:items-center gap-3 sm:gap-4">
          <p class="text-slate-200 text-xs sm:text-sm flex-1">
            {gettext(
              "Este sitio usa solo cookies técnicas necesarias para el funcionamiento del servicio (sesión y preferencia de idioma). No usamos cookies de seguimiento ni analíticas."
            )}
            <a href="/cookies" class="underline text-indigo-400 hover:text-indigo-300 ml-1">
              {gettext("Más información")}
            </a>
          </p>
          <button
            id="cookie-accept-btn"
            type="button"
            data-cookie-accept
            class="shrink-0 bg-indigo-600 hover:bg-indigo-500 text-white text-xs sm:text-sm font-medium px-4 py-2 rounded-lg transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-400"
          >
            {gettext("Entendido")}
          </button>
        </div>
      </div>
    </div>
    """
  end

  # ── Public layout ────────────────────────────────────────────────────

  @doc """
  Layout for public pages (home, docs, faq, about, etc.).
  Wraps content with site_navbar + main + site_footer.

  ## Examples

      <Layouts.public flash={@flash} current_user={@current_user} locale={@locale} legal={@legal} active_page={:home}>
        <h1>Content</h1>
      </Layouts.public>
  """
  attr :flash, :map, default: %{}
  attr :current_user, :any, default: nil
  attr :locale, :string, default: "en"
  attr :legal, :map, default: %{}
  attr :active_page, :atom, default: nil
  attr :main_class, :string, default: "max-w-3xl mx-auto px-4 sm:px-6 py-12"
  slot :inner_block, required: true

  def public(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-50 dark:bg-slate-900 relative flex flex-col">
      <a href="#main-content" class="skip-link">{gettext("Saltar al contenido")}</a>
      <.site_navbar current_user={@current_user} locale={@locale} active_page={@active_page} />
      <main id="main-content" class={@main_class} role="main" tabindex="-1">
        {render_slot(@inner_block)}
      </main>
      <.site_footer locale={@locale} legal={@legal} /> <.flash_group flash={@flash} />
      <.cookie_banner />
    </div>
    """
  end

  # ── App layout (authenticated) ───────────────────────────────────────

  @doc """
  Renders your app layout (for authenticated LiveViews like Dashboard, Account).

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :any,
    default: nil,
    doc: "current scope (:account, :platform, etc.)"

  attr :current_user, :any,
    default: nil,
    doc: "logged-in user (for showing Admin link if admin/superadmin)"

  attr :locale, :string, default: "en", doc: "current locale (en/es)"

  attr :main_class, :string,
    default: nil,
    doc: "optional class for main (e.g. wider max-width for account page)"

  attr :active_page, :atom, default: nil, doc: "active page for navbar highlighting"

  slot :inner_block, required: true

  def app(assigns) do
    legal = Application.get_env(:streamflix_web, :legal, []) |> Enum.into(%{})
    assigns = assign(assigns, :legal, legal)

    ~H"""
    <div class="min-h-screen bg-slate-50 dark:bg-slate-900 relative flex flex-col">
      <a href="#main-content" class="skip-link">{gettext("Saltar al contenido")}</a>
      <.site_navbar current_user={@current_user} locale={@locale} active_page={@active_page} />
      <main
        id="main-content"
        class={@main_class || "max-w-6xl mx-auto px-4 sm:px-6 py-8 flex-1"}
        role="main"
      >
        {render_slot(@inner_block)}
      </main>
      <.site_footer locale={@locale} legal={@legal} /> <.flash_group flash={@flash} />
      <.cookie_banner />
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
      <.flash kind={:info} flash={@flash} /> <.flash kind={:error} flash={@flash} />
      <.flash
        id="client-error"
        kind={:error}
        title={gettext("No encontramos la conexión a internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Intentando reconectar")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("¡Algo salió mal!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Intentando reconectar")}
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
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme-choice=light]_&]:left-1/3 [[data-theme-choice=dark]_&]:left-2/3 transition-[left]" />
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
