defmodule StreamflixWebWeb.Docs.SectionAdvanced do
  @moduledoc """
  Advanced features documentation section covering topic wildcards, delayed events,
  batch events, cursor pagination, webhook templates, IP allowlist, simulate,
  idempotency keys, external alerts, embed portal, rate limiting, Prometheus metrics,
  webhook testing, and data retention.
  """
  use Phoenix.Component
  use Gettext, backend: StreamflixWebWeb.Gettext

  import StreamflixWebWeb.Docs.Components

  attr :base_url, :string, required: true

  def render(assigns) do
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
        code={"# Option 1: idempotency_key in the request body\ncurl -X POST \"#{@base_url}/api/v1/send\" \\\n  -H \"Authorization: Bearer YOUR_API_KEY\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"topic\":\"order.created\",\"amount\":150,\"idempotency_key\":\"order-123-abc\"}'"}
        copy_id="copy-idempotency-body"
      />
      <.code_block
        code={"# Option 2: X-Idempotency-Key as header\ncurl -X POST \"#{@base_url}/api/v1/send\" \\\n  -H \"Authorization: Bearer YOUR_API_KEY\" \\\n  -H \"Content-Type: application/json\" \\\n  -H \"X-Idempotency-Key: order-123-abc\" \\\n  -d '{\"topic\":\"order.created\",\"amount\":150}'"}
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
      <.api_endpoint
        id="notification-channel-show"
        method="GET"
        path="/api/v1/notification-channels"
        description={gettext("Listar los canales de notificación configurados.")}
      >
        <.code_block
          code={"curl \"#{@base_url}/api/v1/notification-channels\" \\\n  -H \"Authorization: Bearer YOUR_API_KEY\""}
          copy_id="copy-notification-show"
        />
        <.response_block
          code={
            ~s|{\n  "data": {\n    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "project_id": "p1a2b3c4-d5e6-7890-abcd-ef1234567890",\n    "email_enabled": true,\n    "email_address": "alerts@example.com",\n    "slack_enabled": true,\n    "slack_webhook_url": "https://hooks.slack.com/••••••",\n    "discord_enabled": false,\n    "discord_webhook_url": null,\n    "meta_webhook_enabled": false,\n    "meta_webhook_url": null,\n    "meta_webhook_secret": null,\n    "event_types": ["webhook_failing", "circuit_open"],\n    "inserted_at": "2026-03-07T14:30:00Z",\n    "updated_at": "2026-03-07T14:30:00Z"\n  }\n}|
          }
          status="200 OK"
          copy_id="copy-notification-show-resp"
        />
      </.api_endpoint>
      <.api_endpoint
        id="notification-channel-delete"
        method="DELETE"
        path="/api/v1/notification-channels"
        description={gettext("Eliminar la configuración de canal de notificación.")}
      >
        <.code_block
          code={"curl -X DELETE \"#{@base_url}/api/v1/notification-channels\" \\\n  -H \"Authorization: Bearer YOUR_API_KEY\""}
          copy_id="copy-notification-delete"
        />
        <.response_block
          code={~s|# 204 No Content (empty response body)|}
          status="204 No Content"
          copy_id="copy-notification-delete-resp"
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
      <.api_endpoint
        id="embed-token-list"
        method="GET"
        path="/api/v1/embed/tokens"
        description={gettext("Listar los tokens de embed del proyecto.")}
      >
        <.code_block
          code={"curl \"#{@base_url}/api/v1/embed/tokens\" \\\n  -H \"Authorization: Bearer YOUR_API_KEY\""}
          copy_id="copy-embed-token-list"
        />
        <.response_block
          code={
            ~s|{\n  "data": [\n    {\n      "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "prefix": "emb_abc",\n      "name": "My Portal",\n      "status": "active",\n      "scopes": ["webhooks:read", "webhooks:write"],\n      "allowed_origins": ["https://example.com"],\n      "metadata": {},\n      "expires_at": null,\n      "inserted_at": "2026-03-07T14:30:00Z"\n    }\n  ]\n}|
          }
          status="200 OK"
          copy_id="copy-embed-token-list-resp"
        />
      </.api_endpoint>
      <.api_endpoint
        id="embed-token-revoke"
        method="DELETE"
        path="/api/v1/embed/tokens/:id"
        description={gettext("Revocar un token de embed.")}
      >
        <.code_block
          code={"curl -X DELETE \"#{@base_url}/api/v1/embed/tokens/TOKEN_ID\" \\\n  -H \"Authorization: Bearer YOUR_API_KEY\""}
          copy_id="copy-embed-token-revoke"
        />
        <.response_block
          code={~s|{\n  "status": "revoked"\n}|}
          status="200 OK"
          copy_id="copy-embed-token-revoke-resp"
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

    <.docs_section
      id="webhook-testing"
      title={gettext("Testing de webhooks")}
      subtitle={
        gettext("Envía un evento de prueba a un webhook sin crear un evento real en el proyecto.")
      }
    >
      <p class="text-slate-700 dark:text-slate-300 leading-relaxed mb-4">
        {gettext(
          "Usa el endpoint de test para verificar que el receptor está configurado correctamente. Se envía un payload de prueba con el tipo webhook.test, se calcula la firma HMAC si el webhook tiene secret, y se retorna el código de respuesta y la latencia."
        )}
      </p>

      <.api_endpoint
        method="POST"
        path="/api/v1/webhooks/:id/test"
        description={gettext("Enviar evento de prueba a un webhook.")}
        id="ep-test-webhook"
      >
        <.code_block
          code={"curl -X POST #{@base_url}/api/v1/webhooks/WEBHOOK_ID/test \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
          copy_id="copy-test-webhook"
        />
        <.response_block
          code={
            ~s|{\n  "success": true,\n  "status": 200,\n  "latency_ms": 145,\n  "webhook_id": "abc-123"\n}|
          }
          status="200 OK"
          copy_id="copy-test-webhook-resp"
        />
      </.api_endpoint>

      <.callout kind="info">
        {gettext(
          "El evento de prueba no se almacena ni genera entregas reales. También puedes enviar pruebas desde el dashboard usando el botón de avión de papel en la fila del webhook."
        )}
      </.callout>
    </.docs_section>

    <.docs_section
      id="data-retention"
      title={gettext("Retención de datos")}
      subtitle={
        gettext("Configura retención automática por proyecto y ejecuta purgas manuales selectivas.")
      }
    >
      <h4 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-3">
        {gettext("Retención automática")}
      </h4>
      <p class="text-slate-700 dark:text-slate-300 leading-relaxed mb-4">
        {gettext(
          "Configura cuántos días retener cada tipo de dato. El sistema purga automáticamente los registros antiguos de forma semanal. Un valor de 0 significa retención ilimitada."
        )}
      </p>

      <.api_endpoint
        method="GET"
        path="/api/v1/retention"
        description={gettext("Consultar la política de retención actual del proyecto.")}
        id="ep-get-retention"
      >
        <.code_block
          code={"curl \"#{@base_url}/api/v1/retention\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
          copy_id="copy-get-retention"
        />
        <.response_block
          code={
            ~s|{\n  "retention_days": null,\n  "retention_policy": {\n    "events_days": 90,\n    "deliveries_days": 30,\n    "audit_logs_days": 365\n  }\n}|
          }
          status="200 OK"
          copy_id="copy-get-retention-resp"
        />
      </.api_endpoint>

      <.api_endpoint
        method="PATCH"
        path="/api/v1/retention"
        description={gettext("Actualizar política de retención.")}
        id="ep-update-retention"
      >
        <.code_block
          code={"curl -X PATCH #{@base_url}/api/v1/retention \\\n  -H \"X-Api-Key: YOUR_API_KEY\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"events_days\": 90, \"deliveries_days\": 30, \"audit_logs_days\": 365}'"}
          copy_id="copy-update-retention"
        />
        <.response_block
          code={
            ~s|{\n  "retention_policy": {\n    "events_days": 90,\n    "deliveries_days": 30,\n    "audit_logs_days": 365\n  }\n}|
          }
          status="200 OK"
          copy_id="copy-retention-resp"
        />
      </.api_endpoint>

      <h4 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mt-6 mb-3">
        {gettext("Purga manual")}
      </h4>
      <p class="text-slate-700 dark:text-slate-300 leading-relaxed mb-4">
        {gettext(
          "Elimina datos de forma selectiva por tipo, fecha, topic y status. Usa el endpoint de preview para ver cuántos registros se eliminarían antes de ejecutar."
        )}
      </p>

      <.api_endpoint
        method="POST"
        path="/api/v1/purge/preview"
        description={gettext("Vista previa de purga (sin eliminar).")}
        id="ep-purge-preview"
      >
        <.code_block
          code={"curl -X POST #{@base_url}/api/v1/purge/preview \\\n  -H \"X-Api-Key: YOUR_API_KEY\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"type\": \"deliveries\", \"older_than\": \"2025-01-01\", \"status\": \"failed\"}'"}
          copy_id="copy-purge-preview"
        />
        <.response_block
          code={~s|{\n  "type": "deliveries",\n  "count": 1247,\n  "older_than": "2025-01-01"\n}|}
          status="200 OK"
          copy_id="copy-purge-preview-resp"
        />
      </.api_endpoint>

      <.api_endpoint
        method="POST"
        path="/api/v1/purge"
        description={gettext("Ejecutar purga de datos.")}
        id="ep-purge-execute"
      >
        <.code_block
          code={"curl -X POST #{@base_url}/api/v1/purge \\\n  -H \"X-Api-Key: YOUR_API_KEY\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"type\": \"deliveries\", \"older_than\": \"2025-01-01\", \"status\": \"failed\"}'"}
          copy_id="copy-purge-execute"
        />
        <.response_block
          code={
            ~s|{\n  "type": "deliveries",\n  "deleted_count": 1247,\n  "older_than": "2025-01-01"\n}|
          }
          status="200 OK"
          copy_id="copy-purge-execute-resp"
        />
      </.api_endpoint>

      <div class="bg-slate-50 dark:bg-slate-800/50 rounded-lg p-4 mb-4">
        <h4 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-2">
          {gettext("Tipos disponibles para purga")}
        </h4>
        <table class="w-full text-sm">
          <thead class="text-left text-slate-500 dark:text-slate-400">
            <tr>
              <th class="py-1 pr-4">{gettext("Tipo")}</th>
              <th class="py-1 pr-4">{gettext("Filtros opcionales")}</th>
            </tr>
          </thead>
          <tbody class="text-slate-700 dark:text-slate-300">
            <tr class="border-t border-slate-200 dark:border-slate-700">
              <td class="py-1 pr-4 font-mono text-xs">events</td>
              <td class="py-1 text-xs">topic</td>
            </tr>
            <tr class="border-t border-slate-200 dark:border-slate-700">
              <td class="py-1 pr-4 font-mono text-xs">deliveries</td>
              <td class="py-1 text-xs">topic, status</td>
            </tr>
            <tr class="border-t border-slate-200 dark:border-slate-700">
              <td class="py-1 pr-4 font-mono text-xs">audit_logs</td>
              <td class="py-1 text-xs">—</td>
            </tr>
            <tr class="border-t border-slate-200 dark:border-slate-700">
              <td class="py-1 pr-4 font-mono text-xs">dead_letters</td>
              <td class="py-1 text-xs">—</td>
            </tr>
          </tbody>
        </table>
      </div>

      <.callout kind="warning">
        {gettext(
          "La purga de datos es irreversible. Usa siempre el endpoint de preview antes de ejecutar para confirmar el número de registros afectados."
        )}
      </.callout>
    </.docs_section>
    """
  end
end
