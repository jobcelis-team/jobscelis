defmodule StreamflixWebWeb.DocsLive do
  @moduledoc """
  Public documentation page as a LiveView.
  Features: scroll spy, SDK code switcher, collapsible sidebar, mobile drawer,
  copy-to-clipboard, bilingual (EN/ES), dark mode support.
  """
  use StreamflixWebWeb, :live_view

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
           "Documentación completa de la API de Jobcelis: 74 endpoints, ejemplos curl, respuestas JSON, 13 SDKs."
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
          %{id: "realtime-stream", label: "SSE Streaming"}
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
          %{id: "simulate", label: gettext("Simulador")}
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
          %{id: "session-management", label: gettext("Gestión de sesiónes")},
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
    <div class="min-h-screen bg-slate-50 relative flex flex-col">
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
              class="sticky top-16 max-h-[calc(100vh-4rem)] overflow-y-auto space-y-1 text-sm bg-white/80 backdrop-blur rounded-2xl border border-slate-200 shadow-sm p-4"
              phx-hook="DocsScrollSpy"
            >
              <div :for={group <- @nav_groups} class="mb-2">
                <details open>
                  <summary class="flex items-center justify-between cursor-pointer font-bold text-slate-700 uppercase tracking-wider text-xs px-2 py-2 hover:text-indigo-600 transition select-none list-none">
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
                      class="docs-nav-item block py-1.5 px-3 rounded-lg transition text-sm text-slate-600 hover:text-indigo-600 hover:bg-indigo-50"
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
            <nav class="absolute left-0 top-0 bottom-0 w-72 bg-white shadow-2xl overflow-y-auto p-5 space-y-2">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-lg font-bold text-slate-900">{gettext("Navegación")}</h2>
                <button
                  phx-click={JS.hide(to: "#mobile-nav-overlay")}
                  class="p-1 rounded-lg hover:bg-slate-100 text-slate-500"
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
                <p class="font-bold text-slate-700 uppercase tracking-wider text-xs px-2 py-1">
                  {group.title}
                </p>
                <div class="space-y-0.5 mt-1">
                  <a
                    :for={item <- group.items}
                    href={"##{item.id}"}
                    phx-click={JS.hide(to: "#mobile-nav-overlay")}
                    class="docs-nav-item block py-2 px-3 rounded-lg transition text-sm text-slate-600 hover:text-indigo-600 hover:bg-indigo-50"
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
            class="docs-main min-w-0 flex-1 max-w-4xl overflow-hidden"
            role="main"
            tabindex="-1"
            phx-hook="SdkSwitcher"
          >
            <.docs_header base_url={@base_url} />
            <.section_getting_started base_url={@base_url} />
            <.section_configuration base_url={@base_url} />
            <.section_api_reference base_url={@base_url} />
            <.section_platform base_url={@base_url} />
            <.section_advanced base_url={@base_url} />
            <.section_sdks sdk_languages={@sdk_languages} />
            <.section_security base_url={@base_url} />
            <.section_reference base_url={@base_url} />
          </main>
        </div>
      </div>

      <%!-- Mobile FAB --%>
      <button
        phx-click={JS.toggle(to: "#mobile-nav-overlay")}
        class="fixed bottom-6 right-6 z-40 lg:hidden w-14 h-14 rounded-full bg-indigo-600 text-white shadow-lg hover:bg-indigo-700 transition flex items-center justify-center"
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

  # ── Reusable Components ───────────────────────────────────────────────

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  slot :inner_block, required: true

  defp docs_section(assigns) do
    ~H"""
    <section id={@id} class="mb-14 scroll-mt-24">
      <div class="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
        <div class="px-8 py-6 border-b border-slate-200 bg-slate-50/80">
          <h2 class="text-2xl font-bold text-slate-900">{@title}</h2>
          <p :if={assigns[:subtitle]} class="text-slate-600 mt-1 text-sm">{@subtitle}</p>
        </div>
        <div class="p-8 space-y-6">
          {render_slot(@inner_block)}
        </div>
      </div>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :method, :string, required: true
  attr :path, :string, required: true
  attr :description, :string, default: nil
  slot :inner_block

  defp api_endpoint(assigns) do
    ~H"""
    <div id={@id} class="rounded-xl border border-slate-200 bg-slate-50/50 p-6 scroll-mt-24">
      <div class="flex flex-wrap items-center gap-2 mb-3">
        <span class={[
          "inline-flex px-2.5 py-1 rounded-lg text-xs font-bold text-white",
          method_color(@method)
        ]}>
          {@method}
        </span>
        <code class="font-mono text-slate-800 font-medium text-sm">{@path}</code>
      </div>
      <p :if={assigns[:description]} class="text-slate-600 text-sm mb-4">{@description}</p>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :code, :string, required: true
  attr :copy_id, :string, required: true
  attr :title, :string, default: nil

  defp code_block(assigns) do
    assigns = assign_new(assigns, :title, fn -> nil end)

    ~H"""
    <div class="relative group">
      <p :if={@title} class="text-slate-500 text-xs font-medium uppercase tracking-wider mb-2">
        {@title}
      </p>
      <div class="relative">
        <pre class="bg-slate-900 text-slate-100 rounded-lg p-4 text-xs overflow-x-auto font-mono"><code>{@code}</code></pre>
        <button
          phx-hook="CopyCode"
          id={@copy_id}
          data-code={@code}
          class="absolute top-2 right-2 p-1.5 rounded-md bg-slate-700/50 hover:bg-slate-600 text-slate-300 hover:text-white opacity-0 group-hover:opacity-100 transition"
          aria-label={gettext("Copiar código")}
        >
          <svg data-copy-icon class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"
            />
          </svg>
          <svg
            data-check-icon
            class="w-4 h-4 hidden text-emerald-400"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M5 13l4 4L19 7"
            />
          </svg>
        </button>
      </div>
    </div>
    """
  end

  attr :kind, :string, default: "info"
  slot :inner_block, required: true

  defp callout(assigns) do
    color_map = %{
      "info" => "bg-blue-50 border-blue-200 text-blue-800",
      "warning" => "bg-amber-50 border-amber-200 text-amber-800",
      "tip" => "bg-emerald-50 border-emerald-200 text-emerald-800",
      "danger" => "bg-red-50 border-red-200 text-red-800"
    }

    assigns = assign(assigns, :colors, Map.get(color_map, assigns.kind, color_map["info"]))

    ~H"""
    <div class={"rounded-xl border p-4 text-sm #{@colors}"}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :curl, :string, required: true
  attr :id, :string, required: true

  defp curl_block(assigns) do
    ~H"""
    <.code_block code={@curl} copy_id={@id} title="curl" />
    """
  end

  defp method_color("GET"), do: "bg-emerald-600"
  defp method_color("POST"), do: "bg-blue-600"
  defp method_color("PATCH"), do: "bg-amber-600"
  defp method_color("PUT"), do: "bg-amber-600"
  defp method_color("DELETE"), do: "bg-red-600"
  defp method_color(_), do: "bg-slate-600"

  # ── SDK Code Block Component ──────────────────────────────────────────

  attr :sdk_languages, :list, required: true
  attr :example, :string, default: "send_event"

  defp sdk_code_block(assigns) do
    ~H"""
    <div class="rounded-xl border border-slate-200 overflow-hidden">
      <%!-- Language tabs --%>
      <div class="flex overflow-x-auto bg-slate-100 border-b border-slate-200 px-2 py-1 gap-1">
        <button
          :for={lang <- @sdk_languages}
          data-sdk-lang={lang}
          class={[
            "sdk-tab px-3 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap transition",
            if(lang == "nodejs",
              do: "bg-white text-indigo-700 shadow-sm",
              else: "text-slate-600 hover:text-slate-900 hover:bg-white/50"
            )
          ]}
        >
          {sdk_label(lang)}
        </button>
      </div>
      <%!-- Code content for each language (hidden by default except nodejs) --%>
      <div
        :for={lang <- @sdk_languages}
        data-sdk-panel={lang}
        class={if(lang != "nodejs", do: "hidden")}
      >
        <div class="p-4 bg-slate-900">
          <p class="text-slate-400 text-xs mb-2 font-mono">{gettext("Instalar:")}</p>
          <pre class="text-slate-100 text-xs overflow-x-auto font-mono mb-4"><code>{sdk_install(lang)}</code></pre>
          <p class="text-slate-400 text-xs mb-2 font-mono">{gettext("Uso:")}</p>
          <pre class="text-slate-100 text-xs overflow-x-auto font-mono"><code>{sdk_usage(lang, @example)}</code></pre>
        </div>
      </div>
    </div>
    """
  end

  defp sdk_label("nodejs"), do: "Node.js"
  defp sdk_label("python"), do: "Python"
  defp sdk_label("go"), do: "Go"
  defp sdk_label("php"), do: "PHP"
  defp sdk_label("ruby"), do: "Ruby"
  defp sdk_label("elixir"), do: "Elixir"
  defp sdk_label("dotnet"), do: ".NET"
  defp sdk_label("rust"), do: "Rust"
  defp sdk_label("swift"), do: "Swift"
  defp sdk_label("java"), do: "Java"
  defp sdk_label("dart"), do: "Dart"
  defp sdk_label("kotlin"), do: "Kotlin"

  attr :label, :string, required: true
  attr :registry, :string, required: true
  attr :url, :string, required: true

  defp sdk_link(assigns) do
    ~H"""
    <a
      href={@url}
      target="_blank"
      rel="noopener"
      class="group flex items-center gap-2 px-3 py-2.5 rounded-lg border border-slate-200 bg-slate-50 hover:bg-indigo-50 hover:border-indigo-300 transition"
    >
      <span class="font-semibold text-indigo-600 group-hover:text-indigo-700">{@label}</span>
      <span class="text-xs text-slate-400 group-hover:text-indigo-400">{@registry}</span>
      <svg
        class="w-3.5 h-3.5 ml-auto text-slate-300 group-hover:text-indigo-500 transition"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
        stroke-width="2"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
        />
      </svg>
    </a>
    """
  end

  defp sdk_install("nodejs"), do: "npm install @jobcelis/sdk"
  defp sdk_install("python"), do: "pip install jobcelis"
  defp sdk_install("go"), do: "go get github.com/vladimirCeli/go-jobcelis"
  defp sdk_install("php"), do: "composer require jobcelis/sdk"
  defp sdk_install("ruby"), do: "gem install jobcelis"
  defp sdk_install("elixir"), do: ~s|{:jobcelis, "~> 1.0"}  # add to mix.exs deps|
  defp sdk_install("dotnet"), do: "dotnet add package Jobcelis"
  defp sdk_install("rust"), do: ~s|cargo add jobcelis|

  defp sdk_install("swift"),
    do:
      ~s|// Swift Package Manager\n.package(url: "https://github.com/vladimirCeli/jobcelis-swift", from: "1.0.0")|

  defp sdk_install("java"),
    do:
      ~s|<!-- Maven -->\n<dependency>\n  <groupId>com.jobcelis</groupId>\n  <artifactId>jobcelis</artifactId>\n  <versión>1.0.0</versión>\n</dependency>|

  defp sdk_install("dart"), do: ~s|dart pub add jobcelis|
  defp sdk_install("kotlin"), do: ~s|implementation("com.jobcelis:jobcelis:1.0.0")|

  defp sdk_usage("nodejs", "send_event") do
    ~s|const { JobcelisClient } = require('@jobcelis/sdk');

const client = new JobcelisClient({ apiKey: 'YOUR_API_KEY' });

await client.sendEvent({
  topic: 'order.created',
  payload: { order_id: '12345', amount: 99.99 },
});|
  end

  defp sdk_usage("python", "send_event") do
    ~s|from jobcelis import JobcelisClient

client = JobcelisClient(api_key="YOUR_API_KEY")

client.send_event("order.created", {"order_id": "12345", "amount": 99.99})|
  end

  defp sdk_usage("go", "send_event") do
    ~s|client := jobcelis.NewClient("YOUR_API_KEY")

resp, err := client.SendEvent(ctx, jobcelis.EventRequest{
    Topic:   "order.created",
    Payload: map[string]interface{}{"order_id": "12345", "amount": 99.99},
})|
  end

  defp sdk_usage("php", "send_event") do
    ~s|use Jobcelis\\JobcelisClient;

$client = new JobcelisClient('YOUR_API_KEY');

$response = $client->sendEvent([
    'topic' => 'order.created',
    'payload' => ['order_id' => '12345', 'amount' => 99.99],
]);|
  end

  defp sdk_usage("ruby", "send_event") do
    ~s|require 'jobcelis'

client = Jobcelis::Client.new(api_key: 'YOUR_API_KEY')

response = client.send_event(
  topic: 'order.created',
  payload: { order_id: '12345', amount: 99.99 }
)|
  end

  defp sdk_usage("elixir", "send_event") do
    ~s|client = Jobcelis.client(api_key: "YOUR_API_KEY")

{:ok, event} = Jobcelis.send_event(client,
  topic: "order.created",
  payload: %{order_id: "12345", amount: 99.99}
)|
  end

  defp sdk_usage("dotnet", "send_event") do
    ~s|using Jobcelis;

var client = new JobcelisClient("YOUR_API_KEY");

var response = await client.SendEventAsync(new {
    topic = "order.created",
    payload = new { order_id = "12345", amount = 99.99 }
});|
  end

  defp sdk_usage("rust", "send_event") do
    ~s|use jobcelis::JobcelisClient;

let client = JobcelisClient::new("YOUR_API_KEY");

let response = client.send_event(
    "order.created",
    serde_json::json!({"order_id": "12345", "amount": 99.99})
).await?;|
  end

  defp sdk_usage("swift", "send_event") do
    ~s|import Jobcelis

let client = JobcelisClient(apiKey: "YOUR_API_KEY")

let response = try await client.sendEvent(
    topic: "order.created",
    payload: ["order_id": "12345", "amount": 99.99]
)|
  end

  defp sdk_usage("java", "send_event") do
    ~s|import com.jobcelis.JobcelisClient;

JobcelisClient client = new JobcelisClient("YOUR_API_KEY");

JsonObject response = client.sendEvent(
    "order.created",
    Map.of("order_id", "12345", "amount", 99.99)
);|
  end

  defp sdk_usage("dart", "send_event") do
    ~s|import 'package:jobcelis/jobcelis.dart';

final client = JobcelisClient(apiKey: 'YOUR_API_KEY');

final response = await client.sendEvent(
  topic: 'order.created',
  payload: {'order_id': '12345', 'amount': 99.99},
);|
  end

  defp sdk_usage("kotlin", "send_event") do
    ~s|import com.jobcelis.JobcelisClient

val client = JobcelisClient("YOUR_API_KEY")

val response = client.sendEvent(
    topic = "order.created",
    payload = mapOf("order_id" to "12345", "amount" to 99.99)
)|
  end

  defp sdk_usage("nodejs", "verify_webhook") do
    ~s|const crypto = require('crypto');

function verifySignature(secret, body, signature) {
  if (!signature.startsWith('sha256=')) return false;
  const received = signature.slice(7);
  const expected = crypto
    .createHmac('sha256', secret)
    .update(body)
    .digest('base64')
    .replace(/=+$/, '');
  const a = Buffer.from(received, 'base64');
  const b = Buffer.from(expected, 'base64');
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}|
  end

  defp sdk_usage("python", "verify_webhook") do
    ~s|import base64, hashlib, hmac

def verify_signature(secret, body, signature):
    if not signature.startswith('sha256='):
        return False
    received = signature[7:]
    expected = base64.b64encode(
        hmac.new(secret.encode(), body.encode(), hashlib.sha256).digest()
    ).rstrip(b'=').decode()
    return hmac.compare_digest(received, expected)|
  end

  defp sdk_usage("go", "verify_webhook") do
    ~s|import (
    "crypto/hmac"
    "crypto/sha256"
    "encoding/base64"
    "strings"
)

func VerifySignature(secret, body, signature string) bool {
    if !strings.HasPrefix(signature, "sha256=") {
        return false
    }
    received := signature[7:]
    mac := hmac.New(sha256.New, []byte(secret))
    mac.Write([]byte(body))
    expected := base64.RawStdEncoding.EncodeToString(mac.Sum(nil))
    return hmac.Equal([]byte(received), []byte(expected))
}|
  end

  defp sdk_usage(_, "verify_webhook") do
    ~s|// See the SDK documentation for your language's
// webhook verification implementation.
// All SDKs provide a verifySignature() helper.|
  end

  defp sdk_usage(_, _), do: "// See SDK documentation for usage"

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
          class="inline-flex items-center px-4 py-2 rounded-xl bg-white border border-slate-300 text-slate-700 text-sm font-medium hover:bg-slate-50 transition"
        >
          {gettext("Eventos")}
        </a>
        <a
          href="#sdks"
          class="inline-flex items-center px-4 py-2 rounded-xl bg-white border border-slate-300 text-slate-700 text-sm font-medium hover:bg-slate-50 transition"
        >
          SDKs
        </a>
      </div>
    </header>
    """
  end

  attr :base_url, :string, required: true

  # ══════════════════════════════════════════════════════════════════════
  # SECTION 1: GETTING STARTED
  # ══════════════════════════════════════════════════════════════════════

  defp section_getting_started(assigns) do
    ~H"""
    <%!-- Introduction --%>
    <.docs_section
      id="intro"
      title={gettext("Introducción")}
      subtitle={gettext("Qué es Jobcelis y que puedes hacer con la API.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "Jobcelis es una plataforma de eventos y webhooks 100%% configurable. Envía cualquier JSON desde tu código; nosotros enrutamos, filtramos, transformamos y entregamos a tus URLs. Sin esquemas fijos: tu defines topics, payloads y reglas."
        )}
      </p>
      <div class="grid sm:grid-cols-2 gap-4">
        <div class="rounded-xl bg-slate-50 border border-slate-200 p-4">
          <h3 class="font-semibold text-slate-900 mb-2 text-sm">
            {gettext("Capacidades principales")}
          </h3>
          <ul class="text-slate-600 text-sm space-y-1.5">
            <li>
              <strong>{gettext("Eventos:")}</strong> {gettext(
                "envía JSON con topic opcional via POST. Sin esquemas fijos."
              )}
            </li>
            <li>
              <strong>Webhooks:</strong> {gettext(
                "URLs de destino, filtros (topic, amount, status), body_config (full, pick, rename, extra)."
              )}
            </li>
            <li>
              <strong>{gettext("Entregas:")}</strong> {gettext(
                "reintentos automáticos con backoff exponencial."
              )}
            </li>
            <li>
              <strong>Jobs:</strong> {gettext(
                "daily, weekly, monthly o cron. Emitir evento o POST a URL."
              )}
            </li>
            <li><strong>Topics:</strong> {gettext("etiquetas para filtrar y organizar eventos.")}</li>
          </ul>
        </div>
        <div class="rounded-xl bg-slate-50 border border-slate-200 p-4">
          <h3 class="font-semibold text-slate-900 mb-2 text-sm">{gettext("Grupos de rutas")}</h3>
          <ul class="text-slate-600 text-sm space-y-1.5">
            <li>
              <strong>{gettext("Rutas publicas:")}</strong> {gettext(
                "registro, login, refresh JWT. Sin API Key."
              )}
            </li>
            <li>
              <strong>{gettext("Rutas con API Key:")}</strong> {gettext(
                "eventos, webhooks, deliveries, jobs, proyecto. Token en Dashboard."
              )}
            </li>
          </ul>
          <p class="text-slate-500 text-xs mt-3">
            {gettext("Respuestas en JSON. CORS habilitado. Payload máximo 256 KB.")}
          </p>
        </div>
      </div>
    </.docs_section>

    <%!-- Core Concepts --%>
    <.docs_section
      id="concepts"
      title={gettext("Conceptos básicos")}
      subtitle={gettext("Estos son los conceptos que necesitas para usar Jobcelis.")}
    >
      <div class="space-y-6">
        <div class="rounded-xl border border-slate-200 border-l-4 border-l-indigo-500 bg-slate-50/50 p-6">
          <h3 class="text-lg font-semibold text-slate-900 mb-3">{gettext("Qué es un evento?")}</h3>
          <p class="text-slate-700 leading-relaxed mb-4">
            {gettext(
              "Un evento es un mensaje JSON que envías a Jobcelis desde tu aplicación (con un POST). Puede ser cualquier JSON: un pedido, un pago, un registro, etc. Opcionalmente le pones un topic para clasificarlo. Jobcelis guarda el evento y segun los webhooks que tengas configurados, envía esa información a las URLs que tu indiques."
            )}
          </p>
          <.code_block
            code={~s|{"topic": "order.created", "order_id": 123, "total": 99.99}|}
            copy_id="copy-event-example"
            title={gettext("Ejemplo")}
          />
        </div>

        <div class="rounded-xl border border-slate-200 border-l-4 border-l-indigo-500 bg-slate-50/50 p-6">
          <h3 class="text-lg font-semibold text-slate-900 mb-3">{gettext("Qué es un webhook?")}</h3>
          <p class="text-slate-700 leading-relaxed">
            {gettext(
              "Un webhook es una URL de destino que tu configuras. Cuando llega un evento que cumple las condiciones (topic, filtros), Jobcelis hace un POST a esa URL con los datos que tu eliges."
            )}
          </p>
        </div>

        <div class="rounded-xl border border-slate-200 border-l-4 border-l-indigo-500 bg-slate-50/50 p-6">
          <h3 class="text-lg font-semibold text-slate-900 mb-3">
            {gettext("Qué es una entrega (delivery)?")}
          </h3>
          <p class="text-slate-700 leading-relaxed">
            {gettext(
              "Cada vez que Jobcelis intenta enviar un evento a una URL de webhook, se crea una entrega. Esa entrega tiene un estado: pendiente, éxito o fallo. Si falla, Jobcelis reintenta automáticamente con backoff exponencial."
            )}
          </p>
        </div>

        <div class="rounded-xl border border-slate-200 border-l-4 border-l-indigo-500 bg-slate-50/50 p-6">
          <h3 class="text-lg font-semibold text-slate-900 mb-3">{gettext("Qué es un job?")}</h3>
          <p class="text-slate-700 leading-relaxed">
            {gettext(
              "Un job es una tarea programada: daily, weekly, monthly o cron. Cuando se ejecuta, puede emitir un evento interno o hacer un POST a una URL externa."
            )}
          </p>
        </div>

        <div class="rounded-xl border border-slate-200 border-l-4 border-l-indigo-500 bg-slate-50/50 p-6">
          <h3 class="text-lg font-semibold text-slate-900 mb-3">{gettext("Qué es un topic?")}</h3>
          <p class="text-slate-700 leading-relaxed">
            {gettext(
              "El topic es una etiqueta opcional para clasificar eventos (ej. order.created, payment.completed). Sirve para filtrar en webhooks. Tu inventas los nombres."
            )}
          </p>
        </div>
      </div>
    </.docs_section>

    <%!-- Quick Start --%>
    <.docs_section
      id="quick-start"
      title={gettext("Inicio rápido")}
      subtitle={gettext("Sigue estos pasos para tener todo funcionando en pocos minutos.")}
    >
      <div class="space-y-6">
        <.quick_start_step
          number={1}
          title={gettext("Regístrate e inicia sesión")}
          description={
            gettext("En la web, regístrate con tu email y contraseña. Entra al Dashboard.")
          }
        />
        <.quick_start_step
          number={2}
          title={gettext("Copia tu API Token")}
          description={
            gettext(
              "En el Dashboard, sección API Token, verás el token. Guárdalo; lo usarás en todas las peticiones con header Authorization: Bearer TU_TOKEN o X-Api-Key: TU_TOKEN."
            )
          }
        />
        <.quick_start_step number={3} title={gettext("Envía tu primer evento")}>
          <p class="text-slate-600 text-sm leading-relaxed mb-3">
            {gettext("Desde tu código o con curl: POST /api/v1/events con body JSON.")}
          </p>
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/events\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"topic\":\"test\",\"message\":\"Hello\"}'"}
            copy_id="copy-quickstart-curl"
          />
        </.quick_start_step>
        <.quick_start_step
          number={4}
          title={gettext("Crea un webhook")}
          description={
            gettext(
              "En el Dashboard, Webhooks > Crear. Pon una URL que pueda recibir POST. Opcional: elige un topic para filtrar."
            )
          }
        />
        <.quick_start_step
          number={5}
          title={gettext("Crea un job (opcional)")}
          description={
            gettext(
              "En el Dashboard, Jobs > Crear. Elige programacion y accion (emitir evento o POST a URL)."
            )
          }
          last={true}
        />

        <.callout kind="warning">
          {gettext(
            "Si algo falla, revisa que el token este bien en el header y que la URL del webhook sea accesible. Las entregas fallidas se pueden reintentar desde el Dashboard."
          )}
        </.callout>
      </div>
    </.docs_section>
    """
  end

  attr :number, :integer, required: true
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :last, :boolean, default: false
  slot :inner_block

  defp quick_start_step(assigns) do
    assigns =
      assigns
      |> assign_new(:description, fn -> nil end)
      |> assign_new(:last, fn -> false end)

    ~H"""
    <div class="flex gap-4 rounded-xl border border-slate-200 bg-white p-5 hover:border-indigo-200 transition">
      <span class={[
        "flex-shrink-0 w-10 h-10 rounded-full font-bold flex items-center justify-center text-lg",
        if(@last, do: "bg-slate-100 text-slate-600", else: "bg-indigo-100 text-indigo-700")
      ]}>
        {@number}
      </span>
      <div class="min-w-0 flex-1">
        <h3 class="font-semibold text-slate-900 mb-1">{@title}</h3>
        <p :if={@description} class="text-slate-600 text-sm leading-relaxed">{@description}</p>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # ══════════════════════════════════════════════════════════════════════
  # SECTION 2: CONFIGURATION
  # ══════════════════════════════════════════════════════════════════════

  attr :base_url, :string, required: true

  defp section_configuration(assigns) do
    ~H"""
    <.docs_section
      id="base-url"
      title="Base URL"
      subtitle={gettext("Todos los ejemplos usan la base URL actual:")}
    >
      <.code_block code={@base_url} copy_id="copy-base-url" />
      <p class="text-slate-600 text-sm mt-2">
        {gettext(
          "En producción la base URL será tu dominio. Los ejemplos curl ya incluyen esta base."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="auth"
      title={gettext("Autenticación")}
      subtitle={gettext("Como enviar el API Key o usar JWT en las peticiones.")}
    >
      <div>
        <h3 class="text-lg font-semibold text-slate-900 mb-3">{gettext("Rutas con API Key")}</h3>
        <p class="text-slate-600 mb-3">{gettext("Puedes enviar el token de tres maneras:")}</p>
        <ol class="list-decimal list-inside text-slate-700 space-y-2 mb-3">
          <li>
            {gettext("Header")}
            <code class="bg-slate-100 px-2 py-1 rounded font-mono text-sm">
              Authorization: Bearer &lt;token&gt;
            </code>
          </li>
          <li>
            {gettext("Header")}
            <code class="bg-slate-100 px-2 py-1 rounded font-mono text-sm">
              X-Api-Key: &lt;token&gt;
            </code>
          </li>
          <li>
            {gettext("Query param")}
            <code class="bg-slate-100 px-2 py-1 rounded font-mono text-sm">
              ?api_key=&lt;token&gt;
            </code>
          </li>
        </ol>
        <p class="text-slate-600 text-sm">
          {gettext(
            "El token se obtiene en el Dashboard (sección API Token). El valor completo solo se muestra una vez; guárdalo."
          )}
        </p>
      </div>
      <div class="border-t border-slate-200 pt-6">
        <h3 class="text-lg font-semibold text-slate-900 mb-3">{gettext("Rutas publicas (Auth)")}</h3>
        <p class="text-slate-600 text-sm">
          {gettext("No envies API Key. Registro y login devuelven un JWT para usar en tu app.")}
        </p>
      </div>
    </.docs_section>

    <.docs_section
      id="cors"
      title="CORS"
      subtitle={gettext("Uso de la API desde el navegador u otros origenes.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "La API tiene CORS habilitado para cualquier origen (Access-Control-Allow-Origin: *). Cualquier frontend puede consumir la API sin bloqueos del navegador."
        )}
      </p>
      <div class="rounded-xl bg-slate-50 border border-slate-200 p-4">
        <p class="font-medium text-slate-800 mb-2 text-sm">{gettext("Headers permitidos:")}</p>
        <ul class="text-slate-600 text-sm space-y-1">
          <li>
            <code class="bg-white px-1.5 py-0.5 rounded border border-slate-200 font-mono">
              Authorization
            </code>
          </li>
          <li>
            <code class="bg-white px-1.5 py-0.5 rounded border border-slate-200 font-mono">
              X-Api-Key
            </code>
          </li>
          <li>
            <code class="bg-white px-1.5 py-0.5 rounded border border-slate-200 font-mono">Content-Type</code>,
            <code class="bg-white px-1.5 py-0.5 rounded border border-slate-200 font-mono">
              Accept
            </code>
          </li>
        </ul>
      </div>
      <p class="text-slate-500 text-sm">
        {gettext("Métodos: GET, POST, PUT, PATCH, DELETE, OPTIONS.")}
      </p>
    </.docs_section>
    """
  end

  attr :base_url, :string, required: true

  # ══════════════════════════════════════════════════════════════════════
  # SECTION 3: API REFERENCE
  # ══════════════════════════════════════════════════════════════════════

  defp section_api_reference(assigns) do
    ~H"""
    <%!-- Auth Routes --%>
    <.docs_section
      id="auth-routes"
      title={gettext("Auth (registro/login)")}
      subtitle={gettext("Rutas publicas sin API Key. Body y respuesta en JSON.")}
    >
      <div class="space-y-6">
        <.api_endpoint
          id="auth-register"
          method="POST"
          path="/api/v1/auth/register"
          description={gettext("Crea una cuenta nueva.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/auth/register\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"name\":\"Test\",\"email\":\"test@example.com\",\"password\":\"SecurePass123!\"}'"}
            copy_id="copy-auth-register"
          />
          <.code_block
            code={
              ~s|// Response (201 Created)\n{\n  "user": {\n    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "email": "test@example.com",\n    "name": "Test"\n  },\n  "token": "eyJhbGciOiJIUzI1NiIs...",\n  "api_key": "jc_live_a1b2c3d4e5f6..."\n}|
            }
            copy_id="copy-auth-register-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>

        <.api_endpoint
          id="auth-login"
          method="POST"
          path="/api/v1/auth/login"
          description={gettext("Inicia sesión y obtiene JWT.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/auth/login\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"email\":\"test@example.com\",\"password\":\"SecurePass123!\"}'"}
            copy_id="copy-auth-login"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "user": {\n    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "email": "test@example.com",\n    "name": "Test"\n  },\n  "token": "eyJhbGciOiJIUzI1NiIs..."\n}\n\n// If MFA is enabled:\n{\n  "mfa_required": true,\n  "mfa_token": "eyJhbGciOiJIUzI1NiIs..."\n}|
            }
            copy_id="copy-auth-login-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>

        <.api_endpoint
          id="auth-refresh"
          method="POST"
          path="/api/v1/auth/refresh"
          description={gettext("Renueva un JWT.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/auth/refresh\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"token\":\"YOUR_JWT\"}'"}
            copy_id="copy-auth-refresh"
          />
          <.code_block
            code={~s|// Response (200 OK)\n{\n  "token": "eyJhbGciOiJIUzI1NiIs..."\n}|}
            copy_id="copy-auth-refresh-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>

        <.api_endpoint
          id="auth-mfa"
          method="POST"
          path="/api/v1/auth/mfa/verify"
          description={gettext("Verifica código MFA después del login.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/auth/mfa/verify\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"mfa_token\":\"TEMP_TOKEN\",\"code\":\"123456\"}'"}
            copy_id="copy-auth-mfa"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "user": {\n    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "email": "test@example.com",\n    "name": "Test"\n  },\n  "token": "eyJhbGciOiJIUzI1NiIs..."\n}|
            }
            copy_id="copy-auth-mfa-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <%!-- Events --%>
    <.docs_section
      id="events"
      title={gettext("Eventos")}
      subtitle={gettext("Enviar, listar y gestiónar eventos.")}
    >
      <div class="space-y-6">
        <.api_endpoint
          id="events-create"
          method="POST"
          path="/api/v1/events"
          description={gettext("Envía un nuevo evento.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/events\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"topic\":\"order.created\",\"order_id\":\"12345\",\"amount\":99.99}'"}
            copy_id="copy-events-create"
          />
          <.code_block
            code={
              ~s|// Response (202 Accepted)\n{\n  "event_id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",\n  "payload_hash": "sha256:a3f2b8c1d4e5..."\n}|
            }
            copy_id="copy-events-create-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>

        <.api_endpoint
          id="events-list"
          method="GET"
          path="/api/v1/events"
          description={gettext("Lista eventos con paginación.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/events?limit=10\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-events-list"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "events": [\n    {\n      "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",\n      "topic": "order.created",\n      "payload": {"order_id": "12345", "amount": 99.99},\n      "status": "active",\n      "occurred_at": "2026-01-15T10:30:00Z",\n      "deliver_at": null,\n      "payload_hash": "sha256:a3f2b8c1d4e5...",\n      "idempotency_key": null,\n      "inserted_at": "2026-01-15T10:30:00Z"\n    }\n  ],\n  "has_next": true,\n  "next_cursor": "c3d4e5f6-a7b8-9012-cdef-123456789012"\n}|
            }
            copy_id="copy-events-list-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>

        <.api_endpoint
          id="events-show"
          method="GET"
          path="/api/v1/events/:id"
          description={gettext("Detalle de un evento.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/events/EVENT_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-events-show"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",\n  "topic": "order.created",\n  "payload": {"order_id": "12345", "amount": 99.99},\n  "status": "active",\n  "occurred_at": "2026-01-15T10:30:00Z",\n  "deliver_at": null,\n  "payload_hash": "sha256:a3f2b8c1d4e5...",\n  "idempotency_key": null,\n  "inserted_at": "2026-01-15T10:30:00Z",\n  "deliveries": [\n    {"id": "d4e5f6a7-b8c9-0123-defg-234567890123", "status": "success", "attempt_number": 1}\n  ]\n}|
            }
            copy_id="copy-events-show-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>

        <.api_endpoint
          id="events-delete"
          method="DELETE"
          path="/api/v1/events/:id"
          description={gettext("Elimina un evento.")}
        >
          <.code_block
            code={"curl -X DELETE \"#{@base_url}/api/v1/events/EVENT_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-events-delete"
          />
          <.code_block
            code={~s|// Response (200 OK)\n{\n  "status": "inactive"\n}|}
            copy_id="copy-events-delete-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <%!-- Webhooks --%>
    <.docs_section
      id="webhooks"
      title="Webhooks"
      subtitle={gettext("Crear, listar y gestiónar webhooks.")}
    >
      <div class="space-y-6">
        <.api_endpoint
          id="webhooks-list"
          method="GET"
          path="/api/v1/webhooks"
          description={gettext("Lista webhooks del proyecto.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/webhooks\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-webhooks-list"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "webhooks": [\n    {\n      "id": "c3d4e5f6-a7b8-9012-cdef-123456789012",\n      "url": "https://example.com/hook",\n      "status": "active",\n      "topics": ["order.*"],\n      "filters": [],\n      "body_config": {},\n      "headers": {},\n      "retry_config": {},\n      "inserted_at": "2026-01-10T08:00:00Z"\n    }\n  ]\n}|
            }
            copy_id="copy-webhooks-list-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>

        <.api_endpoint
          id="webhooks-create"
          method="POST"
          path="/api/v1/webhooks"
          description={gettext("Crea un webhook nuevo.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/webhooks\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"url\":\"https://example.com/hook\",\"topics\":[\"order.*\"]}'"}
            copy_id="copy-webhooks-create"
          />
          <.code_block
            code={
              ~s|// Response (201 Created)\n{\n  "id": "c3d4e5f6-a7b8-9012-cdef-123456789012",\n  "url": "https://example.com/hook",\n  "status": "active",\n  "topics": ["order.*"],\n  "filters": [],\n  "body_config": {},\n  "headers": {},\n  "retry_config": {},\n  "inserted_at": "2026-01-10T08:00:00Z"\n}|
            }
            copy_id="copy-webhooks-create-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>

        <.api_endpoint
          id="webhooks-show"
          method="GET"
          path="/api/v1/webhooks/:id"
          description={gettext("Detalle de un webhook.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/webhooks/WEBHOOK_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-webhooks-show"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "id": "c3d4e5f6-a7b8-9012-cdef-123456789012",\n  "url": "https://example.com/hook",\n  "status": "active",\n  "topics": ["order.*"],\n  "filters": [],\n  "body_config": {},\n  "headers": {},\n  "retry_config": {},\n  "inserted_at": "2026-01-10T08:00:00Z"\n}|
            }
            copy_id="copy-webhooks-show-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>

        <.api_endpoint
          id="webhooks-update"
          method="PATCH"
          path="/api/v1/webhooks/:id"
          description={gettext("Actualiza un webhook.")}
        >
          <.code_block
            code={"curl -X PATCH \"#{@base_url}/api/v1/webhooks/WEBHOOK_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"active\":false}'"}
            copy_id="copy-webhooks-update"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "id": "c3d4e5f6-a7b8-9012-cdef-123456789012",\n  "url": "https://example.com/hook",\n  "status": "active",\n  "topics": ["order.*"],\n  "filters": [],\n  "body_config": {},\n  "headers": {},\n  "retry_config": {},\n  "inserted_at": "2026-01-10T08:00:00Z"\n}|
            }
            copy_id="copy-webhooks-update-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>

        <.api_endpoint
          id="webhooks-delete"
          method="DELETE"
          path="/api/v1/webhooks/:id"
          description={gettext("Elimina un webhook.")}
        >
          <.code_block
            code={"curl -X DELETE \"#{@base_url}/api/v1/webhooks/WEBHOOK_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-webhooks-delete"
          />
          <.code_block
            code={~s|// Response (200 OK)\n{\n  "status": "inactive"\n}|}
            copy_id="copy-webhooks-delete-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <%!-- Deliveries --%>
    <.docs_section
      id="deliveries"
      title={gettext("Entregas")}
      subtitle={gettext("Historial de entregas y reintentos.")}
    >
      <div class="space-y-6">
        <.api_endpoint
          id="deliveries-list"
          method="GET"
          path="/api/v1/deliveries"
          description={gettext("Lista entregas con filtros opcionales.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/deliveries?status=failed&limit=10\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-deliveries-list"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "deliveries": [\n    {\n      "id": "d4e5f6a7-b8c9-0123-defg-234567890123",\n      "event_id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",\n      "webhook_id": "c3d4e5f6-a7b8-9012-cdef-123456789012",\n      "status": "failed",\n      "attempt_number": 3,\n      "response_status": 500,\n      "next_retry_at": "2026-01-15T11:00:00Z",\n      "inserted_at": "2026-01-15T10:30:00Z"\n    }\n  ],\n  "has_next": false,\n  "next_cursor": null\n}|
            }
            copy_id="copy-deliveries-list-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>

        <.api_endpoint
          id="deliveries-retry"
          method="POST"
          path="/api/v1/deliveries/:id/retry"
          description={gettext("Reintenta una entrega fallida.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/deliveries/DELIVERY_ID/retry\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-deliveries-retry"
          />
          <.code_block
            code={~s|// Response (200 OK)\n{\n  "status": "retry_queued"\n}|}
            copy_id="copy-deliveries-retry-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <%!-- Jobs --%>
    <.docs_section
      id="jobs"
      title="Jobs"
      subtitle={gettext("Tareas programadas: daily, weekly, monthly o cron.")}
    >
      <div class="space-y-6">
        <.api_endpoint
          id="jobs-list"
          method="GET"
          path="/api/v1/jobs"
          description={gettext("Lista jobs del proyecto.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/jobs\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-jobs-list"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "jobs": [\n    {\n      "id": "e5f6a7b8-c9d0-1234-efgh-345678901234",\n      "name": "Daily Report",\n      "schedule_type": "daily",\n      "schedule_config": {},\n      "action_type": "emit_event",\n      "action_config": {"topic": "report.daily", "payload": {}},\n      "status": "active",\n      "inserted_at": "2026-01-05T12:00:00Z"\n    }\n  ]\n}|
            }
            copy_id="copy-jobs-list-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>

        <.api_endpoint
          id="jobs-create"
          method="POST"
          path="/api/v1/jobs"
          description={gettext("Crea un job programado.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/jobs\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"name\":\"Daily Report\",\"schedule_type\":\"daily\",\"schedule_hour\":0,\"action_type\":\"emit_event\",\"action_config\":{\"topic\":\"report.daily\",\"payload\":{}}}'"}
            copy_id="copy-jobs-create"
          />
          <.code_block
            code={
              ~s|// Response (201 Created)\n{\n  "id": "e5f6a7b8-c9d0-1234-efgh-345678901234",\n  "name": "Daily Report",\n  "schedule_type": "daily",\n  "schedule_config": {},\n  "action_type": "emit_event",\n  "action_config": {"topic": "report.daily", "payload": {}},\n  "status": "active",\n  "inserted_at": "2026-01-15T10:30:00Z"\n}|
            }
            copy_id="copy-jobs-create-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>

        <.api_endpoint
          id="jobs-show"
          method="GET"
          path="/api/v1/jobs/:id"
          description={gettext("Detalle de un job.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/jobs/JOB_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-jobs-show"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "id": "e5f6a7b8-c9d0-1234-efgh-345678901234",\n  "name": "Daily Report",\n  "schedule_type": "daily",\n  "schedule_config": {},\n  "action_type": "emit_event",\n  "action_config": {"topic": "report.daily", "payload": {}},\n  "status": "active",\n  "inserted_at": "2026-01-05T12:00:00Z",\n  "recent_runs": [\n    {"id": "f6a7b8c9-d0e1-2345-fghi-456789012345", "executed_at": "2026-01-15T00:00:00Z", "status": "success", "result": null}\n  ]\n}|
            }
            copy_id="copy-jobs-show-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="jobs-update"
          method="PATCH"
          path="/api/v1/jobs/:id"
          description={gettext("Actualiza un job.")}
        >
          <.code_block
            code={"curl -X PATCH \"#{@base_url}/api/v1/jobs/JOB_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"name\":\"Updated Report\",\"schedule_hour\":6}'"}
            copy_id="copy-jobs-update"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "id": "e5f6a7b8-c9d0-1234-efgh-345678901234",\n  "name": "Updated Report",\n  "schedule_type": "daily",\n  "schedule_config": {},\n  "action_type": "emit_event",\n  "action_config": {"topic": "report.daily", "payload": {}},\n  "status": "active",\n  "inserted_at": "2026-01-05T12:00:00Z"\n}|
            }
            copy_id="copy-jobs-update-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="jobs-delete"
          method="DELETE"
          path="/api/v1/jobs/:id"
          description={gettext("Elimina un job.")}
        >
          <.code_block
            code={"curl -X DELETE \"#{@base_url}/api/v1/jobs/JOB_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-jobs-delete"
          />
          <.code_block
            code={~s|// Response (200 OK)\n{\n  "status": "inactive"\n}|}
            copy_id="copy-jobs-delete-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>

        <.api_endpoint
          id="jobs-runs"
          method="GET"
          path="/api/v1/jobs/:id/runs"
          description={gettext("Historial de ejecuciones de un job.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/jobs/JOB_ID/runs\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-jobs-runs"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "runs": [\n    {\n      "id": "f6a7b8c9-d0e1-2345-fghi-456789012345",\n      "executed_at": "2026-01-15T00:00:00Z",\n      "status": "success",\n      "result": null\n    }\n  ]\n}|
            }
            copy_id="copy-jobs-runs-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>

        <.api_endpoint
          id="jobs-cron-preview"
          method="GET"
          path="/api/v1/jobs/cron-preview"
          description={gettext("Previsualiza proximas ejecuciones de una expresion cron.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/jobs/cron-preview?expression=*/15+*+*+*+*\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-jobs-cron-preview"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "expression": "*/15 * * * *",\n  "next_executions": [\n    "2026-01-15T10:45:00Z",\n    "2026-01-15T11:00:00Z",\n    "2026-01-15T11:15:00Z",\n    "2026-01-15T11:30:00Z",\n    "2026-01-15T11:45:00Z"\n  ]\n}|
            }
            copy_id="copy-jobs-cron-preview-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <%!-- Project & Token --%>
    <.docs_section
      id="project-token"
      title={gettext("Proyecto y token")}
      subtitle={gettext("Consultar y actualizar tu proyecto, gestiónar API tokens.")}
    >
      <div class="space-y-6">
        <.api_endpoint
          id="project-show"
          method="GET"
          path="/api/v1/project"
          description={gettext("Detalle del proyecto actual.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/project\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-project-show"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n  "name": "My Project",\n  "status": "active",\n  "settings": {}\n}|
            }
            copy_id="copy-project-show-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="project-update"
          method="PATCH"
          path="/api/v1/project"
          description={gettext("Actualiza el nombre del proyecto.")}
        >
          <.code_block
            code={"curl -X PATCH \"#{@base_url}/api/v1/project\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"name\":\"My Project\"}'"}
            copy_id="copy-project-update"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n  "name": "My Project",\n  "status": "active"\n}|
            }
            copy_id="copy-project-update-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="project-topics"
          method="GET"
          path="/api/v1/topics"
          description={gettext("Lista todos los topics usados.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/topics\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-project-topics"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "topics": ["order.created", "order.updated", "payment.completed", "user.registered"]\n}|
            }
            copy_id="copy-project-topics-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="project-token-show"
          method="GET"
          path="/api/v1/token"
          description={gettext("Muestra info del token actual (prefix).")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/token\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-project-token-show"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "prefix": "jc_live_a1b2",\n  "message": "Use Authorization: Bearer <your_key>. Regenerate from dashboard to get a new key."\n}|
            }
            copy_id="copy-project-token-show-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="project-token-regen"
          method="POST"
          path="/api/v1/token/regenerate"
          description={gettext("Regenera el API token. El anterior deja de funcionar.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/token/regenerate\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-project-token-regen"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "token": "jc_live_new_token_value_here...",\n  "message": "The previous token no longer works. Only this token is valid. Save it; it is only shown once."\n}|
            }
            copy_id="copy-project-token-regen-response"
            title={gettext("Respuesta")}
          />
          <.callout kind="warning">
            {gettext(
              "Al regenerar, el token anterior se invalida inmediatamente. Actualiza tu código con el nuevo token."
            )}
          </.callout>
        </.api_endpoint>
      </div>
    </.docs_section>

    <%!-- Pipelines --%>
    <.docs_section
      id="pipelines"
      title="Pipelines"
      subtitle={gettext("Pipelines de procesamiento de eventos con pasos encadenados.")}
    >
      <div class="space-y-6">
        <.api_endpoint
          id="pipelines-list"
          method="GET"
          path="/api/v1/pipelines"
          description={gettext("Lista pipelines del proyecto.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/pipelines\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-pipelines-list"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "data": [\n    {\n      "id": "f6a7b8c9-d0e1-2345-fghi-456789012345",\n      "name": "Order Pipeline",\n      "status": "active",\n      "description": "Process orders",\n      "topics": ["order.*"],\n      "steps": [{"type": "filter", "config": {"field": "amount", "operator": "gt", "value": 100}}],\n      "webhook_id": null,\n      "inserted_at": "2026-01-10T08:00:00Z"\n    }\n  ]\n}|
            }
            copy_id="copy-pipelines-list-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="pipelines-create"
          method="POST"
          path="/api/v1/pipelines"
          description={gettext("Crea un pipeline nuevo.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/pipelines\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"name\":\"Order Pipeline\",\"description\":\"Process orders\",\"steps\":[{\"type\":\"filter\",\"config\":{\"field\":\"amount\",\"operator\":\"gt\",\"value\":100}}]}'"}
            copy_id="copy-pipelines-create"
          />
          <.code_block
            code={
              ~s|// Response (201 Created)\n{\n  "data": {\n    "id": "f6a7b8c9-d0e1-2345-fghi-456789012345",\n    "name": "Order Pipeline",\n    "status": "active",\n    "description": "Process orders",\n    "topics": null,\n    "steps": [{"type": "filter", "config": {"field": "amount", "operator": "gt", "value": 100}}],\n    "webhook_id": null,\n    "inserted_at": "2026-01-15T10:30:00Z"\n  }\n}|
            }
            copy_id="copy-pipelines-create-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="pipelines-show"
          method="GET"
          path="/api/v1/pipelines/:id"
          description={gettext("Detalle de un pipeline.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/pipelines/PIPELINE_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-pipelines-show"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "data": {\n    "id": "f6a7b8c9-d0e1-2345-fghi-456789012345",\n    "name": "Order Pipeline",\n    "status": "active",\n    "description": "Process orders",\n    "topics": ["order.*"],\n    "steps": [{"type": "filter", "config": {"field": "amount", "operator": "gt", "value": 100}}],\n    "webhook_id": null,\n    "inserted_at": "2026-01-10T08:00:00Z"\n  }\n}|
            }
            copy_id="copy-pipelines-show-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="pipelines-update"
          method="PATCH"
          path="/api/v1/pipelines/:id"
          description={gettext("Actualiza un pipeline.")}
        >
          <.code_block
            code={"curl -X PATCH \"#{@base_url}/api/v1/pipelines/PIPELINE_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"name\":\"Updated Pipeline\",\"description\":\"New description\"}'"}
            copy_id="copy-pipelines-update"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "data": {\n    "id": "f6a7b8c9-d0e1-2345-fghi-456789012345",\n    "name": "Updated Pipeline",\n    "status": "active",\n    "description": "New description",\n    "topics": ["order.*"],\n    "steps": [{"type": "filter", "config": {"field": "amount", "operator": "gt", "value": 100}}],\n    "webhook_id": null,\n    "inserted_at": "2026-01-10T08:00:00Z"\n  }\n}|
            }
            copy_id="copy-pipelines-update-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="pipelines-delete"
          method="DELETE"
          path="/api/v1/pipelines/:id"
          description={gettext("Elimina un pipeline.")}
        >
          <.code_block
            code={"curl -X DELETE \"#{@base_url}/api/v1/pipelines/PIPELINE_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-pipelines-delete"
          />
          <.code_block
            code={~s|// Response (204 No Content)|}
            copy_id="copy-pipelines-delete-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="pipelines-test"
          method="POST"
          path="/api/v1/pipelines/:id/test"
          description={gettext("Prueba un pipeline con un payload de ejemplo.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/pipelines/PIPELINE_ID/test\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"topic\":\"order.created\",\"payload\":{\"order_id\":\"123\",\"amount\":99.99}}'"}
            copy_id="copy-pipelines-test"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "input": {"order_id": "123", "amount": 99.99},\n  "output": {"order_id": "123", "amount": 99.99},\n  "steps_count": 1,\n  "status": "passed"\n}|
            }
            copy_id="copy-pipelines-test-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <%!-- Dead Letters --%>
    <.docs_section
      id="dead-letters"
      title="Dead Letters"
      subtitle={gettext("Eventos que agotaron los reintentos.")}
    >
      <div class="space-y-6">
        <.api_endpoint
          id="dead-letters-list"
          method="GET"
          path="/api/v1/dead-letters"
          description={gettext("Lista dead letters.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/dead-letters\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-dead-letters-list"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "dead_letters": [\n    {\n      "id": "a7b8c9d0-e1f2-3456-ghij-567890123456",\n      "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "delivery_id": "d4e5f6a7-b8c9-0123-defg-234567890123",\n      "event_id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",\n      "webhook_id": "c3d4e5f6-a7b8-9012-cdef-123456789012",\n      "webhook_url": "https://example.com/hook",\n      "original_payload": {"order_id": "12345"},\n      "last_error": "Connection refused",\n      "last_response_status": null,\n      "attempts_exhausted": 5,\n      "resolved": false,\n      "resolved_at": null,\n      "inserted_at": "2026-01-15T10:30:00Z"\n    }\n  ]\n}|
            }
            copy_id="copy-dead-letters-list-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="dead-letters-show"
          method="GET"
          path="/api/v1/dead-letters/:id"
          description={gettext("Detalle de un dead letter.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/dead-letters/DEAD_LETTER_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-dead-letters-show"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "id": "a7b8c9d0-e1f2-3456-ghij-567890123456",\n  "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n  "delivery_id": "d4e5f6a7-b8c9-0123-defg-234567890123",\n  "event_id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",\n  "webhook_id": "c3d4e5f6-a7b8-9012-cdef-123456789012",\n  "webhook_url": "https://example.com/hook",\n  "original_payload": {"order_id": "12345"},\n  "last_error": "Connection refused",\n  "last_response_status": null,\n  "attempts_exhausted": 5,\n  "resolved": false,\n  "resolved_at": null,\n  "inserted_at": "2026-01-15T10:30:00Z"\n}|
            }
            copy_id="copy-dead-letters-show-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="dead-letters-retry"
          method="POST"
          path="/api/v1/dead-letters/:id/retry"
          description={gettext("Reintenta un dead letter.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/dead-letters/DEAD_LETTER_ID/retry\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-dead-letters-retry"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "status": "retrying",\n  "delivery_id": "d4e5f6a7-b8c9-0123-defg-234567890123"\n}|
            }
            copy_id="copy-dead-letters-retry-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="dead-letters-resolve"
          method="PATCH"
          path="/api/v1/dead-letters/:id/resolve"
          description={gettext("Marca un dead letter como resuelto.")}
        >
          <.code_block
            code={"curl -X PATCH \"#{@base_url}/api/v1/dead-letters/DEAD_LETTER_ID/resolve\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-dead-letters-resolve"
          />
          <.code_block
            code={~s|// Response (200 OK)\n{\n  "status": "resolved"\n}|}
            copy_id="copy-dead-letters-resolve-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <%!-- Replays --%>
    <.docs_section
      id="replays"
      title={gettext("Event Replay")}
      subtitle={gettext("Re-envía eventos históricos a tus webhooks.")}
    >
      <div class="space-y-6">
        <.api_endpoint
          id="replays-create"
          method="POST"
          path="/api/v1/replays"
          description={gettext("Crea un replay de eventos.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/replays\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"webhook_id\":\"WEBHOOK_ID\",\"from\":\"2026-01-01T00:00:00Z\",\"to\":\"2026-01-31T23:59:59Z\"}'"}
            copy_id="copy-replays-create"
          />
          <.code_block
            code={
              ~s|// Response (201 Created)\n{\n  "id": "b8c9d0e1-f2a3-4567-hijk-678901234567",\n  "status": "pending",\n  "filters": {"webhook_id": "WEBHOOK_ID", "from_date": "2026-01-01T00:00:00Z", "to_date": "2026-01-31T23:59:59Z"},\n  "total_events": 0,\n  "processed_events": 0,\n  "started_at": null,\n  "completed_at": null,\n  "inserted_at": "2026-01-15T10:30:00Z"\n}|
            }
            copy_id="copy-replays-create-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="replays-list"
          method="GET"
          path="/api/v1/replays"
          description={gettext("Lista replays.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/replays\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-replays-list"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "data": [\n    {\n      "id": "b8c9d0e1-f2a3-4567-hijk-678901234567",\n      "status": "completed",\n      "filters": {"webhook_id": "WEBHOOK_ID", "from_date": "2026-01-01T00:00:00Z"},\n      "total_events": 42,\n      "processed_events": 42,\n      "started_at": "2026-01-15T10:31:00Z",\n      "completed_at": "2026-01-15T10:32:00Z",\n      "inserted_at": "2026-01-15T10:30:00Z"\n    }\n  ]\n}|
            }
            copy_id="copy-replays-list-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="replays-show"
          method="GET"
          path="/api/v1/replays/:id"
          description={gettext("Detalle de un replay.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/replays/REPLAY_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-replays-show"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "id": "b8c9d0e1-f2a3-4567-hijk-678901234567",\n  "status": "running",\n  "filters": {"webhook_id": "WEBHOOK_ID"},\n  "total_events": 42,\n  "processed_events": 15,\n  "started_at": "2026-01-15T10:31:00Z",\n  "completed_at": null,\n  "inserted_at": "2026-01-15T10:30:00Z"\n}|
            }
            copy_id="copy-replays-show-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="replays-cancel"
          method="DELETE"
          path="/api/v1/replays/:id"
          description={gettext("Cancela un replay en curso.")}
        >
          <.code_block
            code={"curl -X DELETE \"#{@base_url}/api/v1/replays/REPLAY_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-replays-cancel"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "id": "b8c9d0e1-f2a3-4567-hijk-678901234567",\n  "status": "cancelled",\n  "filters": {"webhook_id": "WEBHOOK_ID"},\n  "total_events": 42,\n  "processed_events": 15,\n  "started_at": "2026-01-15T10:31:00Z",\n  "completed_at": "2026-01-15T10:35:00Z",\n  "inserted_at": "2026-01-15T10:30:00Z"\n}|
            }
            copy_id="copy-replays-cancel-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <%!-- Event Schemas --%>
    <.docs_section
      id="event-schemas"
      title={gettext("Event Schemas")}
      subtitle={gettext("Define y valida la estructura de tus eventos con JSON Schema.")}
    >
      <div class="space-y-6">
        <.api_endpoint
          id="schemas-list"
          method="GET"
          path="/api/v1/event-schemas"
          description={gettext("Lista schemas del proyecto.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/event-schemas\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-schemas-list"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "data": [\n    {\n      "id": "c9d0e1f2-a3b4-5678-ijkl-789012345678",\n      "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "topic": "order.created",\n      "schema": {"type": "object", "required": ["order_id"], "properties": {"order_id": {"type": "string"}}},\n      "version": 1,\n      "status": "active",\n      "inserted_at": "2026-01-10T08:00:00Z",\n      "updated_at": "2026-01-10T08:00:00Z"\n    }\n  ]\n}|
            }
            copy_id="copy-schemas-list-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="schemas-create"
          method="POST"
          path="/api/v1/event-schemas"
          description={gettext("Crea un schema de validacion.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/event-schemas\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"topic\":\"order.created\",\"schema\":{\"type\":\"object\",\"required\":[\"order_id\"],\"properties\":{\"order_id\":{\"type\":\"string\"}}}}'"}
            copy_id="copy-schemas-create"
          />
          <.code_block
            code={
              ~s|// Response (201 Created)\n{\n  "data": {\n    "id": "c9d0e1f2-a3b4-5678-ijkl-789012345678",\n    "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "topic": "order.created",\n    "schema": {"type": "object", "required": ["order_id"], "properties": {"order_id": {"type": "string"}}},\n    "version": 1,\n    "status": "active",\n    "inserted_at": "2026-01-15T10:30:00Z",\n    "updated_at": "2026-01-15T10:30:00Z"\n  }\n}|
            }
            copy_id="copy-schemas-create-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="schemas-show"
          method="GET"
          path="/api/v1/event-schemas/:id"
          description={gettext("Detalle de un schema.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/event-schemas/SCHEMA_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-schemas-show"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "data": {\n    "id": "c9d0e1f2-a3b4-5678-ijkl-789012345678",\n    "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "topic": "order.created",\n    "schema": {"type": "object", "required": ["order_id"], "properties": {"order_id": {"type": "string"}}},\n    "version": 1,\n    "status": "active",\n    "inserted_at": "2026-01-10T08:00:00Z",\n    "updated_at": "2026-01-10T08:00:00Z"\n  }\n}|
            }
            copy_id="copy-schemas-show-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="schemas-update"
          method="PATCH"
          path="/api/v1/event-schemas/:id"
          description={gettext("Actualiza un schema.")}
        >
          <.code_block
            code={"curl -X PATCH \"#{@base_url}/api/v1/event-schemas/SCHEMA_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"schema\":{\"type\":\"object\",\"required\":[\"order_id\",\"amount\"],\"properties\":{\"order_id\":{\"type\":\"string\"},\"amount\":{\"type\":\"number\"}}}}'"}
            copy_id="copy-schemas-update"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "data": {\n    "id": "c9d0e1f2-a3b4-5678-ijkl-789012345678",\n    "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "topic": "order.created",\n    "schema": {"type": "object", "required": ["order_id", "amount"], "properties": {"order_id": {"type": "string"}, "amount": {"type": "number"}}},\n    "version": 1,\n    "status": "active",\n    "inserted_at": "2026-01-10T08:00:00Z",\n    "updated_at": "2026-01-15T10:30:00Z"\n  }\n}|
            }
            copy_id="copy-schemas-update-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="schemas-delete"
          method="DELETE"
          path="/api/v1/event-schemas/:id"
          description={gettext("Elimina un schema.")}
        >
          <.code_block
            code={"curl -X DELETE \"#{@base_url}/api/v1/event-schemas/SCHEMA_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-schemas-delete"
          />
          <.code_block
            code={~s|// Response (200 OK)\n{\n  "ok": true\n}|}
            copy_id="copy-schemas-delete-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="schemas-validate"
          method="POST"
          path="/api/v1/event-schemas/validate"
          description={gettext("Valida un payload contra un schema sin guardarlo.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/event-schemas/validate\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"topic\":\"order.created\",\"payload\":{\"order_id\":\"123\"}}'"}
            copy_id="copy-schemas-validate"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "valid": true,\n  "errors": []\n}\n\n// If validation fails:\n{\n  "valid": false,\n  "errors": [\n    {"message": "Required property order_id is missing", "path": "#/order_id"}\n  ]\n}|
            }
            copy_id="copy-schemas-validate-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <%!-- Export --%>
    <.docs_section
      id="export"
      title={gettext("Exportar datos")}
      subtitle={gettext("Descarga datos en CSV o JSON.")}
    >
      <div class="space-y-6">
        <.api_endpoint
          id="export-events"
          method="GET"
          path="/api/v1/export/events"
          description={gettext("Exporta eventos.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/export/events?format=csv\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-export-events"
          />
          <.code_block
            code={
              ~s|// Response (200 OK) — CSV\nid,topic,status,occurred_at,payload,payload_hash\nb2c3d4e5-...,order.created,active,2026-01-15T10:30:00Z,"{""order_id"":""12345""}",sha256:a3f2...\n\n// With ?format=json:\n{"data": [...], "total": 1}|
            }
            copy_id="copy-export-events-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="export-deliveries"
          method="GET"
          path="/api/v1/export/deliveries"
          description={gettext("Exporta entregas.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/export/deliveries?format=csv\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-export-deliveries"
          />
          <.code_block
            code={
              ~s|// Response (200 OK) — CSV\nid,event_id,webhook_id,status,attempt_number,response_status,inserted_at\nd4e5f6a7-...,b2c3d4e5-...,c3d4e5f6-...,success,1,200,2026-01-15T10:30:00Z\n\n// With ?format=json:\n{"data": [...], "total": 1}|
            }
            copy_id="copy-export-deliveries-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="export-jobs"
          method="GET"
          path="/api/v1/export/jobs"
          description={gettext("Exporta jobs.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/export/jobs?format=csv\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-export-jobs"
          />
          <.code_block
            code={
              ~s|// Response (200 OK) — CSV\nid,name,status,schedule_type,action_type,inserted_at\ne5f6a7b8-...,Daily Report,active,daily,emit_event,2026-01-05T12:00:00Z\n\n// With ?format=json:\n{"data": [...], "total": 1}|
            }
            copy_id="copy-export-jobs-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="export-audit"
          method="GET"
          path="/api/v1/export/audit-log"
          description={gettext("Exporta audit log.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/export/audit-log?format=csv\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-export-audit"
          />
          <.code_block
            code={
              ~s|// Response (200 OK) — CSV\nid,action,resource_type,resource_id,user_id,ip_address,inserted_at\nf6a7b8c9-...,event.created,event,b2c3d4e5-...,a1b2c3d4-...,192.168.1.1,2026-01-15T10:30:00Z\n\n// With ?format=json:\n{"data": [...], "total": 1}|
            }
            copy_id="copy-export-audit-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
      </div>
      <.callout kind="tip">
        {gettext(
          "Usa el query param ?format=csv para CSV o ?format=json para JSON. Por defecto es CSV."
        )}
      </.callout>
    </.docs_section>
    """
  end

  attr :base_url, :string, required: true

  # ══════════════════════════════════════════════════════════════════════
  # SECTION 4: PLATFORM FEATURES
  # ══════════════════════════════════════════════════════════════════════

  defp section_platform(assigns) do
    ~H"""
    <.docs_section
      id="dashboard-overview"
      title="Dashboard"
      subtitle={gettext("Panel principal para gestiónar tu plataforma.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "El Dashboard es tu centro de control. Desde ahi puedes ver eventos, webhooks, entregas, jobs, analíticas, audit log y gestiónar tu API token. Accede desde la web después de iniciar sesión."
        )}
      </p>
      <div class="grid sm:grid-cols-2 gap-4">
        <div class="rounded-xl bg-slate-50 border border-slate-200 p-4">
          <h3 class="font-semibold text-slate-900 mb-2 text-sm">
            {gettext("Secciones principales")}
          </h3>
          <ul class="text-slate-600 text-sm space-y-1">
            <li>{gettext("Eventos: lista, detalle, filtros")}</li>
            <li>{gettext("Webhooks: crear, editar, activar/desactivar")}</li>
            <li>{gettext("Entregas: historial, reintentos")}</li>
            <li>{gettext("Jobs: crear, editar, ver ejecuciones")}</li>
          </ul>
        </div>
        <div class="rounded-xl bg-slate-50 border border-slate-200 p-4">
          <h3 class="font-semibold text-slate-900 mb-2 text-sm">{gettext("Herramientas")}</h3>
          <ul class="text-slate-600 text-sm space-y-1">
            <li>{gettext("Analíticas: gráficos y métricas")}</li>
            <li>{gettext("Audit Log: registro de acciones")}</li>
            <li>{gettext("Sandbox: endpoints de prueba")}</li>
            <li>{gettext("API Token: ver y regenerar")}</li>
          </ul>
        </div>
      </div>
    </.docs_section>

    <.docs_section
      id="account-management"
      title={gettext("Gestión de cuenta")}
      subtitle={gettext("Perfil, email, contraseña y MFA.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "Desde la página de cuenta puedes actualizar tu nombre, email y contraseña. También puedes activar la autenticación de dos factores (MFA) para mayor seguridad."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="password-recovery"
      title={gettext("Recuperar contraseña")}
      subtitle={gettext("Flujo de recuperación de contraseña.")}
    >
      <div class="space-y-4">
        <p class="text-slate-700 leading-relaxed">
          {gettext(
            "Si olvidaste tu contraseña, solicita un enlace de recuperación desde la página de login. Recibirás un email con un enlace temporal para establecer una nueva contraseña."
          )}
        </p>
        <.callout kind="info">
          {gettext(
            "El enlace de recuperación expira en un periodo corto de tiempo por seguridad. Si expira, solicita uno nuevo."
          )}
        </.callout>
      </div>
    </.docs_section>

    <.docs_section
      id="multi-project"
      title={gettext("Multi-proyecto")}
      subtitle={gettext("Gestióna múltiples proyectos desde una sola cuenta.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Puedes crear múltiples proyectos, cada uno con su propio API token, webhooks, eventos y configuración. Útil para separar entornos (dev, staging, prod) o distintas aplicaciónes."
        )}
      </p>
      <div class="space-y-4">
        <.api_endpoint
          id="projects-list"
          method="GET"
          path="/api/v1/projects"
          description={gettext("Lista tus proyectos (requiere JWT).")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/projects\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-projects-list"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "data": [\n    {\n      "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "name": "Production",\n      "status": "active",\n      "is_default": true,\n      "settings": {},\n      "inserted_at": "2026-01-01T00:00:00Z",\n      "updated_at": "2026-01-10T08:00:00Z"\n    }\n  ]\n}|
            }
            copy_id="copy-projects-list-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="projects-create"
          method="POST"
          path="/api/v1/projects"
          description={gettext("Crea un proyecto nuevo.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/projects\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"name\":\"My New Project\"}'"}
            copy_id="copy-projects-create"
          />
          <.code_block
            code={
              ~s|// Response (201 Created)\n{\n  "data": {\n    "id": "d0e1f2a3-b4c5-6789-klmn-890123456789",\n    "name": "My New Project",\n    "status": "active",\n    "is_default": false,\n    "settings": {},\n    "inserted_at": "2026-01-15T10:30:00Z",\n    "updated_at": "2026-01-15T10:30:00Z"\n  }\n}|
            }
            copy_id="copy-projects-create-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="projects-default"
          method="PATCH"
          path="/api/v1/projects/:id/default"
          description={gettext("Marca un proyecto como predeterminado.")}
        >
          <.code_block
            code={"curl -X PATCH \"#{@base_url}/api/v1/projects/PROJECT_ID/default\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-projects-default"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "data": {\n    "id": "d0e1f2a3-b4c5-6789-klmn-890123456789",\n    "name": "My New Project",\n    "status": "active",\n    "is_default": true,\n    "settings": {},\n    "inserted_at": "2026-01-15T10:30:00Z",\n    "updated_at": "2026-01-15T10:35:00Z"\n  }\n}|
            }
            copy_id="copy-projects-default-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <.docs_section
      id="teams"
      title={gettext("Equipos")}
      subtitle={gettext("Colabora con tu equipo en proyectos compartidos.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Invita miembros a tus proyectos con roles diferenciados (admin, member, viewer). Los miembros invitados reciben un email y pueden aceptar o rechazar la invitación."
        )}
      </p>
      <div class="space-y-4">
        <.api_endpoint
          id="members-list"
          method="GET"
          path="/api/v1/projects/:id/members"
          description={gettext("Lista miembros del proyecto.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/projects/PROJECT_ID/members\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-members-list"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "data": [\n    {\n      "id": "e1f2a3b4-c5d6-7890-lmno-901234567890",\n      "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "user_id": "f2a3b4c5-d6e7-8901-mnop-012345678901",\n      "role": "member",\n      "status": "accepted",\n      "invited_by": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "inserted_at": "2026-01-10T08:00:00Z"\n    }\n  ]\n}|
            }
            copy_id="copy-members-list-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="members-add"
          method="POST"
          path="/api/v1/projects/:id/members"
          description={gettext("Invita un miembro.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/projects/PROJECT_ID/members\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"email\":\"member@example.com\",\"role\":\"member\"}'"}
            copy_id="copy-members-add"
          />
          <.code_block
            code={
              ~s|// Response (201 Created)\n{\n  "data": {\n    "id": "e1f2a3b4-c5d6-7890-lmno-901234567890",\n    "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "user_id": "f2a3b4c5-d6e7-8901-mnop-012345678901",\n    "role": "member",\n    "status": "pending",\n    "invited_by": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "inserted_at": "2026-01-15T10:30:00Z"\n  }\n}|
            }
            copy_id="copy-members-add-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="members-update"
          method="PATCH"
          path="/api/v1/projects/:id/members/:mid"
          description={gettext("Cambia rol de un miembro.")}
        >
          <.code_block
            code={"curl -X PATCH \"#{@base_url}/api/v1/projects/PROJECT_ID/members/MEMBER_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"role\":\"admin\"}'"}
            copy_id="copy-members-update"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "data": {\n    "id": "e1f2a3b4-c5d6-7890-lmno-901234567890",\n    "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "user_id": "f2a3b4c5-d6e7-8901-mnop-012345678901",\n    "role": "admin",\n    "status": "accepted",\n    "invited_by": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "inserted_at": "2026-01-10T08:00:00Z"\n  }\n}|
            }
            copy_id="copy-members-update-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="members-remove"
          method="DELETE"
          path="/api/v1/projects/:id/members/:mid"
          description={gettext("Elimina un miembro.")}
        >
          <.code_block
            code={"curl -X DELETE \"#{@base_url}/api/v1/projects/PROJECT_ID/members/MEMBER_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-members-remove"
          />
          <.code_block
            code={~s|// Response (200 OK)\n{\n  "ok": true\n}|}
            copy_id="copy-members-remove-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <.docs_section
      id="sandbox"
      title="Sandbox"
      subtitle={gettext("Endpoints de prueba para recibir webhooks.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Crea endpoints sandbox para probar tus webhooks sin necesitar un servidor externo. Cada endpoint tiene una URL única que captura todas las peticiones recibidas."
        )}
      </p>
      <div class="space-y-4">
        <.api_endpoint
          id="sandbox-list"
          method="GET"
          path="/api/v1/sandbox-endpoints"
          description={gettext("Lista endpoints sandbox.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/sandbox-endpoints\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-sandbox-list"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "data": [\n    {\n      "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "slug": "test-endpoint-x7k9",\n      "name": "Test Endpoint",\n      "url": "/sandbox/test-endpoint-x7k9",\n      "expires_at": "2026-03-14T14:30:00Z",\n      "inserted_at": "2026-03-07T14:30:00Z"\n    }\n  ]\n}|
            }
            copy_id="copy-sandbox-list-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="sandbox-create"
          method="POST"
          path="/api/v1/sandbox-endpoints"
          description={gettext("Crea un endpoint sandbox.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/sandbox-endpoints\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"name\":\"Test Endpoint\"}'"}
            copy_id="copy-sandbox-create"
          />
          <.code_block
            code={
              ~s|// Response (201 Created)\n{\n  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n  "slug": "test-endpoint-x7k9",\n  "name": "Test Endpoint",\n  "url": "/sandbox/test-endpoint-x7k9",\n  "expires_at": "2026-03-14T14:30:00Z",\n  "inserted_at": "2026-03-07T14:30:00Z"\n}|
            }
            copy_id="copy-sandbox-create-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="sandbox-requests"
          method="GET"
          path="/api/v1/sandbox-endpoints/:id/requests"
          description={gettext("Ve las peticiones recibidas.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/sandbox-endpoints/ENDPOINT_ID/requests\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-sandbox-requests"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "data": [\n    {\n      "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "method": "POST",\n      "path": "/sandbox/test-endpoint-x7k9",\n      "headers": {"content-type": "application/json"},\n      "body": {"order_id": "123", "amount": 99.99},\n      "query_params": {},\n      "ip": "203.0.113.42",\n      "inserted_at": "2026-03-07T14:30:00Z"\n    }\n  ]\n}|
            }
            copy_id="copy-sandbox-requests-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="sandbox-delete"
          method="DELETE"
          path="/api/v1/sandbox-endpoints/:id"
          description={gettext("Elimina un endpoint sandbox.")}
        >
          <.code_block
            code={"curl -X DELETE \"#{@base_url}/api/v1/sandbox-endpoints/ENDPOINT_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-sandbox-delete"
          />
          <.code_block
            code={~s|// Response (200 OK)\n{\n  "status": "deleted"\n}|}
            copy_id="copy-sandbox-delete-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <.docs_section
      id="analytics"
      title={gettext("Analíticas")}
      subtitle={gettext("Metricas y gráficos de tu plataforma.")}
    >
      <div class="space-y-4">
        <.api_endpoint
          id="analytics-events"
          method="GET"
          path="/api/v1/analytics/events-per-day"
          description={gettext("Eventos por dia.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/analytics/events-per-day\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-analytics-events"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "data": [\n    {"date": "2026-03-05", "count": 245},\n    {"date": "2026-03-06", "count": 312},\n    {"date": "2026-03-07", "count": 178}\n  ]\n}|
            }
            copy_id="copy-analytics-events-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="analytics-deliveries"
          method="GET"
          path="/api/v1/analytics/deliveries-per-day"
          description={gettext("Entregas por dia.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/analytics/deliveries-per-day\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-analytics-deliveries"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "data": [\n    {"date": "2026-03-05", "count": 320},\n    {"date": "2026-03-06", "count": 415},\n    {"date": "2026-03-07", "count": 198}\n  ]\n}|
            }
            copy_id="copy-analytics-deliveries-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="analytics-topics"
          method="GET"
          path="/api/v1/analytics/top-topics"
          description={gettext("Topics mas usados.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/analytics/top-topics\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-analytics-topics"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "data": [\n    {"topic": "order.created", "count": 1250},\n    {"topic": "user.signup", "count": 890},\n    {"topic": "payment.completed", "count": 567}\n  ]\n}|
            }
            copy_id="copy-analytics-topics-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="analytics-webhooks"
          method="GET"
          path="/api/v1/analytics/webhook-stats"
          description={gettext("Estadisticas de webhooks.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/analytics/webhook-stats\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-analytics-webhooks"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "data": [\n    {\n      "webhook_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "url": "https://example.com/hook",\n      "total_deliveries": 150,\n      "successful": 142,\n      "failed": 8\n    }\n  ]\n}|
            }
            copy_id="copy-analytics-webhooks-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <.docs_section
      id="audit-log"
      title="Audit Log"
      subtitle={gettext("Registro inmutable de acciones en tu proyecto.")}
    >
      <.api_endpoint
        id="audit-index"
        method="GET"
        path="/api/v1/audit-log"
        description={gettext("Lista entradas del audit log con paginación.")}
      >
        <.code_block
          code={"curl \"#{@base_url}/api/v1/audit-log?limit=20\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
          copy_id="copy-audit-index"
        />
        <.code_block
          code={
            ~s|// Response (200 OK)\n{\n  "data": [\n    {\n      "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "action": "webhook.created",\n      "resource_type": "webhook",\n      "resource_id": "f1e2d3c4-b5a6-7890-fedc-ba0987654321",\n      "metadata": {"url": "https://example.com/hook"},\n      "user_id": "c3d4e5f6-a7b8-9012-cdef-234567890abc",\n      "ip_address": "203.0.113.42",\n      "inserted_at": "2026-03-07T14:30:00Z"\n    }\n  ]\n}|
          }
          copy_id="copy-audit-index-response"
          title={gettext("Respuesta")}
        />
        <p class="text-slate-600 text-sm">
          {gettext("Filtros opcionales: action, actor_email, from, to.")}
        </p>
      </.api_endpoint>
    </.docs_section>

    <.docs_section
      id="realtime-stream"
      title="SSE Streaming"
      subtitle={gettext("Recibe eventos en tiempo real via Server-Sent Events.")}
    >
      <.api_endpoint
        id="sse-stream"
        method="GET"
        path="/api/v1/stream"
        description={gettext("Abre una conexión SSE para recibir eventos en tiempo real.")}
      >
        <.code_block
          code={"curl -N \"#{@base_url}/api/v1/stream\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
          copy_id="copy-sse-stream"
        />
        <.code_block
          code={
            ~s|// Response (200 OK) — Server-Sent Events stream\ndata: {"type":"connected","project_id":"a1b2c3d4-e5f6-7890-abcd-ef1234567890"}\n\ndata: {"type":"event.created","data":{"id":"b2c3d4e5-f6a7-8901-bcde-f12345678901","topic":"order.created","payload":{"order_id":"123"},"occurred_at":"2026-03-07T14:30:00Z"}}\n\ndata: {"type":"delivery.updated","data":{"id":"c3d4e5f6-a7b8-9012-cdef-234567890abc","status":"delivered","event_id":"b2c3d4e5-f6a7-8901-bcde-f12345678901"}}|
          }
          copy_id="copy-sse-stream-response"
          title={gettext("Respuesta")}
        />
      </.api_endpoint>
      <p class="text-slate-600 text-sm">
        {gettext(
          "La conexión permanece abierta y envía eventos a medida que ocurren. Usa EventSource en JavaScript o curl -N para probar."
        )}
      </p>
    </.docs_section>
    """
  end

  # ══════════════════════════════════════════════════════════════════════
  # SECTION 5: ADVANCED
  # ══════════════════════════════════════════════════════════════════════

  defp section_advanced(assigns) do
    ~H"""
    <.docs_section
      id="topic-wildcards"
      title="Topic Wildcards"
      subtitle={gettext("Usa patrones con * para filtrar múltiples topics en webhooks.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Puedes usar * como comodin en los topics de un webhook. Por ejemplo, order.* coincide con order.created, order.updated, order.deleted, etc."
        )}
      </p>
      <div class="rounded-xl bg-slate-50 border border-slate-200 p-4">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-slate-500">
              <th class="pb-2 font-medium">{gettext("Patron")}</th>
              <th class="pb-2 font-medium">{gettext("Coincide con")}</th>
            </tr>
          </thead>
          <tbody class="text-slate-700">
            <tr>
              <td class="py-1 font-mono text-xs">order.*</td>
              <td class="py-1">order.created, order.updated</td>
            </tr>
            <tr>
              <td class="py-1 font-mono text-xs">*.created</td>
              <td class="py-1">order.created, user.created</td>
            </tr>
            <tr>
              <td class="py-1 font-mono text-xs">*</td>
              <td class="py-1">{gettext("Todos los topics")}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </.docs_section>

    <.docs_section
      id="delayed-events"
      title={gettext("Eventos diferidos")}
      subtitle={gettext("Programa un evento para que se procese en el futuro.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Incluye el campo deliver_at con una fecha ISO 8601 en el futuro. El evento se almacena inmediatamente pero no se entrega hasta la fecha indicada."
        )}
      </p>
      <.code_block
        code={"curl -X POST \"#{@base_url}/api/v1/events\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"topic\":\"reminder\",\"deliver_at\":\"2026-12-25T00:00:00Z\",\"message\":\"Merry Christmas\"}'"}
        copy_id="copy-delayed-events"
      />
    </.docs_section>

    <.docs_section
      id="batch-events"
      title="Batch Events"
      subtitle={gettext("Envía múltiples eventos en una sola petición.")}
    >
      <.api_endpoint
        id="batch-create"
        method="POST"
        path="/api/v1/events/batch"
        description={gettext("Envía un array de eventos.")}
      >
        <.code_block
          code={"curl -X POST \"#{@base_url}/api/v1/events/batch\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"events\":[{\"topic\":\"a\",\"data\":1},{\"topic\":\"b\",\"data\":2}]}'"}
          copy_id="copy-batch-events"
        />
        <.code_block
          code={
            ~s|// Response (202 Accepted)\n{\n  "accepted": 2,\n  "rejected": 0,\n  "events": [\n    {\n      "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "topic": "a",\n      "payload": 1,\n      "status": "pending",\n      "occurred_at": "2026-03-07T14:30:00Z",\n      "payload_hash": "e3b0c44298fc1c14...",\n      "inserted_at": "2026-03-07T14:30:00Z"\n    },\n    {\n      "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",\n      "topic": "b",\n      "payload": 2,\n      "status": "pending",\n      "occurred_at": "2026-03-07T14:30:00Z",\n      "payload_hash": "a1b2c3d4e5f67890...",\n      "inserted_at": "2026-03-07T14:30:00Z"\n    }\n  ]\n}|
          }
          copy_id="copy-batch-events-response"
          title={gettext("Respuesta")}
        />
      </.api_endpoint>
    </.docs_section>

    <.docs_section
      id="cursor-págination"
      title={gettext("Paginación cursor")}
      subtitle={gettext("Paginación eficiente basada en cursor para listas grandes.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Las listas soportan paginación basada en cursor. Usa el campo next_cursor de la respuesta como parámetro cursor en la siguiente petición."
        )}
      </p>
      <.code_block
        code={"curl \"#{@base_url}/api/v1/events?limit=20&cursor=NEXT_CURSOR\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
        copy_id="copy-cursor-págination"
      />
    </.docs_section>

    <.docs_section
      id="webhook-templates"
      title={gettext("Plantillas webhook")}
      subtitle={gettext("Configuraciónes predefinidas para webhooks.")}
    >
      <.api_endpoint
        id="templates-list"
        method="GET"
        path="/api/v1/webhooks/templates"
        description={gettext("Lista plantillas disponibles.")}
      >
        <.code_block
          code={"curl \"#{@base_url}/api/v1/webhooks/templates\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
          copy_id="copy-webhook-templates"
        />
        <.code_block
          code={
            ~s|// Response (200 OK)\n{\n  "templates": [\n    {\n      "name": "Slack Notification",\n      "url": "https://hooks.slack.com/services/...",\n      "topics": ["order.created", "payment.completed"],\n      "headers": {"Content-Type": "application/json"}\n    },\n    {\n      "name": "Email Alert",\n      "url": "https://api.example.com/email-hook",\n      "topics": ["user.signup"],\n      "headers": {}\n    }\n  ]\n}|
          }
          copy_id="copy-webhook-templates-response"
          title={gettext("Respuesta")}
        />
      </.api_endpoint>
    </.docs_section>

    <.docs_section
      id="ip-allowlist"
      title="IP Allowlist"
      subtitle={gettext("Restringe el acceso a la API a IPs específicas.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "Puedes configurar una lista de IPs permitidas para tu API key. Solo las peticiones desde esas IPs serán aceptadas. Configurable al actualizar tu proyecto."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="simulate"
      title={gettext("Simulador")}
      subtitle={gettext("Prueba webhooks sin enviar eventos reales.")}
    >
      <.api_endpoint
        id="simulate-endpoint"
        method="POST"
        path="/api/v1/simulate"
        description={gettext("Simula el envío de un evento para probar tus webhooks.")}
      >
        <.code_block
          code={"curl -X POST \"#{@base_url}/api/v1/simulate\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"topic\":\"order.created\",\"payload\":{\"test\":true}}'"}
          copy_id="copy-simulate"
        />
        <.code_block
          code={
            ~s|// Response (200 OK)\n{\n  "simulation": true,\n  "matching_webhooks": 1,\n  "results": [\n    {\n      "id": "b3e7c8a1-4f2d-4e9a-8c1b-5d6f7a8b9c0d",\n      "url": "https://example.com/hook",\n      "topics": ["order.*"]\n    }\n  ]\n}|
          }
          copy_id="copy-simulate-response"
          title={gettext("Respuesta")}
        />
      </.api_endpoint>
      <.callout kind="info">
        {gettext(
          "El simulador no guarda el evento ni crea entregas reales. Solo muestra que webhooks recibirian el evento y como se veria el payload."
        )}
      </.callout>
    </.docs_section>
    """
  end

  attr :sdk_languages, :list, required: true

  # ══════════════════════════════════════════════════════════════════════
  # SECTION 6: SDKs & TOOLS
  # ══════════════════════════════════════════════════════════════════════

  defp section_sdks(assigns) do
    ~H"""
    <.docs_section
      id="sdks"
      title={gettext("SDKs (12 lenguajes)")}
      subtitle={gettext("Librerías oficiales para todos los lenguajes populares.")}
    >
      <p class="text-slate-700 leading-relaxed mb-6">
        {gettext("Todas las SDKs cubren el 100%% de las rutas de la API. Elige tu lenguaje favorito:")}
      </p>

      <%!-- SDK grid --%>
      <div class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 gap-2 mb-6">
        <button
          :for={lang <- @sdk_languages}
          data-sdk-lang={lang}
          class={[
            "sdk-grid-btn px-3 py-2 rounded-lg text-xs font-medium text-center transition border",
            if(lang == "nodejs",
              do: "bg-indigo-50 border-indigo-300 text-indigo-700",
              else:
                "bg-white border-slate-200 text-slate-600 hover:border-indigo-200 hover:text-indigo-600"
            )
          ]}
        >
          {sdk_label(lang)}
        </button>
      </div>

      <%!-- SDK links --%>
      <div class="rounded-xl border border-slate-200 bg-white p-5 mb-6">
        <h3 class="text-sm font-semibold text-slate-900 mb-3">
          {gettext("Links de instalación")}
        </h3>
        <div class="grid sm:grid-cols-2 md:grid-cols-3 gap-2 text-sm">
          <.sdk_link label="Node.js" registry="npm" url="https://www.npmjs.com/package/@jobcelis/sdk" />
          <.sdk_link label="Python" registry="PyPI" url="https://pypi.org/project/jobcelis/" />
          <.sdk_link
            label="Go"
            registry="pkg.go.dev"
            url="https://pkg.go.dev/github.com/vladimirCeli/go-jobcelis"
          />
          <.sdk_link
            label="PHP"
            registry="Packagist"
            url="https://packagist.org/packages/jobcelis/sdk"
          />
          <.sdk_link label="Ruby" registry="RubyGems" url="https://rubygems.org/gems/jobcelis" />
          <.sdk_link label="Elixir" registry="Hex.pm" url="https://hex.pm/packages/jobcelis" />
          <.sdk_link label=".NET" registry="NuGet" url="https://www.nuget.org/packages/Jobcelis" />
          <.sdk_link label="Rust" registry="crates.io" url="https://crates.io/crates/jobcelis" />
          <.sdk_link
            label="Swift"
            registry="SPM"
            url="https://github.com/vladimirCeli/jobcelis-swift"
          />
          <.sdk_link
            label="Java"
            registry="Maven Central"
            url="https://central.sonatype.com/artifact/com.jobcelis/jobcelis"
          />
          <.sdk_link label="Dart" registry="pub.dev" url="https://pub.dev/packages/jobcelis" />
          <.sdk_link
            label="Kotlin"
            registry="Maven Central"
            url="https://central.sonatype.com/artifact/com.jobcelis/jobcelis-kotlin"
          />
        </div>
      </div>

      <%!-- Send Event example --%>
      <h3 class="text-lg font-semibold text-slate-900 mb-3">{gettext("Enviar un evento")}</h3>
      <.sdk_code_block
        sdk_languages={@sdk_languages}
        example="send_event"
      />
    </.docs_section>

    <.docs_section
      id="cli"
      title="CLI"
      subtitle={gettext("Interfaz de línea de comandos para gestiónar eventos, webhooks y mas.")}
    >
      <p class="text-slate-600 text-sm mb-4">
        <a
          href="https://www.npmjs.com/package/@jobcelis/cli"
          target="_blank"
          rel="noopener"
          class="text-indigo-600 hover:text-indigo-800 font-medium underline"
        >
          @jobcelis/cli
        </a>
        {gettext(" en npm")}
      </p>
      <.code_block
        code={"npm install -g @jobcelis/cli\nexport JOBCELIS_API_KEY=\"YOUR_API_KEY\"\n\n# Send an event\njobcelis events send --topic order.created --payload '{\"id\":\"123\"}'\n\n# List events\njobcelis events list --limit 10\n\n# List webhooks\njobcelis webhooks list\n\n# Create a webhook\njobcelis webhooks create --url https://example.com/hook --topics \"order.*\"\n\n# Check platform status\njobcelis status"}
        copy_id="copy-cli"
      />
    </.docs_section>

    <.docs_section
      id="webhook-verification"
      title={gettext("Verificación de webhooks")}
      subtitle={gettext("Verifica la firma de cada entrega para asegurar que proviene de Jobcelis.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Cada entrega incluye una firma HMAC en el header X-Signature. Siempre verifica las firmas para asegurar que la petición proviene de Jobcelis."
        )}
      </p>

      <.sdk_code_block
        sdk_languages={@sdk_languages}
        example="verify_webhook"
      />

      <.callout kind="warning">
        {gettext(
          "Siempre usa comparación de tiempo constante. Nunca uses == o === para verificar firmas. Verifica el body crudo, no una versión re-serializada."
        )}
      </.callout>
    </.docs_section>
    """
  end

  # ══════════════════════════════════════════════════════════════════════
  # SECTION 7: SECURITY & COMPLIANCE
  # ══════════════════════════════════════════════════════════════════════

  attr :base_url, :string, required: true

  defp section_security(assigns) do
    ~H"""
    <.docs_section
      id="account-lockout"
      title={gettext("Bloqueo de cuenta")}
      subtitle={gettext("Proteccion contra ataques de fuerza bruta.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "Después de múltiples intentos de login fallidos en un periodo corto, la cuenta se bloquea temporalmente. Esto protege contra ataques de fuerza bruta y credenciales robadas."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="session-management"
      title={gettext("Gestión de sesiónes")}
      subtitle={gettext("Control de sesiónes activas.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "Las sesiónes web utilizan cookies cifradas con timeout de inactividad. Si no hay actividad durante un periodo, la sesión se cierra automáticamente."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="mfa-totp"
      title="MFA / TOTP"
      subtitle={gettext("Autenticación de dos factores.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Activa la autenticación de dos factores desde la página de cuenta. Usa una app de autenticación (Google Authenticator, Authy, etc.) para escanear el código QR. Cada vez que inicies sesión, ademas de tu contraseña necesitarás el código temporal de la app."
        )}
      </p>
      <.callout kind="tip">
        {gettext(
          "Al activar MFA se generan códigos de respaldo de un solo uso. Guárdalos en un lugar seguro para poder acceder si pierdes tu dispositivo."
        )}
      </.callout>
    </.docs_section>

    <.docs_section
      id="password-policy"
      title={gettext("Política de contraseñas")}
      subtitle={gettext("Requisitos para contraseñas seguras.")}
    >
      <div class="rounded-xl bg-slate-50 border border-slate-200 p-4">
        <ul class="text-slate-700 text-sm space-y-2">
          <li>{gettext("Longitud mínima requerida")}</li>
          <li>{gettext("Debe incluir mayúsculas, minúsculas y números")}</li>
          <li>{gettext("Se recomienda usar caracteres especiales")}</li>
          <li>{gettext("Las contraseñas se almacenan con hashing seguro basado en memoria")}</li>
        </ul>
      </div>
    </.docs_section>

    <.docs_section
      id="data-encryption"
      title={gettext("Cifrado de datos")}
      subtitle={gettext("Proteccion de datos personales.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Los datos personales (email, nombre) se cifran en reposo con cifrado de nivel industrial. Las busquedas por email usan un hash determinista para que no sea necesario descifrar para buscar."
        )}
      </p>
      <.callout kind="info">
        {gettext(
          "El cifrado en reposo protege tus datos incluso si alguien accede a la base de datos directamente. Solo la aplicación puede descifrar los datos."
        )}
      </.callout>
    </.docs_section>

    <.docs_section
      id="circuit-breaker"
      title="Circuit Breaker"
      subtitle={gettext("Proteccion automatica para webhooks inestables.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "Si un webhook falla repetidamente, el circuit breaker lo desactiva temporalmente para evitar sobrecarga. Cuando el endpoint se recupera, el webhook se reactiva automáticamente."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="breach-detection"
      title={gettext("Detección de brechas")}
      subtitle={gettext("Monitoreo continuo de seguridad.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "El sistema monitorea continuamente patrones anómalos como múltiples intentos fallidos, accesos desde ubicaciones inusuales y otros indicadores de posibles brechas de seguridad."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="event-integrity"
      title={gettext("Integridad de eventos")}
      subtitle={gettext("Garantiza que los eventos no se modifiquen.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Cada evento recibe un hash criptográfico único al crearse. Esto permite verificar que el contenido no ha sido alterado. Los eventos se almacenan de forma inmutable."
        )}
      </p>
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "Ademas, cada evento tiene un idempotency_key opcional para evitar duplicados. Si envías dos eventos con el mismo idempotency_key, solo el primero se procesa."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="uptime-monitoring"
      title={gettext("Monitoreo")}
      subtitle={gettext("Supervisión automatica de la plataforma.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "La plataforma se monitorea de forma continua. Puedes ver el estado actual en la página de estado (/status). Los componentes monitoreados incluyen la base de datos, el sistema de procesamiento y la cache."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="backups"
      title={gettext("Backups")}
      subtitle={gettext("Copias de seguridad automáticas.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "Se realizan copias de seguridad automáticas de forma periódica. Los backups se almacenan de forma segura y cifrada. En caso de incidente, los datos se pueden restaurar rápidamente."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="data-protection"
      title={gettext("GDPR / RGPD")}
      subtitle={gettext("Derechos de protección de datos.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext("Jobcelis cumple con el RGPD/GDPR. Como usuario tienes derecho a:")}
      </p>
      <ul class="text-slate-700 text-sm space-y-2 mb-4">
        <li>
          <strong>{gettext("Acceso:")}</strong> {gettext(
            "Exporta todos tus datos personales (GET /api/v1/me/data)"
          )}
        </li>
        <li>
          <strong>{gettext("Rectificación:")}</strong> {gettext("Actualiza tu perfil desde la cuenta")}
        </li>
        <li>
          <strong>{gettext("Restricción:")}</strong> {gettext(
            "Restringe el procesamiento (POST /api/v1/me/restrict)"
          )}
        </li>
        <li>
          <strong>{gettext("Objeción:")}</strong> {gettext(
            "Objeta el procesamiento (POST /api/v1/me/object)"
          )}
        </li>
        <li>
          <strong>{gettext("Portabilidad:")}</strong> {gettext(
            "Exporta datos en formato JSON estándar"
          )}
        </li>
      </ul>
    </.docs_section>

    <.docs_section
      id="consent-versióning"
      title={gettext("Consentimientos")}
      subtitle={gettext("Gestión versiónada de consentimientos GDPR.")}
    >
      <div class="space-y-4">
        <.api_endpoint
          id="consent-status"
          method="GET"
          path="/api/v1/me/consents"
          description={gettext("Estado de tus consentimientos.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/me/consents\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-consent-status"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "consents": [\n    {\n      "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "purpose": "essential",\n      "version": 1,\n      "granted_at": "2026-01-15T10:00:00Z"\n    },\n    {\n      "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",\n      "purpose": "analytics",\n      "version": 2,\n      "granted_at": "2026-02-20T14:00:00Z"\n    }\n  ],\n  "outdated": ["analytics"],\n  "current_versions": {\n    "essential": 1,\n    "analytics": 3\n  }\n}|
            }
            copy_id="copy-consent-status-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="consent-accept"
          method="POST"
          path="/api/v1/me/consents/:purpose/accept"
          description={gettext("Acepta un consentimiento.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/me/consents/analytics/accept\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-consent-accept"
          />
          <.code_block
            code={
              ~s|// Response (200 OK)\n{\n  "consent": {\n    "id": "c3d4e5f6-a7b8-9012-cdef-234567890abc",\n    "purpose": "analytics",\n    "version": 3,\n    "granted_at": "2026-03-07T14:30:00Z"\n  }\n}|
            }
            copy_id="copy-consent-accept-response"
            title={gettext("Respuesta")}
          />
        </.api_endpoint>
      </div>
    </.docs_section>
    """
  end

  # ══════════════════════════════════════════════════════════════════════
  # SECTION 8: REFERENCE
  # ══════════════════════════════════════════════════════════════════════

  attr :base_url, :string, required: true

  defp section_reference(assigns) do
    ~H"""
    <.docs_section
      id="status-codes"
      title={gettext("Códigos de respuesta")}
      subtitle={gettext("Códigos HTTP estándar usados por la API.")}
    >
      <div class="rounded-xl bg-slate-50 border border-slate-200 p-4 overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-slate-500 border-b border-slate-200">
              <th class="pb-2 font-medium">{gettext("Codigo")}</th>
              <th class="pb-2 font-medium">{gettext("Significado")}</th>
            </tr>
          </thead>
          <tbody class="text-slate-700">
            <tr>
              <td class="py-1.5 font-mono">200</td>
              <td class="py-1.5">OK</td>
            </tr>
            <tr>
              <td class="py-1.5 font-mono">201</td>
              <td class="py-1.5">Created</td>
            </tr>
            <tr>
              <td class="py-1.5 font-mono">204</td>
              <td class="py-1.5">No Content</td>
            </tr>
            <tr>
              <td class="py-1.5 font-mono">400</td>
              <td class="py-1.5">Bad Request</td>
            </tr>
            <tr>
              <td class="py-1.5 font-mono">401</td>
              <td class="py-1.5">Unauthorized</td>
            </tr>
            <tr>
              <td class="py-1.5 font-mono">403</td>
              <td class="py-1.5">Forbidden</td>
            </tr>
            <tr>
              <td class="py-1.5 font-mono">404</td>
              <td class="py-1.5">Not Found</td>
            </tr>
            <tr>
              <td class="py-1.5 font-mono">409</td>
              <td class="py-1.5">Conflict</td>
            </tr>
            <tr>
              <td class="py-1.5 font-mono">422</td>
              <td class="py-1.5">Unprocessable Entity</td>
            </tr>
            <tr>
              <td class="py-1.5 font-mono">429</td>
              <td class="py-1.5">Too Many Requests</td>
            </tr>
            <tr>
              <td class="py-1.5 font-mono">500</td>
              <td class="py-1.5">Internal Server Error</td>
            </tr>
          </tbody>
        </table>
      </div>
    </.docs_section>

    <.docs_section
      id="response-headers"
      title={gettext("Headers de respuesta")}
      subtitle={gettext("Headers incluidos en las respuestas de la API.")}
    >
      <div class="rounded-xl bg-slate-50 border border-slate-200 p-4 overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-slate-500 border-b border-slate-200">
              <th class="pb-2 font-medium">Header</th>
              <th class="pb-2 font-medium">{gettext("Descripción")}</th>
            </tr>
          </thead>
          <tbody class="text-slate-700">
            <tr>
              <td class="py-1.5 font-mono text-xs">X-Request-Id</td>
              <td class="py-1.5">{gettext("ID único de la petición para debugging")}</td>
            </tr>
            <tr>
              <td class="py-1.5 font-mono text-xs">X-RateLimit-Limit</td>
              <td class="py-1.5">{gettext("Limite de peticiones por ventana")}</td>
            </tr>
            <tr>
              <td class="py-1.5 font-mono text-xs">X-RateLimit-Remaining</td>
              <td class="py-1.5">{gettext("Peticiones restantes en la ventana")}</td>
            </tr>
            <tr>
              <td class="py-1.5 font-mono text-xs">X-RateLimit-Reset</td>
              <td class="py-1.5">{gettext("Timestamp de reset del rate limit")}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </.docs_section>

    <.docs_section
      id="health"
      title="Health Check"
      subtitle={gettext("Endpoint para monitoreo externo.")}
    >
      <.api_endpoint
        id="health-endpoint"
        method="GET"
        path="/health"
        description={gettext("Devuelve 200 si la plataforma esta operativa.")}
      >
        <.code_block
          code={"curl \"#{@base_url}/health\""}
          copy_id="copy-health"
        />
        <.code_block
          code={
            ~s|// Response (200 OK)\n{\n  "status": "healthy",\n  "timestamp": "2026-03-07T14:30:00Z"\n}|
          }
          copy_id="copy-health-response"
          title={gettext("Respuesta")}
        />
      </.api_endpoint>
    </.docs_section>

    <.docs_section
      id="api-key-scopes"
      title={gettext("Scopes de API Key")}
      subtitle={gettext("Permisos granulares para API keys.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Puedes configurar scopes para limitar lo que puede hacer cada API key. Los scopes disponibles incluyen:"
        )}
      </p>
      <div class="rounded-xl bg-slate-50 border border-slate-200 p-4">
        <div class="grid sm:grid-cols-2 gap-2 text-sm text-slate-700">
          <div>
            <code class="bg-white px-1.5 py-0.5 rounded border border-slate-200 font-mono text-xs">
              events:read
            </code>
            — {gettext("Leer eventos")}
          </div>
          <div>
            <code class="bg-white px-1.5 py-0.5 rounded border border-slate-200 font-mono text-xs">
              events:write
            </code>
            — {gettext("Crear eventos")}
          </div>
          <div>
            <code class="bg-white px-1.5 py-0.5 rounded border border-slate-200 font-mono text-xs">
              webhooks:read
            </code>
            — {gettext("Leer webhooks")}
          </div>
          <div>
            <code class="bg-white px-1.5 py-0.5 rounded border border-slate-200 font-mono text-xs">
              webhooks:write
            </code>
            — {gettext("Crear/editar webhooks")}
          </div>
          <div>
            <code class="bg-white px-1.5 py-0.5 rounded border border-slate-200 font-mono text-xs">
              jobs:read
            </code>
            — {gettext("Leer jobs")}
          </div>
          <div>
            <code class="bg-white px-1.5 py-0.5 rounded border border-slate-200 font-mono text-xs">
              jobs:write
            </code>
            — {gettext("Crear/editar jobs")}
          </div>
          <div>
            <code class="bg-white px-1.5 py-0.5 rounded border border-slate-200 font-mono text-xs">
              admin
            </code>
            — {gettext("Acceso total")}
          </div>
        </div>
      </div>
    </.docs_section>
    """
  end
end
