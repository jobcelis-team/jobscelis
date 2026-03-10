defmodule StreamflixWebWeb.Docs.SectionReference do
  @moduledoc "Reference documentation section covering HTTP status codes, error response format, response headers, health check, and API key scopes."

  use Phoenix.Component
  use Gettext, backend: StreamflixWebWeb.Gettext

  import StreamflixWebWeb.Docs.Components

  attr :base_url, :string, required: true

  def render(assigns) do
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
