defmodule StreamflixWebWeb.PlatformDashboard.TabComponents do
  @moduledoc """
  Tab render components for the Platform Dashboard.
  Each function renders one tab's content as a HEEx template.
  """
  use Phoenix.Component

  import StreamflixWebWeb.CoreComponents
  import StreamflixWebWeb.PlatformDashboard.Helpers
  import StreamflixWebWeb.PlatformDashboard.ModalComponents, only: [render_token_section: 1]

  use Gettext, backend: StreamflixWebWeb.Gettext

  alias StreamflixCore.Audit

  def render_overview_tab(assigns) do
    ~H"""
    <%= if is_nil(@project) do %>
      <%!-- Skeleton loading state --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6 lg:gap-8">
        <.skeleton type="card" />
        <.skeleton type="card" />
      </div>
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
        <.skeleton type="stat" />
        <.skeleton type="stat" />
        <.skeleton type="stat" />
        <.skeleton type="stat" />
      </div>
      <.skeleton type="table" rows={5} />
      <.skeleton type="table" rows={3} />
    <% else %>
      <%!-- Row 1: API Token + Test Event (2 cols) --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6 lg:gap-8">
        <section class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
          <h2 class="text-base lg:text-lg font-semibold text-slate-900 dark:text-slate-100 mb-1">
            {gettext("API Token")}
          </h2>
          <p class="text-slate-500 dark:text-slate-400 text-xs mb-3 break-words">
            {gettext("Header:")}
            <code class="bg-slate-100 dark:bg-slate-700 dark:text-slate-300 px-1 rounded text-xs break-all">
              Authorization: Bearer &lt;token&gt;
            </code>
            {gettext("o")}
            <code class="bg-slate-100 dark:bg-slate-700 dark:text-slate-300 px-1 rounded text-xs">
              X-Api-Key
            </code>
          </p>
          {render_token_section(assigns)}
        </section>

        <section class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
          <div class="flex items-center gap-3 mb-4">
            <div class="flex-shrink-0 w-9 h-9 rounded-lg bg-indigo-100 dark:bg-indigo-900/30 flex items-center justify-center">
              <.icon name="hero-paper-airplane" class="w-5 h-5 text-indigo-600 dark:text-indigo-400" />
            </div>
            <div>
              <h2 class="text-base lg:text-lg font-semibold text-slate-900 dark:text-slate-100">
                {gettext("Enviar evento de prueba")}
              </h2>
              <p class="text-xs text-slate-500 dark:text-slate-400">
                {gettext("Prueba tu integración enviando un evento a tus webhooks")}
              </p>
            </div>
          </div>
          <%= if can_manage_team?(@current_user_role) do %>
            <%!-- Quick templates --%>
            <div class="mb-4">
              <p class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider mb-2">
                {gettext("Plantillas rápidas")}
              </p>
              <div class="flex flex-wrap gap-2">
                <button
                  type="button"
                  phx-click="apply_test_template"
                  phx-value-template="user_signup"
                  class="group inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-slate-200 dark:border-slate-600 bg-slate-50 dark:bg-slate-700/50 hover:border-indigo-300 dark:hover:border-indigo-600 hover:bg-indigo-50 dark:hover:bg-indigo-900/20 text-xs font-medium text-slate-600 dark:text-slate-300 transition"
                >
                  <.icon
                    name="hero-user-plus"
                    class="w-3.5 h-3.5 text-slate-400 group-hover:text-indigo-500 transition"
                  /> user.signup
                </button>
                <button
                  type="button"
                  phx-click="apply_test_template"
                  phx-value-template="order_created"
                  class="group inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-slate-200 dark:border-slate-600 bg-slate-50 dark:bg-slate-700/50 hover:border-emerald-300 dark:hover:border-emerald-600 hover:bg-emerald-50 dark:hover:bg-emerald-900/20 text-xs font-medium text-slate-600 dark:text-slate-300 transition"
                >
                  <.icon
                    name="hero-shopping-cart"
                    class="w-3.5 h-3.5 text-slate-400 group-hover:text-emerald-500 transition"
                  /> order.created
                </button>
                <button
                  type="button"
                  phx-click="apply_test_template"
                  phx-value-template="payment_completed"
                  class="group inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-slate-200 dark:border-slate-600 bg-slate-50 dark:bg-slate-700/50 hover:border-amber-300 dark:hover:border-amber-600 hover:bg-amber-50 dark:hover:bg-amber-900/20 text-xs font-medium text-slate-600 dark:text-slate-300 transition"
                >
                  <.icon
                    name="hero-credit-card"
                    class="w-3.5 h-3.5 text-slate-400 group-hover:text-amber-500 transition"
                  /> payment.completed
                </button>
                <button
                  type="button"
                  phx-click="apply_test_template"
                  phx-value-template="invoice_paid"
                  class="group inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-slate-200 dark:border-slate-600 bg-slate-50 dark:bg-slate-700/50 hover:border-violet-300 dark:hover:border-violet-600 hover:bg-violet-50 dark:hover:bg-violet-900/20 text-xs font-medium text-slate-600 dark:text-slate-300 transition"
                >
                  <.icon
                    name="hero-document-text"
                    class="w-3.5 h-3.5 text-slate-400 group-hover:text-violet-500 transition"
                  /> invoice.paid
                </button>
              </div>
            </div>
            <.form for={%{}} id="test-event-form" phx-submit="send_test" class="space-y-3">
              <div>
                <label class="text-sm font-medium text-slate-700 dark:text-slate-300">
                  {gettext("Topic (opcional)")}
                </label>
                <p class="text-xs text-slate-400 dark:text-slate-500 mb-1">
                  {gettext(
                    "Un topic categoriza el evento (ej: order.created). Si se omite, se envía sin filtro de topic."
                  )}
                </p>
                <.input
                  type="text"
                  name="topic"
                  id="test-topic"
                  value={@test_topic}
                  placeholder="user.signup"
                  class="w-full px-3 py-2 bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-600 rounded-lg text-slate-900 dark:text-slate-100 placeholder-slate-400 font-mono text-sm"
                />
              </div>
              <div phx-hook="AutoResize" id="test-payload-wrap">
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  Payload (JSON)
                </label>
                <textarea
                  name="payload"
                  id="test-payload"
                  rows="3"
                  data-max-height="320"
                  class="w-full px-3 py-2 bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-600 rounded-lg text-slate-900 dark:text-slate-100 placeholder-slate-400 font-mono text-sm resize-none transition-[height] duration-150"
                >{@test_payload}</textarea>
              </div>
              <div class="flex flex-col sm:flex-row gap-2">
                <button
                  type="submit"
                  phx-disable-with={gettext("Enviando...")}
                  class="inline-flex items-center justify-center gap-2 px-4 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg font-medium text-sm transition disabled:opacity-70 disabled:cursor-not-allowed shadow-sm"
                >
                  <.icon name="hero-paper-airplane" class="w-4 h-4" />
                  {gettext("Enviar")}
                </button>
                <button
                  type="button"
                  phx-click="simulate_event"
                  phx-value-topic={@test_topic}
                  phx-value-payload={@test_payload}
                  phx-disable-with={gettext("Simulando...")}
                  class="inline-flex items-center justify-center gap-2 px-4 py-2.5 bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-600 text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-600 rounded-lg font-medium text-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
                >
                  <.icon name="hero-beaker" class="w-4 h-4" />
                  {gettext("Simular")}
                </button>
              </div>
            </.form>
            <%= if @simulation_result do %>
              <div class="mt-4 p-4 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-700 rounded-lg">
                <div class="flex items-center justify-between mb-3">
                  <h3 class="font-semibold text-amber-900 dark:text-amber-200 flex items-center gap-2">
                    <.icon name="hero-beaker" class="w-4 h-4" />
                    {gettext("Resultado de simulación")}
                  </h3>
                  <button
                    type="button"
                    phx-click="close_simulation"
                    class="text-amber-600 hover:text-amber-800 dark:text-amber-400 dark:hover:text-amber-300 text-sm"
                  >
                    <.icon name="hero-x-mark" class="w-4 h-4" />
                  </button>
                </div>
                <%= if @simulation_result == [] do %>
                  <p class="text-sm text-amber-800 dark:text-amber-300">
                    {gettext("Ningún webhook matchearía con este evento.")}
                  </p>
                <% else %>
                  <p class="text-sm text-amber-800 dark:text-amber-300 mb-2">
                    {gettext("%{count} webhook(s) recibirían este evento:",
                      count: length(@simulation_result)
                    )}
                  </p>
                  <%= for sim <- @simulation_result do %>
                    <div class="mt-2 p-3 bg-white dark:bg-slate-800 border border-amber-100 dark:border-amber-800 rounded-lg text-sm">
                      <p class="font-mono text-xs text-slate-600 dark:text-slate-400 truncate">
                        {sim.webhook_url}
                      </p>
                      <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
                        {gettext("Topics")}:
                        <span class="font-medium">
                          {if sim.matched_by_topics, do: "✓", else: "✗"}
                        </span>
                        · {gettext("Filtros")}:
                        <span class="font-medium">
                          {if sim.matched_by_filters, do: "✓", else: "✗"}
                        </span>
                        <%= if sim.would_send_headers["x-signature"] do %>
                          · {gettext("HMAC")}:
                          <span class="font-mono text-xs">
                            {String.slice(sim.would_send_headers["x-signature"], 0, 20)}...
                          </span>
                        <% end %>
                      </p>
                    </div>
                  <% end %>
                <% end %>
              </div>
            <% end %>
          <% else %>
            <div class="flex items-center gap-3 p-4 rounded-lg bg-slate-50 dark:bg-slate-700/50 border border-slate-200 dark:border-slate-600">
              <.icon name="hero-lock-closed" class="w-5 h-5 text-slate-400" />
              <p class="text-sm text-slate-500 dark:text-slate-400">
                {gettext("Solo lectura. No tienes permisos para enviar eventos.")}
              </p>
            </div>
          <% end %>
        </section>
      </div>

      <%!-- System Health Status --%>
      <section class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
          <div class="flex items-center gap-3">
            <span class={[
              "inline-block w-3 h-3 rounded-full",
              uptime_dot_color(@uptime_status)
            ]}>
            </span>
            <h2 class="text-base lg:text-lg font-semibold text-slate-900 dark:text-slate-100">
              {gettext("Estado del sistema")}
            </h2>
            <span class={[
              "px-2 py-0.5 rounded-full text-xs font-medium",
              uptime_badge_color(@uptime_status)
            ]}>
              {uptime_label(@uptime_status)}
            </span>
          </div>
          <div class="flex flex-wrap gap-2">
            <span class="px-3 py-1 bg-slate-100 dark:bg-slate-700 dark:text-slate-300 rounded-full text-xs font-medium text-slate-700">
              {gettext("24h")}: {@uptime_stats.last_24h.uptime_percent}%
            </span>
            <span class="px-3 py-1 bg-slate-100 dark:bg-slate-700 dark:text-slate-300 rounded-full text-xs font-medium text-slate-700">
              {gettext("7d")}: {@uptime_stats.last_7d.uptime_percent}%
            </span>
            <span class="px-3 py-1 bg-slate-100 dark:bg-slate-700 dark:text-slate-300 rounded-full text-xs font-medium text-slate-700">
              {gettext("30d")}: {@uptime_stats.last_30d.uptime_percent}%
            </span>
          </div>
        </div>
      </section>

      <%!-- Row 2: Recent Events (full width) --%>
      <section class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900 dark:text-slate-100 mb-4">
          {gettext("Eventos recientes")}
        </h2>
        <div class="overflow-x-auto rounded-lg border border-slate-200 dark:border-slate-700">
          <table class="min-w-full">
            <thead>
              <tr class="bg-slate-50 dark:bg-slate-800 border-b border-slate-200 dark:border-slate-700">
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700 dark:text-slate-300">
                  {gettext("ID")}
                </th>
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700 dark:text-slate-300">
                  {gettext("Topic")}
                </th>
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700 dark:text-slate-300">
                  {gettext("Estado")}
                </th>
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700 dark:text-slate-300 hidden sm:table-cell">
                  {gettext("Fecha")}
                </th>
              </tr>
            </thead>
            <tbody>
              <%= if @events == [] do %>
                <tr>
                  <td colspan="4" class="px-4 py-12 text-center">
                    <div class="flex flex-col items-center gap-2">
                      <div class="w-12 h-12 rounded-full bg-slate-100 dark:bg-slate-700 flex items-center justify-center mb-1">
                        <.icon
                          name="hero-bolt-slash"
                          class="w-6 h-6 text-slate-400 dark:text-slate-500"
                        />
                      </div>
                      <p class="text-sm font-medium text-slate-600 dark:text-slate-300">
                        {gettext("Sin eventos todavía")}
                      </p>
                      <p class="text-xs text-slate-400 dark:text-slate-500 max-w-xs">
                        {gettext(
                          "Envía tu primer evento usando la API o la sección de prueba de arriba."
                        )}
                      </p>
                    </div>
                  </td>
                </tr>
              <% else %>
                <%= for e <- Enum.take(@events, 10) do %>
                  <tr class="border-b border-slate-100 dark:border-slate-700 last:border-0">
                    <td class="px-3 sm:px-4 py-2 sm:py-3 font-mono text-xs sm:text-sm text-slate-600 dark:text-slate-400">
                      {String.slice(e.id, 0, 8)}...
                    </td>
                    <td class="px-3 sm:px-4 py-2 sm:py-3 text-sm text-slate-700 dark:text-slate-300 truncate max-w-[8rem] sm:max-w-none">
                      {e.topic || "—"}
                    </td>
                    <td class="px-3 sm:px-4 py-2 sm:py-3">
                      <span class="px-2 py-0.5 rounded text-xs font-medium bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-300">
                        {e.status}
                      </span>
                      <%= if e.deliver_at && DateTime.compare(e.deliver_at, DateTime.utc_now()) == :gt do %>
                        <span class="ml-1 px-1.5 py-0.5 rounded text-[10px] font-medium bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-400">
                          {gettext("Programado")}
                        </span>
                      <% end %>
                    </td>
                    <td class="px-3 sm:px-4 py-2 sm:py-3 text-sm text-slate-600 dark:text-slate-400 hidden sm:table-cell">
                      {format_dt(e.occurred_at)}
                    </td>
                  </tr>
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>
      </section>

      <%!-- Row 3: Webhooks Health (full width, compact) --%>
      <section class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900 dark:text-slate-100 mb-4">
          {gettext("Webhooks")}
        </h2>
        <div class="overflow-x-auto rounded-lg border border-slate-200 dark:border-slate-700">
          <table class="min-w-full">
            <thead>
              <tr class="bg-slate-50 dark:bg-slate-800 border-b border-slate-200 dark:border-slate-700">
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700 dark:text-slate-300">
                  {gettext("URL")}
                </th>
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700 dark:text-slate-300">
                  {gettext("Salud")}
                </th>
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700 dark:text-slate-300">
                  {gettext("Estado")}
                </th>
              </tr>
            </thead>
            <tbody>
              <%= if @webhooks == [] do %>
                <tr>
                  <td colspan="3" class="px-4 py-12 text-center">
                    <div class="flex flex-col items-center gap-2">
                      <div class="w-12 h-12 rounded-full bg-slate-100 dark:bg-slate-700 flex items-center justify-center mb-1">
                        <.icon
                          name="hero-link-slash"
                          class="w-6 h-6 text-slate-400 dark:text-slate-500"
                        />
                      </div>
                      <p class="text-sm font-medium text-slate-600 dark:text-slate-300">
                        {gettext("Sin webhooks configurados")}
                      </p>
                      <p class="text-xs text-slate-400 dark:text-slate-500 max-w-xs">
                        {gettext(
                          "Crea un webhook en la pestaña Webhooks para empezar a recibir eventos."
                        )}
                      </p>
                    </div>
                  </td>
                </tr>
              <% else %>
                <%= for w <- @webhooks do %>
                  <% health = @webhook_health[w.id] %>
                  <tr class="border-b border-slate-100 dark:border-slate-700 last:border-0">
                    <td class="px-3 sm:px-4 py-2 sm:py-3 font-mono text-xs sm:text-sm text-slate-600 dark:text-slate-400 truncate max-w-[8rem] sm:max-w-[12rem] lg:max-w-none">
                      {w.url}
                    </td>
                    <td class="px-3 sm:px-4 py-2 sm:py-3">
                      <%= if health do %>
                        <span
                          title={"#{health.success_rate}% — #{health.total} #{gettext("entregas")} (24h)"}
                          class={"inline-flex items-center gap-1 px-2 py-0.5 rounded text-xs font-medium #{health_class(health.score)}"}
                        >
                          <span class={"w-2 h-2 rounded-full #{health_dot(health.score)}"}></span>
                          {health_label(health.score)}
                        </span>
                      <% end %>
                    </td>
                    <td class="px-3 sm:px-4 py-2 sm:py-3">
                      <span class="px-2 py-0.5 rounded text-xs font-medium bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-300">
                        {w.status}
                      </span>
                    </td>
                  </tr>
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>
      </section>
    <% end %>
    """
  end

  # ===== TAB: EVENTS =====
  def render_events_tab(assigns) do
    ~H"""
    <%= if is_nil(@project) do %>
      <.skeleton type="table" rows={8} />
    <% else %>
      <%!-- Events table (full width with export + search) --%>
      <section class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-4">
          <h2 class="text-base lg:text-lg font-semibold text-slate-900 dark:text-slate-100">
            {gettext("Eventos recientes")}
          </h2>
          <div class="flex flex-wrap items-center gap-2">
            <%!-- Search bar (#24) --%>
            <.form for={%{}} id="event-search-form" phx-submit="search_events" class="flex gap-1">
              <div class="relative">
                <input
                  type="text"
                  name="q"
                  value={@search_query}
                  placeholder={gettext("Buscar por topic o ID...")}
                  class="w-40 sm:w-56 border border-slate-300 dark:border-slate-600 dark:bg-slate-700 dark:text-slate-100 rounded-lg px-3 py-1.5 pl-8 text-xs sm:text-sm"
                />
                <.icon
                  name="hero-magnifying-glass"
                  class="w-4 h-4 text-slate-400 absolute left-2.5 top-1/2 -translate-y-1/2"
                />
              </div>
              <%= if @search_query != "" do %>
                <button
                  type="button"
                  phx-click="clear_search"
                  class="px-2 py-1.5 text-xs text-slate-500 hover:text-slate-700 hover:bg-slate-100 dark:text-slate-400 dark:hover:text-slate-200 dark:hover:bg-slate-700 rounded-lg transition"
                >
                  <.icon name="hero-x-mark" class="w-4 h-4" />
                </button>
              <% end %>
            </.form>
            <a
              href="/export/events?format=csv"
              target="_blank"
              class="inline-flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium text-slate-600 dark:text-slate-300 bg-slate-100 dark:bg-slate-700 hover:bg-slate-200 dark:hover:bg-slate-600 rounded-lg transition"
            >
              <.icon name="hero-arrow-down-tray" class="w-3.5 h-3.5" /> CSV
            </a>
            <a
              href="/export/events?format=json"
              target="_blank"
              class="inline-flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium text-slate-600 dark:text-slate-300 bg-slate-100 dark:bg-slate-700 hover:bg-slate-200 dark:hover:bg-slate-600 rounded-lg transition"
            >
              <.icon name="hero-arrow-down-tray" class="w-3.5 h-3.5" /> JSON
            </a>
          </div>
        </div>
        <%= if @search_results do %>
          <p class="text-xs text-slate-500 dark:text-slate-400 mb-2">
            {gettext("%{count} resultados para \"%{query}\"",
              count: length(@search_results),
              query: @search_query
            )}
          </p>
        <% end %>
        <div class="overflow-x-auto rounded-lg border border-slate-200 dark:border-slate-700">
          <table class="min-w-full">
            <thead>
              <tr class="bg-slate-50 dark:bg-slate-800 border-b border-slate-200 dark:border-slate-700">
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700 dark:text-slate-300">
                  {gettext("ID")}
                </th>
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700 dark:text-slate-300">
                  {gettext("Topic")}
                </th>
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700 dark:text-slate-300">
                  {gettext("Estado")}
                </th>
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700 dark:text-slate-300 hidden sm:table-cell">
                  {gettext("Fecha")}
                </th>
              </tr>
            </thead>
            <tbody>
              <% display_events = @search_results || @events %>
              <%= if display_events == [] do %>
                <tr>
                  <td colspan="4" class="px-4 py-12 text-center">
                    <div class="flex flex-col items-center gap-2">
                      <div class="w-12 h-12 rounded-full bg-slate-100 dark:bg-slate-700 flex items-center justify-center mb-1">
                        <.icon
                          name="hero-bolt-slash"
                          class="w-6 h-6 text-slate-400 dark:text-slate-500"
                        />
                      </div>
                      <p class="text-sm font-medium text-slate-600 dark:text-slate-300">
                        {gettext("Sin eventos todavía")}
                      </p>
                      <p class="text-xs text-slate-400 dark:text-slate-500 max-w-xs">
                        {gettext(
                          "Envía tu primer evento usando la API o la sección de prueba en Overview."
                        )}
                      </p>
                    </div>
                  </td>
                </tr>
              <% else %>
                <%= for e <- display_events do %>
                  <tr
                    class="border-b border-slate-100 dark:border-slate-700 last:border-0 hover:bg-indigo-50/50 dark:hover:bg-indigo-900/20 cursor-pointer transition"
                    phx-click="show_event_detail"
                    phx-value-id={e.id}
                  >
                    <td class="px-3 sm:px-4 py-2 sm:py-3 font-mono text-xs sm:text-sm text-indigo-600 dark:text-indigo-400">
                      {String.slice(e.id, 0, 8)}...
                    </td>
                    <td class="px-3 sm:px-4 py-2 sm:py-3 text-sm text-slate-700 dark:text-slate-300 truncate max-w-[8rem] sm:max-w-none">
                      {e.topic || "—"}
                    </td>
                    <td class="px-3 sm:px-4 py-2 sm:py-3">
                      <span class="px-2 py-0.5 rounded text-xs font-medium bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-300">
                        {e.status}
                      </span>
                      <%= if e.deliver_at && DateTime.compare(e.deliver_at, DateTime.utc_now()) == :gt do %>
                        <span class="ml-1 px-1.5 py-0.5 rounded text-[10px] font-medium bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-400">
                          {gettext("Programado")}
                        </span>
                      <% end %>
                    </td>
                    <td class="px-3 sm:px-4 py-2 sm:py-3 text-sm text-slate-600 dark:text-slate-400 hidden sm:table-cell">
                      {format_dt(e.occurred_at)}
                    </td>
                  </tr>
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>
      </section>

      <%!-- Row 2: Event Schemas + Replay (2 cols) --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6 lg:gap-8">
        <%!-- Event Schemas --%>
        <section class="bg-white dark:bg-slate-800 rounded-xl border border-teal-200 dark:border-teal-800 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
          <div class="flex items-center gap-2 mb-4">
            <.icon name="hero-document-check" class="w-5 h-5 text-teal-600 dark:text-teal-400" />
            <h2 class="text-base lg:text-lg font-semibold text-slate-900 dark:text-slate-100">
              {gettext("Event Schemas")}
            </h2>
          </div>
          <%= if can_manage_team?(@current_user_role) do %>
            <%!-- Quick schema templates --%>
            <div class="mb-3">
              <p class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wider mb-2">
                {gettext("Plantillas rápidas")}
              </p>
              <div class="flex flex-wrap gap-2">
                <button
                  type="button"
                  phx-click="apply_schema_template"
                  phx-value-template="order"
                  class="group inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-slate-200 dark:border-slate-600 bg-slate-50 dark:bg-slate-700/50 hover:border-teal-300 dark:hover:border-teal-600 hover:bg-teal-50 dark:hover:bg-teal-900/20 text-xs font-medium text-slate-600 dark:text-slate-300 transition"
                >
                  <.icon
                    name="hero-shopping-cart"
                    class="w-3.5 h-3.5 text-slate-400 group-hover:text-teal-500 transition"
                  /> order.created
                </button>
                <button
                  type="button"
                  phx-click="apply_schema_template"
                  phx-value-template="user"
                  class="group inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-slate-200 dark:border-slate-600 bg-slate-50 dark:bg-slate-700/50 hover:border-teal-300 dark:hover:border-teal-600 hover:bg-teal-50 dark:hover:bg-teal-900/20 text-xs font-medium text-slate-600 dark:text-slate-300 transition"
                >
                  <.icon
                    name="hero-user-plus"
                    class="w-3.5 h-3.5 text-slate-400 group-hover:text-teal-500 transition"
                  /> user.signup
                </button>
                <button
                  type="button"
                  phx-click="apply_schema_template"
                  phx-value-template="payment"
                  class="group inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-slate-200 dark:border-slate-600 bg-slate-50 dark:bg-slate-700/50 hover:border-teal-300 dark:hover:border-teal-600 hover:bg-teal-50 dark:hover:bg-teal-900/20 text-xs font-medium text-slate-600 dark:text-slate-300 transition"
                >
                  <.icon
                    name="hero-credit-card"
                    class="w-3.5 h-3.5 text-slate-400 group-hover:text-teal-500 transition"
                  /> payment.completed
                </button>
              </div>
            </div>
            <.form
              for={%{}}
              id="event-schema-form"
              phx-submit="create_event_schema"
              class="flex flex-col gap-2 mb-4"
            >
              <div>
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  Topic
                </label>
                <input
                  type="text"
                  name="topic"
                  id="schema-topic-input"
                  value={assigns[:schema_topic] || ""}
                  placeholder="order.created"
                  required
                  class="w-full border border-slate-300 dark:border-slate-600 dark:bg-slate-700 dark:text-slate-100 rounded-lg px-3 py-2 text-sm font-mono placeholder-slate-400"
                />
              </div>
              <div phx-hook="AutoResize" id="schema-textarea-wrap">
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  JSON Schema
                </label>
                <textarea
                  name="schema"
                  id="schema-json-input"
                  rows="3"
                  data-max-height="256"
                  placeholder={"{\"type\": \"object\", \"required\": [\"amount\"]}"}
                  required
                  class="w-full border border-slate-300 dark:border-slate-600 dark:bg-slate-700 dark:text-slate-100 rounded-lg px-3 py-2 text-sm font-mono placeholder-slate-400 resize-none transition-[height] duration-150"
                >{assigns[:schema_body] || ""}</textarea>
              </div>
              <button
                type="submit"
                phx-disable-with={gettext("Creando...")}
                class="inline-flex items-center justify-center gap-2 px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white rounded-lg text-sm font-medium transition shadow-sm"
              >
                <.icon name="hero-plus" class="w-4 h-4" />
                {gettext("Crear")}
              </button>
            </.form>
          <% end %>
          <%= if @event_schemas == [] do %>
            <div class="text-center py-6">
              <.icon
                name="hero-document-check"
                class="w-10 h-10 mx-auto mb-3 text-slate-300 dark:text-slate-600"
              />
              <p class="text-sm font-medium text-slate-600 dark:text-slate-300">
                {gettext("Sin schemas")}
              </p>
              <p class="text-xs text-slate-400 dark:text-slate-500 mt-1 max-w-xs mx-auto">
                {gettext(
                  "Define schemas JSON para validar los payloads de tus eventos antes de procesarlos."
                )}
              </p>
            </div>
          <% else %>
            <div class="overflow-x-auto rounded-lg border border-slate-200 dark:border-slate-700">
              <table class="min-w-full divide-y divide-slate-200 dark:divide-slate-700">
                <thead>
                  <tr class="bg-slate-50/80 dark:bg-slate-800">
                    <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase">
                      {gettext("Topic")}
                    </th>
                    <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase hidden sm:table-cell">
                      {gettext("Versión")}
                    </th>
                    <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase">
                      {gettext("Estado")}
                    </th>
                    <th class="px-3 py-2 text-right text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase">
                      {gettext("Acciones")}
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-100 dark:divide-slate-700">
                  <%= for s <- @event_schemas do %>
                    <tr class="hover:bg-slate-50/50 dark:hover:bg-slate-700/50 transition">
                      <td class="px-3 py-2 text-sm text-slate-700 dark:text-slate-300 font-mono">
                        {s.topic}
                      </td>
                      <td class="px-3 py-2 text-sm text-slate-600 dark:text-slate-400 hidden sm:table-cell">
                        v{s.version}
                      </td>
                      <td class="px-3 py-2">
                        <span class="px-2 py-0.5 rounded text-xs font-medium bg-teal-100 dark:bg-teal-900/30 text-teal-800 dark:text-teal-400">
                          {s.status}
                        </span>
                      </td>
                      <%= if can_manage_team?(@current_user_role) do %>
                        <td class="px-3 py-2 text-right">
                          <button
                            phx-click={show_confirm("confirm-delete-schema-#{s.id}")}
                            phx-disable-with={gettext("Eliminando...")}
                            class="text-red-600 hover:text-red-700 text-xs font-medium disabled:opacity-50"
                          >
                            {gettext("Eliminar")}
                          </button>
                          <.confirm_modal
                            id={"confirm-delete-schema-#{s.id}"}
                            title={gettext("Confirmar eliminación")}
                            message={gettext("¿Eliminar este schema?")}
                            confirm_text={gettext("Eliminar")}
                            confirm_event="delete_event_schema"
                            confirm_value={%{id: s.id}}
                            variant="danger"
                          />
                        </td>
                      <% end %>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </section>

        <%!-- Event Replay --%>
        <section class="bg-white dark:bg-slate-800 rounded-xl border border-blue-200 dark:border-blue-800 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
          <div class="flex flex-wrap items-center justify-between gap-3 mb-4">
            <div class="flex items-center gap-2">
              <.icon name="hero-arrow-uturn-left" class="w-5 h-5 text-blue-600 dark:text-blue-400" />
              <h2 class="text-base lg:text-lg font-semibold text-slate-900 dark:text-slate-100">
                {gettext("Event Replay")}
              </h2>
            </div>
            <%= if can_manage_team?(@current_user_role) do %>
              <button
                type="button"
                phx-click="open_replay_modal"
                class="inline-flex items-center gap-2 px-3 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-medium text-sm shadow-sm transition"
              >
                <.icon name="hero-play" class="w-4 h-4" /> {gettext("Nuevo replay")}
              </button>
            <% end %>
          </div>
          <%= if @replays == [] do %>
            <div class="text-center py-8">
              <.icon
                name="hero-arrow-path"
                class="w-10 h-10 mx-auto mb-3 text-slate-300 dark:text-slate-600"
              />
              <p class="text-sm font-medium text-slate-600 dark:text-slate-300">
                {gettext("Sin replays")}
              </p>
              <p class="text-xs text-slate-400 dark:text-slate-500 mt-1 max-w-xs mx-auto">
                {gettext("Usa esta función para re-enviar eventos históricos a tus webhooks.")}
              </p>
            </div>
          <% else %>
            <div class="overflow-x-auto rounded-lg border border-slate-200 dark:border-slate-700">
              <table class="min-w-full divide-y divide-slate-200 dark:divide-slate-700">
                <thead>
                  <tr class="bg-slate-50/80 dark:bg-slate-800">
                    <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase">
                      {gettext("Estado")}
                    </th>
                    <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase">
                      {gettext("Progreso")}
                    </th>
                    <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase hidden sm:table-cell">
                      {gettext("Fecha")}
                    </th>
                    <th class="px-3 py-2 text-right text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase">
                      {gettext("Acciones")}
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-100 dark:divide-slate-700">
                  <%= for r <- @replays do %>
                    <tr class="hover:bg-slate-50/50 dark:hover:bg-slate-700/50 transition">
                      <td class="px-3 py-2">
                        <span class={"inline-flex px-2 py-0.5 rounded text-xs font-medium #{replay_status_class(r.status)}"}>
                          {replay_status_label(r.status)}
                        </span>
                      </td>
                      <td class="px-3 py-2">
                        <div class="flex items-center gap-2">
                          <div class="flex-1 bg-slate-200 dark:bg-slate-600 rounded-full h-2 max-w-[6rem] sm:max-w-[8rem]">
                            <div
                              class="bg-blue-600 h-2 rounded-full transition-all"
                              style={"width: #{if r.total_events > 0, do: Float.round(r.processed_events / r.total_events * 100, 0), else: 0}%"}
                            >
                            </div>
                          </div>
                          <span class="text-xs text-slate-600 dark:text-slate-400">
                            {r.processed_events}/{r.total_events}
                          </span>
                        </div>
                      </td>
                      <td class="px-3 py-2 text-sm text-slate-600 dark:text-slate-400 hidden sm:table-cell">
                        {format_dt(r.inserted_at)}
                      </td>
                      <td class="px-3 py-2 text-right">
                        <%= if r.status in ["pending", "running"] && can_manage_team?(@current_user_role) do %>
                          <button
                            phx-click="cancel_replay"
                            phx-value-id={r.id}
                            class="text-red-600 hover:text-red-700 font-medium text-xs"
                          >
                            {gettext("Cancelar")}
                          </button>
                        <% end %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </section>
      </div>
    <% end %>
    """
  end

  # ===== TAB: WEBHOOKS =====
  def render_webhooks_tab(assigns) do
    ~H"""
    <%!-- Webhooks table --%>
    <section class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-4">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900 dark:text-slate-100">
          {gettext("Webhooks")}
        </h2>
        <%= if can_manage_team?(@current_user_role) do %>
          <button
            type="button"
            phx-click="new_webhook"
            class="inline-flex items-center gap-1.5 px-3 py-2 text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 rounded-lg transition"
          >
            <.icon name="hero-plus" class="w-4 h-4" />
            {gettext("Crear webhook")}
          </button>
        <% end %>
      </div>
      <div class="overflow-x-auto rounded-lg border border-slate-200 dark:border-slate-700">
        <table class="min-w-full">
          <thead>
            <tr class="bg-slate-50 dark:bg-slate-800 border-b border-slate-200 dark:border-slate-700">
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700 dark:text-slate-300">
                {gettext("URL")}
              </th>
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700 dark:text-slate-300 hidden sm:table-cell">
                {gettext("Topics")}
              </th>
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700 dark:text-slate-300">
                {gettext("Salud")}
              </th>
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700 dark:text-slate-300">
                {gettext("Estado")}
              </th>
              <%= if can_manage_team?(@current_user_role) do %>
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-right text-xs sm:text-sm font-medium text-slate-700 dark:text-slate-300">
                  {gettext("Acciones")}
                </th>
              <% end %>
            </tr>
          </thead>
          <tbody>
            <%= if @webhooks == [] do %>
              <tr>
                <td
                  colspan={if can_manage_team?(@current_user_role), do: "5", else: "4"}
                  class="px-4 py-16 text-center"
                >
                  <div class="flex flex-col items-center gap-3">
                    <div class="w-14 h-14 rounded-full bg-indigo-50 dark:bg-indigo-900/20 flex items-center justify-center">
                      <.icon
                        name="hero-globe-alt"
                        class="w-7 h-7 text-indigo-400 dark:text-indigo-500"
                      />
                    </div>
                    <div>
                      <p class="text-sm font-semibold text-slate-700 dark:text-slate-200">
                        {gettext("Sin webhooks configurados")}
                      </p>
                      <p class="text-xs text-slate-400 dark:text-slate-500 mt-1 max-w-sm mx-auto">
                        {gettext(
                          "Los webhooks envían eventos a tu servidor en tiempo real. Crea uno para empezar a recibir notificaciones."
                        )}
                      </p>
                    </div>
                    <%= if can_manage_team?(@current_user_role) do %>
                      <button
                        type="button"
                        phx-click="new_webhook"
                        class="mt-1 inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 rounded-lg transition shadow-sm"
                      >
                        <.icon name="hero-plus" class="w-4 h-4" />
                        {gettext("Crear webhook")}
                      </button>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% else %>
              <%= for w <- @webhooks do %>
                <% health = @webhook_health[w.id] %>
                <tr class={"border-b border-slate-100 dark:border-slate-700 last:border-0 #{if w.status == "inactive", do: "opacity-50"}"}>
                  <td class="px-3 sm:px-4 py-2 sm:py-3 font-mono text-xs sm:text-sm text-slate-600 dark:text-slate-400 truncate max-w-[8rem] sm:max-w-[12rem] lg:max-w-none">
                    {w.url}
                  </td>
                  <td class="px-3 sm:px-4 py-2 sm:py-3 hidden sm:table-cell">
                    <%= if w.topics && w.topics != [] do %>
                      <div class="flex flex-wrap gap-1">
                        <%= for topic <- Enum.take(w.topics, 3) do %>
                          <span class="px-1.5 py-0.5 rounded text-xs bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-400">
                            {topic}
                          </span>
                        <% end %>
                        <%= if length(w.topics) > 3 do %>
                          <span class="text-xs text-slate-400 dark:text-slate-500">
                            +{length(w.topics) - 3}
                          </span>
                        <% end %>
                      </div>
                    <% else %>
                      <span class="text-xs text-slate-400 dark:text-slate-500">
                        {gettext("Todos")}
                      </span>
                    <% end %>
                  </td>
                  <td class="px-3 sm:px-4 py-2 sm:py-3">
                    <%= if health do %>
                      <span
                        title={"#{health.success_rate}% — #{health.total} #{gettext("entregas")} (24h)"}
                        class={"inline-flex items-center gap-1 px-2 py-0.5 rounded text-xs font-medium #{health_class(health.score)}"}
                      >
                        <span class={"w-2 h-2 rounded-full #{health_dot(health.score)}"}></span> {health_label(
                          health.score
                        )}
                      </span>
                    <% end %>
                  </td>
                  <td class="px-3 sm:px-4 py-2 sm:py-3">
                    <span class={[
                      "px-2 py-0.5 rounded text-xs font-medium",
                      if(w.status == "active",
                        do:
                          "bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-400",
                        else: "bg-slate-100 dark:bg-slate-700 text-slate-500 dark:text-slate-400"
                      )
                    ]}>
                      {w.status}
                    </span>
                  </td>
                  <%= if can_manage_team?(@current_user_role) do %>
                    <td class="px-3 sm:px-4 py-2 sm:py-3 text-right">
                      <div class="flex items-center justify-end gap-1">
                        <button
                          type="button"
                          phx-click="edit_webhook"
                          phx-value-id={w.id}
                          class="p-1.5 rounded-lg text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 dark:hover:bg-indigo-900/20 transition"
                          title={gettext("Editar")}
                        >
                          <.icon name="hero-pencil-square" class="w-4 h-4" />
                        </button>
                        <%= if w.status == "active" do %>
                          <button
                            type="button"
                            phx-click={show_confirm("confirm-deactivate-wh-#{w.id}")}
                            class="p-1.5 rounded-lg text-slate-400 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 transition"
                            title={gettext("Desactivar")}
                          >
                            <.icon name="hero-pause-circle" class="w-4 h-4" />
                          </button>
                          <.confirm_modal
                            id={"confirm-deactivate-wh-#{w.id}"}
                            title={gettext("Confirmar desactivación")}
                            message={gettext("¿Desactivar este webhook?")}
                            confirm_text={gettext("Desactivar")}
                            confirm_event="deactivate_webhook"
                            confirm_value={%{id: w.id}}
                            variant="warning"
                          />
                        <% else %>
                          <button
                            type="button"
                            phx-click="activate_webhook"
                            phx-value-id={w.id}
                            class="p-1.5 rounded-lg text-slate-400 hover:text-emerald-600 hover:bg-emerald-50 dark:hover:bg-emerald-900/20 transition"
                            title={gettext("Activar")}
                          >
                            <.icon name="hero-play-circle" class="w-4 h-4" />
                          </button>
                        <% end %>
                      </div>
                    </td>
                  <% end %>
                </tr>
              <% end %>
            <% end %>
          </tbody>
        </table>
      </div>
    </section>

    <%!-- Webhook create/edit modal (2-step wizard) --%>
    <%= if @webhook_modal do %>
      <div class="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6">
        <div
          class="absolute inset-0 bg-black/50 backdrop-blur-sm"
          phx-click="close_webhook_modal"
          aria-hidden="true"
        >
        </div>
        <div
          class="relative z-10 bg-white dark:bg-slate-800 rounded-2xl shadow-2xl w-full max-w-lg mx-auto border border-slate-200/50 dark:border-slate-700 max-h-[90vh] overflow-y-auto"
          role="dialog"
          aria-modal="true"
        >
          <%!-- Header --%>
          <div class="px-6 pt-6 pb-4 flex items-start justify-between border-b border-slate-200 dark:border-slate-700">
            <div>
              <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
                {if @webhook_modal == :new,
                  do: gettext("Crear webhook"),
                  else: gettext("Editar webhook")}
              </h2>
              <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
                {gettext("Paso %{current} de %{total}", current: @webhook_step, total: 2)}
              </p>
            </div>
            <button
              type="button"
              phx-click="close_webhook_modal"
              class="rounded-lg p-1.5 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 transition"
            >
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>

          <%!-- Step indicator --%>
          <div class="px-6 pt-4 flex items-center gap-3">
            <button
              type="button"
              phx-click="webhook_step"
              phx-value-step="1"
              class={"flex items-center gap-2 text-sm font-medium transition " <> if(@webhook_step == 1, do: "text-indigo-600 dark:text-indigo-400", else: "text-slate-400 dark:text-slate-500 hover:text-slate-600")}
            >
              <span class={"w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold border-2 transition " <> if(@webhook_step == 1, do: "border-indigo-600 bg-indigo-600 text-white dark:border-indigo-400 dark:bg-indigo-500", else: "border-slate-300 dark:border-slate-600 text-slate-400")}>
                1
              </span>
              {gettext("Destino")}
            </button>
            <div class="flex-1 h-0.5 bg-slate-200 dark:bg-slate-700 rounded"></div>
            <button
              type="button"
              phx-click="webhook_step"
              phx-value-step="2"
              class={"flex items-center gap-2 text-sm font-medium transition " <> if(@webhook_step == 2, do: "text-indigo-600 dark:text-indigo-400", else: "text-slate-400 dark:text-slate-500 hover:text-slate-600")}
            >
              <span class={"w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold border-2 transition " <> if(@webhook_step == 2, do: "border-indigo-600 bg-indigo-600 text-white dark:border-indigo-400 dark:bg-indigo-500", else: "border-slate-300 dark:border-slate-600 text-slate-400")}>
                2
              </span>
              {gettext("Filtros y seguridad")}
            </button>
          </div>

          <form
            phx-submit="save_webhook"
            phx-change="webhook_form_change"
            class="px-6 pb-6 pt-4 space-y-4"
          >
            <%!-- STEP 1: Destination --%>
            <div class={if @webhook_step != 1, do: "hidden"}>
              <%!-- Info box --%>
              <div class="flex gap-3 p-3.5 rounded-xl bg-indigo-50 dark:bg-indigo-900/30 border border-indigo-100 dark:border-indigo-800/50 mb-4">
                <.icon
                  name="hero-information-circle"
                  class="w-5 h-5 text-indigo-500 dark:text-indigo-400 flex-shrink-0 mt-0.5"
                />
                <p class="text-sm text-indigo-700 dark:text-indigo-300">
                  {gettext(
                    "Un webhook envía datos automáticamente a una URL cada vez que ocurre un evento en tu proyecto. Tu servidor recibirá un POST con el payload del evento."
                  )}
                </p>
              </div>

              <div>
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  {gettext("URL de destino")}
                </label>
                <p class="text-xs text-slate-400 dark:text-slate-500 mb-1.5">
                  {gettext("La URL de tu servidor que recibirá los eventos vía HTTP POST.")}
                </p>
                <input
                  type="url"
                  name="webhook[url]"
                  value={@webhook_form["url"]}
                  required
                  placeholder="https://api.example.com/webhooks/receive"
                  class="w-full px-3 py-2.5 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 text-sm text-slate-900 dark:text-slate-100 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500"
                />
                <%= for err <- @webhook_form_errors do %>
                  <p class="mt-1 text-xs text-red-500 dark:text-red-400 flex items-center gap-1">
                    <.icon name="hero-exclamation-circle" class="w-3.5 h-3.5" />{err}
                  </p>
                <% end %>
                <p class="text-xs text-slate-400 dark:text-slate-500 mt-1.5">
                  {gettext("Debe ser una URL HTTPS accesible públicamente.")}
                </p>
              </div>
            </div>

            <%!-- STEP 2: Filters & Security --%>
            <div class={if @webhook_step != 2, do: "hidden"}>
              <%!-- Topics --%>
              <div class="mb-4">
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  {gettext("Topics")}
                  <span class="font-normal text-slate-400 dark:text-slate-500 ml-1">
                    ({gettext("opcional")})
                  </span>
                </label>
                <p class="text-xs text-slate-400 dark:text-slate-500 mb-1.5">
                  {gettext(
                    "Filtra qué eventos recibe este webhook. Vacío = recibe todos los eventos."
                  )}
                </p>
                <input
                  type="text"
                  name="webhook[topics]"
                  value={@webhook_form["topics"]}
                  placeholder="user.created, order.paid, payment.failed"
                  class="w-full px-3 py-2.5 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 text-sm text-slate-900 dark:text-slate-100 font-mono placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500"
                />
                <p class="text-xs text-slate-400 dark:text-slate-500 mt-1.5">
                  {gettext("Separados por coma, ej: order.created, payment.failed")}
                </p>
              </div>

              <%!-- HMAC Secret --%>
              <div>
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  {gettext("Secreto HMAC")}
                  <span class="font-normal text-slate-400 dark:text-slate-500 ml-1">
                    ({gettext("opcional")})
                  </span>
                </label>
                <p class="text-xs text-slate-400 dark:text-slate-500 mb-1.5">
                  {gettext(
                    "Secreto para firmar payloads. Tu servidor verifica la firma en el header x-signature."
                  )}
                </p>
                <input
                  type="password"
                  name="webhook[secret]"
                  value=""
                  placeholder="whsec_..."
                  autocomplete="off"
                  class="w-full px-3 py-2.5 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 text-sm text-slate-900 dark:text-slate-100 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500"
                />
                <p class="text-xs text-slate-400 dark:text-slate-500 mt-1.5">
                  {if @webhook_modal == :new,
                    do:
                      gettext(
                        "Si lo defines, cada entrega incluirá un header x-signature con la firma HMAC."
                      ),
                    else: gettext("Dejar vacío para mantener el secreto actual.")}
                </p>
              </div>

              <%!-- Security info --%>
              <div class="flex gap-3 p-3.5 rounded-xl bg-amber-50 dark:bg-amber-900/20 border border-amber-100 dark:border-amber-800/50 mt-4">
                <.icon
                  name="hero-shield-check"
                  class="w-5 h-5 text-amber-600 dark:text-amber-400 flex-shrink-0 mt-0.5"
                />
                <div class="text-sm text-amber-700 dark:text-amber-300">
                  <p class="font-medium">{gettext("Verificación de firma")}</p>
                  <p class="mt-0.5 text-xs text-amber-600 dark:text-amber-400">
                    {gettext(
                      "Recomendamos definir un secreto HMAC para verificar que los eventos provienen de Jobcelis y no de un tercero."
                    )}
                  </p>
                </div>
              </div>
            </div>

            <%!-- Navigation buttons --%>
            <div class="flex flex-col-reverse sm:flex-row sm:justify-between gap-3 pt-3 border-t border-slate-200 dark:border-slate-700">
              <div>
                <%= if @webhook_step > 1 do %>
                  <button
                    type="button"
                    phx-click="webhook_step"
                    phx-value-step={@webhook_step - 1}
                    class="w-full sm:w-auto px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 hover:bg-slate-50 dark:hover:bg-slate-600 text-slate-700 dark:text-slate-300 text-sm font-medium transition"
                  >
                    {gettext("Anterior")}
                  </button>
                <% else %>
                  <button
                    type="button"
                    phx-click="close_webhook_modal"
                    class="w-full sm:w-auto px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 hover:bg-slate-50 dark:hover:bg-slate-600 text-slate-700 dark:text-slate-300 text-sm font-medium transition"
                  >
                    {gettext("Cancelar")}
                  </button>
                <% end %>
              </div>
              <div>
                <%= if @webhook_step < 2 do %>
                  <button
                    type="button"
                    phx-click="webhook_step"
                    phx-value-step={@webhook_step + 1}
                    class="w-full sm:w-auto px-4 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium transition"
                  >
                    {gettext("Siguiente")}
                  </button>
                <% else %>
                  <button
                    type="submit"
                    phx-disable-with={gettext("Guardando...")}
                    class="w-full sm:w-auto px-4 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium transition disabled:opacity-70"
                  >
                    {if @webhook_modal == :new,
                      do: gettext("Crear webhook"),
                      else: gettext("Guardar cambios")}
                  </button>
                <% end %>
              </div>
            </div>
          </form>
        </div>
      </div>
    <% end %>

    <%!-- Deliveries --%>
    <section class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-4">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900 dark:text-slate-100">
          {gettext("Entregas")}
        </h2>
        <div class="flex flex-wrap gap-2">
          <a
            href="/export/deliveries?format=csv"
            target="_blank"
            class="inline-flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium text-slate-600 dark:text-slate-300 bg-slate-100 dark:bg-slate-700 hover:bg-slate-200 dark:hover:bg-slate-600 rounded-lg transition"
          >
            <.icon name="hero-arrow-down-tray" class="w-3.5 h-3.5" /> CSV
          </a>
          <a
            href="/export/deliveries?format=json"
            target="_blank"
            class="inline-flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium text-slate-600 dark:text-slate-300 bg-slate-100 dark:bg-slate-700 hover:bg-slate-200 dark:hover:bg-slate-600 rounded-lg transition"
          >
            <.icon name="hero-arrow-down-tray" class="w-3.5 h-3.5" /> JSON
          </a>
        </div>
      </div>
      <div class="overflow-x-auto rounded-xl border border-slate-200 dark:border-slate-700">
        <table class="min-w-full divide-y divide-slate-200 dark:divide-slate-700">
          <thead>
            <tr class="bg-slate-50/80 dark:bg-slate-800">
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider">
                {gettext("Evento / Topic")}
              </th>
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider hidden md:table-cell">
                {gettext("Webhook")}
              </th>
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider">
                {gettext("Estado")}
              </th>
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider hidden lg:table-cell">
                {gettext("Intento")}
              </th>
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider hidden sm:table-cell">
                {gettext("HTTP")}
              </th>
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider hidden sm:table-cell">
                {gettext("Fecha")}
              </th>
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-right text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider">
                {gettext("Acciones")}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100 dark:divide-slate-700">
            <%= if @deliveries == [] do %>
              <tr>
                <td colspan="7" class="px-4 py-14 text-center">
                  <div class="flex flex-col items-center gap-2">
                    <div class="w-12 h-12 rounded-full bg-slate-100 dark:bg-slate-700 flex items-center justify-center mb-1">
                      <.icon
                        name="hero-inbox-stack"
                        class="w-6 h-6 text-slate-400 dark:text-slate-500"
                      />
                    </div>
                    <p class="text-sm font-medium text-slate-600 dark:text-slate-300">
                      {gettext("Sin entregas registradas")}
                    </p>
                    <p class="text-xs text-slate-400 dark:text-slate-500 max-w-xs">
                      {gettext(
                        "Las entregas aparecen aquí cuando tus eventos son enviados a los webhooks."
                      )}
                    </p>
                  </div>
                </td>
              </tr>
            <% else %>
              <%= for d <- @deliveries do %>
                <tr class="hover:bg-slate-50/50 dark:hover:bg-slate-700/50 transition">
                  <td class="px-3 sm:px-5 py-3 sm:py-4 text-xs sm:text-sm text-slate-600 dark:text-slate-400 font-mono truncate max-w-[8rem] sm:max-w-none">
                    {if d.event,
                      do: d.event.topic || String.slice(d.event_id, 0, 8),
                      else: String.slice(d.event_id, 0, 8)}
                  </td>
                  <td class="px-3 sm:px-5 py-3 sm:py-4 font-mono text-xs text-slate-600 dark:text-slate-400 max-w-[14rem] truncate hidden md:table-cell">
                    {if d.webhook, do: d.webhook.url, else: d.webhook_id}
                  </td>
                  <td class="px-3 sm:px-5 py-3 sm:py-4">
                    <span class={[
                      "inline-flex px-2 sm:px-2.5 py-0.5 sm:py-1 rounded-lg text-xs font-medium",
                      if(d.status == "success",
                        do:
                          "bg-emerald-100 dark:bg-emerald-900/30 text-emerald-800 dark:text-emerald-400",
                        else:
                          if(d.status == "pending",
                            do:
                              "bg-amber-100 dark:bg-amber-900/30 text-amber-800 dark:text-amber-400",
                            else: "bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-400"
                          )
                      )
                    ]}>
                      {d.status}
                    </span>
                  </td>
                  <td class="px-3 sm:px-5 py-3 sm:py-4 text-sm text-slate-600 dark:text-slate-400 hidden lg:table-cell">
                    {d.attempt_number}
                  </td>
                  <td class="px-3 sm:px-5 py-3 sm:py-4 text-sm text-slate-600 dark:text-slate-400 font-mono hidden sm:table-cell">
                    {d.response_status || "—"}
                  </td>
                  <td class="px-3 sm:px-5 py-3 sm:py-4 text-sm text-slate-600 dark:text-slate-400 hidden sm:table-cell">
                    {format_dt(d.inserted_at)}
                  </td>
                  <td class="px-3 sm:px-5 py-3 sm:py-4 text-right">
                    <%= if d.status != "success" and d.status != "pending" and can_manage_team?(@current_user_role) do %>
                      <button
                        phx-click="retry_delivery"
                        phx-value-id={d.id}
                        phx-disable-with={gettext("Reintentando...")}
                        class="text-indigo-600 dark:text-indigo-400 hover:text-indigo-700 dark:hover:text-indigo-300 font-medium text-xs sm:text-sm disabled:opacity-70"
                      >
                        {gettext("Reintentar")}
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            <% end %>
          </tbody>
        </table>
      </div>
    </section>

    <%!-- Dead Letter Queue --%>
    <%= if @dead_letters != [] do %>
      <section class="bg-white dark:bg-slate-800 rounded-xl border border-red-200 dark:border-red-800 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-4">
          <div class="flex items-center gap-2">
            <span class="w-2.5 h-2.5 rounded-full bg-red-500 animate-pulse"></span>
            <h2 class="text-base font-semibold text-red-900 dark:text-red-300">
              {gettext("Dead Letter Queue")}
            </h2>
            <span class="px-2 py-0.5 rounded-full bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400 text-xs font-medium">
              {length(@dead_letters)}
            </span>
          </div>
          <%!-- Bulk actions (#25) --%>
          <%= if can_manage_team?(@current_user_role) do %>
            <div class="flex items-center gap-2">
              <%= if @selected_dead_letters != [] do %>
                <span class="text-xs text-slate-500 dark:text-slate-400">
                  {gettext("%{count} seleccionados", count: length(@selected_dead_letters))}
                </span>
                <button
                  phx-click="bulk_retry_dl"
                  phx-disable-with={gettext("...")}
                  class="px-2.5 py-1.5 text-xs font-medium text-white bg-indigo-600 hover:bg-indigo-700 rounded-lg transition"
                >
                  {gettext("Reintentar seleccionados")}
                </button>
                <button
                  phx-click="bulk_resolve_dl"
                  phx-disable-with={gettext("...")}
                  class="px-2.5 py-1.5 text-xs font-medium text-slate-600 dark:text-slate-300 bg-slate-100 dark:bg-slate-700 hover:bg-slate-200 dark:hover:bg-slate-600 rounded-lg transition"
                >
                  {gettext("Descartar seleccionados")}
                </button>
              <% end %>
              <%= if @selected_dead_letters == [] do %>
                <button
                  phx-click="select_all_dl"
                  class="px-2.5 py-1.5 text-xs font-medium text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg transition"
                >
                  {gettext("Seleccionar todo")}
                </button>
              <% else %>
                <button
                  phx-click="deselect_all_dl"
                  class="px-2.5 py-1.5 text-xs font-medium text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg transition"
                >
                  {gettext("Deseleccionar")}
                </button>
              <% end %>
            </div>
          <% end %>
        </div>
        <p class="text-sm text-red-700 dark:text-red-400 mb-4">
          {gettext("Entregas que agotaron todos los reintentos. Puedes reintentar o descartar.")}
        </p>
        <div class="overflow-x-auto rounded-lg border border-red-100 dark:border-red-800">
          <table class="min-w-full divide-y divide-red-100 dark:divide-red-800">
            <thead>
              <tr class="bg-red-50/50 dark:bg-red-900/20">
                <%= if can_manage_team?(@current_user_role) do %>
                  <th class="w-8 px-3 py-2"></th>
                <% end %>
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs font-semibold text-red-700 dark:text-red-400 uppercase">
                  {gettext("Webhook")}
                </th>
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs font-semibold text-red-700 dark:text-red-400 uppercase hidden sm:table-cell">
                  {gettext("Error")}
                </th>
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs font-semibold text-red-700 dark:text-red-400 uppercase">
                  {gettext("Intentos")}
                </th>
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs font-semibold text-red-700 dark:text-red-400 uppercase hidden sm:table-cell">
                  {gettext("Fecha")}
                </th>
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-right text-xs font-semibold text-red-700 dark:text-red-400 uppercase">
                  {gettext("Acciones")}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-red-50 dark:divide-red-900/30">
              <%= for dl <- @dead_letters do %>
                <tr class="hover:bg-red-50/30 dark:hover:bg-red-900/10 transition">
                  <%= if can_manage_team?(@current_user_role) do %>
                    <td class="w-8 px-3 py-2">
                      <input
                        type="checkbox"
                        checked={dl.id in @selected_dead_letters}
                        phx-click="toggle_dl_select"
                        phx-value-id={dl.id}
                        class="rounded border-red-300 dark:border-red-700 text-red-600 focus:ring-red-500"
                      />
                    </td>
                  <% end %>
                  <td class="px-3 sm:px-4 py-2 sm:py-3 font-mono text-xs text-slate-600 dark:text-slate-400 truncate max-w-[6rem] sm:max-w-[10rem] lg:max-w-none">
                    {if dl.webhook, do: dl.webhook.url, else: "—"}
                  </td>
                  <td class="px-3 sm:px-4 py-2 sm:py-3 text-xs text-red-700 dark:text-red-400 truncate max-w-[12rem] hidden sm:table-cell">
                    {dl.last_error || "—"}
                  </td>
                  <td class="px-3 sm:px-4 py-2 sm:py-3 text-sm text-slate-600 dark:text-slate-400">
                    {dl.attempts_exhausted}
                  </td>
                  <td class="px-3 sm:px-4 py-2 sm:py-3 text-sm text-slate-600 dark:text-slate-400 hidden sm:table-cell">
                    {format_dt(dl.inserted_at)}
                  </td>
                  <td class="px-3 sm:px-4 py-2 sm:py-3 text-right">
                    <%= if can_manage_team?(@current_user_role) do %>
                      <div class="flex flex-col sm:flex-row sm:justify-end gap-1">
                        <button
                          phx-click="retry_dead_letter"
                          phx-value-id={dl.id}
                          phx-disable-with={gettext("...")}
                          class="text-indigo-600 dark:text-indigo-400 hover:text-indigo-700 dark:hover:text-indigo-300 font-medium text-xs disabled:opacity-70"
                        >
                          {gettext("Reintentar")}
                        </button>
                        <button
                          phx-click="resolve_dead_letter"
                          phx-value-id={dl.id}
                          phx-disable-with={gettext("...")}
                          class="text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 font-medium text-xs disabled:opacity-70"
                        >
                          {gettext("Descartar")}
                        </button>
                      </div>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </section>
    <% end %>
    """
  end

  # ===== TAB: JOBS =====
  def render_jobs_tab(assigns) do
    ~H"""
    <section class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
      <div class="flex flex-wrap items-center justify-between gap-3 sm:gap-4 mb-4 sm:mb-6">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900 dark:text-slate-100">
          {gettext("Jobs")}
        </h2>
        <div class="flex flex-wrap gap-2">
          <a
            href="/export/jobs?format=csv"
            target="_blank"
            class="inline-flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium text-slate-600 dark:text-slate-300 bg-slate-100 dark:bg-slate-700 hover:bg-slate-200 dark:hover:bg-slate-600 rounded-lg transition"
          >
            <.icon name="hero-arrow-down-tray" class="w-3.5 h-3.5" /> CSV
          </a>
          <%= if can_manage_team?(@current_user_role) do %>
            <button
              type="button"
              phx-click="new_job"
              phx-disable-with={gettext("Cargando...")}
              class="inline-flex items-center gap-2 px-3 sm:px-4 py-2 sm:py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl font-medium text-sm shadow-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
            >
              <.icon name="hero-plus" class="w-4 h-4" /> {gettext("Nuevo job")}
            </button>
          <% end %>
        </div>
      </div>
      <div class="overflow-x-auto rounded-xl border border-slate-200 dark:border-slate-700">
        <table class="min-w-full divide-y divide-slate-200 dark:divide-slate-700">
          <thead>
            <tr class="bg-slate-50/80 dark:bg-slate-800">
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider">
                {gettext("Nombre")}
              </th>
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider hidden sm:table-cell">
                {gettext("Programación")}
              </th>
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider hidden sm:table-cell">
                {gettext("Acción")}
              </th>
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider">
                {gettext("Estado")}
              </th>
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-right text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider">
                {gettext("Acciones")}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100 dark:divide-slate-700">
            <%= if @jobs == [] do %>
              <tr>
                <td colspan="5" class="px-4 py-16 text-center">
                  <div class="flex flex-col items-center gap-3">
                    <div class="w-14 h-14 rounded-full bg-amber-50 dark:bg-amber-900/20 flex items-center justify-center">
                      <.icon
                        name="hero-clock"
                        class="w-7 h-7 text-amber-400 dark:text-amber-500"
                      />
                    </div>
                    <div>
                      <p class="text-sm font-semibold text-slate-700 dark:text-slate-200">
                        {gettext("Sin jobs programados")}
                      </p>
                      <p class="text-xs text-slate-400 dark:text-slate-500 mt-1 max-w-sm mx-auto">
                        {gettext(
                          "Los jobs te permiten enviar eventos automáticamente con un horario cron o intervalo fijo."
                        )}
                      </p>
                    </div>
                    <%= if can_manage_team?(@current_user_role) do %>
                      <button
                        type="button"
                        phx-click="new_job"
                        class="mt-1 inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 rounded-lg transition shadow-sm"
                      >
                        <.icon name="hero-plus" class="w-4 h-4" />
                        {gettext("Nuevo job")}
                      </button>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% else %>
              <%= for j <- @jobs do %>
                <tr class="hover:bg-slate-50/50 dark:hover:bg-slate-700/50 transition">
                  <td class="px-3 sm:px-5 py-3 sm:py-4 font-medium text-slate-800 dark:text-slate-200 text-sm">
                    {j.name}
                  </td>
                  <td class="px-3 sm:px-5 py-3 sm:py-4 text-sm text-slate-600 dark:text-slate-400 hidden sm:table-cell">
                    {j.schedule_type}
                  </td>
                  <td class="px-3 sm:px-5 py-3 sm:py-4 text-sm text-slate-600 dark:text-slate-400 hidden sm:table-cell">
                    {j.action_type}
                  </td>
                  <td class="px-3 sm:px-5 py-3 sm:py-4">
                    <span class={[
                      "inline-flex px-2 sm:px-2.5 py-0.5 sm:py-1 rounded-lg text-xs font-medium",
                      if(j.status == "active",
                        do:
                          "bg-emerald-100 dark:bg-emerald-900/30 text-emerald-800 dark:text-emerald-400",
                        else: "bg-slate-200 dark:bg-slate-700 text-slate-600 dark:text-slate-400"
                      )
                    ]}>
                      {j.status}
                    </span>
                  </td>
                  <td class="px-3 sm:px-5 py-3 sm:py-4 text-right">
                    <div class="flex flex-col sm:flex-row sm:inline-flex gap-1 sm:gap-2 items-start sm:items-center">
                      <%= if can_manage_team?(@current_user_role) do %>
                        <button
                          phx-click="edit_job"
                          phx-value-id={j.id}
                          phx-disable-with={gettext("Cargando...")}
                          class="text-indigo-600 dark:text-indigo-400 hover:text-indigo-700 dark:hover:text-indigo-300 font-medium text-xs sm:text-sm disabled:opacity-70"
                        >
                          {gettext("Editar")}
                        </button>
                      <% end %>
                      <button
                        phx-click="show_job_runs"
                        phx-value-id={j.id}
                        phx-disable-with={gettext("Cargando...")}
                        class="text-slate-600 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 font-medium text-xs sm:text-sm disabled:opacity-70"
                      >
                        {gettext("Runs")}
                      </button>
                      <%= if j.status == "active" && can_manage_team?(@current_user_role) do %>
                        <button
                          phx-click="deactivate_job"
                          phx-value-id={j.id}
                          phx-disable-with={gettext("Desactivando...")}
                          class="text-red-600 hover:text-red-700 font-medium text-xs sm:text-sm disabled:opacity-70"
                        >
                          {gettext("Desactivar")}
                        </button>
                      <% end %>
                    </div>
                  </td>
                </tr>
              <% end %>
            <% end %>
          </tbody>
        </table>
      </div>
    </section>
    """
  end

  # ===== TAB: PIPELINES =====
  def render_pipelines_tab(assigns) do
    ~H"""
    <section class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
      <div class="flex flex-wrap items-center justify-between gap-3 sm:gap-4 mb-4 sm:mb-6">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900 dark:text-slate-100">
          {gettext("Pipelines")}
        </h2>
        <%= if can_manage_team?(@current_user_role) do %>
          <button
            type="button"
            phx-click="new_pipeline"
            phx-disable-with={gettext("Cargando...")}
            class="inline-flex items-center gap-2 px-3 sm:px-4 py-2 sm:py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl font-medium text-sm shadow-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
          >
            <.icon name="hero-plus" class="w-4 h-4" /> {gettext("Nuevo pipeline")}
          </button>
        <% end %>
      </div>

      <%= if @pipelines == [] do %>
        <div class="text-center py-12 text-slate-500 dark:text-slate-400">
          <.icon name="hero-funnel" class="w-12 h-12 mx-auto mb-3 text-slate-300 dark:text-slate-600" />
          <p class="text-sm">{gettext("No hay pipelines configurados.")}</p>
          <p class="text-xs text-slate-400 dark:text-slate-500 mt-1">
            {gettext(
              "Los pipelines permiten filtrar, transformar y retrasar eventos antes de entregarlos."
            )}
          </p>
        </div>
      <% else %>
        <div class="overflow-x-auto rounded-xl border border-slate-200 dark:border-slate-700">
          <table class="min-w-full divide-y divide-slate-200 dark:divide-slate-700">
            <thead>
              <tr class="bg-slate-50/80 dark:bg-slate-800">
                <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider">
                  {gettext("Nombre")}
                </th>
                <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider hidden sm:table-cell">
                  {gettext("Topics")}
                </th>
                <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider hidden md:table-cell">
                  {gettext("Pasos")}
                </th>
                <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider">
                  {gettext("Estado")}
                </th>
                <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-right text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase tracking-wider">
                  {gettext("Acciones")}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100 dark:divide-slate-700">
              <%= for p <- @pipelines do %>
                <tr class="hover:bg-slate-50/50 dark:hover:bg-slate-700/50 transition">
                  <td class="px-3 sm:px-5 py-3 sm:py-4">
                    <div class="font-medium text-slate-800 dark:text-slate-200 text-sm">{p.name}</div>
                    <%= if p.description do %>
                      <div class="text-xs text-slate-500 dark:text-slate-400 mt-0.5 truncate max-w-[200px]">
                        {p.description}
                      </div>
                    <% end %>
                  </td>
                  <td class="px-3 sm:px-5 py-3 sm:py-4 hidden sm:table-cell">
                    <div class="flex flex-wrap gap-1">
                      <%= for topic <- Enum.take(p.topics || [], 3) do %>
                        <span class="inline-flex px-2 py-0.5 rounded-md text-xs bg-blue-50 dark:bg-blue-900/20 text-blue-700 dark:text-blue-400 font-mono">
                          {topic}
                        </span>
                      <% end %>
                      <%= if length(p.topics || []) > 3 do %>
                        <span class="text-xs text-slate-400 dark:text-slate-500">
                          +{length(p.topics) - 3}
                        </span>
                      <% end %>
                    </div>
                  </td>
                  <td class="px-3 sm:px-5 py-3 sm:py-4 hidden md:table-cell">
                    <div class="flex gap-1">
                      <%= for step <- p.steps || [] do %>
                        <span class={[
                          "inline-flex px-1.5 py-0.5 rounded text-xs font-medium",
                          pipeline_step_color(step["type"])
                        ]}>
                          {step["type"]}
                        </span>
                      <% end %>
                    </div>
                  </td>
                  <td class="px-3 sm:px-5 py-3 sm:py-4">
                    <span class={[
                      "inline-flex px-2 sm:px-2.5 py-0.5 sm:py-1 rounded-lg text-xs font-medium",
                      if(p.status == "active",
                        do:
                          "bg-emerald-100 dark:bg-emerald-900/30 text-emerald-800 dark:text-emerald-400",
                        else: "bg-slate-200 dark:bg-slate-700 text-slate-600 dark:text-slate-400"
                      )
                    ]}>
                      {p.status}
                    </span>
                  </td>
                  <td class="px-3 sm:px-5 py-3 sm:py-4 text-right">
                    <div class="flex flex-col sm:flex-row sm:inline-flex gap-1 sm:gap-2 items-start sm:items-center">
                      <%= if can_manage_team?(@current_user_role) do %>
                        <button
                          phx-click="edit_pipeline"
                          phx-value-id={p.id}
                          phx-disable-with={gettext("Cargando...")}
                          class="text-indigo-600 dark:text-indigo-400 hover:text-indigo-700 dark:hover:text-indigo-300 font-medium text-xs sm:text-sm disabled:opacity-70"
                        >
                          {gettext("Editar")}
                        </button>
                      <% end %>
                      <%= if p.status == "active" && can_manage_team?(@current_user_role) do %>
                        <button
                          phx-click="deactivate_pipeline"
                          phx-value-id={p.id}
                          phx-disable-with={gettext("Desactivando...")}
                          class="text-red-600 hover:text-red-700 font-medium text-xs sm:text-sm disabled:opacity-70"
                        >
                          {gettext("Desactivar")}
                        </button>
                      <% end %>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </section>

    <%!-- Pipeline Modal (improved with info, tooltips, presets) --%>
    <%= if @pipeline_modal do %>
      <div class="fixed inset-0 z-50 overflow-y-auto" aria-modal="true">
        <div class="flex min-h-full items-center justify-center p-3 sm:p-6">
          <div
            class="fixed inset-0 bg-black/50 backdrop-blur-sm"
            phx-click="close_pipeline_modal"
            aria-hidden="true"
          >
          </div>
          <div class="relative bg-white dark:bg-slate-800 rounded-2xl shadow-2xl max-w-lg w-full border border-slate-200/50 dark:border-slate-700 max-h-[90vh] overflow-y-auto">
            <%!-- Header --%>
            <div class="px-6 pt-6 pb-4 flex items-start justify-between border-b border-slate-200 dark:border-slate-700">
              <div>
                <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
                  {if @pipeline_modal == :new,
                    do: gettext("Nuevo pipeline"),
                    else: gettext("Editar pipeline")}
                </h3>
                <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
                  {gettext("Procesa eventos antes de entregarlos a tus webhooks.")}
                </p>
              </div>
              <button
                type="button"
                phx-click="close_pipeline_modal"
                class="rounded-lg p-1.5 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 transition"
              >
                <.icon name="hero-x-mark" class="w-5 h-5" />
              </button>
            </div>

            <%!-- Info box --%>
            <div class="px-6 pt-4">
              <div class="flex gap-3 p-3.5 rounded-xl bg-blue-50 dark:bg-blue-900/20 border border-blue-100 dark:border-blue-800/50">
                <.icon
                  name="hero-funnel"
                  class="w-5 h-5 text-blue-500 dark:text-blue-400 flex-shrink-0 mt-0.5"
                />
                <p class="text-sm text-blue-700 dark:text-blue-300">
                  {gettext(
                    "Un pipeline filtra, transforma o retrasa eventos antes de entregarlos. Los pasos se ejecutan en orden: si un filtro no coincide, el evento se omite para ese pipeline."
                  )}
                </p>
              </div>
            </div>

            <form phx-submit="save_pipeline" class="px-6 pb-6 pt-4 space-y-4">
              <%= if @pipeline_modal not in [:new] do %>
                <input type="hidden" name="pipeline_id" value={@pipeline_modal} />
              <% end %>

              <%!-- Name --%>
              <div>
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">
                  {gettext("Nombre")}
                </label>
                <input
                  type="text"
                  name="name"
                  value={@pipeline_form["name"]}
                  required
                  placeholder={gettext("Ej: Filtrar pagos completados")}
                  class="w-full rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2.5 text-sm text-slate-900 dark:text-slate-100 placeholder-slate-400 focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500"
                />
              </div>

              <%!-- Description --%>
              <div>
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">
                  {gettext("Descripción")}
                  <span class="font-normal text-slate-400 dark:text-slate-500 ml-1">
                    ({gettext("opcional")})
                  </span>
                </label>
                <input
                  type="text"
                  name="description"
                  value={@pipeline_form["description"]}
                  placeholder={gettext("Breve descripción de lo que hace este pipeline")}
                  class="w-full rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2.5 text-sm text-slate-900 dark:text-slate-100 placeholder-slate-400 focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500"
                />
              </div>

              <%!-- Topics --%>
              <div>
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  {gettext("Topics")}
                </label>
                <p class="text-xs text-slate-400 dark:text-slate-500 mb-1.5">
                  {gettext(
                    "Solo los eventos con estos topics pasarán por este pipeline. Vacío = todos."
                  )}
                </p>
                <input
                  type="text"
                  name="topics"
                  value={@pipeline_form["topics"]}
                  placeholder="order.created, payment.*"
                  class="w-full rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2.5 text-sm text-slate-900 dark:text-slate-100 font-mono placeholder-slate-400 focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500"
                />
                <p class="text-xs text-slate-400 dark:text-slate-500 mt-1">
                  {gettext(
                    "Separados por coma. Soporta wildcards: payment.* matchea payment.created, payment.failed, etc."
                  )}
                </p>
              </div>

              <%!-- Steps --%>
              <div>
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                  {gettext("Pasos del pipeline")}
                </label>
                <p class="text-xs text-slate-400 dark:text-slate-500 mb-1.5">
                  {gettext(
                    "Define los pasos como JSON. Cada paso tiene un tipo (filter, transform, delay) y su configuración."
                  )}
                </p>
                <textarea
                  name="steps"
                  rows="5"
                  class="w-full rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2.5 text-sm text-slate-900 dark:text-slate-100 font-mono placeholder-slate-400 focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500"
                >{@pipeline_form["steps"]}</textarea>

                <%!-- Step type presets --%>
                <div class="mt-2 space-y-1.5">
                  <p class="text-xs font-medium text-slate-500 dark:text-slate-400">
                    {gettext("Plantillas de pasos:")}
                  </p>
                  <div class="flex flex-wrap gap-1.5">
                    <button
                      type="button"
                      phx-click="pipeline_step_preset"
                      phx-value-preset="filter"
                      class="inline-flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium rounded-lg bg-emerald-50 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-800/50 hover:bg-emerald-100 dark:hover:bg-emerald-900/50 transition"
                    >
                      <.icon name="hero-funnel" class="w-3.5 h-3.5" />
                      {gettext("Filtro")}
                    </button>
                    <button
                      type="button"
                      phx-click="pipeline_step_preset"
                      phx-value-preset="transform"
                      class="inline-flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium rounded-lg bg-violet-50 dark:bg-violet-900/30 text-violet-700 dark:text-violet-400 border border-violet-200 dark:border-violet-800/50 hover:bg-violet-100 dark:hover:bg-violet-900/50 transition"
                    >
                      <.icon name="hero-arrow-path" class="w-3.5 h-3.5" />
                      {gettext("Transformar")}
                    </button>
                    <button
                      type="button"
                      phx-click="pipeline_step_preset"
                      phx-value-preset="delay"
                      class="inline-flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium rounded-lg bg-amber-50 dark:bg-amber-900/30 text-amber-700 dark:text-amber-400 border border-amber-200 dark:border-amber-800/50 hover:bg-amber-100 dark:hover:bg-amber-900/50 transition"
                    >
                      <.icon name="hero-clock" class="w-3.5 h-3.5" />
                      {gettext("Retraso")}
                    </button>
                  </div>
                </div>
              </div>

              <%!-- Buttons --%>
              <div class="flex flex-col-reverse sm:flex-row sm:justify-end gap-3 pt-3 border-t border-slate-200 dark:border-slate-700">
                <button
                  type="button"
                  phx-click="close_pipeline_modal"
                  class="w-full sm:w-auto px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 hover:bg-slate-50 dark:hover:bg-slate-600 text-slate-700 dark:text-slate-300 text-sm font-medium transition"
                >
                  {gettext("Cancelar")}
                </button>
                <button
                  type="submit"
                  phx-disable-with={gettext("Guardando...")}
                  class="w-full sm:w-auto px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-sm font-medium transition disabled:opacity-70"
                >
                  {if @pipeline_modal == :new,
                    do: gettext("Crear pipeline"),
                    else: gettext("Guardar cambios")}
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ===== TAB: QUEUE (Oban Monitor) =====
  def render_queue_tab(assigns) do
    ~H"""
    <%!-- State summary cards --%>
    <div class="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-7 gap-3 mb-6">
      <div
        :for={
          {state, color} <- [
            {"available", "emerald"},
            {"scheduled", "blue"},
            {"executing", "amber"},
            {"retryable", "orange"},
            {"completed", "slate"},
            {"discarded", "red"},
            {"cancelled", "zinc"}
          ]
        }
        phx-click="oban_filter_state"
        phx-value-state={state}
        class={"cursor-pointer rounded-lg border p-3 text-center transition hover:shadow-md #{if @oban_filter_state == state, do: "ring-2 ring-indigo-500 border-indigo-300 dark:border-indigo-600", else: "border-slate-200 dark:border-slate-700"} bg-white dark:bg-slate-800"}
      >
        <p class={"text-2xl font-bold text-#{color}-600"}>
          {Map.get(@oban_state_counts, state, 0)}
        </p>
        <p class="text-xs text-slate-500 dark:text-slate-400 capitalize">{state}</p>
      </div>
    </div>

    <%!-- Queue breakdown --%>
    <section class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm p-4 sm:p-6 lg:p-8 mb-6">
      <h2 class="text-base lg:text-lg font-semibold text-slate-900 dark:text-slate-100 mb-4">
        {gettext("Colas")}
      </h2>
      <div :if={@oban_queue_stats == []} class="text-center py-8">
        <.icon
          name="hero-queue-list"
          class="w-10 h-10 mx-auto mb-3 text-slate-300 dark:text-slate-600"
        />
        <p class="text-sm font-medium text-slate-600 dark:text-slate-300">
          {gettext("Sin colas activas")}
        </p>
        <p class="text-xs text-slate-400 dark:text-slate-500 mt-1">
          {gettext("Las colas aparecerán cuando haya jobs en proceso.")}
        </p>
      </div>
      <div :if={@oban_queue_stats != []} class="overflow-x-auto">
        <table class="min-w-full text-sm">
          <thead>
            <tr class="border-b border-slate-200 dark:border-slate-700">
              <th class="text-left py-2 px-3 font-medium text-slate-600 dark:text-slate-400">
                {gettext("Cola")}
              </th>
              <th class="text-center py-2 px-3 font-medium text-emerald-600">Available</th>
              <th class="text-center py-2 px-3 font-medium text-blue-600">Scheduled</th>
              <th class="text-center py-2 px-3 font-medium text-amber-600">Executing</th>
              <th class="text-center py-2 px-3 font-medium text-orange-600">Retryable</th>
              <th class="text-center py-2 px-3 font-medium text-slate-600">Completed</th>
              <th class="text-center py-2 px-3 font-medium text-red-600">Discarded</th>
              <th class="text-center py-2 px-3 font-medium text-zinc-600">Cancelled</th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={qs <- @oban_queue_stats}
              class="border-b border-slate-100 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-700/50 cursor-pointer"
              phx-click="oban_filter_queue"
              phx-value-queue={qs.queue}
            >
              <td class={"py-2 px-3 font-medium #{if @oban_filter_queue == qs.queue, do: "text-indigo-700 dark:text-indigo-400", else: "text-slate-900 dark:text-slate-100"}"}>
                {qs.queue}
              </td>
              <td class="text-center py-2 px-3">{Map.get(qs.counts, "available", 0)}</td>
              <td class="text-center py-2 px-3">{Map.get(qs.counts, "scheduled", 0)}</td>
              <td class="text-center py-2 px-3">{Map.get(qs.counts, "executing", 0)}</td>
              <td class="text-center py-2 px-3">{Map.get(qs.counts, "retryable", 0)}</td>
              <td class="text-center py-2 px-3">{Map.get(qs.counts, "completed", 0)}</td>
              <td class="text-center py-2 px-3">{Map.get(qs.counts, "discarded", 0)}</td>
              <td class="text-center py-2 px-3">{Map.get(qs.counts, "cancelled", 0)}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <%!-- Recent jobs list --%>
    <section class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm p-4 sm:p-6 lg:p-8">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900 dark:text-slate-100">
          {gettext("Jobs recientes")}
          <span
            :if={@oban_filter_state}
            class="ml-2 text-sm font-normal text-indigo-600 dark:text-indigo-400"
          >
            ({@oban_filter_state})
          </span>
          <span
            :if={@oban_filter_queue}
            class="ml-2 text-sm font-normal text-indigo-600 dark:text-indigo-400"
          >
            [{@oban_filter_queue}]
          </span>
        </h2>
        <div class="flex gap-2">
          <button
            :if={@oban_filter_state || @oban_filter_queue}
            phx-click="oban_clear_filters"
            class="text-xs px-3 py-1.5 rounded-lg border border-slate-300 dark:border-slate-600 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 transition"
          >
            {gettext("Limpiar filtros")}
          </button>
          <button
            phx-click="oban_refresh"
            class="text-xs px-3 py-1.5 rounded-lg bg-indigo-50 dark:bg-indigo-900/20 text-indigo-700 dark:text-indigo-300 hover:bg-indigo-100 dark:hover:bg-indigo-900/40 transition"
          >
            {gettext("Actualizar")}
          </button>
          <button
            phx-click={show_confirm("confirm-oban-purge")}
            class="text-xs px-3 py-1.5 rounded-lg bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-300 hover:bg-red-100 dark:hover:bg-red-900/40 transition"
          >
            {gettext("Purgar antiguos")}
          </button>
          <.confirm_modal
            id="confirm-oban-purge"
            title={gettext("Confirmar purga")}
            message={gettext("¿Eliminar jobs completados/descartados/cancelados de más de 7 días?")}
            confirm_text={gettext("Purgar")}
            confirm_event="oban_purge"
            variant="danger"
          />
        </div>
      </div>

      <div :if={@oban_jobs == []} class="text-center py-8">
        <.icon
          name="hero-clock"
          class="w-10 h-10 mx-auto mb-3 text-slate-300 dark:text-slate-600"
        />
        <p class="text-sm font-medium text-slate-600 dark:text-slate-300">
          {gettext("Sin jobs")}
        </p>
        <p class="text-xs text-slate-400 dark:text-slate-500 mt-1">
          {gettext("Filtra por estado o cola para ver jobs específicos.")}
        </p>
      </div>

      <div :if={@oban_jobs != []} class="overflow-x-auto">
        <table class="min-w-full text-sm">
          <thead>
            <tr class="border-b border-slate-200 dark:border-slate-700">
              <th class="text-left py-2 px-3 font-medium text-slate-600 dark:text-slate-400">ID</th>
              <th class="text-left py-2 px-3 font-medium text-slate-600 dark:text-slate-400">
                {gettext("Estado")}
              </th>
              <th class="text-left py-2 px-3 font-medium text-slate-600 dark:text-slate-400">
                {gettext("Cola")}
              </th>
              <th class="text-left py-2 px-3 font-medium text-slate-600 dark:text-slate-400">
                Worker
              </th>
              <th class="text-center py-2 px-3 font-medium text-slate-600 dark:text-slate-400">
                {gettext("Intentos")}
              </th>
              <th class="text-left py-2 px-3 font-medium text-slate-600 dark:text-slate-400">
                {gettext("Creado")}
              </th>
              <th class="text-right py-2 px-3 font-medium text-slate-600 dark:text-slate-400">
                {gettext("Acciones")}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={job <- @oban_jobs}
              class="border-b border-slate-100 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-700/50"
            >
              <td class="py-2 px-3 font-mono text-xs text-slate-500 dark:text-slate-400">{job.id}</td>
              <td class="py-2 px-3">
                <span class={"inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium #{oban_state_badge(job.state)}"}>
                  {job.state}
                </span>
              </td>
              <td class="py-2 px-3 text-slate-700 dark:text-slate-300">{job.queue}</td>
              <td class="py-2 px-3 text-slate-700 dark:text-slate-300 font-mono text-xs">
                {job.worker |> String.split(".") |> List.last()}
              </td>
              <td class="text-center py-2 px-3 text-slate-600 dark:text-slate-400">
                {job.attempt}/{job.max_attempts}
              </td>
              <td class="py-2 px-3 text-slate-500 dark:text-slate-400 text-xs whitespace-nowrap">
                {Calendar.strftime(job.inserted_at, "%Y-%m-%d %H:%M:%S")}
              </td>
              <td class="py-2 px-3 text-right space-x-1">
                <button
                  :if={job.state in ["retryable", "discarded"]}
                  phx-click="oban_retry_job"
                  phx-value-id={job.id}
                  class="text-xs text-indigo-600 dark:text-indigo-400 hover:text-indigo-800 dark:hover:text-indigo-300"
                  title={gettext("Reintentar")}
                >
                  {gettext("Reintentar")}
                </button>
                <button
                  :if={job.state in ["available", "scheduled", "retryable"]}
                  phx-click={show_confirm("confirm-cancel-job-#{job.id}")}
                  class="text-xs text-red-600 dark:text-red-400 hover:text-red-800 dark:hover:text-red-300"
                  title={gettext("Cancelar")}
                >
                  {gettext("Cancelar")}
                </button>
                <.confirm_modal
                  :if={job.state in ["available", "scheduled", "retryable"]}
                  id={"confirm-cancel-job-#{job.id}"}
                  title={gettext("Confirmar cancelación")}
                  message={gettext("¿Cancelar este job?")}
                  confirm_text={gettext("Cancelar")}
                  confirm_event="oban_cancel_job"
                  confirm_value={%{id: job.id}}
                  variant="danger"
                />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
    """
  end

  # ===== TAB: SETTINGS =====
  def render_settings_tab(assigns) do
    ~H"""
    <%!-- Row 1: Project + Analytics (2 cols) --%>
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6 lg:gap-8">
      <%!-- Project info --%>
      <section class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900 dark:text-slate-100 mb-2">
          {gettext("Proyecto")}
        </h2>
        <%= if @editing_project_name do %>
          <.form
            for={%{}}
            id="project-name-form"
            phx-submit="update_project_name"
            class="flex flex-wrap items-center gap-2"
          >
            <.input
              type="text"
              name="name"
              value={@project.name}
              class="w-full max-w-xs px-3 py-2 bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-600 rounded-lg text-slate-900 dark:text-slate-100"
              placeholder={gettext("Nombre del proyecto")}
            />
            <button
              type="submit"
              phx-disable-with={gettext("Guardando...")}
              class="px-3 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-sm font-medium disabled:opacity-70 disabled:cursor-not-allowed"
            >
              {gettext("Guardar")}
            </button>
            <button
              type="button"
              phx-click="cancel_edit_project_name"
              class="px-3 py-2 bg-slate-200 dark:bg-slate-700 hover:bg-slate-300 dark:hover:bg-slate-600 text-slate-800 dark:text-slate-200 rounded-lg text-sm font-medium"
            >
              {gettext("Cancelar")}
            </button>
          </.form>
        <% else %>
          <p class="text-slate-600 dark:text-slate-300">
            <strong>{@project.name}</strong>
            <%= if can_admin_team?(@current_user_role) do %>
              <button
                type="button"
                phx-click="edit_project_name"
                class="ml-2 text-indigo-600 dark:text-indigo-400 hover:text-indigo-700 dark:hover:text-indigo-300 text-sm font-medium"
              >
                {gettext("Editar nombre")}
              </button>
            <% end %>
          </p>
        <% end %>
        <p class="text-slate-500 dark:text-slate-400 text-sm font-mono mt-1 break-all">
          {@project.id}
        </p>
        <%!-- Delete project --%>
        <%= if @project.user_id == @current_user.id do %>
          <div class="mt-4 pt-4 border-t border-slate-200 dark:border-slate-700">
            <button
              phx-click={show_confirm("confirm-delete-project-#{@project.id}")}
              phx-disable-with={gettext("Eliminando...")}
              class="text-red-600 hover:text-red-700 text-xs font-medium disabled:opacity-50"
            >
              {gettext("Eliminar proyecto")}
            </button>
            <.confirm_modal
              id={"confirm-delete-project-#{@project.id}"}
              title={gettext("Confirmar eliminación")}
              message={gettext("¿Eliminar este proyecto? Esta acción no se puede deshacer.")}
              confirm_text={gettext("Eliminar proyecto")}
              confirm_event="delete_project"
              confirm_value={%{id: @project.id}}
              variant="danger"
            />
          </div>
        <% end %>
      </section>

      <%!-- Analytics (always visible) --%>
      <section class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <div class="flex items-center gap-2 mb-4">
          <.icon name="hero-chart-bar" class="w-5 h-5 text-indigo-600 dark:text-indigo-400" />
          <h2 class="text-base lg:text-lg font-semibold text-slate-900 dark:text-slate-100">
            {gettext("Analíticas")}
          </h2>
        </div>
        <%= if @analytics != %{} do %>
          <div class="grid grid-cols-1 gap-4">
            <div class="border border-slate-200 dark:border-slate-700 rounded-lg p-3">
              <h3 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-3">
                {gettext("Eventos por día (30d)")}
              </h3>
              <div class="h-32 sm:h-40">
                <canvas
                  id="events-chart"
                  phx-hook="Chart"
                  data-chart-type="line"
                  data-chart-labels={Jason.encode!(Enum.map(@analytics.events_per_day, & &1.date))}
                  data-chart-datasets={
                    Jason.encode!([
                      %{
                        label: gettext("Eventos"),
                        data: Enum.map(@analytics.events_per_day, & &1.count),
                        borderColor: "#6366f1",
                        backgroundColor: "rgba(99,102,241,0.1)",
                        fill: true,
                        tension: 0.3
                      }
                    ])
                  }
                >
                </canvas>
              </div>
            </div>
            <div class="border border-slate-200 dark:border-slate-700 rounded-lg p-3">
              <h3 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-3">
                {gettext("Entregas por día (30d)")}
              </h3>
              <div class="h-32 sm:h-40">
                <canvas
                  id="deliveries-chart"
                  phx-hook="Chart"
                  data-chart-type="bar"
                  data-chart-labels={
                    Jason.encode!(Enum.map(@analytics.deliveries_per_day, & &1.date))
                  }
                  data-chart-datasets={
                    Jason.encode!([
                      %{
                        label: gettext("Exitosas"),
                        data: Enum.map(@analytics.deliveries_per_day, & &1.success),
                        backgroundColor: "#10b981"
                      },
                      %{
                        label: gettext("Fallidas"),
                        data: Enum.map(@analytics.deliveries_per_day, & &1.failed),
                        backgroundColor: "#ef4444"
                      }
                    ])
                  }
                >
                </canvas>
              </div>
            </div>
          </div>
        <% else %>
          <p class="text-sm text-slate-400 dark:text-slate-500 text-center py-8">
            {gettext("Sin datos")}
          </p>
        <% end %>
      </section>
    </div>

    <%!-- Row 2: Sandbox + Team (2 cols) --%>
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6 lg:gap-8">
      <%!-- Sandbox --%>
      <section class="bg-white dark:bg-slate-800 rounded-xl border border-purple-200 dark:border-purple-800 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <div class="flex flex-wrap items-center justify-between gap-3 mb-4">
          <div class="flex items-center gap-2">
            <.icon name="hero-beaker" class="w-5 h-5 text-purple-600 dark:text-purple-400" />
            <h2 class="text-base lg:text-lg font-semibold text-slate-900 dark:text-slate-100">
              {gettext("Sandbox")}
            </h2>
          </div>
          <%= if can_manage_team?(@current_user_role) do %>
            <button
              type="button"
              phx-click="create_sandbox"
              class="inline-flex items-center gap-2 px-3 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded-xl font-medium text-sm shadow-sm transition"
            >
              <.icon name="hero-plus" class="w-4 h-4" /> {gettext("Crear endpoint")}
            </button>
          <% end %>
        </div>
        <%= if @sandbox_endpoints == [] do %>
          <div class="text-center py-8">
            <.icon
              name="hero-beaker"
              class="w-10 h-10 mx-auto mb-3 text-slate-300 dark:text-slate-600"
            />
            <p class="text-sm font-medium text-slate-600 dark:text-slate-300">
              {gettext("Sin endpoints de prueba")}
            </p>
            <p class="text-xs text-slate-400 dark:text-slate-500 mt-1 max-w-xs mx-auto">
              {gettext("Crea un endpoint temporal para recibir y ver requests en tiempo real.")}
            </p>
          </div>
        <% else %>
          <div class="flex flex-wrap gap-2 mb-4">
            <%= for ep <- @sandbox_endpoints do %>
              <div
                class={"inline-flex items-center gap-1 px-3 py-1.5 rounded-lg border text-sm cursor-pointer transition #{if @sandbox_active && @sandbox_active.id == ep.id, do: "bg-purple-50 dark:bg-purple-900/20 border-purple-300 dark:border-purple-700 text-purple-800 dark:text-purple-300", else: "bg-white dark:bg-slate-800 border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-400 hover:bg-slate-50 dark:hover:bg-slate-700/50"}"}
                phx-click="select_sandbox"
                phx-value-id={ep.id}
              >
                <span class="font-mono text-xs">{ep.slug}</span>
                <%= if can_manage_team?(@current_user_role) do %>
                  <button
                    type="button"
                    phx-click="delete_sandbox"
                    phx-value-id={ep.id}
                    phx-disable-with="..."
                    class="ml-1 text-slate-400 hover:text-red-500 disabled:opacity-50"
                    title={gettext("Eliminar")}
                  >
                    <.icon name="hero-x-mark" class="w-3.5 h-3.5" />
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
        <%= if @sandbox_active do %>
          <div class="rounded-lg border border-purple-100 dark:border-purple-800 bg-purple-50/50 dark:bg-purple-900/20 p-3 mb-4">
            <p class="text-sm text-purple-800 dark:text-purple-300 mb-1">
              {gettext("URL del endpoint:")}
            </p>
            <code class="text-xs font-mono text-purple-900 dark:text-purple-200 break-all">
              {sandbox_url(@sandbox_active)}
            </code>
          </div>
          <%= if @sandbox_requests == [] do %>
            <div class="text-center py-6">
              <.icon
                name="hero-signal"
                class="w-8 h-8 mx-auto mb-2 text-purple-300 dark:text-purple-600 animate-pulse"
              />
              <p class="text-sm text-slate-500 dark:text-slate-400">
                {gettext("Esperando requests... Envía un POST/GET a la URL de arriba.")}
              </p>
            </div>
          <% else %>
            <div class="overflow-x-auto rounded-lg border border-slate-200 dark:border-slate-700">
              <table class="min-w-full divide-y divide-slate-200 dark:divide-slate-700">
                <thead>
                  <tr class="bg-slate-50/80 dark:bg-slate-800">
                    <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase">
                      {gettext("Método")}
                    </th>
                    <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase hidden sm:table-cell">
                      {gettext("Body")}
                    </th>
                    <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase">
                      {gettext("Fecha")}
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-100 dark:divide-slate-700">
                  <%= for req <- @sandbox_requests do %>
                    <tr class="hover:bg-slate-50/50 dark:hover:bg-slate-700/50 transition">
                      <td class="px-3 py-2">
                        <span class={"inline-flex px-2 py-0.5 rounded text-xs font-medium #{method_color(req.method)}"}>
                          {req.method}
                        </span>
                      </td>
                      <td class="px-3 py-2 text-xs text-slate-600 dark:text-slate-400 font-mono truncate max-w-[16rem] hidden sm:table-cell">
                        {if req.body && req.body != "", do: String.slice(req.body, 0, 80), else: "—"}
                      </td>
                      <td class="px-3 py-2 text-xs text-slate-600 dark:text-slate-400">
                        {format_dt(req.inserted_at)}
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        <% end %>
      </section>

      <%!-- Team --%>
      <section class="bg-white dark:bg-slate-800 rounded-xl border border-cyan-200 dark:border-cyan-800 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <div class="flex items-center justify-between mb-4">
          <div class="flex items-center gap-2">
            <.icon name="hero-user-group" class="w-5 h-5 text-cyan-600 dark:text-cyan-400" />
            <h2 class="text-base lg:text-lg font-semibold text-slate-900 dark:text-slate-100">
              {gettext("Equipo")}
            </h2>
          </div>
          <span class={"px-2 py-0.5 rounded text-xs font-medium #{member_role_class(@current_user_role)}"}>
            {gettext("Tu rol: %{role}", role: @current_user_role || "—")}
          </span>
        </div>
        <%= if can_manage_team?(@current_user_role) do %>
          <.form
            for={%{}}
            id="invite-member-form"
            phx-submit="invite_member"
            class="flex flex-col sm:flex-row gap-2 mb-4"
          >
            <input
              type="email"
              name="email"
              placeholder={gettext("Email del usuario")}
              required
              class="flex-1 min-w-0 border border-slate-300 dark:border-slate-600 dark:bg-slate-700 dark:text-slate-100 rounded-lg px-3 py-2 text-sm"
            />
            <select
              name="role"
              class="border border-slate-300 dark:border-slate-600 rounded-lg px-3 py-2 text-sm bg-white dark:bg-slate-700 dark:text-slate-100"
            >
              <option value="viewer">{gettext("Viewer")}</option>
              <%= if can_admin_team?(@current_user_role) do %>
                <option value="editor">{gettext("Editor")}</option>
              <% end %>
            </select>
            <button
              type="submit"
              phx-disable-with={gettext("Invitando...")}
              class="px-4 py-2 bg-cyan-600 hover:bg-cyan-700 text-white rounded-lg text-sm font-medium shrink-0"
            >
              {gettext("Invitar")}
            </button>
          </.form>
        <% end %>
        <%= if @team_members == [] do %>
          <div class="text-center py-8">
            <.icon
              name="hero-user-group"
              class="w-10 h-10 mx-auto mb-3 text-slate-300 dark:text-slate-600"
            />
            <p class="text-sm font-medium text-slate-600 dark:text-slate-300">
              {gettext("Sin miembros del equipo")}
            </p>
            <p class="text-xs text-slate-400 dark:text-slate-500 mt-1">
              {gettext("Solo tú tienes acceso. Invita colaboradores arriba.")}
            </p>
          </div>
        <% else %>
          <div class="overflow-x-auto rounded-lg border border-slate-200 dark:border-slate-700">
            <table class="min-w-full divide-y divide-slate-200 dark:divide-slate-700">
              <thead>
                <tr class="bg-slate-50/80 dark:bg-slate-800">
                  <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase">
                    {gettext("Usuario")}
                  </th>
                  <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase">
                    {gettext("Rol")}
                  </th>
                  <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase">
                    {gettext("Estado")}
                  </th>
                  <%= if can_admin_team?(@current_user_role) do %>
                    <th class="px-3 py-2 text-right text-xs font-semibold text-slate-600 dark:text-slate-400 uppercase">
                      {gettext("Acciones")}
                    </th>
                  <% end %>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100 dark:divide-slate-700">
                <%= for m <- @team_members do %>
                  <tr class="hover:bg-slate-50/50 dark:hover:bg-slate-700/50 transition">
                    <td class="px-3 py-2 text-sm text-slate-700 dark:text-slate-300 font-mono truncate max-w-[6rem] sm:max-w-[10rem] lg:max-w-none">
                      {String.slice(m.user_id, 0, 8)}...
                    </td>
                    <td class="px-3 py-2">
                      <span class={"px-2 py-0.5 rounded text-xs font-medium #{member_role_class(m.role)}"}>
                        {m.role}
                      </span>
                    </td>
                    <td class="px-3 py-2">
                      <span class={"px-2 py-0.5 rounded text-xs font-medium #{member_status_class(m.status)}"}>
                        {m.status}
                      </span>
                    </td>
                    <%= if can_admin_team?(@current_user_role) do %>
                      <td class="px-3 py-2 text-right">
                        <%= if m.role != "owner" do %>
                          <div class="flex flex-col sm:flex-row sm:justify-end gap-1">
                            <%= if m.role == "viewer" do %>
                              <button
                                phx-click="update_member_role"
                                phx-value-id={m.id}
                                phx-value-role="editor"
                                phx-disable-with={gettext("Actualizando...")}
                                class="text-indigo-600 hover:text-indigo-700 text-xs font-medium disabled:opacity-50"
                              >
                                {gettext("Promover")}
                              </button>
                            <% end %>
                            <%= if m.role == "editor" do %>
                              <button
                                phx-click="update_member_role"
                                phx-value-id={m.id}
                                phx-value-role="viewer"
                                phx-disable-with={gettext("Actualizando...")}
                                class="text-amber-600 hover:text-amber-700 text-xs font-medium disabled:opacity-50"
                              >
                                {gettext("Degradar")}
                              </button>
                            <% end %>
                            <button
                              phx-click={show_confirm("confirm-remove-member-#{m.id}")}
                              phx-disable-with={gettext("Removiendo...")}
                              class="text-red-600 hover:text-red-700 text-xs font-medium disabled:opacity-50"
                            >
                              {gettext("Remover")}
                            </button>
                            <.confirm_modal
                              id={"confirm-remove-member-#{m.id}"}
                              title={gettext("Confirmar remoción")}
                              message={gettext("¿Remover este miembro?")}
                              confirm_text={gettext("Remover")}
                              confirm_event="remove_member"
                              confirm_value={%{id: m.id}}
                              variant="danger"
                            />
                          </div>
                        <% end %>
                      </td>
                    <% end %>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </section>
    </div>

    <%!-- Row 3: More analytics charts (full width, 2-col grid) --%>
    <%= if @analytics != %{} do %>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6 lg:gap-8">
        <section class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm p-4 sm:p-6">
          <h3 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-3">
            {gettext("Top topics")}
          </h3>
          <div class="h-48 sm:h-56">
            <canvas
              id="topics-chart"
              phx-hook="Chart"
              data-chart-type="doughnut"
              data-chart-labels={Jason.encode!(Enum.map(@analytics.top_topics, & &1.topic))}
              data-chart-datasets={
                Jason.encode!([
                  %{
                    data: Enum.map(@analytics.top_topics, & &1.count),
                    backgroundColor: [
                      "#6366f1",
                      "#8b5cf6",
                      "#a78bfa",
                      "#c4b5fd",
                      "#ddd6fe",
                      "#818cf8",
                      "#6d28d9",
                      "#5b21b6",
                      "#4c1d95",
                      "#312e81"
                    ]
                  }
                ])
              }
            >
            </canvas>
          </div>
        </section>
        <section class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm p-4 sm:p-6">
          <h3 class="text-sm font-semibold text-slate-700 dark:text-slate-300 mb-3">
            {gettext("Entregas por webhook (7d)")}
          </h3>
          <%= if @analytics.webhook_stats == [] do %>
            <div class="text-center py-8">
              <.icon
                name="hero-chart-bar"
                class="w-8 h-8 mx-auto mb-2 text-slate-300 dark:text-slate-600"
              />
              <p class="text-sm text-slate-400 dark:text-slate-500">
                {gettext("Sin datos de entregas aún")}
              </p>
            </div>
          <% else %>
            <div class="space-y-2 max-h-56 overflow-y-auto">
              <%= for ws <- @analytics.webhook_stats do %>
                <div class="flex items-center gap-2 text-sm">
                  <span class="font-mono text-xs text-slate-600 dark:text-slate-400 truncate flex-1 min-w-0">
                    {ws.webhook_url}
                  </span>
                  <span class="text-emerald-700 dark:text-emerald-400 font-medium text-xs shrink-0">
                    {ws.success}
                  </span>
                  <span class="text-slate-300 dark:text-slate-600 shrink-0">/</span>
                  <span class="text-red-600 dark:text-red-400 font-medium text-xs shrink-0">
                    {ws.failed}
                  </span>
                </div>
              <% end %>
            </div>
          <% end %>
        </section>
      </div>
    <% end %>

    <%!-- Row 4: Audit Log (full width) --%>
    <section class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
      <div class="flex items-center gap-2 mb-4">
        <.icon name="hero-clipboard-document-list" class="w-5 h-5 text-slate-600 dark:text-slate-400" />
        <h2 class="text-base lg:text-lg font-semibold text-slate-900 dark:text-slate-100">
          {gettext("Registro de actividad")}
        </h2>
      </div>
      <%= if @audit_logs == [] do %>
        <div class="text-center py-8">
          <.icon
            name="hero-clipboard-document-list"
            class="w-10 h-10 mx-auto mb-3 text-slate-300 dark:text-slate-600"
          />
          <p class="text-sm font-medium text-slate-600 dark:text-slate-300">
            {gettext("Sin actividad registrada")}
          </p>
          <p class="text-xs text-slate-400 dark:text-slate-500 mt-1">
            {gettext("Las acciones del equipo se registrarán aquí automáticamente.")}
          </p>
        </div>
      <% else %>
        <div class="space-y-2 max-h-48 sm:max-h-80 overflow-y-auto">
          <%= for log <- @audit_logs do %>
            <div class="flex items-start gap-3 py-2 border-b border-slate-100 dark:border-slate-700 last:border-0">
              <div class="mt-0.5 shrink-0">
                <.icon
                  name={Audit.action_icon(log.action)}
                  class="w-4 h-4 text-slate-400 dark:text-slate-500"
                />
              </div>
              <div class="min-w-0 flex-1">
                <p class="text-sm text-slate-800 dark:text-slate-200">
                  {audit_action_label(log.action)}
                </p>
                <p class="text-[11px] text-slate-400 dark:text-slate-500">
                  {format_dt(log.inserted_at)}
                </p>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </section>
    """
  end
end
