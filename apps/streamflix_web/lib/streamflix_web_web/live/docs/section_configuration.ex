defmodule StreamflixWebWeb.Docs.SectionConfiguration do
  @moduledoc "Configuration documentation section covering base URL, authentication, and CORS"

  use Phoenix.Component
  use Gettext, backend: StreamflixWebWeb.Gettext

  import StreamflixWebWeb.Docs.Components

  attr :base_url, :string, required: true

  def render(assigns) do
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
end
