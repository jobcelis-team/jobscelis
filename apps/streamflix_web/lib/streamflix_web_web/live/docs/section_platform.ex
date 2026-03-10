defmodule StreamflixWebWeb.Docs.SectionPlatform do
  @moduledoc "Platform documentation section covering dashboard, account management, password recovery, multi-project, teams, sandbox, analytics, audit log, and real-time streaming."

  use Phoenix.Component
  use Gettext, backend: StreamflixWebWeb.Gettext

  import StreamflixWebWeb.Docs.Components

  attr :base_url, :string, required: true

  def render(assigns) do
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
        <.api_endpoint
          id="projects-show"
          method="GET"
          path="/api/v1/projects/:id"
          description={
            gettext("Obtiene los detalles de un proyecto específico por su ID (requiere JWT).")
          }
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/projects/PROJECT_ID\" \\\n  -H \"Authorization: Bearer YOUR_JWT_TOKEN\""}
            copy_id="copy-projects-show"
          />
          <.response_block
            code={
              ~s|{\n  "data": {\n    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "name": "Production",\n    "status": "active",\n    "is_default": true,\n    "settings": {},\n    "inserted_at": "2026-01-01T00:00:00Z",\n    "updated_at": "2026-01-10T08:00:00Z"\n  }\n}|
            }
            copy_id="copy-projects-show-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="projects-update"
          method="PATCH"
          path="/api/v1/projects/:id"
          description={
            gettext(
              "Actualiza el nombre, configuración o política de retención de un proyecto existente."
            )
          }
        >
          <.code_block
            code={"curl -X PATCH \"#{@base_url}/api/v1/projects/PROJECT_ID\" \\\n  -H \"Authorization: Bearer YOUR_JWT_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"name\":\"Updated Project Name\",\"settings\":{\"notifications\":true}}'"}
            copy_id="copy-projects-update"
          />
          <.response_block
            code={
              ~s|{\n  "data": {\n    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "name": "Updated Project Name",\n    "status": "active",\n    "is_default": true,\n    "settings": {"notifications": true},\n    "inserted_at": "2026-01-01T00:00:00Z",\n    "updated_at": "2026-01-15T12:00:00Z"\n  }\n}|
            }
            copy_id="copy-projects-update-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="projects-delete"
          method="DELETE"
          path="/api/v1/projects/:id"
          description={
            gettext(
              "Elimina un proyecto (solo el propietario puede hacerlo). Los datos asociados se desactivan."
            )
          }
        >
          <.code_block
            code={"curl -X DELETE \"#{@base_url}/api/v1/projects/PROJECT_ID\" \\\n  -H \"Authorization: Bearer YOUR_JWT_TOKEN\""}
            copy_id="copy-projects-delete"
          />
          <.response_block
            code={~s|{\n  "ok": true\n}|}
            copy_id="copy-projects-delete-response"
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
        <.api_endpoint
          id="invitations-pending"
          method="GET"
          path="/api/v1/invitations/pending"
          description={
            gettext(
              "Lista las invitaciones pendientes del usuario autenticado en todos los proyectos."
            )
          }
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/invitations/pending\" \\\n  -H \"Authorization: Bearer YOUR_JWT_TOKEN\""}
            copy_id="copy-invitations-pending"
          />
          <.response_block
            code={
              ~s|{\n  "data": [\n    {\n      "id": "f3a4b5c6-d7e8-9012-opqr-345678901234",\n      "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "user_id": "f2a3b4c5-d6e7-8901-mnop-012345678901",\n      "role": "member",\n      "status": "pending",\n      "invited_by": "c3d4e5f6-a7b8-9012-cdef-234567890abc",\n      "inserted_at": "2026-01-20T09:00:00Z"\n    }\n  ]\n}|
            }
            copy_id="copy-invitations-pending-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="invitations-accept"
          method="POST"
          path="/api/v1/invitations/:id/accept"
          description={
            gettext(
              "Acepta una invitación pendiente, otorgando acceso al proyecto con el rol asignado."
            )
          }
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/invitations/INVITATION_ID/accept\" \\\n  -H \"Authorization: Bearer YOUR_JWT_TOKEN\""}
            copy_id="copy-invitations-accept"
          />
          <.response_block
            code={
              ~s|{\n  "data": {\n    "id": "f3a4b5c6-d7e8-9012-opqr-345678901234",\n    "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "user_id": "f2a3b4c5-d6e7-8901-mnop-012345678901",\n    "role": "member",\n    "status": "accepted",\n    "invited_by": "c3d4e5f6-a7b8-9012-cdef-234567890abc",\n    "inserted_at": "2026-01-20T09:00:00Z"\n  }\n}|
            }
            copy_id="copy-invitations-accept-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="invitations-reject"
          method="POST"
          path="/api/v1/invitations/:id/reject"
          description={gettext("Rechaza una invitación pendiente, declinando el acceso al proyecto.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/invitations/INVITATION_ID/reject\" \\\n  -H \"Authorization: Bearer YOUR_JWT_TOKEN\""}
            copy_id="copy-invitations-reject"
          />
          <.response_block
            code={
              ~s|{\n  "data": {\n    "id": "f3a4b5c6-d7e8-9012-opqr-345678901234",\n    "project_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n    "user_id": "f2a3b4c5-d6e7-8901-mnop-012345678901",\n    "role": "member",\n    "status": "rejected",\n    "invited_by": "c3d4e5f6-a7b8-9012-cdef-234567890abc",\n    "inserted_at": "2026-01-20T09:00:00Z"\n  }\n}|
            }
            copy_id="copy-invitations-reject-response"
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
      title={gettext("Streaming en tiempo real")}
      subtitle={
        gettext(
          "Recibe eventos y actualizaciones de entregas en tiempo real mediante SSE (Server-Sent Events) o WebSocket (Phoenix Channel). Dos protocolos, los mismos datos."
        )
      }
    >
      <%!-- ── Tipos de mensaje ── --%>
      <div class="mb-8">
        <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100 mb-3">
          {gettext("Tipos de mensaje")}
        </h3>
        <p class="text-slate-600 dark:text-slate-400 text-sm mb-4">
          {gettext("Ambos protocolos (SSE y WebSocket) transmiten los mismos tipos de mensaje:")}
        </p>
        <div class="rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-4 overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-slate-500">
                <th class="pb-2 font-medium">{gettext("Mensaje")}</th>
                <th class="pb-2 font-medium">{gettext("Cuándo se emite")}</th>
                <th class="pb-2 font-medium">{gettext("Campos")}</th>
              </tr>
            </thead>
            <tbody class="text-slate-700 dark:text-slate-300">
              <tr class="border-t border-slate-200 dark:border-slate-700">
                <td class="py-2 font-mono text-xs">event.created</td>
                <td class="py-2 text-xs">
                  {gettext("Cada vez que llega un evento nuevo al proyecto")}
                </td>
                <td class="py-2 font-mono text-xs">id, topic, payload, occurred_at</td>
              </tr>
              <tr class="border-t border-slate-200 dark:border-slate-700">
                <td class="py-2 font-mono text-xs">delivery.updated</td>
                <td class="py-2 text-xs">
                  {gettext("Cada vez que un webhook responde (éxito o fallo)")}
                </td>
                <td class="py-2 font-mono text-xs">id, status, event_id</td>
              </tr>
              <tr class="border-t border-slate-200 dark:border-slate-700">
                <td class="py-2 font-mono text-xs">connected</td>
                <td class="py-2 text-xs">{gettext("Al establecer la conexión (solo SSE)")}</td>
                <td class="py-2 font-mono text-xs">project_id</td>
              </tr>
              <tr class="border-t border-slate-200 dark:border-slate-700">
                <td class="py-2 font-mono text-xs">keepalive</td>
                <td class="py-2 text-xs">
                  {gettext("Cada 30 segundos para mantener la conexión (solo SSE)")}
                </td>
                <td class="py-2 font-mono text-xs">—</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <%!-- ── SSE vs WebSocket ── --%>
      <div class="mb-8">
        <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100 mb-3">
          {gettext("SSE vs WebSocket")}
        </h3>
        <div class="rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-4 overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-slate-500">
                <th class="pb-2 font-medium"></th>
                <th class="pb-2 font-medium">SSE</th>
                <th class="pb-2 font-medium">WebSocket</th>
              </tr>
            </thead>
            <tbody class="text-slate-700 dark:text-slate-300">
              <tr class="border-t border-slate-200 dark:border-slate-700">
                <td class="py-2 font-medium text-xs">{gettext("Endpoint")}</td>
                <td class="py-2 font-mono text-xs">GET /api/v1/stream</td>
                <td class="py-2 font-mono text-xs">WS /ws</td>
              </tr>
              <tr class="border-t border-slate-200 dark:border-slate-700">
                <td class="py-2 font-medium text-xs">{gettext("Autenticación")}</td>
                <td class="py-2 text-xs">Header Authorization / X-Api-Key</td>
                <td class="py-2 text-xs">Query param ?token=API_KEY</td>
              </tr>
              <tr class="border-t border-slate-200 dark:border-slate-700">
                <td class="py-2 font-medium text-xs">{gettext("Dirección")}</td>
                <td class="py-2 text-xs">{gettext("Unidireccional (server → cliente)")}</td>
                <td class="py-2 text-xs">{gettext("Bidireccional")}</td>
              </tr>
              <tr class="border-t border-slate-200 dark:border-slate-700">
                <td class="py-2 font-medium text-xs">{gettext("Reconexión")}</td>
                <td class="py-2 text-xs">
                  {gettext("Automática en navegadores (EventSource)")}
                </td>
                <td class="py-2 text-xs">
                  {gettext("Automática con Phoenix Socket")}
                </td>
              </tr>
              <tr class="border-t border-slate-200 dark:border-slate-700">
                <td class="py-2 font-medium text-xs">{gettext("Ideal para")}</td>
                <td class="py-2 text-xs">
                  {gettext("curl, scripts, CLIs, integraciones simples")}
                </td>
                <td class="py-2 text-xs">
                  {gettext("Apps frontend, dashboards, servicios persistentes")}
                </td>
              </tr>
              <tr class="border-t border-slate-200 dark:border-slate-700">
                <td class="py-2 font-medium text-xs">Scope</td>
                <td class="py-2 font-mono text-xs">events:read</td>
                <td class="py-2 font-mono text-xs">events:read</td>
              </tr>
              <tr class="border-t border-slate-200 dark:border-slate-700">
                <td class="py-2 font-medium text-xs">Timeout</td>
                <td class="py-2 text-xs">
                  {gettext("120 segundos sin actividad (reconectar)")}
                </td>
                <td class="py-2 text-xs">
                  {gettext("120 segundos sin actividad (reconectar)")}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <%!-- ── SSE Endpoint ── --%>
      <div class="space-y-6">
        <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100">
          SSE (Server-Sent Events)
        </h3>
        <.api_endpoint
          id="sse-stream"
          method="GET"
          path="/api/v1/stream"
          description={
            gettext(
              "Establece una conexión SSE para recibir eventos y actualizaciones de entregas en tiempo real. La conexión permanece abierta y transmite datos a medida que ocurren."
            )
          }
        >
          <.code_block
            code={"curl -N \"#{@base_url}/api/v1/stream\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-sse-stream"
          />
          <.response_block
            code={
              ~s|data: {"type":"connected","project_id":"a1b2c3d4-e5f6-7890-abcd-ef1234567890"}\n\ndata: {"type":"event.created","data":{"id":"b2c3d4e5-f6a7-8901-bcde-f12345678901","topic":"order.created","payload":{"order_id":"123"},"occurred_at":"2026-03-07T14:30:00Z"}}\n\ndata: {"type":"delivery.updated","data":{"id":"c3d4e5f6-a7b8-9012-cdef-234567890abc","status":"delivered","event_id":"b2c3d4e5-f6a7-8901-bcde-f12345678901"}}\n\n: keepalive|
            }
            copy_id="copy-sse-stream-response"
            status="200 OK"
            note={gettext("Stream de Server-Sent Events.")}
          />
        </.api_endpoint>

        <%!-- SSE — JavaScript --%>
        <div>
          <p class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
            {gettext("JavaScript (navegador o Node.js)")}
          </p>
          <.code_block
            code={
              "const source = new EventSource(\n  \"#{@base_url}/api/v1/stream\",\n  { headers: { \"Authorization\": \"Bearer YOUR_TOKEN\" } }\n);\n\nsource.onmessage = (event) => {\n  const data = JSON.parse(event.data);\n\n  if (data.type === \"event.created\") {\n    console.log(\"New event:\", data.data.topic, data.data.payload);\n  }\n\n  if (data.type === \"delivery.updated\") {\n    console.log(\"Delivery:\", data.data.id, \"→\", data.data.status);\n  }\n};\n\nsource.onerror = () => console.log(\"Reconnecting...\");"
            }
            copy_id="copy-sse-js"
          />
        </div>

        <%!-- SSE — Python --%>
        <div>
          <p class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">Python</p>
          <.code_block
            code={
              "import requests, json\n\nresponse = requests.get(\n    \"#{@base_url}/api/v1/stream\",\n    headers={\"Authorization\": \"Bearer YOUR_TOKEN\"},\n    stream=True\n)\n\nfor line in response.iter_lines():\n    if line and line.startswith(b\"data: \"):\n        event = json.loads(line[6:])\n        print(f\"{event['type']}: {event.get('data', {})}\")"
            }
            copy_id="copy-sse-python"
          />
        </div>
      </div>

      <%!-- ── WebSocket (Phoenix Channel) ── --%>
      <div class="space-y-6 mt-8 pt-8 border-t border-slate-200 dark:border-slate-700">
        <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100">
          WebSocket (Phoenix Channel)
        </h3>
        <p class="text-slate-600 dark:text-slate-400 text-sm">
          {gettext(
            "Conexión persistente vía WebSocket usando Phoenix Channel. Autenticación con API Key como query param. El canal es events:<project_id>."
          )}
        </p>

        <%!-- WebSocket — Conexión --%>
        <div>
          <p class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
            {gettext("Endpoint")}
          </p>
          <div class="rounded-lg bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-3 font-mono text-sm text-slate-800 dark:text-slate-200">
            WS {@base_url |> String.replace("https", "wss") |> String.replace("http", "ws")}/ws?token=YOUR_TOKEN
          </div>
        </div>

        <div>
          <p class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
            {gettext("Canal")}
          </p>
          <div class="rounded-lg bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-3 font-mono text-sm text-slate-800 dark:text-slate-200">
            events:YOUR_PROJECT_ID
          </div>
        </div>

        <%!-- WebSocket — JavaScript --%>
        <div>
          <p class="text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
            {gettext("JavaScript con Phoenix Socket")}
          </p>
          <.code_block
            code={
              "import { Socket } from \"phoenix\";\n\nconst socket = new Socket(\"#{@base_url |> String.replace("https", "wss") |> String.replace("http", "ws")}/ws\", {\n  params: { token: \"YOUR_TOKEN\" }\n});\nsocket.connect();\n\nconst channel = socket.channel(\"events:YOUR_PROJECT_ID\", {});\n\nchannel.join()\n  .receive(\"ok\", () => console.log(\"Connected to stream\"))\n  .receive(\"error\", (resp) => console.log(\"Error:\", resp));\n\n// Listen for new events\nchannel.on(\"event:created\", (event) => {\n  console.log(\"New event:\", event.topic, event.payload);\n});\n\n// Listen for delivery updates\nchannel.on(\"delivery:updated\", (delivery) => {\n  console.log(\"Delivery\", delivery.id, \"→\", delivery.status);\n});"
            }
            copy_id="copy-ws-js"
          />
          <p class="text-slate-500 dark:text-slate-400 text-xs mt-2">
            {gettext(
              "Instalar phoenix con: npm install phoenix. El paquete proporciona el cliente Socket con reconexión automática."
            )}
          </p>
        </div>
      </div>

      <%!-- ── Casos de uso ── --%>
      <div class="mt-8 pt-8 border-t border-slate-200 dark:border-slate-700">
        <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100 mb-4">
          {gettext("Casos de uso")}
        </h3>
        <div class="grid gap-4 sm:grid-cols-2">
          <div class="rounded-xl bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 p-4">
            <p class="font-medium text-slate-900 dark:text-slate-100 text-sm mb-1">
              {gettext("Monitor en terminal")}
            </p>
            <p class="text-slate-500 dark:text-slate-400 text-xs">
              {gettext(
                "Ejecutar curl -N en una terminal para ver eventos pasando en tiempo real mientras se desarrolla. Ideal para debugging."
              )}
            </p>
          </div>
          <div class="rounded-xl bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 p-4">
            <p class="font-medium text-slate-900 dark:text-slate-100 text-sm mb-1">
              {gettext("Microservicio sin webhook")}
            </p>
            <p class="text-slate-500 dark:text-slate-400 text-xs">
              {gettext(
                "Un servicio se conecta al stream y procesa eventos sin necesidad de exponer una URL pública. Sin firewall, sin DNS."
              )}
            </p>
          </div>
          <div class="rounded-xl bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 p-4">
            <p class="font-medium text-slate-900 dark:text-slate-100 text-sm mb-1">
              {gettext("Dashboard en tiempo real")}
            </p>
            <p class="text-slate-500 dark:text-slate-400 text-xs">
              {gettext(
                "Mostrar actividad en vivo en una interfaz propia. Los eventos aparecen al instante sin recargar la página."
              )}
            </p>
          </div>
          <div class="rounded-xl bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 p-4">
            <p class="font-medium text-slate-900 dark:text-slate-100 text-sm mb-1">
              {gettext("Alertas inmediatas")}
            </p>
            <p class="text-slate-500 dark:text-slate-400 text-xs">
              {gettext(
                "Reaccionar al instante cuando una entrega falla. Escuchar delivery.updated y filtrar por status para enviar alertas a Slack, email u otro canal."
              )}
            </p>
          </div>
        </div>
      </div>
    </.docs_section>
    """
  end
end
