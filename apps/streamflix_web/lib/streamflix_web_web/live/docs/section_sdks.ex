defmodule StreamflixWebWeb.Docs.SectionSdks do
  @moduledoc "SDKs and tools documentation section covering 12 language SDKs, CLI, and webhook verification."
  use Phoenix.Component
  use Gettext, backend: StreamflixWebWeb.Gettext

  import StreamflixWebWeb.Docs.Components
  import StreamflixWebWeb.Docs.Helpers

  attr :sdk_languages, :list, required: true

  def render(assigns) do
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
end
