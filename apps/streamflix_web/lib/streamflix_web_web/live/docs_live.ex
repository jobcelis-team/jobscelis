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
          %{id: "simulate", label: gettext("Simulador")},
          %{id: "idempotency-keys", label: gettext("Claves de idempotencia")},
          %{id: "external-alerts", label: gettext("Alertas externas")},
          %{id: "embed-portal", label: gettext("Portal embebible")},
          %{id: "rate-limiting-outbound", label: gettext("Rate limiting saliente")},
          %{id: "prometheus-metrics", label: gettext("Métricas Prometheus")}
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

  # ── Reusable Components ───────────────────────────────────────────────

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  slot :inner_block, required: true

  defp docs_section(assigns) do
    ~H"""
    <section id={@id} class="mb-14 scroll-mt-24">
      <div class="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-700 shadow-sm overflow-hidden">
        <div class="px-8 py-6 border-b border-slate-200 dark:border-slate-700 bg-slate-50/80 dark:bg-slate-800/80">
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
    <div
      id={@id}
      class="rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50/50 dark:bg-slate-800/50 p-6 scroll-mt-24"
    >
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

  attr :code, :string, required: true
  attr :copy_id, :string, required: true
  attr :status, :string, required: true
  attr :note, :string, default: nil

  defp response_block(assigns) do
    status_num = assigns.status |> String.split(" ") |> List.first() |> String.to_integer()

    color =
      cond do
        status_num < 300 ->
          "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-300"

        status_num < 400 ->
          "bg-blue-100 text-blue-800 dark:bg-blue-900/40 dark:text-blue-300"

        status_num < 500 ->
          "bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300"

        true ->
          "bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-300"
      end

    assigns = assign(assigns, :color, color)

    ~H"""
    <div class="mt-5">
      <div class="flex items-center gap-2.5 mb-2">
        <span class="text-slate-500 dark:text-slate-400 text-xs font-semibold uppercase tracking-wider">
          {gettext("Respuesta")}
        </span>
        <span class={"inline-flex px-2 py-0.5 rounded-md text-xs font-bold font-mono #{@color}"}>
          {@status}
        </span>
      </div>
      <p :if={@note} class="text-slate-500 dark:text-slate-400 text-xs italic mb-2">{@note}</p>
      <div class="relative group">
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

  # ── Framework Example Component ────────────────────────────────────────

  attr :name, :string, required: true
  attr :code, :string, required: true

  defp framework_example(assigns) do
    ~H"""
    <details class="group border border-slate-200 dark:border-slate-700 rounded-lg">
      <summary class="px-4 py-2 cursor-pointer text-sm font-medium text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800/50 rounded-lg">
        {@name}
      </summary>
      <pre class="p-4 bg-slate-800 text-slate-100 text-xs overflow-x-auto font-mono rounded-b-lg"><code>{@code}</code></pre>
    </details>
    """
  end

  defp framework_code(:express) do
    ~s|const crypto = require('crypto');

app.post('/webhook', express.raw({ type: '*/*' }), (req, res) => {
  const signature = req.headers['x-signature'];
  const body = req.body.toString();
  if (!verifySignature(process.env.WEBHOOK_SECRET, body, signature)) {
    return res.status(401).send('Invalid signature');
  }
  const event = JSON.parse(body);
  // Process event...
  res.sendStatus(200);
});|
  end

  defp framework_code(:fastapi) do
    ~s|from fastapi import FastAPI, Request, HTTPException

@app.post("/webhook")
async def webhook(request: Request):
    body = (await request.body()).decode()
    signature = request.headers.get("x-signature", "")
    if not verify_signature(WEBHOOK_SECRET, body, signature):
        raise HTTPException(status_code=401, detail="Invalid signature")
    event = await request.json()
    # Process event...
    return {"ok": True}|
  end

  defp framework_code(:gin) do
    ~s|func webhookHandler(c *gin.Context) {
    body, _ := io.ReadAll(c.Request.Body)
    signature := c.GetHeader("X-Signature")
    if !jobcelis.VerifyWebhookSignature(secret, string(body), signature) {
        c.JSON(401, gin.H{"error": "invalid signature"})
        return
    }
    // Process event...
    c.JSON(200, gin.H{"ok": true})
}|
  end

  defp framework_code(:phoenix) do
    "defmodule MyAppWeb.WebhookController do\n" <>
      "  use MyAppWeb, :controller\n\n" <>
      "  def handle(conn, _params) do\n" <>
      "    {:ok, body, conn} = Plug.Conn.read_body(conn)\n" <>
      "    sig = Plug.Conn.get_req_header(conn, \"x-signature\") |> List.first(\"\")\n" <>
      "    if Jobcelis.WebhookVerifier.verify(secret, body, sig) do\n" <>
      "      event = Jason.decode!(body)\n" <>
      "      # Process event...\n" <>
      "      json(conn, %{ok: true})\n" <>
      "    else\n" <>
      "      conn |> put_status(401) |> json(%{error: \"invalid signature\"})\n" <>
      "    end\n" <>
      "  end\n" <>
      "end"
  end

  defp framework_code(:laravel) do
    ~s|Route::post('/webhook', function (Request $request) {
    $body = $request->getContent();
    $signature = $request->header('X-Signature', '');
    if (!WebhookVerifier::verify($secret, $body, $signature)) {
        return response()->json(['error' => 'invalid signature'], 401);
    }
    $event = json_decode($body, true);
    // Process event...
    return response()->json(['ok' => true]);
});|
  end

  defp framework_code(:spring) do
    "@PostMapping(\"/webhook\")\n" <>
      "public ResponseEntity<Map<String, Object>> webhook(\n" <>
      "        @RequestBody String body,\n" <>
      "        @RequestHeader(\"X-Signature\") String signature) {\n" <>
      "    if (!WebhookVerifier.verify(secret, body, signature)) {\n" <>
      "        return ResponseEntity.status(401).body(Map.of(\"error\", \"invalid signature\"));\n" <>
      "    }\n" <>
      "    // Process event...\n" <>
      "    return ResponseEntity.ok(Map.of(\"ok\", true));\n" <>
      "}"
  end

  defp framework_code(:aspnet) do
    "[HttpPost(\"webhook\")]\n" <>
      "public async Task<IActionResult> Webhook() {\n" <>
      "    using var reader = new StreamReader(Request.Body);\n" <>
      "    var body = await reader.ReadToEndAsync();\n" <>
      "    var signature = Request.Headers[\"X-Signature\"].FirstOrDefault() ?? \"\";\n" <>
      "    if (!WebhookVerifier.Verify(secret, body, signature))\n" <>
      "        return Unauthorized(new { error = \"invalid signature\" });\n" <>
      "    // Process event...\n" <>
      "    return Ok(new { ok = true });\n" <>
      "}"
  end

  defp framework_code(:rails) do
    "class WebhooksController < ApplicationController\n" <>
      "  skip_before_action :verify_authenticity_token\n\n" <>
      "  def handle\n" <>
      "    body = request.raw_post\n" <>
      "    signature = request.headers[\"X-Signature\"] || \"\"\n" <>
      "    unless Jobcelis::WebhookVerifier.verify(\n" <>
      "      secret: ENV[\"WEBHOOK_SECRET\"], body: body, signature: signature\n" <>
      "    )\n" <>
      "      return render json: { error: \"invalid signature\" }, status: 401\n" <>
      "    end\n" <>
      "    event = JSON.parse(body)\n" <>
      "    # Process event...\n" <>
      "    render json: { ok: true }\n" <>
      "  end\n" <>
      "end"
  end

  # ── SDK Code Block Component ──────────────────────────────────────────

  attr :sdk_languages, :list, required: true
  attr :example, :string, default: "send_event"

  defp sdk_code_block(assigns) do
    ~H"""
    <div class="rounded-xl border border-slate-200 overflow-hidden">
      <%!-- Language tabs --%>
      <div class="flex overflow-x-auto bg-slate-100 dark:bg-slate-800 border-b border-slate-200 dark:border-slate-700 px-2 py-1 gap-1">
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
        <pre class="p-4 bg-slate-800 dark:bg-slate-900 text-slate-100 text-xs overflow-x-auto font-mono"><span class="text-slate-400"># {gettext("Instalar")}</span>
    {sdk_install(lang)}

    <span class="text-slate-400"># {gettext("Uso")}</span>
    {sdk_usage(lang, @example)}</pre>
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
      class="group flex items-center gap-2 px-3 py-2.5 rounded-lg border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800 hover:bg-indigo-50 dark:hover:bg-indigo-900/30 hover:border-indigo-300 dark:hover:border-indigo-600 transition"
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

  defp sdk_usage("php", "verify_webhook") do
    ~s|<?php
function verifySignature(string $secret, string $body, string $signature): bool {
    if (!str_starts_with($signature, 'sha256=')) return false;
    $received = substr($signature, 7);
    $expected = rtrim(base64_encode(
        hash_hmac('sha256', $body, $secret, true)
    ), '=');
    return hash_equals($received, $expected);
}|
  end

  defp sdk_usage("ruby", "verify_webhook") do
    "require 'openssl'\n" <>
      "require 'base64'\n\n" <>
      "def verify_signature(secret, body, signature)\n" <>
      "  return false unless signature.start_with?('sha256=')\n" <>
      "  received = signature[7..]\n" <>
      "  expected = Base64.strict_encode64(\n" <>
      "    OpenSSL::HMAC.digest('sha256', secret, body)\n" <>
      "  ).delete_suffix('=')\n" <>
      "  Rack::Utils.secure_compare(received, expected)\n" <>
      "end"
  end

  defp sdk_usage("elixir", "verify_webhook") do
    "defmodule WebhookVerifier do\n" <>
      "  def verify_signature(secret, body, signature) do\n" <>
      "    case signature do\n" <>
      "      \"sha256=\" <> received ->\n" <>
      "        expected =\n" <>
      "          :crypto.mac(:hmac, :sha256, secret, body)\n" <>
      "          |> Base.encode64(padding: false)\n" <>
      "        Plug.Crypto.secure_compare(received, expected)\n" <>
      "      _ ->\n" <>
      "        false\n" <>
      "    end\n" <>
      "  end\n" <>
      "end"
  end

  defp sdk_usage("dotnet", "verify_webhook") do
    ~s|using System.Security.Cryptography;
using System.Text;

public static bool VerifySignature(string secret, string body, string signature) {
    if (!signature.StartsWith("sha256=")) return false;
    var received = signature.Substring(7);
    using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(secret));
    var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(body));
    var expected = Convert.ToBase64String(hash).TrimEnd('=');
    return CryptographicOperations.FixedTimeEquals(
        Encoding.UTF8.GetBytes(received),
        Encoding.UTF8.GetBytes(expected));
}|
  end

  defp sdk_usage("rust", "verify_webhook") do
    ~s|use hmac::{Hmac, Mac};
use sha2::Sha256;
use base64::engine::general_purpose::STANDARD_NO_PAD;
use base64::Engine;

fn verify_signature(secret: &str, body: &str, signature: &str) -> bool {
    let received = match signature.strip_prefix("sha256=") {
        Some(s) => s,
        None => return false,
    };
    let mut mac = Hmac::<Sha256>::new_from_slice(secret.as_bytes()).unwrap();
    mac.update(body.as_bytes());
    let expected = STANDARD_NO_PAD.encode(mac.finalize().into_bytes());
    received == expected
}|
  end

  defp sdk_usage("swift", "verify_webhook") do
    ~s|import CryptoKit
import Foundation

func verifySignature(secret: String, body: String, signature: String) -> Bool {
    guard signature.hasPrefix("sha256=") else { return false }
    let received = String(signature.dropFirst(7))
    let key = SymmetricKey(data: Data(secret.utf8))
    let mac = HMAC<SHA256>.authenticationCode(
        for: Data(body.utf8), using: key
    )
    let expected = Data(mac).base64EncodedString()
        .replacingOccurrences(of: "=", with: "")
    return received == expected
}|
  end

  defp sdk_usage("java", "verify_webhook") do
    ~s|import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.util.Base64;

public static boolean verifySignature(String secret, String body, String signature) {
    if (!signature.startsWith("sha256=")) return false;
    String received = signature.substring(7);
    Mac mac = Mac.getInstance("HmacSHA256");
    mac.init(new SecretKeySpec(secret.getBytes("UTF-8"), "HmacSHA256"));
    byte[] hash = mac.doFinal(body.getBytes("UTF-8"));
    String expected = Base64.getEncoder().withoutPadding().encodeToString(hash);
    return MessageDigest.isEqual(received.getBytes(), expected.getBytes());
}|
  end

  defp sdk_usage("dart", "verify_webhook") do
    ~s|import 'dart:convert';
import 'package:crypto/crypto.dart';

bool verifySignature(String secret, String body, String signature) {
  if (!signature.startsWith('sha256=')) return false;
  final received = signature.substring(7);
  final hmac = Hmac(sha256, utf8.encode(secret));
  final digest = hmac.convert(utf8.encode(body));
  final expected = base64Encode(digest.bytes).replaceAll('=', '');
  return received == expected;
}|
  end

  defp sdk_usage("kotlin", "verify_webhook") do
    ~s|import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import java.security.MessageDigest
import java.util.Base64

fun verifySignature(secret: String, body: String, signature: String): Boolean {
    if (!signature.startsWith("sha256=")) return false
    val received = signature.removePrefix("sha256=")
    val mac = Mac.getInstance("HmacSHA256")
    mac.init(SecretKeySpec(secret.toByteArray(), "HmacSHA256"))
    val hash = mac.doFinal(body.toByteArray())
    val expected = Base64.getEncoder().withoutPadding().encodeToString(hash)
    return MessageDigest.isEqual(received.toByteArray(), expected.toByteArray())
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
      subtitle={gettext("Qué es Jobcelis y capacidades de la API.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "Jobcelis es una plataforma de eventos y webhooks completamente configurable. Permite enviar cualquier JSON mediante HTTP POST; la plataforma enruta, filtra, transforma y entrega a las URLs de destino configuradas. Sin esquemas fijos: los topics, payloads y reglas se definen libremente."
        )}
      </p>
      <div class="grid sm:grid-cols-2 gap-4">
        <div class="rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-4">
          <h3 class="font-semibold text-slate-900 mb-2 text-sm">
            {gettext("Capacidades principales")}
          </h3>
          <ul class="text-slate-600 text-sm space-y-1.5">
            <li>
              <strong>{gettext("Eventos:")}</strong> {gettext(
                "envío de JSON con topic opcional via POST. Sin restricción de esquema."
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
                "programación daily, weekly, monthly o expresión cron. Emite eventos o ejecuta POST a URLs de destino."
              )}
            </li>
            <li><strong>Topics:</strong> {gettext("etiquetas para filtrar y organizar eventos.")}</li>
          </ul>
        </div>
        <div class="rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-4">
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
      subtitle={gettext("Conceptos fundamentales de la plataforma.")}
    >
      <div class="space-y-6">
        <div class="rounded-xl border border-slate-200 dark:border-slate-700 border-l-4 border-l-indigo-500 bg-slate-50/50 dark:bg-slate-800/50 p-6">
          <h3 class="text-lg font-semibold text-slate-900 mb-3">{gettext("Qué es un evento?")}</h3>
          <p class="text-slate-700 leading-relaxed mb-4">
            {gettext(
              "Un evento es un mensaje JSON enviado a Jobcelis mediante HTTP POST. Acepta cualquier estructura JSON: pedidos, pagos, registros, etc. Opcionalmente incluye un topic para clasificación. Jobcelis persiste el evento y, según los webhooks configurados, entrega la información a las URLs de destino especificadas."
            )}
          </p>
          <.code_block
            code={~s|{"topic": "order.created", "order_id": 123, "total": 99.99}|}
            copy_id="copy-event-example"
            title={gettext("Ejemplo")}
          />
        </div>

        <div class="rounded-xl border border-slate-200 dark:border-slate-700 border-l-4 border-l-indigo-500 bg-slate-50/50 dark:bg-slate-800/50 p-6">
          <h3 class="text-lg font-semibold text-slate-900 mb-3">{gettext("Qué es un webhook?")}</h3>
          <p class="text-slate-700 leading-relaxed">
            {gettext(
              "Un webhook es una URL de destino configurada en el proyecto. Cuando un evento cumple las condiciones especificadas (topic, filtros), Jobcelis realiza un POST a esa URL con el payload configurado."
            )}
          </p>
        </div>

        <div class="rounded-xl border border-slate-200 dark:border-slate-700 border-l-4 border-l-indigo-500 bg-slate-50/50 dark:bg-slate-800/50 p-6">
          <h3 class="text-lg font-semibold text-slate-900 mb-3">
            {gettext("Qué es una entrega (delivery)?")}
          </h3>
          <p class="text-slate-700 leading-relaxed">
            {gettext(
              "Cada intento de envío de un evento a una URL de webhook genera un registro de entrega (delivery). El registro tiene estados: pending, success o failed. En caso de fallo, Jobcelis reintenta automáticamente con backoff exponencial."
            )}
          </p>
        </div>

        <div class="rounded-xl border border-slate-200 dark:border-slate-700 border-l-4 border-l-indigo-500 bg-slate-50/50 dark:bg-slate-800/50 p-6">
          <h3 class="text-lg font-semibold text-slate-900 mb-3">{gettext("Qué es un job?")}</h3>
          <p class="text-slate-700 leading-relaxed">
            {gettext(
              "Un job es una tarea programada con schedule daily, weekly, monthly o expresión cron. Al ejecutarse, emite un evento interno o realiza un POST a una URL externa."
            )}
          </p>
        </div>

        <div class="rounded-xl border border-slate-200 dark:border-slate-700 border-l-4 border-l-indigo-500 bg-slate-50/50 dark:bg-slate-800/50 p-6">
          <h3 class="text-lg font-semibold text-slate-900 mb-3">{gettext("Qué es un topic?")}</h3>
          <p class="text-slate-700 leading-relaxed">
            {gettext(
              "El topic es una etiqueta opcional para clasificar eventos (ej. order.created, payment.completed). Se utiliza como criterio de filtrado en webhooks. La nomenclatura es libre y definida por el usuario."
            )}
          </p>
        </div>
      </div>
    </.docs_section>

    <%!-- Quick Start --%>
    <.docs_section
      id="quick-start"
      title={gettext("Inicio rápido")}
      subtitle={gettext("Pasos de configuración inicial para integrar la API.")}
    >
      <div class="space-y-6">
        <.quick_start_step
          number={1}
          title={gettext("Regístrate e inicia sesión")}
          description={
            gettext("Crear una cuenta en la plataforma con email y contraseña. Acceder al Dashboard.")
          }
        />
        <.quick_start_step
          number={2}
          title={gettext("Obtener el API Token")}
          description={
            gettext(
              "El token API se encuentra en la sección API Token del Dashboard. Almacenar el token completo de forma segura; se requiere en todas las solicitudes con header Authorization: Bearer TU_TOKEN o X-Api-Key: TU_TOKEN."
            )
          }
        />
        <.quick_start_step number={3} title={gettext("Enviar el primer evento")}>
          <p class="text-slate-600 text-sm leading-relaxed mb-3">
            {gettext("Enviar una solicitud POST a /api/v1/events con body JSON.")}
          </p>
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/events\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"topic\":\"test\",\"message\":\"Hello\"}'"}
            copy_id="copy-quickstart-curl"
          />
        </.quick_start_step>
        <.quick_start_step
          number={4}
          title={gettext("Configurar un webhook")}
          description={
            gettext(
              "En el Dashboard, Webhooks > Crear. Configurar una URL accesible que acepte solicitudes POST. Opcionalmente, especificar un topic para filtrar eventos."
            )
          }
        />
        <.quick_start_step
          number={5}
          title={gettext("Configurar un job (opcional)")}
          description={
            gettext(
              "En el Dashboard, Jobs > Crear. Seleccionar schedule (daily, weekly, monthly o cron) y acción (emitir evento o POST a URL)."
            )
          }
          last={true}
        />

        <.callout kind="warning">
          {gettext(
            "En caso de error, verificar que el token API esté incluido correctamente en el header Authorization y que la URL del webhook sea accesible públicamente. Las entregas fallidas pueden reintentarse desde el Dashboard."
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
    <div class="flex gap-4 rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800/50 p-5 hover:border-indigo-200 dark:hover:border-indigo-600 transition">
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
          "En producción, la URL base corresponde al dominio configurado. Los ejemplos curl incluyen esta base."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="auth"
      title={gettext("Autenticación")}
      subtitle={gettext("Métodos de autenticación: API Key y JWT.")}
    >
      <div>
        <h3 class="text-lg font-semibold text-slate-900 mb-3">{gettext("Rutas con API Key")}</h3>
        <p class="text-slate-600 mb-3">
          {gettext("La autenticación por token soporta tres métodos:")}
        </p>
        <ol class="list-decimal list-inside text-slate-700 space-y-2 mb-3">
          <li>
            {gettext("Header")}
            <code class="bg-slate-100 dark:bg-slate-800 px-2 py-1 rounded font-mono text-sm dark:text-slate-200">
              Authorization: Bearer &lt;token&gt;
            </code>
          </li>
          <li>
            {gettext("Header")}
            <code class="bg-slate-100 dark:bg-slate-800 px-2 py-1 rounded font-mono text-sm dark:text-slate-200">
              X-Api-Key: &lt;token&gt;
            </code>
          </li>
          <li>
            {gettext("Query param")}
            <code class="bg-slate-100 dark:bg-slate-800 px-2 py-1 rounded font-mono text-sm dark:text-slate-200">
              ?api_key=&lt;token&gt;
            </code>
          </li>
        </ol>
        <p class="text-slate-600 text-sm">
          {gettext(
            "El token API se genera en la sección API Token del Dashboard. El valor completo se muestra únicamente en el momento de creación. Debe almacenarse de forma segura."
          )}
        </p>
      </div>
      <div class="border-t border-slate-200 pt-6">
        <h3 class="text-lg font-semibold text-slate-900 mb-3">{gettext("Rutas publicas (Auth)")}</h3>
        <p class="text-slate-600 text-sm">
          {gettext(
            "Los endpoints de autenticación no requieren API Key. Los endpoints de registro y login devuelven un JWT para autenticación en la aplicación."
          )}
        </p>
      </div>
    </.docs_section>

    <.docs_section
      id="cors"
      title="CORS"
      subtitle={gettext("Configuración de Cross-Origin Resource Sharing (CORS).")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "La API tiene CORS habilitado para cualquier origen (Access-Control-Allow-Origin: *). Cualquier frontend puede consumir la API sin bloqueos del navegador."
        )}
      </p>
      <div class="rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-4">
        <p class="font-medium text-slate-800 mb-2 text-sm">{gettext("Headers permitidos:")}</p>
        <ul class="text-slate-600 text-sm space-y-1">
          <li>
            <code class="bg-white dark:bg-slate-800 px-1.5 py-0.5 rounded border border-slate-200 dark:border-slate-600 font-mono dark:text-slate-200">
              Authorization
            </code>
          </li>
          <li>
            <code class="bg-white dark:bg-slate-800 px-1.5 py-0.5 rounded border border-slate-200 dark:border-slate-600 font-mono dark:text-slate-200">
              X-Api-Key
            </code>
          </li>
          <li>
            <code class="bg-white dark:bg-slate-800 px-1.5 py-0.5 rounded border border-slate-200 dark:border-slate-600 font-mono dark:text-slate-200">Content-Type</code>,
            <code class="bg-white dark:bg-slate-800 px-1.5 py-0.5 rounded border border-slate-200 dark:border-slate-600 font-mono dark:text-slate-200">
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
          <.response_block
            code={
              ~s|{\n  "user": {\n    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "email": "test@example.com",\n    "name": "Test"\n  },\n  "token": "eyJhbGciOiJIUzI1NiIs...",\n  "api_key": "jc_live_a1b2c3d4e5f6..."\n}|
            }
            copy_id="copy-auth-register-response"
            status="201 Created"
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
          <.response_block
            code={
              ~s|{\n  "user": {\n    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "email": "test@example.com",\n    "name": "Test"\n  },\n  "token": "eyJhbGciOiJIUzI1NiIs..."\n}\n\n{\n  "mfa_required": true,\n  "mfa_token": "eyJhbGciOiJIUzI1NiIs..."\n}|
            }
            copy_id="copy-auth-login-response"
            status="200 OK"
            note={gettext("Si MFA está habilitado, se retorna mfa_required en vez del token.")}
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
          <.response_block
            code={~s|{\n  "token": "eyJhbGciOiJIUzI1NiIs..."\n}|}
            copy_id="copy-auth-refresh-response"
            status="200 OK"
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
          <.response_block
            code={
              ~s|{\n  "user": {\n    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "email": "test@example.com",\n    "name": "Test"\n  },\n  "token": "eyJhbGciOiJIUzI1NiIs..."\n}|
            }
            copy_id="copy-auth-mfa-response"
            status="200 OK"
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <%!-- Events --%>
    <.docs_section
      id="events"
      title={gettext("Eventos")}
      subtitle={gettext("Gestión de eventos: creación, listado y consulta.")}
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
          <.response_block
            code={
              ~s|{\n  "event_id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",\n  "payload_hash": "sha256:a3f2b8c1d4e5..."\n}|
            }
            copy_id="copy-events-create-response"
            status="202 Accepted"
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
          <.response_block
            code={
              ~s|{\n  "events": [\n    {\n      "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",\n      "topic": "order.created",\n      "payload": {"order_id": "12345", "amount": 99.99},\n      "status": "active",\n      "occurred_at": "2026-01-15T10:30:00Z",\n      "deliver_at": null,\n      "payload_hash": "sha256:a3f2b8c1d4e5...",\n      "idempotency_key": null,\n      "inserted_at": "2026-01-15T10:30:00Z"\n    }\n  ],\n  "has_next": true,\n  "next_cursor": "c3d4e5f6-a7b8-9012-cdef-123456789012"\n}|
            }
            copy_id="copy-events-list-response"
            status="200 OK"
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
          <.response_block
            code={
              ~s|{\n  "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",\n  "topic": "order.created",\n  "payload": {"order_id": "12345", "amount": 99.99},\n  "status": "active",\n  "occurred_at": "2026-01-15T10:30:00Z",\n  "deliver_at": null,\n  "payload_hash": "sha256:a3f2b8c1d4e5...",\n  "idempotency_key": null,\n  "inserted_at": "2026-01-15T10:30:00Z",\n  "deliveries": [\n    {"id": "d4e5f6a7-b8c9-0123-defg-234567890123", "status": "success", "attempt_number": 1}\n  ]\n}|
            }
            copy_id="copy-events-show-response"
            status="200 OK"
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
          <.response_block
            code={~s|{\n  "status": "inactive"\n}|}
            copy_id="copy-events-delete-response"
            status="200 OK"
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <%!-- Webhooks --%>
    <.docs_section
      id="webhooks"
      title="Webhooks"
      subtitle={gettext("Crear, listar y gestionar webhooks.")}
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
          <.response_block
            code={
              ~s|{\n  "webhooks": [\n    {\n      "id": "c3d4e5f6-a7b8-9012-cdef-123456789012",\n      "url": "https://example.com/hook",\n      "status": "active",\n      "topics": ["order.*"],\n      "filters": [],\n      "body_config": {},\n      "headers": {},\n      "retry_config": {},\n      "inserted_at": "2026-01-10T08:00:00Z"\n    }\n  ]\n}|
            }
            copy_id="copy-webhooks-list-response"
            status="200 OK"
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
          <.response_block
            code={
              ~s|{\n  "id": "c3d4e5f6-a7b8-9012-cdef-123456789012",\n  "url": "https://example.com/hook",\n  "status": "active",\n  "topics": ["order.*"],\n  "filters": [],\n  "body_config": {},\n  "headers": {},\n  "retry_config": {},\n  "inserted_at": "2026-01-10T08:00:00Z"\n}|
            }
            copy_id="copy-webhooks-create-response"
            status="201 Created"
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
          <.response_block
            code={
              ~s|{\n  "id": "c3d4e5f6-a7b8-9012-cdef-123456789012",\n  "url": "https://example.com/hook",\n  "status": "active",\n  "topics": ["order.*"],\n  "filters": [],\n  "body_config": {},\n  "headers": {},\n  "retry_config": {},\n  "inserted_at": "2026-01-10T08:00:00Z"\n}|
            }
            copy_id="copy-webhooks-show-response"
            status="200 OK"
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
          <.response_block
            code={
              ~s|{\n  "id": "c3d4e5f6-a7b8-9012-cdef-123456789012",\n  "url": "https://example.com/hook",\n  "status": "active",\n  "topics": ["order.*"],\n  "filters": [],\n  "body_config": {},\n  "headers": {},\n  "retry_config": {},\n  "inserted_at": "2026-01-10T08:00:00Z"\n}|
            }
            copy_id="copy-webhooks-update-response"
            status="200 OK"
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
          <.response_block
            code={~s|{\n  "status": "inactive"\n}|}
            copy_id="copy-webhooks-delete-response"
            status="200 OK"
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
          <.response_block
            code={
              ~s|{\n  "deliveries": [\n    {\n      "id": "d4e5f6a7-b8c9-0123-defg-234567890123",\n      "event_id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",\n      "webhook_id": "c3d4e5f6-a7b8-9012-cdef-123456789012",\n      "status": "failed",\n      "attempt_number": 3,\n      "response_status": 500,\n      "next_retry_at": "2026-01-15T11:00:00Z",\n      "inserted_at": "2026-01-15T10:30:00Z"\n    }\n  ],\n  "has_next": false,\n  "next_cursor": null\n}|
            }
            copy_id="copy-deliveries-list-response"
            status="200 OK"
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
          <.response_block
            code={~s|{\n  "status": "retry_queued"\n}|}
            copy_id="copy-deliveries-retry-response"
            status="200 OK"
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
          <.response_block
            code={
              ~s|{\n  "jobs": [\n    {\n      "id": "e5f6a7b8-c9d0-1234-efgh-345678901234",\n      "name": "Daily Report",\n      "schedule_type": "daily",\n      "schedule_config": {},\n      "action_type": "emit_event",\n      "action_config": {"topic": "report.daily", "payload": {}},\n      "status": "active",\n      "inserted_at": "2026-01-05T12:00:00Z"\n    }\n  ]\n}|
            }
            copy_id="copy-jobs-list-response"
            status="200 OK"
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
          <.response_block
            code={
              ~s|{\n  "id": "e5f6a7b8-c9d0-1234-efgh-345678901234",\n  "name": "Daily Report",\n  "schedule_type": "daily",\n  "schedule_config": {},\n  "action_type": "emit_event",\n  "action_config": {"topic": "report.daily", "payload": {}},\n  "status": "active",\n  "inserted_at": "2026-01-15T10:30:00Z"\n}|
            }
            copy_id="copy-jobs-create-response"
            status="201 Created"
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
          <.response_block
            code={
              ~s|{\n  "id": "e5f6a7b8-c9d0-1234-efgh-345678901234",\n  "name": "Daily Report",\n  "schedule_type": "daily",\n  "schedule_config": {},\n  "action_type": "emit_event",\n  "action_config": {"topic": "report.daily", "payload": {}},\n  "status": "active",\n  "inserted_at": "2026-01-05T12:00:00Z",\n  "recent_runs": [\n    {"id": "f6a7b8c9-d0e1-2345-fghi-456789012345", "executed_at": "2026-01-15T00:00:00Z", "status": "success", "result": null}\n  ]\n}|
            }
            copy_id="copy-jobs-show-response"
            status="200 OK"
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
          <.response_block
            code={
              ~s|{\n  "id": "e5f6a7b8-c9d0-1234-efgh-345678901234",\n  "name": "Updated Report",\n  "schedule_type": "daily",\n  "schedule_config": {},\n  "action_type": "emit_event",\n  "action_config": {"topic": "report.daily", "payload": {}},\n  "status": "active",\n  "inserted_at": "2026-01-05T12:00:00Z"\n}|
            }
            copy_id="copy-jobs-update-response"
            status="200 OK"
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
          <.response_block
            code={~s|{\n  "status": "inactive"\n}|}
            copy_id="copy-jobs-delete-response"
            status="200 OK"
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
          <.response_block
            code={
              ~s|{\n  "runs": [\n    {\n      "id": "f6a7b8c9-d0e1-2345-fghi-456789012345",\n      "executed_at": "2026-01-15T00:00:00Z",\n      "status": "success",\n      "result": null\n    }\n  ]\n}|
            }
            copy_id="copy-jobs-runs-response"
            status="200 OK"
          />
        </.api_endpoint>

        <.api_endpoint
          id="jobs-cron-preview"
          method="GET"
          path="/api/v1/jobs/cron-preview"
          description={gettext("Previsualiza próximas ejecuciones de una expresión cron.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/jobs/cron-preview?expression=*/15+*+*+*+*\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-jobs-cron-preview"
          />
          <.response_block
            code={
              ~s|{\n  "expression": "*/15 * * * *",\n  "next_executions": [\n    "2026-01-15T10:45:00Z",\n    "2026-01-15T11:00:00Z",\n    "2026-01-15T11:15:00Z",\n    "2026-01-15T11:30:00Z",\n    "2026-01-15T11:45:00Z"\n  ]\n}|
            }
            copy_id="copy-jobs-cron-preview-response"
            status="200 OK"
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <%!-- Project & Token --%>
    <.docs_section
      id="project-token"
      title={gettext("Proyecto y token")}
      subtitle={gettext("Consultar y actualizar el proyecto, gestionar API tokens.")}
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
          <.response_block
            code={
              ~s|{\n  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n  "name": "My Project",\n  "status": "active",\n  "settings": {}\n}|
            }
            copy_id="copy-project-show-response"
            status="200 OK"
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
          <.response_block
            code={
              ~s|{\n  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n  "name": "My Project",\n  "status": "active"\n}|
            }
            copy_id="copy-project-update-response"
            status="200 OK"
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
          <.response_block
            code={
              ~s|{\n  "topics": ["order.created", "order.updated", "payment.completed", "user.registered"]\n}|
            }
            copy_id="copy-project-topics-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="project-token-show"
          method="GET"
          path="/api/v1/token"
          description={gettext("Muestra información del token API actual (prefix).")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/token\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-project-token-show"
          />
          <.response_block
            code={
              ~s|{\n  "prefix": "jc_live_a1b2",\n  "message": "Use Authorization: Bearer <your_key>. Regenerate from dashboard to get a new key."\n}|
            }
            copy_id="copy-project-token-show-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="project-token-regen"
          method="POST"
          path="/api/v1/token/regenerate"
          description={
            gettext("Regenera el API token. El token anterior se invalida inmediatamente.")
          }
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/token/regenerate\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-project-token-regen"
          />
          <.response_block
            code={
              ~s|{\n  "token": "jc_live_new_token_value_here...",\n  "message": "The previous token no longer works. Only this token is valid. Save it; it is only shown once."\n}|
            }
            copy_id="copy-project-token-regen-response"
            status="200 OK"
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
      subtitle={
        gettext("Pipelines de procesamiento de eventos con pasos secuenciales de transformación.")
      }
    >
      <div class="space-y-6">
        <.api_endpoint
          id="pipelines-list"
          method="GET"
          path="/api/v1/pipelines"
          description={gettext("Lista los pipelines del proyecto.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/pipelines\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-pipelines-list"
          />
          <.response_block
            code={
              ~s|{\n  "data": [\n    {\n      "id": "f6a7b8c9-d0e1-2345-fghi-456789012345",\n      "name": "Order Pipeline",\n      "status": "active",\n      "description": "Process orders",\n      "topics": ["order.*"],\n      "steps": [{"type": "filter", "config": {"field": "amount", "operator": "gt", "value": 100}}],\n      "webhook_id": null,\n      "inserted_at": "2026-01-10T08:00:00Z"\n    }\n  ]\n}|
            }
            copy_id="copy-pipelines-list-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="pipelines-create"
          method="POST"
          path="/api/v1/pipelines"
          description={gettext("Crea un nuevo pipeline de procesamiento.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/pipelines\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"name\":\"Order Pipeline\",\"description\":\"Process orders\",\"steps\":[{\"type\":\"filter\",\"config\":{\"field\":\"amount\",\"operator\":\"gt\",\"value\":100}}]}'"}
            copy_id="copy-pipelines-create"
          />
          <.response_block
            code={
              ~s|{\n  "data": {\n    "id": "f6a7b8c9-d0e1-2345-fghi-456789012345",\n    "name": "Order Pipeline",\n    "status": "active",\n    "description": "Process orders",\n    "topics": null,\n    "steps": [{"type": "filter", "config": {"field": "amount", "operator": "gt", "value": 100}}],\n    "webhook_id": null,\n    "inserted_at": "2026-01-15T10:30:00Z"\n  }\n}|
            }
            copy_id="copy-pipelines-create-response"
            status="201 Created"
          />
        </.api_endpoint>
        <.api_endpoint
          id="pipelines-show"
          method="GET"
          path="/api/v1/pipelines/:id"
          description={gettext("Obtiene la configuración detallada de un pipeline.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/pipelines/PIPELINE_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-pipelines-show"
          />
          <.response_block
            code={
              ~s|{\n  "data": {\n    "id": "f6a7b8c9-d0e1-2345-fghi-456789012345",\n    "name": "Order Pipeline",\n    "status": "active",\n    "description": "Process orders",\n    "topics": ["order.*"],\n    "steps": [{"type": "filter", "config": {"field": "amount", "operator": "gt", "value": 100}}],\n    "webhook_id": null,\n    "inserted_at": "2026-01-10T08:00:00Z"\n  }\n}|
            }
            copy_id="copy-pipelines-show-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="pipelines-update"
          method="PATCH"
          path="/api/v1/pipelines/:id"
          description={gettext("Actualiza la configuración de un pipeline.")}
        >
          <.code_block
            code={"curl -X PATCH \"#{@base_url}/api/v1/pipelines/PIPELINE_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"name\":\"Updated Pipeline\",\"description\":\"New description\"}'"}
            copy_id="copy-pipelines-update"
          />
          <.response_block
            code={
              ~s|{\n  "data": {\n    "id": "f6a7b8c9-d0e1-2345-fghi-456789012345",\n    "name": "Updated Pipeline",\n    "status": "active",\n    "description": "New description",\n    "topics": ["order.*"],\n    "steps": [{"type": "filter", "config": {"field": "amount", "operator": "gt", "value": 100}}],\n    "webhook_id": null,\n    "inserted_at": "2026-01-10T08:00:00Z"\n  }\n}|
            }
            copy_id="copy-pipelines-update-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="pipelines-delete"
          method="DELETE"
          path="/api/v1/pipelines/:id"
          description={gettext("Elimina un pipeline y sus configuraciones asociadas.")}
        >
          <.code_block
            code={"curl -X DELETE \"#{@base_url}/api/v1/pipelines/PIPELINE_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-pipelines-delete"
          />
          <.response_block
            code={gettext("Sin contenido.")}
            copy_id="copy-pipelines-delete-response"
            status="204 No Content"
          />
        </.api_endpoint>
        <.api_endpoint
          id="pipelines-test"
          method="POST"
          path="/api/v1/pipelines/:id/test"
          description={
            gettext("Ejecuta un pipeline con un payload de prueba sin persistir resultados.")
          }
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/pipelines/PIPELINE_ID/test\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"topic\":\"order.created\",\"payload\":{\"order_id\":\"123\",\"amount\":99.99}}'"}
            copy_id="copy-pipelines-test"
          />
          <.response_block
            code={
              ~s|{\n  "input": {"order_id": "123", "amount": 99.99},\n  "output": {"order_id": "123", "amount": 99.99},\n  "steps_count": 1,\n  "status": "passed"\n}|
            }
            copy_id="copy-pipelines-test-response"
            status="200 OK"
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <%!-- Dead Letters --%>
    <.docs_section
      id="dead-letters"
      title="Dead Letters"
      subtitle={gettext("Eventos que agotaron todos los intentos de entrega configurados.")}
    >
      <div class="space-y-6">
        <.api_endpoint
          id="dead-letters-list"
          method="GET"
          path="/api/v1/dead-letters"
          description={gettext("Lista los eventos no entregados (dead letters) del proyecto.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/dead-letters\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-dead-letters-list"
          />
          <.response_block
            code={
              ~s|{\n  "dead_letters": [\n    {\n      "id": "a7b8c9d0-e1f2-3456-ghij-567890123456",\n      "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "delivery_id": "d4e5f6a7-b8c9-0123-defg-234567890123",\n      "event_id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",\n      "webhook_id": "c3d4e5f6-a7b8-9012-cdef-123456789012",\n      "webhook_url": "https://example.com/hook",\n      "original_payload": {"order_id": "12345"},\n      "last_error": "Connection refused",\n      "last_response_status": null,\n      "attempts_exhausted": 5,\n      "resolved": false,\n      "resolved_at": null,\n      "inserted_at": "2026-01-15T10:30:00Z"\n    }\n  ]\n}|
            }
            copy_id="copy-dead-letters-list-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="dead-letters-show"
          method="GET"
          path="/api/v1/dead-letters/:id"
          description={gettext("Obtiene los detalles completos de un dead letter.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/dead-letters/DEAD_LETTER_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-dead-letters-show"
          />
          <.response_block
            code={
              ~s|{\n  "id": "a7b8c9d0-e1f2-3456-ghij-567890123456",\n  "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n  "delivery_id": "d4e5f6a7-b8c9-0123-defg-234567890123",\n  "event_id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",\n  "webhook_id": "c3d4e5f6-a7b8-9012-cdef-123456789012",\n  "webhook_url": "https://example.com/hook",\n  "original_payload": {"order_id": "12345"},\n  "last_error": "Connection refused",\n  "last_response_status": null,\n  "attempts_exhausted": 5,\n  "resolved": false,\n  "resolved_at": null,\n  "inserted_at": "2026-01-15T10:30:00Z"\n}|
            }
            copy_id="copy-dead-letters-show-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="dead-letters-retry"
          method="POST"
          path="/api/v1/dead-letters/:id/retry"
          description={gettext("Reintenta la entrega de un dead letter al endpoint de webhook.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/dead-letters/DEAD_LETTER_ID/retry\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-dead-letters-retry"
          />
          <.response_block
            code={
              ~s|{\n  "status": "retrying",\n  "delivery_id": "d4e5f6a7-b8c9-0123-defg-234567890123"\n}|
            }
            copy_id="copy-dead-letters-retry-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="dead-letters-resolve"
          method="PATCH"
          path="/api/v1/dead-letters/:id/resolve"
          description={gettext("Marca un dead letter como resuelto, removiéndolo de la cola.")}
        >
          <.code_block
            code={"curl -X PATCH \"#{@base_url}/api/v1/dead-letters/DEAD_LETTER_ID/resolve\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-dead-letters-resolve"
          />
          <.response_block
            code={~s|{\n  "status": "resolved"\n}|}
            copy_id="copy-dead-letters-resolve-response"
            status="200 OK"
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <%!-- Replays --%>
    <.docs_section
      id="replays"
      title={gettext("Event Replay")}
      subtitle={gettext("Re-entrega eventos históricos a los endpoints de webhook.")}
    >
      <div class="space-y-6">
        <.api_endpoint
          id="replays-create"
          method="POST"
          path="/api/v1/replays"
          description={
            gettext("Crea un job de replay para re-entregar eventos en un rango de tiempo.")
          }
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/replays\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"webhook_id\":\"WEBHOOK_ID\",\"from\":\"2026-01-01T00:00:00Z\",\"to\":\"2026-01-31T23:59:59Z\"}'"}
            copy_id="copy-replays-create"
          />
          <.response_block
            code={
              ~s|{\n  "id": "b8c9d0e1-f2a3-4567-hijk-678901234567",\n  "status": "pending",\n  "filters": {"webhook_id": "WEBHOOK_ID", "from_date": "2026-01-01T00:00:00Z", "to_date": "2026-01-31T23:59:59Z"},\n  "total_events": 0,\n  "processed_events": 0,\n  "started_at": null,\n  "completed_at": null,\n  "inserted_at": "2026-01-15T10:30:00Z"\n}|
            }
            copy_id="copy-replays-create-response"
            status="201 Created"
          />
        </.api_endpoint>
        <.api_endpoint
          id="replays-list"
          method="GET"
          path="/api/v1/replays"
          description={gettext("Lista los jobs de replay con su estado y progreso.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/replays\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-replays-list"
          />
          <.response_block
            code={
              ~s|{\n  "data": [\n    {\n      "id": "b8c9d0e1-f2a3-4567-hijk-678901234567",\n      "status": "completed",\n      "filters": {"webhook_id": "WEBHOOK_ID", "from_date": "2026-01-01T00:00:00Z"},\n      "total_events": 42,\n      "processed_events": 42,\n      "started_at": "2026-01-15T10:31:00Z",\n      "completed_at": "2026-01-15T10:32:00Z",\n      "inserted_at": "2026-01-15T10:30:00Z"\n    }\n  ]\n}|
            }
            copy_id="copy-replays-list-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="replays-show"
          method="GET"
          path="/api/v1/replays/:id"
          description={gettext("Obtiene el estado y configuración de un replay específico.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/replays/REPLAY_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-replays-show"
          />
          <.response_block
            code={
              ~s|{\n  "id": "b8c9d0e1-f2a3-4567-hijk-678901234567",\n  "status": "running",\n  "filters": {"webhook_id": "WEBHOOK_ID"},\n  "total_events": 42,\n  "processed_events": 15,\n  "started_at": "2026-01-15T10:31:00Z",\n  "completed_at": null,\n  "inserted_at": "2026-01-15T10:30:00Z"\n}|
            }
            copy_id="copy-replays-show-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="replays-cancel"
          method="DELETE"
          path="/api/v1/replays/:id"
          description={gettext("Cancela un replay en ejecución, deteniendo entregas pendientes.")}
        >
          <.code_block
            code={"curl -X DELETE \"#{@base_url}/api/v1/replays/REPLAY_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-replays-cancel"
          />
          <.response_block
            code={
              ~s|{\n  "id": "b8c9d0e1-f2a3-4567-hijk-678901234567",\n  "status": "cancelled",\n  "filters": {"webhook_id": "WEBHOOK_ID"},\n  "total_events": 42,\n  "processed_events": 15,\n  "started_at": "2026-01-15T10:31:00Z",\n  "completed_at": "2026-01-15T10:35:00Z",\n  "inserted_at": "2026-01-15T10:30:00Z"\n}|
            }
            copy_id="copy-replays-cancel-response"
            status="200 OK"
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <%!-- Event Schemas --%>
    <.docs_section
      id="event-schemas"
      title={gettext("Event Schemas")}
      subtitle={gettext("Definición y validación de estructura de eventos mediante JSON Schema.")}
    >
      <div class="space-y-6">
        <.api_endpoint
          id="schemas-list"
          method="GET"
          path="/api/v1/event-schemas"
          description={gettext("Lista los JSON schemas registrados para validación de eventos.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/event-schemas\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-schemas-list"
          />
          <.response_block
            code={
              ~s|{\n  "data": [\n    {\n      "id": "c9d0e1f2-a3b4-5678-ijkl-789012345678",\n      "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "topic": "order.created",\n      "schema": {"type": "object", "required": ["order_id"], "properties": {"order_id": {"type": "string"}}},\n      "version": 1,\n      "status": "active",\n      "inserted_at": "2026-01-10T08:00:00Z",\n      "updated_at": "2026-01-10T08:00:00Z"\n    }\n  ]\n}|
            }
            copy_id="copy-schemas-list-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="schemas-create"
          method="POST"
          path="/api/v1/event-schemas"
          description={gettext("Crea un nuevo JSON Schema para validación de payloads.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/event-schemas\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"topic\":\"order.created\",\"schema\":{\"type\":\"object\",\"required\":[\"order_id\"],\"properties\":{\"order_id\":{\"type\":\"string\"}}}}'"}
            copy_id="copy-schemas-create"
          />
          <.response_block
            code={
              ~s|{\n  "data": {\n    "id": "c9d0e1f2-a3b4-5678-ijkl-789012345678",\n    "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "topic": "order.created",\n    "schema": {"type": "object", "required": ["order_id"], "properties": {"order_id": {"type": "string"}}},\n    "version": 1,\n    "status": "active",\n    "inserted_at": "2026-01-15T10:30:00Z",\n    "updated_at": "2026-01-15T10:30:00Z"\n  }\n}|
            }
            copy_id="copy-schemas-create-response"
            status="201 Created"
          />
        </.api_endpoint>
        <.api_endpoint
          id="schemas-show"
          method="GET"
          path="/api/v1/event-schemas/:id"
          description={gettext("Obtiene la definición completa de un JSON Schema.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/event-schemas/SCHEMA_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-schemas-show"
          />
          <.response_block
            code={
              ~s|{\n  "data": {\n    "id": "c9d0e1f2-a3b4-5678-ijkl-789012345678",\n    "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "topic": "order.created",\n    "schema": {"type": "object", "required": ["order_id"], "properties": {"order_id": {"type": "string"}}},\n    "version": 1,\n    "status": "active",\n    "inserted_at": "2026-01-10T08:00:00Z",\n    "updated_at": "2026-01-10T08:00:00Z"\n  }\n}|
            }
            copy_id="copy-schemas-show-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="schemas-update"
          method="PATCH"
          path="/api/v1/event-schemas/:id"
          description={gettext("Actualiza un JSON Schema e incrementa el número de versión.")}
        >
          <.code_block
            code={"curl -X PATCH \"#{@base_url}/api/v1/event-schemas/SCHEMA_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"schema\":{\"type\":\"object\",\"required\":[\"order_id\",\"amount\"],\"properties\":{\"order_id\":{\"type\":\"string\"},\"amount\":{\"type\":\"number\"}}}}'"}
            copy_id="copy-schemas-update"
          />
          <.response_block
            code={
              ~s|{\n  "data": {\n    "id": "c9d0e1f2-a3b4-5678-ijkl-789012345678",\n    "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "topic": "order.created",\n    "schema": {"type": "object", "required": ["order_id", "amount"], "properties": {"order_id": {"type": "string"}, "amount": {"type": "number"}}},\n    "version": 1,\n    "status": "active",\n    "inserted_at": "2026-01-10T08:00:00Z",\n    "updated_at": "2026-01-15T10:30:00Z"\n  }\n}|
            }
            copy_id="copy-schemas-update-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="schemas-delete"
          method="DELETE"
          path="/api/v1/event-schemas/:id"
          description={gettext("Elimina un JSON Schema del proyecto.")}
        >
          <.code_block
            code={"curl -X DELETE \"#{@base_url}/api/v1/event-schemas/SCHEMA_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-schemas-delete"
          />
          <.response_block
            code={~s|{\n  "ok": true\n}|}
            copy_id="copy-schemas-delete-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="schemas-validate"
          method="POST"
          path="/api/v1/event-schemas/validate"
          description={gettext("Valida un payload contra un JSON Schema sin persistir el evento.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/event-schemas/validate\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"topic\":\"order.created\",\"payload\":{\"order_id\":\"123\"}}'"}
            copy_id="copy-schemas-validate"
          />
          <.response_block
            code={
              ~s|{\n  "valid": true,\n  "errors": []\n}\n\n// If validation fails:\n{\n  "valid": false,\n  "errors": [\n    {"message": "Required property order_id is missing", "path": "#/order_id"}\n  ]\n}|
            }
            copy_id="copy-schemas-validate-response"
            status="200 OK"
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <%!-- Export --%>
    <.docs_section
      id="export"
      title={gettext("Exportar datos")}
      subtitle={gettext("Exportación de datos del proyecto en formato CSV o JSON.")}
    >
      <div class="space-y-6">
        <.api_endpoint
          id="export-events"
          method="GET"
          path="/api/v1/export/events"
          description={gettext("Exporta eventos con metadatos y payload completo.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/export/events?format=csv\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-export-events"
          />
          <.response_block
            code={
              ~s|id,topic,status,occurred_at,payload,payload_hash\nb2c3d4e5-...,order.created,active,2026-01-15T10:30:00Z,"{""order_id"":""12345""}",sha256:a3f2...|
            }
            copy_id="copy-export-events-response"
            status="200 OK"
            note={gettext("Formato CSV por defecto. Usa ?format=json para obtener JSON.")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="export-deliveries"
          method="GET"
          path="/api/v1/export/deliveries"
          description={gettext("Exporta registros de entregas con historial de intentos.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/export/deliveries?format=csv\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-export-deliveries"
          />
          <.response_block
            code={
              ~s|id,event_id,webhook_id,status,attempt_number,response_status,inserted_at\nd4e5f6a7-...,b2c3d4e5-...,c3d4e5f6-...,success,1,200,2026-01-15T10:30:00Z|
            }
            copy_id="copy-export-deliveries-response"
            status="200 OK"
            note={gettext("Formato CSV por defecto. Usa ?format=json para obtener JSON.")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="export-jobs"
          method="GET"
          path="/api/v1/export/jobs"
          description={gettext("Exporta jobs programados con estado y configuración.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/export/jobs?format=csv\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-export-jobs"
          />
          <.response_block
            code={
              ~s|id,name,status,schedule_type,action_type,inserted_at\ne5f6a7b8-...,Daily Report,active,daily,emit_event,2026-01-05T12:00:00Z|
            }
            copy_id="copy-export-jobs-response"
            status="200 OK"
            note={gettext("Formato CSV por defecto. Usa ?format=json para obtener JSON.")}
          />
        </.api_endpoint>
        <.api_endpoint
          id="export-audit"
          method="GET"
          path="/api/v1/export/audit-log"
          description={gettext("Exporta el audit log completo con metadatos de acciones.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/export/audit-log?format=csv\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-export-audit"
          />
          <.response_block
            code={
              ~s|id,action,resource_type,resource_id,user_id,ip_address,inserted_at\nf6a7b8c9-...,event.created,event,b2c3d4e5-...,a1b2c3d4-...,192.168.1.1,2026-01-15T10:30:00Z|
            }
            copy_id="copy-export-audit-response"
            status="200 OK"
            note={gettext("Formato CSV por defecto. Usa ?format=json para obtener JSON.")}
          />
        </.api_endpoint>
      </div>
      <.callout kind="tip">
        {gettext(
          "Utilizar el query parameter ?format=csv para CSV o ?format=json para JSON. El formato por defecto es CSV."
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
      subtitle={gettext("Panel principal para gestión de recursos del proyecto.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "El Dashboard es la interfaz principal de gestión. Permite consultar eventos, webhooks, entregas, jobs, analíticas, audit log y gestionar los tokens API. Se accede mediante la aplicación web tras autenticación."
        )}
      </p>
      <div class="grid sm:grid-cols-2 gap-4">
        <div class="rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-4">
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
        <div class="rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-4">
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
      subtitle={gettext("Gestión de perfil, credenciales y autenticación multifactor.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "Desde la página de cuenta se pueden actualizar nombre, email y contraseña. También es posible activar la autenticación de dos factores (MFA) para seguridad adicional."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="password-recovery"
      title={gettext("Recuperar contraseña")}
      subtitle={gettext("Proceso de recuperación de credenciales.")}
    >
      <div class="space-y-4">
        <p class="text-slate-700 leading-relaxed">
          {gettext(
            "Si se pierde la contraseña, solicitar un enlace de recuperación desde la página de login. Se recibirá un email con un enlace temporal para establecer una nueva contraseña."
          )}
        </p>
        <.callout kind="info">
          {gettext(
            "El enlace de recuperación tiene vigencia limitada por seguridad. Si expira, solicitar uno nuevo."
          )}
        </.callout>
      </div>
    </.docs_section>

    <.docs_section
      id="multi-project"
      title={gettext("Multi-proyecto")}
      subtitle={gettext("Gestión de múltiples proyectos desde una sola cuenta.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Se pueden crear múltiples proyectos aislados, cada uno con su propio API token, webhooks, eventos y configuración. Permite separar entornos (dev, staging, prod) o distintas aplicaciones."
        )}
      </p>
      <div class="space-y-4">
        <.api_endpoint
          id="projects-list"
          method="GET"
          path="/api/v1/projects"
          description={
            gettext("Lista los proyectos asociados a la cuenta autenticada (requiere JWT).")
          }
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/projects\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-projects-list"
          />
          <.response_block
            code={
              ~s|{\n  "data": [\n    {\n      "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "name": "Production",\n      "status": "active",\n      "is_default": true,\n      "settings": {},\n      "inserted_at": "2026-01-01T00:00:00Z",\n      "updated_at": "2026-01-10T08:00:00Z"\n    }\n  ]\n}|
            }
            copy_id="copy-projects-list-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="projects-create"
          method="POST"
          path="/api/v1/projects"
          description={
            gettext("Crea un nuevo proyecto con configuración por defecto y genera un API token.")
          }
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/projects\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"name\":\"My New Project\"}'"}
            copy_id="copy-projects-create"
          />
          <.response_block
            code={
              ~s|{\n  "data": {\n    "id": "d0e1f2a3-b4c5-6789-klmn-890123456789",\n    "name": "My New Project",\n    "status": "active",\n    "is_default": false,\n    "settings": {},\n    "inserted_at": "2026-01-15T10:30:00Z",\n    "updated_at": "2026-01-15T10:30:00Z"\n  }\n}|
            }
            copy_id="copy-projects-create-response"
            status="201 Created"
          />
        </.api_endpoint>
        <.api_endpoint
          id="projects-default"
          method="PATCH"
          path="/api/v1/projects/:id/default"
          description={gettext("Establece un proyecto como predeterminado para solicitudes API.")}
        >
          <.code_block
            code={"curl -X PATCH \"#{@base_url}/api/v1/projects/PROJECT_ID/default\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-projects-default"
          />
          <.response_block
            code={
              ~s|{\n  "data": {\n    "id": "d0e1f2a3-b4c5-6789-klmn-890123456789",\n    "name": "My New Project",\n    "status": "active",\n    "is_default": true,\n    "settings": {},\n    "inserted_at": "2026-01-15T10:30:00Z",\n    "updated_at": "2026-01-15T10:35:00Z"\n  }\n}|
            }
            copy_id="copy-projects-default-response"
            status="200 OK"
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <.docs_section
      id="teams"
      title={gettext("Equipos")}
      subtitle={gettext("Gestión de equipos y permisos en proyectos compartidos.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Permite invitar miembros a proyectos con roles diferenciados (admin, member, viewer). Los miembros invitados reciben un email de notificación y deben aceptar la invitación para obtener acceso."
        )}
      </p>
      <div class="space-y-4">
        <.api_endpoint
          id="members-list"
          method="GET"
          path="/api/v1/projects/:id/members"
          description={gettext("Lista los miembros del proyecto con sus roles asignados.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/projects/PROJECT_ID/members\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-members-list"
          />
          <.response_block
            code={
              ~s|{\n  "data": [\n    {\n      "id": "e1f2a3b4-c5d6-7890-lmno-901234567890",\n      "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "user_id": "f2a3b4c5-d6e7-8901-mnop-012345678901",\n      "role": "member",\n      "status": "accepted",\n      "invited_by": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "inserted_at": "2026-01-10T08:00:00Z"\n    }\n  ]\n}|
            }
            copy_id="copy-members-list-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="members-add"
          method="POST"
          path="/api/v1/projects/:id/members"
          description={gettext("Envía una invitación para agregar un miembro al proyecto.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/projects/PROJECT_ID/members\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"email\":\"member@example.com\",\"role\":\"member\"}'"}
            copy_id="copy-members-add"
          />
          <.response_block
            code={
              ~s|{\n  "data": {\n    "id": "e1f2a3b4-c5d6-7890-lmno-901234567890",\n    "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "user_id": "f2a3b4c5-d6e7-8901-mnop-012345678901",\n    "role": "member",\n    "status": "pending",\n    "invited_by": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "inserted_at": "2026-01-15T10:30:00Z"\n  }\n}|
            }
            copy_id="copy-members-add-response"
            status="201 Created"
          />
        </.api_endpoint>
        <.api_endpoint
          id="members-update"
          method="PATCH"
          path="/api/v1/projects/:id/members/:mid"
          description={gettext("Modifica el rol asignado a un miembro del proyecto.")}
        >
          <.code_block
            code={"curl -X PATCH \"#{@base_url}/api/v1/projects/PROJECT_ID/members/MEMBER_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"role\":\"admin\"}'"}
            copy_id="copy-members-update"
          />
          <.response_block
            code={
              ~s|{\n  "data": {\n    "id": "e1f2a3b4-c5d6-7890-lmno-901234567890",\n    "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "user_id": "f2a3b4c5-d6e7-8901-mnop-012345678901",\n    "role": "admin",\n    "status": "accepted",\n    "invited_by": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "inserted_at": "2026-01-10T08:00:00Z"\n  }\n}|
            }
            copy_id="copy-members-update-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="members-remove"
          method="DELETE"
          path="/api/v1/projects/:id/members/:mid"
          description={
            gettext("Remueve un miembro del proyecto, revocando todos sus permisos de acceso.")
          }
        >
          <.code_block
            code={"curl -X DELETE \"#{@base_url}/api/v1/projects/PROJECT_ID/members/MEMBER_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-members-remove"
          />
          <.response_block
            code={~s|{\n  "ok": true\n}|}
            copy_id="copy-members-remove-response"
            status="200 OK"
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <.docs_section
      id="sandbox"
      title="Sandbox"
      subtitle={gettext("Endpoints de prueba para verificación e integración de webhooks.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Permite crear endpoints sandbox aislados para probar integraciones de webhook sin requerir infraestructura externa. Cada endpoint proporciona una URL única que captura y registra todas las solicitudes HTTP recibidas."
        )}
      </p>
      <div class="space-y-4">
        <.api_endpoint
          id="sandbox-list"
          method="GET"
          path="/api/v1/sandbox-endpoints"
          description={gettext("Lista los endpoints sandbox creados para pruebas de webhook.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/sandbox-endpoints\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-sandbox-list"
          />
          <.response_block
            code={
              ~s|{\n  "data": [\n    {\n      "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "slug": "test-endpoint-x7k9",\n      "name": "Test Endpoint",\n      "url": "/sandbox/test-endpoint-x7k9",\n      "expires_at": "2026-03-14T14:30:00Z",\n      "inserted_at": "2026-03-07T14:30:00Z"\n    }\n  ]\n}|
            }
            copy_id="copy-sandbox-list-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="sandbox-create"
          method="POST"
          path="/api/v1/sandbox-endpoints"
          description={
            gettext("Crea un nuevo endpoint sandbox para pruebas e inspección de solicitudes.")
          }
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/sandbox-endpoints\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"name\":\"Test Endpoint\"}'"}
            copy_id="copy-sandbox-create"
          />
          <.response_block
            code={
              ~s|{\n  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n  "slug": "test-endpoint-x7k9",\n  "name": "Test Endpoint",\n  "url": "/sandbox/test-endpoint-x7k9",\n  "expires_at": "2026-03-14T14:30:00Z",\n  "inserted_at": "2026-03-07T14:30:00Z"\n}|
            }
            copy_id="copy-sandbox-create-response"
            status="201 Created"
          />
        </.api_endpoint>
        <.api_endpoint
          id="sandbox-requests"
          method="GET"
          path="/api/v1/sandbox-endpoints/:id/requests"
          description={
            gettext("Obtiene todas las solicitudes HTTP recibidas por un endpoint sandbox.")
          }
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/sandbox-endpoints/ENDPOINT_ID/requests\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-sandbox-requests"
          />
          <.response_block
            code={
              ~s|{\n  "data": [\n    {\n      "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "method": "POST",\n      "path": "/sandbox/test-endpoint-x7k9",\n      "headers": {"content-type": "application/json"},\n      "body": {"order_id": "123", "amount": 99.99},\n      "query_params": {},\n      "ip": "203.0.113.42",\n      "inserted_at": "2026-03-07T14:30:00Z"\n    }\n  ]\n}|
            }
            copy_id="copy-sandbox-requests-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="sandbox-delete"
          method="DELETE"
          path="/api/v1/sandbox-endpoints/:id"
          description={gettext("Elimina un endpoint sandbox y descarta todos los datos capturados.")}
        >
          <.code_block
            code={"curl -X DELETE \"#{@base_url}/api/v1/sandbox-endpoints/ENDPOINT_ID\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-sandbox-delete"
          />
          <.response_block
            code={~s|{\n  "status": "deleted"\n}|}
            copy_id="copy-sandbox-delete-response"
            status="200 OK"
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <.docs_section
      id="analytics"
      title={gettext("Analíticas")}
      subtitle={gettext("Métricas y visualizaciones de rendimiento del proyecto.")}
    >
      <div class="space-y-4">
        <.api_endpoint
          id="analytics-events"
          method="GET"
          path="/api/v1/analytics/events-per-day"
          description={gettext("Volumen de eventos por día.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/analytics/events-per-day\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-analytics-events"
          />
          <.response_block
            code={
              ~s|{\n  "data": [\n    {"date": "2026-03-05", "count": 245},\n    {"date": "2026-03-06", "count": 312},\n    {"date": "2026-03-07", "count": 178}\n  ]\n}|
            }
            copy_id="copy-analytics-events-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="analytics-deliveries"
          method="GET"
          path="/api/v1/analytics/deliveries-per-day"
          description={gettext("Volumen de entregas por día.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/analytics/deliveries-per-day\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-analytics-deliveries"
          />
          <.response_block
            code={
              ~s|{\n  "data": [\n    {"date": "2026-03-05", "count": 320},\n    {"date": "2026-03-06", "count": 415},\n    {"date": "2026-03-07", "count": 198}\n  ]\n}|
            }
            copy_id="copy-analytics-deliveries-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="analytics-topics"
          method="GET"
          path="/api/v1/analytics/top-topics"
          description={gettext("Topics con mayor volumen de eventos.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/analytics/top-topics\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-analytics-topics"
          />
          <.response_block
            code={
              ~s|{\n  "data": [\n    {"topic": "order.created", "count": 1250},\n    {"topic": "user.signup", "count": 890},\n    {"topic": "payment.completed", "count": 567}\n  ]\n}|
            }
            copy_id="copy-analytics-topics-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="analytics-webhooks"
          method="GET"
          path="/api/v1/analytics/webhook-stats"
          description={gettext("Estadísticas de rendimiento de webhooks.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/analytics/webhook-stats\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-analytics-webhooks"
          />
          <.response_block
            code={
              ~s|{\n  "data": [\n    {\n      "webhook_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "url": "https://example.com/hook",\n      "total_deliveries": 150,\n      "successful": 142,\n      "failed": 8\n    }\n  ]\n}|
            }
            copy_id="copy-analytics-webhooks-response"
            status="200 OK"
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <.docs_section
      id="audit-log"
      title="Audit Log"
      subtitle={gettext("Registro inmutable de acciones en el proyecto.")}
    >
      <.api_endpoint
        id="audit-index"
        method="GET"
        path="/api/v1/audit-log"
        description={gettext("Obtiene las entradas del audit log con soporte de paginación.")}
      >
        <.code_block
          code={"curl \"#{@base_url}/api/v1/audit-log?limit=20\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
          copy_id="copy-audit-index"
        />
        <.response_block
          code={
            ~s|{\n  "data": [\n    {\n      "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "action": "webhook.created",\n      "resource_type": "webhook",\n      "resource_id": "f1e2d3c4-b5a6-7890-fedc-ba0987654321",\n      "metadata": {"url": "https://example.com/hook"},\n      "user_id": "c3d4e5f6-a7b8-9012-cdef-234567890abc",\n      "ip_address": "203.0.113.42",\n      "inserted_at": "2026-03-07T14:30:00Z"\n    }\n  ]\n}|
          }
          copy_id="copy-audit-index-response"
          status="200 OK"
        />
        <p class="text-slate-600 text-sm">
          {gettext("Filtros opcionales: action, actor_email, from, to.")}
        </p>
      </.api_endpoint>
    </.docs_section>

    <.docs_section
      id="realtime-stream"
      title="SSE Streaming"
      subtitle={gettext("Recepción de eventos en tiempo real mediante Server-Sent Events (SSE).")}
    >
      <.api_endpoint
        id="sse-stream"
        method="GET"
        path="/api/v1/stream"
        description={
          gettext("Establece una conexión SSE para recibir notificaciones de eventos en tiempo real.")
        }
      >
        <.code_block
          code={"curl -N \"#{@base_url}/api/v1/stream\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
          copy_id="copy-sse-stream"
        />
        <.response_block
          code={
            ~s|data: {"type":"connected","project_id":"a1b2c3d4-e5f6-7890-abcd-ef1234567890"}\n\ndata: {"type":"event.created","data":{"id":"b2c3d4e5-f6a7-8901-bcde-f12345678901","topic":"order.created","payload":{"order_id":"123"},"occurred_at":"2026-03-07T14:30:00Z"}}\n\ndata: {"type":"delivery.updated","data":{"id":"c3d4e5f6-a7b8-9012-cdef-234567890abc","status":"delivered","event_id":"b2c3d4e5-f6a7-8901-bcde-f12345678901"}}|
          }
          copy_id="copy-sse-stream-response"
          status="200 OK"
          note={gettext("Stream de Server-Sent Events.")}
        />
      </.api_endpoint>
      <p class="text-slate-600 text-sm">
        {gettext(
          "La conexión permanece abierta y transmite eventos a medida que ocurren. Utilizar la API EventSource en JavaScript o curl -N para verificar la conexión."
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
      subtitle={gettext("Patrones wildcard con * para filtrar múltiples topics en webhooks.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Los topics de webhook soportan pattern matching con wildcards. El patrón order.* coincide con order.created, order.updated, order.deleted y topics similares bajo ese namespace."
        )}
      </p>
      <div class="rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-4 overflow-x-auto">
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
      subtitle={gettext("Programación de eventos para entrega diferida.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Incluir el campo deliver_at con un timestamp ISO 8601 en el futuro. El evento se persiste inmediatamente pero la entrega se difiere hasta el timestamp especificado."
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
      subtitle={gettext("Envío de múltiples eventos en una sola solicitud API.")}
    >
      <.api_endpoint
        id="batch-create"
        method="POST"
        path="/api/v1/events/batch"
        description={gettext("Envía un array de objetos de evento en una sola solicitud.")}
      >
        <.code_block
          code={"curl -X POST \"#{@base_url}/api/v1/events/batch\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"events\":[{\"topic\":\"a\",\"data\":1},{\"topic\":\"b\",\"data\":2}]}'"}
          copy_id="copy-batch-events"
        />
        <.response_block
          code={
            ~s|{\n  "accepted": 2,\n  "rejected": 0,\n  "events": [\n    {\n      "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "topic": "a",\n      "payload": 1,\n      "status": "pending",\n      "occurred_at": "2026-03-07T14:30:00Z",\n      "payload_hash": "e3b0c44298fc1c14...",\n      "inserted_at": "2026-03-07T14:30:00Z"\n    },\n    {\n      "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",\n      "topic": "b",\n      "payload": 2,\n      "status": "pending",\n      "occurred_at": "2026-03-07T14:30:00Z",\n      "payload_hash": "a1b2c3d4e5f67890...",\n      "inserted_at": "2026-03-07T14:30:00Z"\n    }\n  ]\n}|
          }
          copy_id="copy-batch-events-response"
          status="202 Accepted"
        />
      </.api_endpoint>
    </.docs_section>

    <.docs_section
      id="cursor-págination"
      title={gettext("Paginación cursor")}
      subtitle={
        gettext("Paginación eficiente basada en cursor para conjuntos de resultados extensos.")
      }
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Los endpoints paginados utilizan paginación basada en cursor. Utilizar el valor de next_cursor de la respuesta como parámetro cursor en solicitudes subsiguientes."
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
      subtitle={gettext("Configuraciones predefinidas para webhooks.")}
    >
      <.api_endpoint
        id="templates-list"
        method="GET"
        path="/api/v1/webhooks/templates"
        description={gettext("Lista las plantillas de webhook disponibles.")}
      >
        <.code_block
          code={"curl \"#{@base_url}/api/v1/webhooks/templates\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
          copy_id="copy-webhook-templates"
        />
        <.response_block
          code={
            ~s|{\n  "templates": [\n    {\n      "name": "Slack Notification",\n      "url": "https://hooks.slack.com/services/...",\n      "topics": ["order.created", "payment.completed"],\n      "headers": {"Content-Type": "application/json"}\n    },\n    {\n      "name": "Email Alert",\n      "url": "https://api.example.com/email-hook",\n      "topics": ["user.signup"],\n      "headers": {}\n    }\n  ]\n}|
          }
          copy_id="copy-webhook-templates-response"
          status="200 OK"
        />
      </.api_endpoint>
    </.docs_section>

    <.docs_section
      id="ip-allowlist"
      title="IP Allowlist"
      subtitle={gettext("Restricción de acceso a la API mediante IP allowlisting.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "Permite configurar IP allowlisting para la API key del proyecto. Solo se aceptan solicitudes originadas desde las IPs autorizadas. Se configura al actualizar el proyecto."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="simulate"
      title={gettext("Simulador")}
      subtitle={gettext("Validación de webhooks sin envío de eventos reales.")}
    >
      <.api_endpoint
        id="simulate-endpoint"
        method="POST"
        path="/api/v1/simulate"
        description={
          gettext("Simula la entrega de un evento para validar la configuración de webhooks.")
        }
      >
        <.code_block
          code={"curl -X POST \"#{@base_url}/api/v1/simulate\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"topic\":\"order.created\",\"payload\":{\"test\":true}}'"}
          copy_id="copy-simulate"
        />
        <.response_block
          code={
            ~s|{\n  "simulation": true,\n  "matching_webhooks": 1,\n  "results": [\n    {\n      "id": "b3e7c8a1-4f2d-4e9a-8c1b-5d6f7a8b9c0d",\n      "url": "https://example.com/hook",\n      "topics": ["order.*"]\n    }\n  ]\n}|
          }
          copy_id="copy-simulate-response"
          status="200 OK"
        />
      </.api_endpoint>
      <.callout kind="info">
        {gettext(
          "El simulador no persiste eventos ni genera entregas reales. Muestra qué webhooks recibirían el evento y el payload transformado resultante."
        )}
      </.callout>
    </.docs_section>

    <.docs_section
      id="idempotency-keys"
      title={gettext("Claves de idempotencia")}
      subtitle={
        gettext("Previene el procesamiento duplicado de eventos usando claves únicas por cliente.")
      }
    >
      <p class="text-slate-700 dark:text-slate-300 leading-relaxed mb-4">
        {gettext(
          "Envía idempotency_key en el body o el header X-Idempotency-Key para deduplicar eventos. Si ya existe un evento con la misma clave en el proyecto, se retorna el evento existente sin crear uno nuevo."
        )}
      </p>
      <.code_block
        code={"# Opción 1: idempotency_key en el body\ncurl -X POST \"#{@base_url}/api/v1/send\" \\\n  -H \"Authorization: Bearer YOUR_API_KEY\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"topic\":\"order.created\",\"amount\":150,\"idempotency_key\":\"order-123-abc\"}'"}
        copy_id="copy-idempotency-body"
      />
      <.code_block
        code={"# Opción 2: X-Idempotency-Key como header\ncurl -X POST \"#{@base_url}/api/v1/send\" \\\n  -H \"Authorization: Bearer YOUR_API_KEY\" \\\n  -H \"Content-Type: application/json\" \\\n  -H \"X-Idempotency-Key: order-123-abc\" \\\n  -d '{\"topic\":\"order.created\",\"amount\":150}'"}
        copy_id="copy-idempotency-header"
      />
      <.callout kind="info">
        {gettext(
          "El header X-Idempotency-Key tiene prioridad sobre el campo del body. Las claves expiran automáticamente después de varios días."
        )}
      </.callout>
    </.docs_section>

    <.docs_section
      id="external-alerts"
      title={gettext("Alertas externas")}
      subtitle={
        gettext("Recibe notificaciones fuera del dashboard cuando algo falla en tus webhooks.")
      }
    >
      <p class="text-slate-700 dark:text-slate-300 leading-relaxed mb-4">
        {gettext(
          "Configura canales de notificación para recibir alertas por email, Slack, Discord o meta-webhook cuando ocurren eventos críticos."
        )}
      </p>
      <div class="rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-4 overflow-x-auto mb-4">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-slate-500">
              <th class="pb-2 font-medium">{gettext("Canal")}</th>
              <th class="pb-2 font-medium">{gettext("Configuración")}</th>
            </tr>
          </thead>
          <tbody class="text-slate-700 dark:text-slate-300">
            <tr class="border-t border-slate-200 dark:border-slate-700">
              <td class="py-2 font-mono text-xs">email</td>
              <td class="py-2 text-xs">{gettext("Dirección de correo del destinatario")}</td>
            </tr>
            <tr class="border-t border-slate-200 dark:border-slate-700">
              <td class="py-2 font-mono text-xs">slack</td>
              <td class="py-2 text-xs">{gettext("URL del Incoming Webhook de Slack")}</td>
            </tr>
            <tr class="border-t border-slate-200 dark:border-slate-700">
              <td class="py-2 font-mono text-xs">discord</td>
              <td class="py-2 text-xs">{gettext("URL del Webhook de Discord")}</td>
            </tr>
            <tr class="border-t border-slate-200 dark:border-slate-700">
              <td class="py-2 font-mono text-xs">webhook</td>
              <td class="py-2 text-xs">
                {gettext("URL de un endpoint HTTP que recibe alertas (meta-webhook)")}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <.api_endpoint
        id="notification-channel-upsert"
        method="PUT"
        path="/api/v1/notification-channels"
        description={gettext("Crear o actualizar un canal de notificación.")}
      >
        <.code_block
          code={"curl -X PUT \"#{@base_url}/api/v1/notification-channels\" \\\n  -H \"Authorization: Bearer YOUR_API_KEY\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"channel\":\"slack\",\"config\":{\"webhook_url\":\"https://hooks.slack.com/services/...\"},\"events\":[\"webhook_failing\",\"circuit_open\"]}'"}
          copy_id="copy-notification-upsert"
        />
      </.api_endpoint>
      <.api_endpoint
        id="notification-channel-test"
        method="POST"
        path="/api/v1/notification-channels/test"
        description={gettext("Enviar una notificación de prueba al canal configurado.")}
      >
        <.code_block
          code={"curl -X POST \"#{@base_url}/api/v1/notification-channels/test\" \\\n  -H \"Authorization: Bearer YOUR_API_KEY\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"channel\":\"slack\"}'"}
          copy_id="copy-notification-test"
        />
      </.api_endpoint>
    </.docs_section>

    <.docs_section
      id="embed-portal"
      title={gettext("Portal embebible")}
      subtitle={
        gettext("Widget JavaScript para que tus usuarios finales gestionen sus propios webhooks.")
      }
    >
      <p class="text-slate-700 dark:text-slate-300 leading-relaxed mb-4">
        {gettext(
          "Genera un token de embed con scopes específicos y usa el widget JS para que tus clientes configuren webhooks y vean entregas sin acceder a tu dashboard."
        )}
      </p>
      <.api_endpoint
        id="embed-token-create"
        method="POST"
        path="/api/v1/embed/tokens"
        description={gettext("Generar un nuevo token de embed.")}
      >
        <.code_block
          code={"curl -X POST \"#{@base_url}/api/v1/embed/tokens\" \\\n  -H \"Authorization: Bearer YOUR_API_KEY\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"project_id\":\"PROJECT_ID\",\"name\":\"My Portal\"}'"}
          copy_id="copy-embed-token"
        />
      </.api_endpoint>
      <div class="mt-4">
        <h4 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-2">
          {gettext("Integrar el widget")}
        </h4>
        <.code_block
          code={"<script src=\"#{@base_url}/embed.js\"></script>\n<div id=\"jobcelis-portal\"></div>\n<script>\n  JobcelisPortal.init({\n    token: \"emb_...\",\n    container: \"#jobcelis-portal\",\n    baseUrl: \"#{@base_url}\",\n    locale: \"en\"\n  });\n</script>"}
          copy_id="copy-embed-widget"
        />
      </div>
      <div class="mt-4 rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-4 overflow-x-auto">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-slate-500">
              <th class="pb-2 font-medium">{gettext("Método")}</th>
              <th class="pb-2 font-medium">{gettext("Ruta")}</th>
              <th class="pb-2 font-medium">{gettext("Descripción")}</th>
            </tr>
          </thead>
          <tbody class="text-slate-700 dark:text-slate-300">
            <tr class="border-t border-slate-200 dark:border-slate-700">
              <td class="py-2">
                <span class="px-1.5 py-0.5 rounded text-xs font-mono bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700">
                  GET
                </span>
              </td>
              <td class="py-2 font-mono text-xs">/api/v1/embed/webhooks</td>
              <td class="py-2 text-xs">{gettext("Listar webhooks")}</td>
            </tr>
            <tr class="border-t border-slate-200 dark:border-slate-700">
              <td class="py-2">
                <span class="px-1.5 py-0.5 rounded text-xs font-mono bg-blue-100 dark:bg-blue-900/30 text-blue-700">
                  POST
                </span>
              </td>
              <td class="py-2 font-mono text-xs">/api/v1/embed/webhooks</td>
              <td class="py-2 text-xs">{gettext("Crear webhook")}</td>
            </tr>
            <tr class="border-t border-slate-200 dark:border-slate-700">
              <td class="py-2">
                <span class="px-1.5 py-0.5 rounded text-xs font-mono bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700">
                  GET
                </span>
              </td>
              <td class="py-2 font-mono text-xs">/api/v1/embed/deliveries</td>
              <td class="py-2 text-xs">{gettext("Listar entregas")}</td>
            </tr>
            <tr class="border-t border-slate-200 dark:border-slate-700">
              <td class="py-2">
                <span class="px-1.5 py-0.5 rounded text-xs font-mono bg-blue-100 dark:bg-blue-900/30 text-blue-700">
                  POST
                </span>
              </td>
              <td class="py-2 font-mono text-xs">/api/v1/embed/deliveries/:id/retry</td>
              <td class="py-2 text-xs">{gettext("Reintentar entrega")}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <.callout kind="info">
        {gettext(
          "El token de embed solo se muestra una vez al crearlo. Los scopes disponibles son: webhooks:read, webhooks:write, deliveries:read, deliveries:retry."
        )}
      </.callout>
    </.docs_section>

    <.docs_section
      id="rate-limiting-outbound"
      title={gettext("Rate limiting saliente")}
      subtitle={
        gettext(
          "Controla la velocidad de entrega de webhooks para no sobrecargar los servidores receptores."
        )
      }
    >
      <p class="text-slate-700 dark:text-slate-300 leading-relaxed mb-4">
        {gettext(
          "Cada webhook puede tener su propio límite de velocidad. Si no se configura, se aplican los valores por defecto."
        )}
      </p>
      <.code_block
        code={"curl -X PATCH \"#{@base_url}/api/v1/webhooks/WEBHOOK_ID\" \\\n  -H \"Authorization: Bearer YOUR_API_KEY\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"rate_limit\":{\"max_per_second\":100,\"max_per_minute\":5000}}'"}
        copy_id="copy-rate-limit"
      />
      <.callout kind="info">
        {gettext(
          "Cuando un webhook alcanza su límite, las entregas pendientes se encolan automáticamente y se reintentan en pocos segundos."
        )}
      </.callout>
    </.docs_section>

    <.docs_section
      id="prometheus-metrics"
      title={gettext("Métricas Prometheus")}
      subtitle={
        gettext("Endpoint /metrics compatible con Prometheus para monitoreo profesional con Grafana.")
      }
    >
      <p class="text-slate-700 dark:text-slate-300 leading-relaxed mb-4">
        {gettext("Métricas disponibles")}:
      </p>
      <div class="space-y-3 mb-4">
        <div>
          <h4 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-1">Counters</h4>
          <ul class="list-disc list-inside text-sm text-slate-600 dark:text-slate-400 space-y-1">
            <li>
              <code class="text-xs bg-slate-100 dark:bg-slate-700 px-1 rounded">
                jobcelis_events_created_total
              </code>
              — {gettext("Eventos creados (por proyecto, topic)")}
            </li>
            <li>
              <code class="text-xs bg-slate-100 dark:bg-slate-700 px-1 rounded">
                jobcelis_deliveries_success_total
              </code>
              — {gettext("Entregas exitosas (por proyecto, webhook, topic)")}
            </li>
            <li>
              <code class="text-xs bg-slate-100 dark:bg-slate-700 px-1 rounded">
                jobcelis_deliveries_failed_total
              </code>
              — {gettext("Entregas fallidas (por proyecto, webhook, topic)")}
            </li>
          </ul>
        </div>
        <div>
          <h4 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-1">Gauges</h4>
          <ul class="list-disc list-inside text-sm text-slate-600 dark:text-slate-400 space-y-1">
            <li>
              <code class="text-xs bg-slate-100 dark:bg-slate-700 px-1 rounded">
                jobcelis_webhooks_active
              </code>
              — {gettext("Webhooks activos")}
            </li>
            <li>
              <code class="text-xs bg-slate-100 dark:bg-slate-700 px-1 rounded">
                jobcelis_circuit_breakers_open
              </code>
              — {gettext("Circuit breakers abiertos")}
            </li>
            <li>
              <code class="text-xs bg-slate-100 dark:bg-slate-700 px-1 rounded">
                jobcelis_deliveries_pending
              </code>
              — {gettext("Entregas pendientes en cola")}
            </li>
          </ul>
        </div>
        <div>
          <h4 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-1">Histograms</h4>
          <ul class="list-disc list-inside text-sm text-slate-600 dark:text-slate-400 space-y-1">
            <li>
              <code class="text-xs bg-slate-100 dark:bg-slate-700 px-1 rounded">
                jobcelis_delivery_latency_milliseconds
              </code>
              — {gettext("Latencia de entregas (por proyecto, webhook, topic)")}
            </li>
          </ul>
        </div>
      </div>
      <.callout kind="info">
        {gettext(
          "Las métricas se exponen en un puerto separado. Configura tu scraper de Prometheus apuntando al puerto de métricas."
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
      subtitle={gettext("SDKs oficiales para los principales lenguajes de programación.")}
    >
      <p class="text-slate-700 leading-relaxed mb-6">
        {gettext(
          "Todas las SDKs proporcionan cobertura completa de la API. Seleccionar el lenguaje de preferencia:"
        )}
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
      <div class="rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800/50 p-5 mb-6">
        <h3 class="text-sm font-semibold text-slate-900 mb-3">
          {gettext("Enlaces de instalación")}
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
      subtitle={
        gettext(
          "Interfaz de línea de comandos para gestionar eventos, webhooks, jobs y recursos de la plataforma."
        )
      }
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
      subtitle={gettext("Verificación de la firma HMAC de cada entrega para confirmar autenticidad.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Cada entrega incluye una firma HMAC en el header X-Signature. Verificar siempre las firmas para confirmar que la solicitud se originó en Jobcelis."
        )}
      </p>

      <h4 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-3">
        {gettext("Algoritmo de firma")}
      </h4>
      <div class="bg-slate-50 dark:bg-slate-800/50 rounded-lg p-4 mb-4 text-sm text-slate-600 dark:text-slate-400">
        <ol class="list-decimal list-inside space-y-1">
          <li>{gettext("Se calcula HMAC-SHA256 del body crudo usando el secret del webhook")}</li>
          <li>{gettext("Se codifica el resultado en Base64 sin padding")}</li>
          <li>{gettext("Se envía en el header como: X-Signature: sha256=<base64>")}</li>
        </ol>
      </div>

      <h4 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-3">
        {gettext("Función de verificación por lenguaje")}
      </h4>

      <.sdk_code_block
        sdk_languages={@sdk_languages}
        example="verify_webhook"
      />

      <h4 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mt-6 mb-3">
        {gettext("Ejemplos de middleware por framework")}
      </h4>

      <div class="space-y-3 mb-4">
        <.framework_example
          name="Express.js (Node.js)"
          code={framework_code(:express)}
        />
        <.framework_example
          name="FastAPI (Python)"
          code={framework_code(:fastapi)}
        />
        <.framework_example
          name="Gin (Go)"
          code={framework_code(:gin)}
        />
        <.framework_example
          name="Phoenix (Elixir)"
          code={framework_code(:phoenix)}
        />
        <.framework_example
          name="Laravel (PHP)"
          code={framework_code(:laravel)}
        />
        <.framework_example
          name="Spring Boot (Java)"
          code={framework_code(:spring)}
        />
        <.framework_example
          name="ASP.NET (C#)"
          code={framework_code(:aspnet)}
        />
        <.framework_example
          name="Rails (Ruby)"
          code={framework_code(:rails)}
        />
      </div>

      <h4 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mt-6 mb-3">
        {gettext("Verificación desde CLI")}
      </h4>
      <.code_block
        code={"jobcelis verify-signature \\\n  --secret \"whsec_your_secret\" \\\n  --body '{\"topic\":\"order.created\",\"data\":{\"id\":\"123\"}}' \\\n  --signature \"sha256=abc123...\""}
        copy_id="copy-verify-cli"
      />

      <.callout kind="warning">
        {gettext(
          "Utilizar siempre comparación de tiempo constante (constant-time comparison). No utilizar operadores == o === para verificar firmas. Verificar el body crudo (raw), no una versión re-serializada."
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
      subtitle={gettext("Protección contra ataques de fuerza bruta.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "Después de múltiples intentos de autenticación fallidos en un período corto, la cuenta se bloquea temporalmente. Proporciona protección contra ataques de fuerza bruta y credenciales comprometidas."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="session-management"
      title={gettext("Gestión de sesiones")}
      subtitle={gettext("Control de sesiones activas.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "Las sesiones web utilizan cookies cifradas con timeout de inactividad. La sesión se cierra automáticamente tras un período de inactividad."
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
          "Activar la autenticación de dos factores desde la página de cuenta. Utilizar una aplicación de autenticación compatible (Google Authenticator, Authy, etc.) para escanear el código QR. Cada inicio de sesión requiere la contraseña y el código TOTP de la aplicación."
        )}
      </p>
      <.callout kind="tip">
        {gettext(
          "Al activar MFA se generan códigos de respaldo de un solo uso. Deben almacenarse de forma segura para permitir acceso en caso de pérdida del dispositivo."
        )}
      </.callout>
    </.docs_section>

    <.docs_section
      id="password-policy"
      title={gettext("Política de contraseñas")}
      subtitle={gettext("Política de requisitos de contraseña.")}
    >
      <div class="rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-4">
        <ul class="text-slate-700 text-sm space-y-2">
          <li>{gettext("Longitud mínima requerida")}</li>
          <li>{gettext("Debe incluir mayúsculas, minúsculas y números")}</li>
          <li>{gettext("Se recomienda incluir caracteres especiales")}</li>
          <li>
            {gettext("Las contraseñas se almacenan con hashing seguro de alto consumo de memoria")}
          </li>
        </ul>
      </div>
    </.docs_section>

    <.docs_section
      id="data-encryption"
      title={gettext("Cifrado de datos")}
      subtitle={gettext("Protección de datos personales.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Los datos personales (email, nombre) se cifran en reposo con cifrado de nivel industrial. Las búsquedas por email utilizan un hash determinista, evitando la necesidad de descifrar durante las consultas."
        )}
      </p>
      <.callout kind="info">
        {gettext(
          "El cifrado en reposo protege los datos incluso en caso de acceso directo a la base de datos. Solo la aplicación puede descifrar los datos."
        )}
      </.callout>
    </.docs_section>

    <.docs_section
      id="circuit-breaker"
      title="Circuit Breaker"
      subtitle={gettext("Protección automática para webhooks inestables.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "Si un webhook falla repetidamente, el circuit breaker lo desactiva temporalmente para prevenir cascadas de fallos. Cuando el endpoint se recupera, el webhook se reactiva automáticamente."
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
          "El sistema monitorea continuamente patrones anómalos: múltiples intentos de autenticación fallidos, accesos desde ubicaciones inusuales y otros indicadores de posibles incidentes de seguridad."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="event-integrity"
      title={gettext("Integridad de eventos")}
      subtitle={gettext("Garantía de integridad e inmutabilidad de eventos.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Cada evento recibe un hash criptográfico único al momento de creación. Permite verificar que el contenido no ha sido alterado. Los eventos se almacenan de forma inmutable."
        )}
      </p>
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "Adicionalmente, cada evento soporta un idempotency_key opcional para prevención de duplicados. Si se envían múltiples eventos con el mismo idempotency_key, solo el primero se procesa."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="uptime-monitoring"
      title={gettext("Monitoreo")}
      subtitle={gettext("Supervisión automática de la plataforma.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "La plataforma se monitorea de forma continua. El estado actual está disponible en la página de estado (/status). Los componentes monitoreados incluyen la base de datos, el sistema de procesamiento y la capa de caché."
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
          "Se realizan copias de seguridad automáticas periódicamente. Los backups se almacenan de forma segura y cifrada. En caso de incidente, los datos pueden restaurarse de forma expedita."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="data-protection"
      title={gettext("GDPR / RGPD")}
      subtitle={gettext("Derechos de protección de datos.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Jobcelis cumple con el RGPD/GDPR. Los usuarios tienen los siguientes derechos de protección de datos:"
        )}
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
      subtitle={gettext("Gestión versionada de consentimientos GDPR.")}
    >
      <div class="space-y-4">
        <.api_endpoint
          id="consent-status"
          method="GET"
          path="/api/v1/me/consents"
          description={
            gettext("Obtiene el estado actual de los consentimientos de procesamiento de datos.")
          }
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/me/consents\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-consent-status"
          />
          <.response_block
            code={
              ~s|{\n  "consents": [\n    {\n      "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "purpose": "essential",\n      "version": 1,\n      "granted_at": "2026-01-15T10:00:00Z"\n    },\n    {\n      "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",\n      "purpose": "analytics",\n      "version": 2,\n      "granted_at": "2026-02-20T14:00:00Z"\n    }\n  ],\n  "outdated": ["analytics"],\n  "current_versions": {\n    "essential": 1,\n    "analytics": 3\n  }\n}|
            }
            copy_id="copy-consent-status-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="consent-accept"
          method="POST"
          path="/api/v1/me/consents/:purpose/accept"
          description={gettext("Acepta un consentimiento específico por identificador de propósito.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/me/consents/analytics/accept\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-consent-accept"
          />
          <.response_block
            code={
              ~s|{\n  "consent": {\n    "id": "c3d4e5f6-a7b8-9012-cdef-234567890abc",\n    "purpose": "analytics",\n    "version": 3,\n    "granted_at": "2026-03-07T14:30:00Z"\n  }\n}|
            }
            copy_id="copy-consent-accept-response"
            status="200 OK"
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
      <div class="rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-4 overflow-x-auto">
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
      id="error-responses"
      title={gettext("Respuestas de error")}
      subtitle={gettext("Formato estándar de errores devueltos por la API.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Las solicitudes fallidas devuelven una respuesta JSON con un campo \"error\" que describe el problema."
        )}
      </p>

      <.code_block
        code={
          ~s|// 400 Bad Request — missing or invalid parameters\n{"error": "Missing required field: topic"}\n\n// 401 Unauthorized — invalid or missing API key\n{"error": "Invalid API key"}\n\n// 404 Not Found — resource does not exist\n{"error": "Event not found"}\n\n// 422 Unprocessable Entity — validation error\n{"error": "URL must start with https://"}\n\n// 429 Too Many Requests — rate limit exceeded\n{"error": "Rate limit exceeded. Try again later."}|
        }
        copy_id="copy-error-responses"
        title={gettext("Ejemplos de errores comunes")}
      />

      <.callout kind="tip">
        {gettext(
          "El campo \"error\" siempre contiene un string legible. Algunos endpoints pueden incluir campos adicionales como \"details\" con información de error específica."
        )}
      </.callout>
    </.docs_section>

    <.docs_section
      id="response-headers"
      title={gettext("Headers de respuesta")}
      subtitle={gettext("Headers incluidos en las respuestas de la API.")}
    >
      <div class="rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-4 overflow-x-auto">
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
        description={gettext("Devuelve HTTP 200 si la plataforma está operativa.")}
      >
        <.code_block
          code={"curl \"#{@base_url}/health\""}
          copy_id="copy-health"
        />
        <.response_block
          code={~s|{\n  "status": "healthy",\n  "timestamp": "2026-03-07T14:30:00Z"\n}|}
          copy_id="copy-health-response"
          status="200 OK"
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
          "Configurar scopes para restringir los permisos de cada API key. Scopes disponibles:"
        )}
      </p>
      <div class="rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-4">
        <div class="grid sm:grid-cols-2 gap-2 text-sm text-slate-700">
          <div>
            <code class="bg-white dark:bg-slate-800 px-1.5 py-0.5 rounded border border-slate-200 dark:border-slate-600 font-mono text-xs dark:text-slate-200">
              events:read
            </code>
            — {gettext("Leer eventos")}
          </div>
          <div>
            <code class="bg-white dark:bg-slate-800 px-1.5 py-0.5 rounded border border-slate-200 dark:border-slate-600 font-mono text-xs dark:text-slate-200">
              events:write
            </code>
            — {gettext("Crear eventos")}
          </div>
          <div>
            <code class="bg-white dark:bg-slate-800 px-1.5 py-0.5 rounded border border-slate-200 dark:border-slate-600 font-mono text-xs dark:text-slate-200">
              webhooks:read
            </code>
            — {gettext("Leer webhooks")}
          </div>
          <div>
            <code class="bg-white dark:bg-slate-800 px-1.5 py-0.5 rounded border border-slate-200 dark:border-slate-600 font-mono text-xs dark:text-slate-200">
              webhooks:write
            </code>
            — {gettext("Crear/editar webhooks")}
          </div>
          <div>
            <code class="bg-white dark:bg-slate-800 px-1.5 py-0.5 rounded border border-slate-200 dark:border-slate-600 font-mono text-xs dark:text-slate-200">
              jobs:read
            </code>
            — {gettext("Leer jobs")}
          </div>
          <div>
            <code class="bg-white dark:bg-slate-800 px-1.5 py-0.5 rounded border border-slate-200 dark:border-slate-600 font-mono text-xs dark:text-slate-200">
              jobs:write
            </code>
            — {gettext("Crear/editar jobs")}
          </div>
          <div>
            <code class="bg-white dark:bg-slate-800 px-1.5 py-0.5 rounded border border-slate-200 dark:border-slate-600 font-mono text-xs dark:text-slate-200">
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
