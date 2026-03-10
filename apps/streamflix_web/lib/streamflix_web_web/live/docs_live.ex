defmodule StreamflixWebWeb.DocsLive do
  @moduledoc """
  Public documentation page as a LiveView.
  Features: scroll spy, SDK code switcher, collapsible sidebar, mobile drawer,
  copy-to-clipboard, bilingual (EN/ES), dark mode support.

  Content is split into separate modules under `StreamflixWebWeb.Docs.*`:
  - Components — shared UI primitives (section, endpoint, code block, etc.)
  - Helpers — SDK data (labels, install, usage) and framework code samples
  - SectionGettingStarted, SectionConfiguration, SectionApiReference,
    SectionPlatform, SectionAdvanced, SectionSdks, SectionSecurity, SectionReference
  """
  use StreamflixWebWeb, :live_view

  alias StreamflixWebWeb.Docs.{
    SectionGettingStarted,
    SectionConfiguration,
    SectionApiReference,
    SectionPlatform,
    SectionAdvanced,
    SectionSdks,
    SectionSecurity,
    SectionReference
  }

  @sdk_languages ~w(nodejs python go php ruby elixir dotnet rust swift java dart kotlin)

  @impl true
  def mount(_params, _session, socket) do
    base_url =
      case socket.endpoint.config(:url) do
        url when is_list(url) ->
          host = Keyword.get(url, :host, "localhost")
          scheme = Keyword.get(url, :scheme, "https")
          port = Keyword.get(url, :port)

          port_str =
            cond do
              is_nil(port) -> ""
              scheme == "https" and port == 443 -> ""
              scheme == "http" and port == 80 -> ""
              true -> ":#{port}"
            end

          "#{scheme}://#{host}#{port_str}"

        _ ->
          "https://jobcelis.com"
      end

    legal = Application.get_env(:streamflix_web, :legal, []) |> Enum.into(%{})

    {:ok,
     assign(socket,
       page_title: gettext("Documentación"),
       meta_description:
         gettext(
           "Documentación completa de la API de Jobcelis: 98 endpoints, ejemplos curl, respuestas JSON, 12 SDKs + CLI."
         ),
       current_path: "/docs",
       base_url: base_url,
       sdk_languages: @sdk_languages,
       active_page: :docs,
       legal: legal
     )}
  end

  # ── Navigation structure ──────────────────────────────────────────────

  defp nav_groups do
    [
      %{
        id: "getting-started",
        title: gettext("Primeros pasos"),
        items: [
          %{id: "intro", label: gettext("Introducción")},
          %{id: "concepts", label: gettext("Conceptos básicos")},
          %{id: "quick-start", label: gettext("Inicio rápido")}
        ]
      },
      %{
        id: "configuration",
        title: gettext("Configuración"),
        items: [
          %{id: "base-url", label: "Base URL"},
          %{id: "auth", label: gettext("Autenticación")},
          %{id: "cors", label: "CORS"}
        ]
      },
      %{
        id: "api-reference",
        title: gettext("Referencia API"),
        items: [
          %{id: "auth-routes", label: gettext("Auth (registro/login)")},
          %{id: "events", label: gettext("Eventos")},
          %{id: "webhooks", label: "Webhooks"},
          %{id: "deliveries", label: gettext("Entregas")},
          %{id: "jobs", label: "Jobs"},
          %{id: "project-token", label: gettext("Proyecto y token")},
          %{id: "pipelines", label: "Pipelines"},
          %{id: "dead-letters", label: "Dead Letters"},
          %{id: "replays", label: gettext("Replays")},
          %{id: "event-schemas", label: gettext("Schemas")},
          %{id: "export", label: gettext("Exportar datos")}
        ]
      },
      %{
        id: "platform",
        title: gettext("Plataforma"),
        items: [
          %{id: "dashboard-overview", label: "Dashboard"},
          %{id: "account-management", label: gettext("Gestión de cuenta")},
          %{id: "password-recovery", label: gettext("Recuperar contraseña")},
          %{id: "multi-project", label: gettext("Multi-proyecto")},
          %{id: "teams", label: gettext("Equipos")},
          %{id: "sandbox", label: "Sandbox"},
          %{id: "analytics", label: gettext("Analíticas")},
          %{id: "audit-log", label: "Audit Log"},
          %{id: "realtime-stream", label: gettext("Streaming en tiempo real")}
        ]
      },
      %{
        id: "advanced",
        title: gettext("Avanzado"),
        items: [
          %{id: "topic-wildcards", label: "Topic Wildcards"},
          %{id: "delayed-events", label: gettext("Eventos diferidos")},
          %{id: "batch-events", label: "Batch Events"},
          %{id: "cursor-págination", label: gettext("Paginación cursor")},
          %{id: "webhook-templates", label: gettext("Plantillas webhook")},
          %{id: "ip-allowlist", label: "IP Allowlist"},
          %{id: "simulate", label: gettext("Simulador")},
          %{id: "idempotency-keys", label: gettext("Claves de idempotencia")},
          %{id: "external-alerts", label: gettext("Alertas externas")},
          %{id: "embed-portal", label: gettext("Portal embebible")},
          %{id: "rate-limiting-outbound", label: gettext("Rate limiting saliente")},
          %{id: "prometheus-metrics", label: gettext("Métricas Prometheus")},
          %{id: "webhook-testing", label: gettext("Testing de webhooks")},
          %{id: "data-retention", label: gettext("Retención de datos")}
        ]
      },
      %{
        id: "sdks-tools",
        title: gettext("SDKs y herramientas"),
        items: [
          %{id: "sdks", label: gettext("SDKs (12 lenguajes)")},
          %{id: "cli", label: "CLI"},
          %{id: "webhook-verification", label: gettext("Verificación de webhooks")}
        ]
      },
      %{
        id: "security",
        title: gettext("Seguridad y cumplimiento"),
        items: [
          %{id: "account-lockout", label: gettext("Bloqueo de cuenta")},
          %{id: "session-management", label: gettext("Gestión de sesiones")},
          %{id: "mfa-totp", label: "MFA / TOTP"},
          %{id: "password-policy", label: gettext("Política de contraseñas")},
          %{id: "data-encryption", label: gettext("Cifrado de datos")},
          %{id: "circuit-breaker", label: "Circuit Breaker"},
          %{id: "breach-detection", label: gettext("Detección de brechas")},
          %{id: "event-integrity", label: gettext("Integridad de eventos")},
          %{id: "uptime-monitoring", label: gettext("Monitoreo")},
          %{id: "backups", label: gettext("Backups")},
          %{id: "data-protection", label: gettext("GDPR / RGPD")},
          %{id: "consent-versióning", label: gettext("Consentimientos")}
        ]
      },
      %{
        id: "reference",
        title: gettext("Referencia"),
        items: [
          %{id: "status-codes", label: gettext("Códigos de respuesta")},
          %{id: "error-responses", label: gettext("Respuestas de error")},
          %{id: "response-headers", label: gettext("Headers de respuesta")},
          %{id: "health", label: "Health Check"},
          %{id: "api-key-scopes", label: gettext("Scopes de API Key")}
        ]
      }
    ]
  end

  # ── Render ────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :nav_groups, nav_groups())

    ~H"""
    <div class="min-h-screen bg-slate-50 dark:bg-slate-950 relative flex flex-col">
      <a href="#main-content" class="skip-link">{gettext("Saltar al contenido")}</a>
      <StreamflixWebWeb.Layouts.site_navbar
        current_user={@current_user}
        locale={@locale}
        active_page={@active_page}
      />

      <div class="flex-1 w-full max-w-[90rem] mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="flex w-full gap-6 lg:gap-10 min-w-0">
          <%!-- Desktop sidebar --%>
          <aside
            class="hidden lg:block w-64 shrink-0"
            aria-label={gettext("Navegación de la documentación")}
          >
            <nav
              id="docs-sidebar"
              class="sticky top-16 max-h-[calc(100vh-4rem)] overflow-y-auto space-y-1 text-sm bg-white/80 dark:bg-slate-900/80 backdrop-blur rounded-2xl border border-slate-200 dark:border-slate-700 shadow-sm p-4"
              phx-hook="DocsScrollSpy"
            >
              <div :for={group <- @nav_groups} class="mb-2">
                <details open>
                  <summary class="flex items-center justify-between cursor-pointer font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider text-xs px-2 py-2 hover:text-indigo-600 dark:hover:text-indigo-400 transition select-none list-none">
                    <span>{group.title}</span>
                    <svg
                      class="w-3.5 h-3.5 text-slate-400 transition-transform duration-200 details-chevron"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      stroke-width="2"
                    >
                      <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
                    </svg>
                  </summary>
                  <div class="space-y-0.5 mt-1">
                    <a
                      :for={item <- group.items}
                      href={"##{item.id}"}
                      id={"nav-#{item.id}"}
                      class="docs-nav-item block py-1.5 px-3 rounded-lg transition text-sm text-slate-600 dark:text-slate-400 hover:text-indigo-600 dark:hover:text-indigo-400 hover:bg-indigo-50 dark:hover:bg-indigo-950/40"
                    >
                      {item.label}
                    </a>
                  </div>
                </details>
              </div>
            </nav>
          </aside>

          <%!-- Mobile nav drawer --%>
          <div
            id="mobile-nav-overlay"
            class="fixed inset-0 z-50 lg:hidden hidden"
          >
            <div
              class="absolute inset-0 bg-slate-900/50 backdrop-blur-sm"
              phx-click={JS.hide(to: "#mobile-nav-overlay")}
            />
            <nav class="absolute left-0 top-0 bottom-0 w-[80vw] max-w-72 bg-white dark:bg-slate-900 shadow-2xl overflow-y-auto p-5 space-y-2">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-lg font-bold text-slate-900 dark:text-white">
                  {gettext("Navegación")}
                </h2>
                <button
                  phx-click={JS.hide(to: "#mobile-nav-overlay")}
                  class="p-1 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 text-slate-500 dark:text-slate-400"
                  aria-label={gettext("Cerrar navegación")}
                >
                  <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M6 18L18 6M6 6l12 12"
                    />
                  </svg>
                </button>
              </div>
              <div :for={group <- @nav_groups} class="mb-3">
                <p class="font-bold text-slate-700 dark:text-slate-300 uppercase tracking-wider text-xs px-2 py-1">
                  {group.title}
                </p>
                <div class="space-y-0.5 mt-1">
                  <a
                    :for={item <- group.items}
                    href={"##{item.id}"}
                    phx-click={JS.hide(to: "#mobile-nav-overlay")}
                    class="docs-nav-item block py-2 px-3 rounded-lg transition text-sm text-slate-600 dark:text-slate-400 hover:text-indigo-600 dark:hover:text-indigo-400 hover:bg-indigo-50 dark:hover:bg-indigo-950/40"
                  >
                    {item.label}
                  </a>
                </div>
              </div>
            </nav>
          </div>

          <%!-- Main content --%>
          <main
            id="main-content"
            class="docs-main min-w-0 flex-1 max-w-6xl overflow-x-auto"
            role="main"
            tabindex="-1"
            phx-hook="SdkSwitcher"
          >
            <.docs_header base_url={@base_url} />
            <SectionGettingStarted.render base_url={@base_url} />
            <SectionConfiguration.render base_url={@base_url} />
            <SectionApiReference.render base_url={@base_url} />
            <SectionPlatform.render base_url={@base_url} />
            <SectionAdvanced.render base_url={@base_url} />
            <SectionSdks.render sdk_languages={@sdk_languages} />
            <SectionSecurity.render base_url={@base_url} />
            <SectionReference.render base_url={@base_url} />
          </main>
        </div>
      </div>

      <%!-- Mobile FAB --%>
      <button
        phx-click={JS.toggle(to: "#mobile-nav-overlay")}
        class="fixed bottom-6 right-6 z-40 lg:hidden w-14 h-14 rounded-full bg-slate-800 dark:bg-slate-700 text-white shadow-lg hover:bg-slate-700 dark:hover:bg-slate-600 transition flex items-center justify-center"
        aria-label={gettext("Abrir navegación")}
      >
        <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M4 6h16M4 12h16M4 18h16" />
        </svg>
      </button>

      <StreamflixWebWeb.Layouts.site_footer locale={@locale} legal={@legal} />
      <StreamflixWebWeb.Layouts.cookie_banner />
    </div>
    """
  end

  # ── Header ────────────────────────────────────────────────────────────

  attr :base_url, :string, required: true

  defp docs_header(assigns) do
    ~H"""
    <header class="mb-10">
      <h1 class="text-4xl font-bold text-slate-900 tracking-tight mb-3">
        {gettext("Documentación de la API")}
      </h1>
      <p class="text-lg text-slate-600 leading-relaxed max-w-2xl">
        {gettext(
          "Referencia completa: rutas, autenticación, CORS, ejemplos y que probar en cada endpoint."
        )}
      </p>
      <div class="mt-6 flex flex-wrap gap-3">
        <a
          href="#quick-start"
          class="inline-flex items-center px-4 py-2 rounded-xl bg-indigo-600 text-white text-sm font-medium hover:bg-indigo-700 transition"
        >
          {gettext("Primeros pasos")}
        </a>
        <a
          href="#events"
          class="inline-flex items-center px-4 py-2 rounded-xl bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-600 text-slate-700 dark:text-slate-200 text-sm font-medium hover:bg-slate-50 dark:hover:bg-slate-700 transition"
        >
          {gettext("Eventos")}
        </a>
        <a
          href="#sdks"
          class="inline-flex items-center px-4 py-2 rounded-xl bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-600 text-slate-700 dark:text-slate-200 text-sm font-medium hover:bg-slate-50 dark:hover:bg-slate-700 transition"
        >
          SDKs
        </a>
      </div>
    </header>
    """
  end
end
