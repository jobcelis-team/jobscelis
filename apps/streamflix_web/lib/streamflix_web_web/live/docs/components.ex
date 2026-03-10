defmodule StreamflixWebWeb.Docs.Components do
  @moduledoc """
  Shared presentation components for the public documentation page.
  Provides reusable blocks: section wrappers, API endpoint cards,
  code blocks with copy-to-clipboard, response blocks, callouts,
  framework examples, SDK code switchers, and SDK registry links.
  """
  use Phoenix.Component
  use Gettext, backend: StreamflixWebWeb.Gettext

  import StreamflixWebWeb.Docs.Helpers, only: [sdk_label: 1, sdk_install: 1, sdk_usage: 2]

  # ── Section wrapper ─────────────────────────────────────────────────

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  slot :inner_block, required: true

  def docs_section(assigns) do
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

  # ── API endpoint card ───────────────────────────────────────────────

  attr :id, :string, required: true
  attr :method, :string, required: true
  attr :path, :string, required: true
  attr :description, :string, default: nil
  slot :inner_block

  def api_endpoint(assigns) do
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

  # ── Code block with copy button ─────────────────────────────────────

  attr :code, :string, required: true
  attr :copy_id, :string, required: true
  attr :title, :string, default: nil

  def code_block(assigns) do
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

  # ── Response block ──────────────────────────────────────────────────

  attr :code, :string, required: true
  attr :copy_id, :string, required: true
  attr :status, :string, required: true
  attr :note, :string, default: nil

  def response_block(assigns) do
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

  # ── Callout ─────────────────────────────────────────────────────────

  attr :kind, :string, default: "info"
  slot :inner_block, required: true

  def callout(assigns) do
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

  # ── Curl block (shortcut) ───────────────────────────────────────────

  attr :curl, :string, required: true
  attr :id, :string, required: true

  def curl_block(assigns) do
    ~H"""
    <.code_block code={@curl} copy_id={@id} title="curl" />
    """
  end

  # ── Framework example (collapsible) ─────────────────────────────────

  attr :name, :string, required: true
  attr :code, :string, required: true

  def framework_example(assigns) do
    ~H"""
    <details class="group border border-slate-200 dark:border-slate-700 rounded-lg">
      <summary class="px-4 py-2 cursor-pointer text-sm font-medium text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800/50 rounded-lg">
        {@name}
      </summary>
      <pre class="p-4 bg-slate-800 text-slate-100 text-xs overflow-x-auto font-mono rounded-b-lg"><code>{@code}</code></pre>
    </details>
    """
  end

  # ── SDK code block with language switcher ───────────────────────────

  attr :sdk_languages, :list, required: true
  attr :example, :string, default: "send_event"

  def sdk_code_block(assigns) do
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

  # ── SDK registry link ───────────────────────────────────────────────

  attr :label, :string, required: true
  attr :registry, :string, required: true
  attr :url, :string, required: true

  def sdk_link(assigns) do
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

  # ── Helpers ─────────────────────────────────────────────────────────

  def method_color("GET"), do: "bg-emerald-600"
  def method_color("POST"), do: "bg-blue-600"
  def method_color("PATCH"), do: "bg-amber-600"
  def method_color("PUT"), do: "bg-amber-600"
  def method_color("DELETE"), do: "bg-red-600"
  def method_color(_), do: "bg-slate-600"
end
