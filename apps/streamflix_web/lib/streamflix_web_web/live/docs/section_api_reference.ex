defmodule StreamflixWebWeb.Docs.SectionApiReference do
  @moduledoc """
  API Reference documentation section covering events, webhooks, deliveries,
  jobs, project/token, pipelines, dead letters, replays, schemas, and data
  export endpoints.
  """

  use Phoenix.Component
  use Gettext, backend: StreamflixWebWeb.Gettext

  import StreamflixWebWeb.Docs.Components

  attr :base_url, :string, required: true

  def render(assigns) do
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
          id="events-send"
          method="POST"
          path="/api/v1/send"
          description={
            gettext(
              "Alias de POST /api/v1/events. Atajo para enviar un evento con el mismo formato de body y respuesta."
            )
          }
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/send\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"topic\":\"order.created\",\"order_id\":\"12345\",\"amount\":99.99}'"}
            copy_id="copy-send-event"
          />
          <.response_block
            code={
              ~s|{\n  "event_id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",\n  "payload_hash": "sha256:a3f2b8c1d4e5..."\n}|
            }
            copy_id="copy-send-event-response"
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

        <.api_endpoint
          id="webhooks-health"
          method="GET"
          path="/api/v1/webhooks/:id/health"
          description={gettext("Obtiene el estado de salud de un webhook.")}
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/webhooks/WEBHOOK_ID/health\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-webhook-health"
          />
          <.response_block
            code={
              ~s|{\n  "webhook_id": "c3d4e5f6-a7b8-9012-cdef-123456789012",\n  "url": "https://example.com/hook",\n  "health": {\n    "status": "healthy",\n    "success_rate": 0.98,\n    "avg_latency_ms": 120,\n    "last_delivery_at": "2026-01-15T10:30:00Z"\n  }\n}|
            }
            copy_id="copy-webhook-health-response"
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
end
