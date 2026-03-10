defmodule StreamflixWebWeb.Docs.SectionGettingStarted do
  @moduledoc "Getting started documentation section"

  use Phoenix.Component
  use Gettext, backend: StreamflixWebWeb.Gettext

  import StreamflixWebWeb.Docs.Components

  attr :base_url, :string, required: true

  def render(assigns) do
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

  # ── Quick start step card ───────────────────────────────────────────

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
end
