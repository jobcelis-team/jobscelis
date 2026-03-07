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
    <%!-- Row 1: API Token + Test Event (2 cols) --%>
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6 lg:gap-8">
      <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900 mb-1">{gettext("API Token")}</h2>
        <p class="text-slate-500 text-xs mb-3 break-words">
          {gettext("Header:")}
          <code class="bg-slate-100 px-1 rounded text-xs break-all">
            Authorization: Bearer &lt;token&gt;
          </code>
          {gettext("o")} <code class="bg-slate-100 px-1 rounded text-xs">X-Api-Key</code>
        </p>
        {render_token_section(assigns)}
      </section>

      <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900 mb-3">
          {gettext("Enviar evento de prueba")}
        </h2>
        <%= if can_manage_team?(@current_user_role) do %>
          <.form for={%{}} id="test-event-form" phx-submit="send_test" class="space-y-3">
            <.input
              type="text"
              name="topic"
              id="test-topic"
              value={@test_topic}
              placeholder={gettext("Topic (opcional)")}
              class="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg text-slate-900 placeholder-slate-400 font-mono text-sm"
            />
            <.input
              type="textarea"
              name="payload"
              id="test-payload"
              value={@test_payload}
              class="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg text-slate-900 placeholder-slate-400 font-mono text-sm"
            />
            <div class="flex flex-col sm:flex-row gap-2">
              <button
                type="submit"
                phx-disable-with={gettext("Enviando...")}
                class="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg font-medium text-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
              >
                {gettext("Enviar")}
              </button>
              <button
                type="button"
                phx-click="simulate_event"
                phx-value-topic={@test_topic}
                phx-value-payload={@test_payload}
                phx-disable-with={gettext("Simulando...")}
                class="px-4 py-2 bg-amber-500 hover:bg-amber-600 text-white rounded-lg font-medium text-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
              >
                {gettext("Simular")}
              </button>
            </div>
          </.form>
          <%= if @simulation_result do %>
            <div class="mt-4 p-4 bg-amber-50 border border-amber-200 rounded-lg">
              <div class="flex items-center justify-between mb-3">
                <h3 class="font-semibold text-amber-900">{gettext("Resultado de simulación")}</h3>
                <button
                  type="button"
                  phx-click="close_simulation"
                  class="text-amber-600 hover:text-amber-800 text-sm"
                >
                  {gettext("Cerrar")}
                </button>
              </div>
              <%= if @simulation_result == [] do %>
                <p class="text-sm text-amber-800">
                  {gettext("Ningún webhook matchearía con este evento.")}
                </p>
              <% else %>
                <p class="text-sm text-amber-800 mb-2">
                  {gettext("%{count} webhook(s) recibirían este evento:",
                    count: length(@simulation_result)
                  )}
                </p>
                <%= for sim <- @simulation_result do %>
                  <div class="mt-2 p-3 bg-white border border-amber-100 rounded text-sm">
                    <p class="font-mono text-xs text-slate-600 truncate">{sim.webhook_url}</p>
                    <p class="text-xs text-slate-500 mt-1">
                      {gettext("Topics")}:
                      <span class="font-medium">{if sim.matched_by_topics, do: "✓", else: "✗"}</span>
                      · {gettext("Filtros")}:
                      <span class="font-medium">{if sim.matched_by_filters, do: "✓", else: "✗"}</span>
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
          <p class="text-sm text-slate-500 italic">
            {gettext("Solo lectura. No tienes permisos para enviar eventos.")}
          </p>
        <% end %>
      </section>
    </div>

    <%!-- System Health Status --%>
    <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div class="flex items-center gap-3">
          <span class={[
            "inline-block w-3 h-3 rounded-full",
            uptime_dot_color(@uptime_status)
          ]}>
          </span>
          <h2 class="text-base lg:text-lg font-semibold text-slate-900">
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
          <span class="px-3 py-1 bg-slate-100 rounded-full text-xs font-medium text-slate-700">
            {gettext("24h")}: {@uptime_stats.last_24h.uptime_percent}%
          </span>
          <span class="px-3 py-1 bg-slate-100 rounded-full text-xs font-medium text-slate-700">
            {gettext("7d")}: {@uptime_stats.last_7d.uptime_percent}%
          </span>
          <span class="px-3 py-1 bg-slate-100 rounded-full text-xs font-medium text-slate-700">
            {gettext("30d")}: {@uptime_stats.last_30d.uptime_percent}%
          </span>
        </div>
      </div>
    </section>

    <%!-- Row 2: Recent Events (full width) --%>
    <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
      <h2 class="text-base lg:text-lg font-semibold text-slate-900 mb-4">
        {gettext("Eventos recientes")}
      </h2>
      <div class="overflow-x-auto rounded-lg border border-slate-200">
        <table class="min-w-full">
          <thead>
            <tr class="bg-slate-50 border-b border-slate-200">
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                {gettext("ID")}
              </th>
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                {gettext("Topic")}
              </th>
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                {gettext("Estado")}
              </th>
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700 hidden sm:table-cell">
                {gettext("Fecha")}
              </th>
            </tr>
          </thead>
          <tbody>
            <%= for e <- Enum.take(@events, 10) do %>
              <tr class="border-b border-slate-100 last:border-0">
                <td class="px-3 sm:px-4 py-2 sm:py-3 font-mono text-xs sm:text-sm text-slate-600">
                  {String.slice(e.id, 0, 8)}...
                </td>
                <td class="px-3 sm:px-4 py-2 sm:py-3 text-sm text-slate-700 truncate max-w-[8rem] sm:max-w-none">
                  {e.topic || "—"}
                </td>
                <td class="px-3 sm:px-4 py-2 sm:py-3">
                  <span class="px-2 py-0.5 rounded text-xs font-medium bg-slate-100 text-slate-700">
                    {e.status}
                  </span>
                  <%= if e.deliver_at && DateTime.compare(e.deliver_at, DateTime.utc_now()) == :gt do %>
                    <span class="ml-1 px-1.5 py-0.5 rounded text-[10px] font-medium bg-amber-100 text-amber-700">
                      {gettext("Programado")}
                    </span>
                  <% end %>
                </td>
                <td class="px-3 sm:px-4 py-2 sm:py-3 text-sm text-slate-600 hidden sm:table-cell">
                  {format_dt(e.occurred_at)}
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </section>

    <%!-- Row 3: Webhooks Health (full width, compact) --%>
    <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
      <h2 class="text-base lg:text-lg font-semibold text-slate-900 mb-4">{gettext("Webhooks")}</h2>
      <div class="overflow-x-auto rounded-lg border border-slate-200">
        <table class="min-w-full">
          <thead>
            <tr class="bg-slate-50 border-b border-slate-200">
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                {gettext("URL")}
              </th>
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                {gettext("Salud")}
              </th>
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                {gettext("Estado")}
              </th>
            </tr>
          </thead>
          <tbody>
            <%= for w <- @webhooks do %>
              <% health = @webhook_health[w.id] %>
              <tr class="border-b border-slate-100 last:border-0">
                <td class="px-3 sm:px-4 py-2 sm:py-3 font-mono text-xs sm:text-sm text-slate-600 truncate max-w-[8rem] sm:max-w-[12rem] lg:max-w-none">
                  {w.url}
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
                  <span class="px-2 py-0.5 rounded text-xs font-medium bg-slate-100 text-slate-700">
                    {w.status}
                  </span>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </section>
    """
  end

  # ===== TAB: EVENTS =====
  def render_events_tab(assigns) do
    ~H"""
    <%!-- Events table (full width with export + search) --%>
    <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-4">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900">
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
                class="w-40 sm:w-56 border border-slate-300 rounded-lg px-3 py-1.5 pl-8 text-xs sm:text-sm"
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
                class="px-2 py-1.5 text-xs text-slate-500 hover:text-slate-700 hover:bg-slate-100 rounded-lg transition"
              >
                <.icon name="hero-x-mark" class="w-4 h-4" />
              </button>
            <% end %>
          </.form>
          <a
            href="/export/events?format=csv"
            target="_blank"
            class="inline-flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-lg transition"
          >
            <.icon name="hero-arrow-down-tray" class="w-3.5 h-3.5" /> CSV
          </a>
          <a
            href="/export/events?format=json"
            target="_blank"
            class="inline-flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-lg transition"
          >
            <.icon name="hero-arrow-down-tray" class="w-3.5 h-3.5" /> JSON
          </a>
        </div>
      </div>
      <%= if @search_results do %>
        <p class="text-xs text-slate-500 mb-2">
          {gettext("%{count} resultados para \"%{query}\"",
            count: length(@search_results),
            query: @search_query
          )}
        </p>
      <% end %>
      <div class="overflow-x-auto rounded-lg border border-slate-200">
        <table class="min-w-full">
          <thead>
            <tr class="bg-slate-50 border-b border-slate-200">
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                {gettext("ID")}
              </th>
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                {gettext("Topic")}
              </th>
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                {gettext("Estado")}
              </th>
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700 hidden sm:table-cell">
                {gettext("Fecha")}
              </th>
            </tr>
          </thead>
          <tbody>
            <% display_events = @search_results || @events %>
            <%= for e <- display_events do %>
              <tr
                class="border-b border-slate-100 last:border-0 hover:bg-indigo-50/50 cursor-pointer transition"
                phx-click="show_event_detail"
                phx-value-id={e.id}
              >
                <td class="px-3 sm:px-4 py-2 sm:py-3 font-mono text-xs sm:text-sm text-indigo-600">
                  {String.slice(e.id, 0, 8)}...
                </td>
                <td class="px-3 sm:px-4 py-2 sm:py-3 text-sm text-slate-700 truncate max-w-[8rem] sm:max-w-none">
                  {e.topic || "—"}
                </td>
                <td class="px-3 sm:px-4 py-2 sm:py-3">
                  <span class="px-2 py-0.5 rounded text-xs font-medium bg-slate-100 text-slate-700">
                    {e.status}
                  </span>
                  <%= if e.deliver_at && DateTime.compare(e.deliver_at, DateTime.utc_now()) == :gt do %>
                    <span class="ml-1 px-1.5 py-0.5 rounded text-[10px] font-medium bg-amber-100 text-amber-700">
                      {gettext("Programado")}
                    </span>
                  <% end %>
                </td>
                <td class="px-3 sm:px-4 py-2 sm:py-3 text-sm text-slate-600 hidden sm:table-cell">
                  {format_dt(e.occurred_at)}
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </section>

    <%!-- Row 2: Event Schemas + Replay (2 cols) --%>
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6 lg:gap-8">
      <%!-- Event Schemas --%>
      <section class="bg-white rounded-xl border border-teal-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <div class="flex items-center gap-2 mb-4">
          <.icon name="hero-document-check" class="w-5 h-5 text-teal-600" />
          <h2 class="text-base lg:text-lg font-semibold text-slate-900">
            {gettext("Event Schemas")}
          </h2>
        </div>
        <%= if can_manage_team?(@current_user_role) do %>
          <.form
            for={%{}}
            id="event-schema-form"
            phx-submit="create_event_schema"
            class="flex flex-col gap-2 mb-4"
          >
            <input
              type="text"
              name="topic"
              placeholder={gettext("Topic (ej: order.created)")}
              required
              class="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm"
            />
            <textarea
              name="schema"
              rows="2"
              placeholder={
                gettext("JSON Schema (ej: {\"type\":\"object\",\"required\":[\"amount\"]})")
              }
              required
              class="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm font-mono"
            ></textarea>
            <button
              type="submit"
              phx-disable-with={gettext("Creando...")}
              class="px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white rounded-lg text-sm font-medium"
            >
              {gettext("Crear")}
            </button>
          </.form>
        <% end %>
        <%= if @event_schemas == [] do %>
          <p class="text-sm text-slate-500">
            {gettext("Sin schemas. Los eventos no serán validados.")}
          </p>
        <% else %>
          <div class="overflow-x-auto rounded-lg border border-slate-200">
            <table class="min-w-full divide-y divide-slate-200">
              <thead>
                <tr class="bg-slate-50/80">
                  <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                    {gettext("Topic")}
                  </th>
                  <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase hidden sm:table-cell">
                    {gettext("Versión")}
                  </th>
                  <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                    {gettext("Estado")}
                  </th>
                  <th class="px-3 py-2 text-right text-xs font-semibold text-slate-600 uppercase">
                    {gettext("Acciones")}
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <%= for s <- @event_schemas do %>
                  <tr class="hover:bg-slate-50/50 transition">
                    <td class="px-3 py-2 text-sm text-slate-700 font-mono">{s.topic}</td>
                    <td class="px-3 py-2 text-sm text-slate-600 hidden sm:table-cell">
                      v{s.version}
                    </td>
                    <td class="px-3 py-2">
                      <span class="px-2 py-0.5 rounded text-xs font-medium bg-teal-100 text-teal-800">
                        {s.status}
                      </span>
                    </td>
                    <%= if can_manage_team?(@current_user_role) do %>
                      <td class="px-3 py-2 text-right">
                        <button
                          phx-click="delete_event_schema"
                          phx-value-id={s.id}
                          phx-disable-with={gettext("Eliminando...")}
                          data-confirm={gettext("¿Eliminar este schema?")}
                          class="text-red-600 hover:text-red-700 text-xs font-medium disabled:opacity-50"
                        >
                          {gettext("Eliminar")}
                        </button>
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
      <section class="bg-white rounded-xl border border-blue-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <div class="flex flex-wrap items-center justify-between gap-3 mb-4">
          <div class="flex items-center gap-2">
            <.icon name="hero-arrow-uturn-left" class="w-5 h-5 text-blue-600" />
            <h2 class="text-base lg:text-lg font-semibold text-slate-900">
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
          <p class="text-sm text-slate-500">
            {gettext(
              "No hay replays. Usa esta función para re-enviar eventos históricos a tus webhooks."
            )}
          </p>
        <% else %>
          <div class="overflow-x-auto rounded-lg border border-slate-200">
            <table class="min-w-full divide-y divide-slate-200">
              <thead>
                <tr class="bg-slate-50/80">
                  <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                    {gettext("Estado")}
                  </th>
                  <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                    {gettext("Progreso")}
                  </th>
                  <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase hidden sm:table-cell">
                    {gettext("Fecha")}
                  </th>
                  <th class="px-3 py-2 text-right text-xs font-semibold text-slate-600 uppercase">
                    {gettext("Acciones")}
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <%= for r <- @replays do %>
                  <tr class="hover:bg-slate-50/50 transition">
                    <td class="px-3 py-2">
                      <span class={"inline-flex px-2 py-0.5 rounded text-xs font-medium #{replay_status_class(r.status)}"}>
                        {replay_status_label(r.status)}
                      </span>
                    </td>
                    <td class="px-3 py-2">
                      <div class="flex items-center gap-2">
                        <div class="flex-1 bg-slate-200 rounded-full h-2 max-w-[6rem] sm:max-w-[8rem]">
                          <div
                            class="bg-blue-600 h-2 rounded-full transition-all"
                            style={"width: #{if r.total_events > 0, do: Float.round(r.processed_events / r.total_events * 100, 0), else: 0}%"}
                          >
                          </div>
                        </div>
                        <span class="text-xs text-slate-600">
                          {r.processed_events}/{r.total_events}
                        </span>
                      </div>
                    </td>
                    <td class="px-3 py-2 text-sm text-slate-600 hidden sm:table-cell">
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
    """
  end

  # ===== TAB: WEBHOOKS =====
  def render_webhooks_tab(assigns) do
    ~H"""
    <%!-- Webhooks table --%>
    <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-4">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900">{gettext("Webhooks")}</h2>
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
      <div class="overflow-x-auto rounded-lg border border-slate-200">
        <table class="min-w-full">
          <thead>
            <tr class="bg-slate-50 border-b border-slate-200">
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                {gettext("URL")}
              </th>
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700 hidden sm:table-cell">
                {gettext("Topics")}
              </th>
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                {gettext("Salud")}
              </th>
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                {gettext("Estado")}
              </th>
              <%= if can_manage_team?(@current_user_role) do %>
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-right text-xs sm:text-sm font-medium text-slate-700">
                  {gettext("Acciones")}
                </th>
              <% end %>
            </tr>
          </thead>
          <tbody>
            <%= for w <- @webhooks do %>
              <% health = @webhook_health[w.id] %>
              <tr class={"border-b border-slate-100 last:border-0 #{if w.status == "inactive", do: "opacity-50"}"}>
                <td class="px-3 sm:px-4 py-2 sm:py-3 font-mono text-xs sm:text-sm text-slate-600 truncate max-w-[8rem] sm:max-w-[12rem] lg:max-w-none">
                  {w.url}
                </td>
                <td class="px-3 sm:px-4 py-2 sm:py-3 hidden sm:table-cell">
                  <%= if w.topics && w.topics != [] do %>
                    <div class="flex flex-wrap gap-1">
                      <%= for topic <- Enum.take(w.topics, 3) do %>
                        <span class="px-1.5 py-0.5 rounded text-xs bg-slate-100 text-slate-600">
                          {topic}
                        </span>
                      <% end %>
                      <%= if length(w.topics) > 3 do %>
                        <span class="text-xs text-slate-400">
                          +{length(w.topics) - 3}
                        </span>
                      <% end %>
                    </div>
                  <% else %>
                    <span class="text-xs text-slate-400">{gettext("Todos")}</span>
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
                      do: "bg-emerald-100 text-emerald-700",
                      else: "bg-slate-100 text-slate-500"
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
                        class="p-1.5 rounded-lg text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 transition"
                        title={gettext("Editar")}
                      >
                        <.icon name="hero-pencil-square" class="w-4 h-4" />
                      </button>
                      <%= if w.status == "active" do %>
                        <button
                          type="button"
                          phx-click="deactivate_webhook"
                          phx-value-id={w.id}
                          data-confirm={gettext("¿Desactivar este webhook?")}
                          class="p-1.5 rounded-lg text-slate-400 hover:text-red-600 hover:bg-red-50 transition"
                          title={gettext("Desactivar")}
                        >
                          <.icon name="hero-pause-circle" class="w-4 h-4" />
                        </button>
                      <% else %>
                        <button
                          type="button"
                          phx-click="activate_webhook"
                          phx-value-id={w.id}
                          class="p-1.5 rounded-lg text-slate-400 hover:text-emerald-600 hover:bg-emerald-50 transition"
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
          </tbody>
        </table>
      </div>
    </section>

    <%!-- Webhook create/edit modal --%>
    <%= if @webhook_modal do %>
      <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div
          class="absolute inset-0 bg-black/50 backdrop-blur-sm"
          phx-click="close_webhook_modal"
          aria-hidden="true"
        >
        </div>
        <div
          class="relative z-10 bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-auto overflow-hidden"
          role="dialog"
          aria-modal="true"
        >
          <div class="px-6 pt-6 pb-4 flex items-start justify-between">
            <h2 class="text-lg font-semibold text-slate-900">
              {if @webhook_modal == :new,
                do: gettext("Crear webhook"),
                else: gettext("Editar webhook")}
            </h2>
            <button
              type="button"
              phx-click="close_webhook_modal"
              class="rounded-lg p-1.5 text-slate-400 hover:text-slate-600 hover:bg-slate-100 transition"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>
          <form phx-submit="save_webhook" class="px-6 pb-6 space-y-4">
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1">{gettext("URL")}</label>
              <input
                type="url"
                name="webhook[url]"
                value={@webhook_form["url"]}
                required
                placeholder={gettext("https://ejemplo.com/webhook")}
                class="w-full px-3 py-2 rounded-lg border border-slate-300 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1">
                {gettext("Topics")}
                <span class="font-normal text-slate-400">
                  ({gettext("separados por coma, vacío = todos")})
                </span>
              </label>
              <input
                type="text"
                name="webhook[topics]"
                value={@webhook_form["topics"]}
                placeholder={gettext("user.created, order.paid")}
                class="w-full px-3 py-2 rounded-lg border border-slate-300 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1">
                {gettext("Secreto HMAC")}
                <span class="font-normal text-slate-400">
                  ({gettext("opcional, dejar vacío para mantener el actual")})
                </span>
              </label>
              <input
                type="password"
                name="webhook[secret]"
                value=""
                placeholder="whsec_..."
                autocomplete="off"
                class="w-full px-3 py-2 rounded-lg border border-slate-300 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500"
              />
            </div>
            <div class="flex flex-col-reverse sm:flex-row sm:justify-end gap-3 pt-2">
              <button
                type="button"
                phx-click="close_webhook_modal"
                class="w-full sm:w-auto px-4 py-2 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-slate-700 text-sm font-medium transition"
              >
                {gettext("Cancelar")}
              </button>
              <button
                type="submit"
                phx-disable-with={gettext("Guardando...")}
                class="w-full sm:w-auto px-4 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium transition"
              >
                {if @webhook_modal == :new, do: gettext("Crear"), else: gettext("Guardar")}
              </button>
            </div>
          </form>
        </div>
      </div>
    <% end %>

    <%!-- Deliveries --%>
    <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-4">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900">{gettext("Entregas")}</h2>
        <div class="flex flex-wrap gap-2">
          <a
            href="/export/deliveries?format=csv"
            target="_blank"
            class="inline-flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-lg transition"
          >
            <.icon name="hero-arrow-down-tray" class="w-3.5 h-3.5" /> CSV
          </a>
          <a
            href="/export/deliveries?format=json"
            target="_blank"
            class="inline-flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-lg transition"
          >
            <.icon name="hero-arrow-down-tray" class="w-3.5 h-3.5" /> JSON
          </a>
        </div>
      </div>
      <div class="overflow-x-auto rounded-xl border border-slate-200">
        <table class="min-w-full divide-y divide-slate-200">
          <thead>
            <tr class="bg-slate-50/80">
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">
                {gettext("Evento / Topic")}
              </th>
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider hidden md:table-cell">
                {gettext("Webhook")}
              </th>
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">
                {gettext("Estado")}
              </th>
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider hidden lg:table-cell">
                {gettext("Intento")}
              </th>
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider hidden sm:table-cell">
                {gettext("HTTP")}
              </th>
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider hidden sm:table-cell">
                {gettext("Fecha")}
              </th>
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-right text-xs font-semibold text-slate-600 uppercase tracking-wider">
                {gettext("Acciones")}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <%= for d <- @deliveries do %>
              <tr class="hover:bg-slate-50/50 transition">
                <td class="px-3 sm:px-5 py-3 sm:py-4 text-xs sm:text-sm text-slate-600 font-mono truncate max-w-[8rem] sm:max-w-none">
                  {if d.event,
                    do: d.event.topic || String.slice(d.event_id, 0, 8),
                    else: String.slice(d.event_id, 0, 8)}
                </td>
                <td class="px-3 sm:px-5 py-3 sm:py-4 font-mono text-xs text-slate-600 max-w-[14rem] truncate hidden md:table-cell">
                  {if d.webhook, do: d.webhook.url, else: d.webhook_id}
                </td>
                <td class="px-3 sm:px-5 py-3 sm:py-4">
                  <span class={[
                    "inline-flex px-2 sm:px-2.5 py-0.5 sm:py-1 rounded-lg text-xs font-medium",
                    if(d.status == "success",
                      do: "bg-emerald-100 text-emerald-800",
                      else:
                        if(d.status == "pending",
                          do: "bg-amber-100 text-amber-800",
                          else: "bg-red-100 text-red-800"
                        )
                    )
                  ]}>
                    {d.status}
                  </span>
                </td>
                <td class="px-3 sm:px-5 py-3 sm:py-4 text-sm text-slate-600 hidden lg:table-cell">
                  {d.attempt_number}
                </td>
                <td class="px-3 sm:px-5 py-3 sm:py-4 text-sm text-slate-600 font-mono hidden sm:table-cell">
                  {d.response_status || "—"}
                </td>
                <td class="px-3 sm:px-5 py-3 sm:py-4 text-sm text-slate-600 hidden sm:table-cell">
                  {format_dt(d.inserted_at)}
                </td>
                <td class="px-3 sm:px-5 py-3 sm:py-4 text-right">
                  <%= if d.status != "success" and d.status != "pending" and can_manage_team?(@current_user_role) do %>
                    <button
                      phx-click="retry_delivery"
                      phx-value-id={d.id}
                      phx-disable-with={gettext("Reintentando...")}
                      class="text-indigo-600 hover:text-indigo-700 font-medium text-xs sm:text-sm disabled:opacity-70"
                    >
                      {gettext("Reintentar")}
                    </button>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </section>

    <%!-- Dead Letter Queue --%>
    <%= if @dead_letters != [] do %>
      <section class="bg-white rounded-xl border border-red-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-4">
          <div class="flex items-center gap-2">
            <span class="w-2.5 h-2.5 rounded-full bg-red-500 animate-pulse"></span>
            <h2 class="text-base font-semibold text-red-900">{gettext("Dead Letter Queue")}</h2>
            <span class="px-2 py-0.5 rounded-full bg-red-100 text-red-700 text-xs font-medium">
              {length(@dead_letters)}
            </span>
          </div>
          <%!-- Bulk actions (#25) --%>
          <%= if can_manage_team?(@current_user_role) do %>
            <div class="flex items-center gap-2">
              <%= if @selected_dead_letters != [] do %>
                <span class="text-xs text-slate-500">
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
                  class="px-2.5 py-1.5 text-xs font-medium text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-lg transition"
                >
                  {gettext("Descartar seleccionados")}
                </button>
              <% end %>
              <%= if @selected_dead_letters == [] do %>
                <button
                  phx-click="select_all_dl"
                  class="px-2.5 py-1.5 text-xs font-medium text-slate-500 hover:text-slate-700 hover:bg-slate-100 rounded-lg transition"
                >
                  {gettext("Seleccionar todo")}
                </button>
              <% else %>
                <button
                  phx-click="deselect_all_dl"
                  class="px-2.5 py-1.5 text-xs font-medium text-slate-500 hover:text-slate-700 hover:bg-slate-100 rounded-lg transition"
                >
                  {gettext("Deseleccionar")}
                </button>
              <% end %>
            </div>
          <% end %>
        </div>
        <p class="text-sm text-red-700 mb-4">
          {gettext("Entregas que agotaron todos los reintentos. Puedes reintentar o descartar.")}
        </p>
        <div class="overflow-x-auto rounded-lg border border-red-100">
          <table class="min-w-full divide-y divide-red-100">
            <thead>
              <tr class="bg-red-50/50">
                <%= if can_manage_team?(@current_user_role) do %>
                  <th class="w-8 px-3 py-2"></th>
                <% end %>
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs font-semibold text-red-700 uppercase">
                  {gettext("Webhook")}
                </th>
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs font-semibold text-red-700 uppercase hidden sm:table-cell">
                  {gettext("Error")}
                </th>
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs font-semibold text-red-700 uppercase">
                  {gettext("Intentos")}
                </th>
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs font-semibold text-red-700 uppercase hidden sm:table-cell">
                  {gettext("Fecha")}
                </th>
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-right text-xs font-semibold text-red-700 uppercase">
                  {gettext("Acciones")}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-red-50">
              <%= for dl <- @dead_letters do %>
                <tr class="hover:bg-red-50/30 transition">
                  <%= if can_manage_team?(@current_user_role) do %>
                    <td class="w-8 px-3 py-2">
                      <input
                        type="checkbox"
                        checked={dl.id in @selected_dead_letters}
                        phx-click="toggle_dl_select"
                        phx-value-id={dl.id}
                        class="rounded border-red-300 text-red-600 focus:ring-red-500"
                      />
                    </td>
                  <% end %>
                  <td class="px-3 sm:px-4 py-2 sm:py-3 font-mono text-xs text-slate-600 truncate max-w-[6rem] sm:max-w-[10rem] lg:max-w-none">
                    {if dl.webhook, do: dl.webhook.url, else: "—"}
                  </td>
                  <td class="px-3 sm:px-4 py-2 sm:py-3 text-xs text-red-700 truncate max-w-[12rem] hidden sm:table-cell">
                    {dl.last_error || "—"}
                  </td>
                  <td class="px-3 sm:px-4 py-2 sm:py-3 text-sm text-slate-600">
                    {dl.attempts_exhausted}
                  </td>
                  <td class="px-3 sm:px-4 py-2 sm:py-3 text-sm text-slate-600 hidden sm:table-cell">
                    {format_dt(dl.inserted_at)}
                  </td>
                  <td class="px-3 sm:px-4 py-2 sm:py-3 text-right">
                    <%= if can_manage_team?(@current_user_role) do %>
                      <div class="flex flex-col sm:flex-row sm:justify-end gap-1">
                        <button
                          phx-click="retry_dead_letter"
                          phx-value-id={dl.id}
                          phx-disable-with={gettext("...")}
                          class="text-indigo-600 hover:text-indigo-700 font-medium text-xs disabled:opacity-70"
                        >
                          {gettext("Reintentar")}
                        </button>
                        <button
                          phx-click="resolve_dead_letter"
                          phx-value-id={dl.id}
                          phx-disable-with={gettext("...")}
                          class="text-slate-500 hover:text-slate-700 font-medium text-xs disabled:opacity-70"
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
    <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
      <div class="flex flex-wrap items-center justify-between gap-3 sm:gap-4 mb-4 sm:mb-6">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900">{gettext("Jobs")}</h2>
        <div class="flex flex-wrap gap-2">
          <a
            href="/export/jobs?format=csv"
            target="_blank"
            class="inline-flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-lg transition"
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
      <div class="overflow-x-auto rounded-xl border border-slate-200">
        <table class="min-w-full divide-y divide-slate-200">
          <thead>
            <tr class="bg-slate-50/80">
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">
                {gettext("Nombre")}
              </th>
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider hidden sm:table-cell">
                {gettext("Programación")}
              </th>
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider hidden sm:table-cell">
                {gettext("Acción")}
              </th>
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">
                {gettext("Estado")}
              </th>
              <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-right text-xs font-semibold text-slate-600 uppercase tracking-wider">
                {gettext("Acciones")}
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <%= for j <- @jobs do %>
              <tr class="hover:bg-slate-50/50 transition">
                <td class="px-3 sm:px-5 py-3 sm:py-4 font-medium text-slate-800 text-sm">{j.name}</td>
                <td class="px-3 sm:px-5 py-3 sm:py-4 text-sm text-slate-600 hidden sm:table-cell">
                  {j.schedule_type}
                </td>
                <td class="px-3 sm:px-5 py-3 sm:py-4 text-sm text-slate-600 hidden sm:table-cell">
                  {j.action_type}
                </td>
                <td class="px-3 sm:px-5 py-3 sm:py-4">
                  <span class={[
                    "inline-flex px-2 sm:px-2.5 py-0.5 sm:py-1 rounded-lg text-xs font-medium",
                    if(j.status == "active",
                      do: "bg-emerald-100 text-emerald-800",
                      else: "bg-slate-200 text-slate-600"
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
                        class="text-indigo-600 hover:text-indigo-700 font-medium text-xs sm:text-sm disabled:opacity-70"
                      >
                        {gettext("Editar")}
                      </button>
                    <% end %>
                    <button
                      phx-click="show_job_runs"
                      phx-value-id={j.id}
                      phx-disable-with={gettext("Cargando...")}
                      class="text-slate-600 hover:text-slate-700 font-medium text-xs sm:text-sm disabled:opacity-70"
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
          </tbody>
        </table>
      </div>
    </section>
    """
  end

  # ===== TAB: PIPELINES =====
  def render_pipelines_tab(assigns) do
    ~H"""
    <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
      <div class="flex flex-wrap items-center justify-between gap-3 sm:gap-4 mb-4 sm:mb-6">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900">{gettext("Pipelines")}</h2>
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
        <div class="text-center py-12 text-slate-500">
          <.icon name="hero-funnel" class="w-12 h-12 mx-auto mb-3 text-slate-300" />
          <p class="text-sm">{gettext("No hay pipelines configurados.")}</p>
          <p class="text-xs text-slate-400 mt-1">
            {gettext(
              "Los pipelines permiten filtrar, transformar y retrasar eventos antes de entregarlos."
            )}
          </p>
        </div>
      <% else %>
        <div class="overflow-x-auto rounded-xl border border-slate-200">
          <table class="min-w-full divide-y divide-slate-200">
            <thead>
              <tr class="bg-slate-50/80">
                <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">
                  {gettext("Nombre")}
                </th>
                <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider hidden sm:table-cell">
                  {gettext("Topics")}
                </th>
                <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider hidden md:table-cell">
                  {gettext("Pasos")}
                </th>
                <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">
                  {gettext("Estado")}
                </th>
                <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-right text-xs font-semibold text-slate-600 uppercase tracking-wider">
                  {gettext("Acciones")}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
              <%= for p <- @pipelines do %>
                <tr class="hover:bg-slate-50/50 transition">
                  <td class="px-3 sm:px-5 py-3 sm:py-4">
                    <div class="font-medium text-slate-800 text-sm">{p.name}</div>
                    <%= if p.description do %>
                      <div class="text-xs text-slate-500 mt-0.5 truncate max-w-[200px]">
                        {p.description}
                      </div>
                    <% end %>
                  </td>
                  <td class="px-3 sm:px-5 py-3 sm:py-4 hidden sm:table-cell">
                    <div class="flex flex-wrap gap-1">
                      <%= for topic <- Enum.take(p.topics || [], 3) do %>
                        <span class="inline-flex px-2 py-0.5 rounded-md text-xs bg-blue-50 text-blue-700 font-mono">
                          {topic}
                        </span>
                      <% end %>
                      <%= if length(p.topics || []) > 3 do %>
                        <span class="text-xs text-slate-400">
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
                        do: "bg-emerald-100 text-emerald-800",
                        else: "bg-slate-200 text-slate-600"
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
                          class="text-indigo-600 hover:text-indigo-700 font-medium text-xs sm:text-sm disabled:opacity-70"
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

    <%!-- Pipeline Modal --%>
    <%= if @pipeline_modal do %>
      <div class="fixed inset-0 z-50 overflow-y-auto" aria-modal="true">
        <div class="flex min-h-full items-center justify-center p-4">
          <div class="fixed inset-0 bg-slate-900/50 backdrop-blur-sm" phx-click="close_pipeline_modal">
          </div>
          <div class="relative bg-white rounded-2xl shadow-xl max-w-lg w-full p-6 sm:p-8">
            <h3 class="text-lg font-semibold text-slate-900 mb-4">
              <%= if @pipeline_modal == :new do %>
                {gettext("Nuevo pipeline")}
              <% else %>
                {gettext("Editar pipeline")}
              <% end %>
            </h3>
            <form phx-submit="save_pipeline" class="space-y-4">
              <%= if @pipeline_modal not in [:new] do %>
                <input type="hidden" name="pipeline_id" value={@pipeline_modal} />
              <% end %>
              <div>
                <label class="block text-sm font-medium text-slate-700 mb-1">
                  {gettext("Nombre")}
                </label>
                <input
                  type="text"
                  name="name"
                  value={@pipeline_form["name"]}
                  required
                  class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-slate-700 mb-1">
                  {gettext("Descripción")}
                </label>
                <input
                  type="text"
                  name="description"
                  value={@pipeline_form["description"]}
                  class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-slate-700 mb-1">
                  {gettext("Topics")}
                  <span class="text-xs text-slate-400 font-normal">
                    ({gettext("separados por coma")})
                  </span>
                </label>
                <input
                  type="text"
                  name="topics"
                  value={@pipeline_form["topics"]}
                  placeholder="order.created, payment.*"
                  class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm font-mono focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-slate-700 mb-1">
                  {gettext("Pasos")}
                  <span class="text-xs text-slate-400 font-normal">(JSON)</span>
                </label>
                <textarea
                  name="steps"
                  rows="5"
                  class="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm font-mono focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                >{@pipeline_form["steps"]}</textarea>
                <p class="text-xs text-slate-400 mt-1">
                  {gettext(
                    "Ej: [{\"type\": \"filter\", \"field\": \"status\", \"operator\": \"eq\", \"value\": \"paid\"}]"
                  )}
                </p>
              </div>
              <div class="flex justify-end gap-3 pt-2">
                <button
                  type="button"
                  phx-click="close_pipeline_modal"
                  class="px-4 py-2 text-sm text-slate-600 hover:text-slate-800"
                >
                  {gettext("Cancelar")}
                </button>
                <button
                  type="submit"
                  phx-disable-with={gettext("Guardando...")}
                  class="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-sm font-medium transition disabled:opacity-70"
                >
                  {gettext("Guardar")}
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
        class={"cursor-pointer rounded-lg border p-3 text-center transition hover:shadow-md #{if @oban_filter_state == state, do: "ring-2 ring-indigo-500 border-indigo-300", else: "border-slate-200"}"}
      >
        <p class={"text-2xl font-bold text-#{color}-600"}>
          {Map.get(@oban_state_counts, state, 0)}
        </p>
        <p class="text-xs text-slate-500 capitalize">{state}</p>
      </div>
    </div>

    <%!-- Queue breakdown --%>
    <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 mb-6">
      <h2 class="text-base lg:text-lg font-semibold text-slate-900 mb-4">
        {gettext("Colas")}
      </h2>
      <div :if={@oban_queue_stats == []} class="text-slate-400 text-sm py-4">
        {gettext("No hay colas activas.")}
      </div>
      <div :if={@oban_queue_stats != []} class="overflow-x-auto">
        <table class="min-w-full text-sm">
          <thead>
            <tr class="border-b border-slate-200">
              <th class="text-left py-2 px-3 font-medium text-slate-600">{gettext("Cola")}</th>
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
              class="border-b border-slate-100 hover:bg-slate-50 cursor-pointer"
              phx-click="oban_filter_queue"
              phx-value-queue={qs.queue}
            >
              <td class={"py-2 px-3 font-medium #{if @oban_filter_queue == qs.queue, do: "text-indigo-700", else: "text-slate-900"}"}>
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
    <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900">
          {gettext("Jobs recientes")}
          <span :if={@oban_filter_state} class="ml-2 text-sm font-normal text-indigo-600">
            ({@oban_filter_state})
          </span>
          <span :if={@oban_filter_queue} class="ml-2 text-sm font-normal text-indigo-600">
            [{@oban_filter_queue}]
          </span>
        </h2>
        <div class="flex gap-2">
          <button
            :if={@oban_filter_state || @oban_filter_queue}
            phx-click="oban_clear_filters"
            class="text-xs px-3 py-1.5 rounded-lg border border-slate-300 text-slate-600 hover:bg-slate-100 transition"
          >
            {gettext("Limpiar filtros")}
          </button>
          <button
            phx-click="oban_refresh"
            class="text-xs px-3 py-1.5 rounded-lg bg-indigo-50 text-indigo-700 hover:bg-indigo-100 transition"
          >
            {gettext("Actualizar")}
          </button>
          <button
            phx-click="oban_purge"
            data-confirm={
              gettext("¿Eliminar jobs completados/descartados/cancelados de más de 7 días?")
            }
            class="text-xs px-3 py-1.5 rounded-lg bg-red-50 text-red-700 hover:bg-red-100 transition"
          >
            {gettext("Purgar antiguos")}
          </button>
        </div>
      </div>

      <div :if={@oban_jobs == []} class="text-slate-400 text-sm py-8 text-center">
        {gettext("No hay jobs que mostrar.")}
      </div>

      <div :if={@oban_jobs != []} class="overflow-x-auto">
        <table class="min-w-full text-sm">
          <thead>
            <tr class="border-b border-slate-200">
              <th class="text-left py-2 px-3 font-medium text-slate-600">ID</th>
              <th class="text-left py-2 px-3 font-medium text-slate-600">{gettext("Estado")}</th>
              <th class="text-left py-2 px-3 font-medium text-slate-600">{gettext("Cola")}</th>
              <th class="text-left py-2 px-3 font-medium text-slate-600">Worker</th>
              <th class="text-center py-2 px-3 font-medium text-slate-600">{gettext("Intentos")}</th>
              <th class="text-left py-2 px-3 font-medium text-slate-600">{gettext("Creado")}</th>
              <th class="text-right py-2 px-3 font-medium text-slate-600">{gettext("Acciones")}</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={job <- @oban_jobs} class="border-b border-slate-100 hover:bg-slate-50">
              <td class="py-2 px-3 font-mono text-xs text-slate-500">{job.id}</td>
              <td class="py-2 px-3">
                <span class={"inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium #{oban_state_badge(job.state)}"}>
                  {job.state}
                </span>
              </td>
              <td class="py-2 px-3 text-slate-700">{job.queue}</td>
              <td class="py-2 px-3 text-slate-700 font-mono text-xs">
                {job.worker |> String.split(".") |> List.last()}
              </td>
              <td class="text-center py-2 px-3 text-slate-600">
                {job.attempt}/{job.max_attempts}
              </td>
              <td class="py-2 px-3 text-slate-500 text-xs whitespace-nowrap">
                {Calendar.strftime(job.inserted_at, "%Y-%m-%d %H:%M:%S")}
              </td>
              <td class="py-2 px-3 text-right space-x-1">
                <button
                  :if={job.state in ["retryable", "discarded"]}
                  phx-click="oban_retry_job"
                  phx-value-id={job.id}
                  class="text-xs text-indigo-600 hover:text-indigo-800"
                  title={gettext("Reintentar")}
                >
                  {gettext("Reintentar")}
                </button>
                <button
                  :if={job.state in ["available", "scheduled", "retryable"]}
                  phx-click="oban_cancel_job"
                  phx-value-id={job.id}
                  data-confirm={gettext("¿Cancelar este job?")}
                  class="text-xs text-red-600 hover:text-red-800"
                  title={gettext("Cancelar")}
                >
                  {gettext("Cancelar")}
                </button>
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
      <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900 mb-2">{gettext("Proyecto")}</h2>
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
              class="w-full max-w-xs px-3 py-2 bg-white border border-slate-300 rounded-lg text-slate-900"
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
              class="px-3 py-2 bg-slate-200 hover:bg-slate-300 text-slate-800 rounded-lg text-sm font-medium"
            >
              {gettext("Cancelar")}
            </button>
          </.form>
        <% else %>
          <p class="text-slate-600">
            <strong>{@project.name}</strong>
            <%= if can_admin_team?(@current_user_role) do %>
              <button
                type="button"
                phx-click="edit_project_name"
                class="ml-2 text-indigo-600 hover:text-indigo-700 text-sm font-medium"
              >
                {gettext("Editar nombre")}
              </button>
            <% end %>
          </p>
        <% end %>
        <p class="text-slate-500 text-sm font-mono mt-1 break-all">{@project.id}</p>
        <%!-- Delete project --%>
        <%= if @project.user_id == @current_user.id do %>
          <div class="mt-4 pt-4 border-t border-slate-200">
            <button
              phx-click="delete_project"
              phx-value-id={@project.id}
              phx-disable-with={gettext("Eliminando...")}
              data-confirm={gettext("¿Eliminar este proyecto? Esta acción no se puede deshacer.")}
              class="text-red-600 hover:text-red-700 text-xs font-medium disabled:opacity-50"
            >
              {gettext("Eliminar proyecto")}
            </button>
          </div>
        <% end %>
      </section>

      <%!-- Analytics (always visible) --%>
      <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <div class="flex items-center gap-2 mb-4">
          <.icon name="hero-chart-bar" class="w-5 h-5 text-indigo-600" />
          <h2 class="text-base lg:text-lg font-semibold text-slate-900">{gettext("Analíticas")}</h2>
        </div>
        <%= if @analytics != %{} do %>
          <div class="grid grid-cols-1 gap-4">
            <div class="border border-slate-200 rounded-lg p-3">
              <h3 class="text-sm font-semibold text-slate-700 mb-3">
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
            <div class="border border-slate-200 rounded-lg p-3">
              <h3 class="text-sm font-semibold text-slate-700 mb-3">
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
          <p class="text-sm text-slate-400 text-center py-8">{gettext("Sin datos")}</p>
        <% end %>
      </section>
    </div>

    <%!-- Row 2: Sandbox + Team (2 cols) --%>
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6 lg:gap-8">
      <%!-- Sandbox --%>
      <section class="bg-white rounded-xl border border-purple-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <div class="flex flex-wrap items-center justify-between gap-3 mb-4">
          <div class="flex items-center gap-2">
            <.icon name="hero-beaker" class="w-5 h-5 text-purple-600" />
            <h2 class="text-base lg:text-lg font-semibold text-slate-900">{gettext("Sandbox")}</h2>
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
          <p class="text-sm text-slate-500">
            {gettext("Crea un endpoint temporal para recibir y ver requests en tiempo real.")}
          </p>
        <% else %>
          <div class="flex flex-wrap gap-2 mb-4">
            <%= for ep <- @sandbox_endpoints do %>
              <div
                class={"inline-flex items-center gap-1 px-3 py-1.5 rounded-lg border text-sm cursor-pointer transition #{if @sandbox_active && @sandbox_active.id == ep.id, do: "bg-purple-50 border-purple-300 text-purple-800", else: "bg-white border-slate-200 text-slate-600 hover:bg-slate-50"}"}
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
          <div class="rounded-lg border border-purple-100 bg-purple-50/50 p-3 mb-4">
            <p class="text-sm text-purple-800 mb-1">{gettext("URL del endpoint:")}</p>
            <code class="text-xs font-mono text-purple-900 break-all">
              {sandbox_url(@sandbox_active)}
            </code>
          </div>
          <%= if @sandbox_requests == [] do %>
            <p class="text-sm text-slate-500 text-center py-4">
              {gettext("Esperando requests... Envía un POST/GET a la URL de arriba.")}
            </p>
          <% else %>
            <div class="overflow-x-auto rounded-lg border border-slate-200">
              <table class="min-w-full divide-y divide-slate-200">
                <thead>
                  <tr class="bg-slate-50/80">
                    <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                      {gettext("Método")}
                    </th>
                    <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase hidden sm:table-cell">
                      {gettext("Body")}
                    </th>
                    <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                      {gettext("Fecha")}
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-100">
                  <%= for req <- @sandbox_requests do %>
                    <tr class="hover:bg-slate-50/50 transition">
                      <td class="px-3 py-2">
                        <span class={"inline-flex px-2 py-0.5 rounded text-xs font-medium #{method_color(req.method)}"}>
                          {req.method}
                        </span>
                      </td>
                      <td class="px-3 py-2 text-xs text-slate-600 font-mono truncate max-w-[16rem] hidden sm:table-cell">
                        {if req.body && req.body != "", do: String.slice(req.body, 0, 80), else: "—"}
                      </td>
                      <td class="px-3 py-2 text-xs text-slate-600">{format_dt(req.inserted_at)}</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        <% end %>
      </section>

      <%!-- Team --%>
      <section class="bg-white rounded-xl border border-cyan-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <div class="flex items-center justify-between mb-4">
          <div class="flex items-center gap-2">
            <.icon name="hero-user-group" class="w-5 h-5 text-cyan-600" />
            <h2 class="text-base lg:text-lg font-semibold text-slate-900">{gettext("Equipo")}</h2>
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
              class="flex-1 min-w-0 border border-slate-300 rounded-lg px-3 py-2 text-sm"
            />
            <select name="role" class="border border-slate-300 rounded-lg px-3 py-2 text-sm bg-white">
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
          <p class="text-sm text-slate-500">
            {gettext("Solo tú tienes acceso. Invita colaboradores.")}
          </p>
        <% else %>
          <div class="overflow-x-auto rounded-lg border border-slate-200">
            <table class="min-w-full divide-y divide-slate-200">
              <thead>
                <tr class="bg-slate-50/80">
                  <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                    {gettext("Usuario")}
                  </th>
                  <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                    {gettext("Rol")}
                  </th>
                  <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                    {gettext("Estado")}
                  </th>
                  <%= if can_admin_team?(@current_user_role) do %>
                    <th class="px-3 py-2 text-right text-xs font-semibold text-slate-600 uppercase">
                      {gettext("Acciones")}
                    </th>
                  <% end %>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <%= for m <- @team_members do %>
                  <tr class="hover:bg-slate-50/50 transition">
                    <td class="px-3 py-2 text-sm text-slate-700 font-mono truncate max-w-[6rem] sm:max-w-[10rem] lg:max-w-none">
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
                              phx-click="remove_member"
                              phx-value-id={m.id}
                              phx-disable-with={gettext("Removiendo...")}
                              data-confirm={gettext("¿Remover este miembro?")}
                              class="text-red-600 hover:text-red-700 text-xs font-medium disabled:opacity-50"
                            >
                              {gettext("Remover")}
                            </button>
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
        <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6">
          <h3 class="text-sm font-semibold text-slate-700 mb-3">{gettext("Top topics")}</h3>
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
        <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6">
          <h3 class="text-sm font-semibold text-slate-700 mb-3">
            {gettext("Entregas por webhook (7d)")}
          </h3>
          <%= if @analytics.webhook_stats == [] do %>
            <p class="text-sm text-slate-400 text-center py-8">{gettext("Sin datos")}</p>
          <% else %>
            <div class="space-y-2 max-h-56 overflow-y-auto">
              <%= for ws <- @analytics.webhook_stats do %>
                <div class="flex items-center gap-2 text-sm">
                  <span class="font-mono text-xs text-slate-600 truncate flex-1 min-w-0">
                    {ws.webhook_url}
                  </span>
                  <span class="text-emerald-700 font-medium text-xs shrink-0">{ws.success}</span>
                  <span class="text-slate-300 shrink-0">/</span>
                  <span class="text-red-600 font-medium text-xs shrink-0">{ws.failed}</span>
                </div>
              <% end %>
            </div>
          <% end %>
        </section>
      </div>
    <% end %>

    <%!-- Row 4: Audit Log (full width) --%>
    <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
      <div class="flex items-center gap-2 mb-4">
        <.icon name="hero-clipboard-document-list" class="w-5 h-5 text-slate-600" />
        <h2 class="text-base lg:text-lg font-semibold text-slate-900">
          {gettext("Registro de actividad")}
        </h2>
      </div>
      <%= if @audit_logs == [] do %>
        <p class="text-sm text-slate-500">{gettext("Sin actividad registrada.")}</p>
      <% else %>
        <div class="space-y-2 max-h-48 sm:max-h-80 overflow-y-auto">
          <%= for log <- @audit_logs do %>
            <div class="flex items-start gap-3 py-2 border-b border-slate-100 last:border-0">
              <div class="mt-0.5 shrink-0">
                <.icon name={Audit.action_icon(log.action)} class="w-4 h-4 text-slate-400" />
              </div>
              <div class="min-w-0 flex-1">
                <p class="text-sm text-slate-800">{audit_action_label(log.action)}</p>
                <p class="text-[11px] text-slate-400">{format_dt(log.inserted_at)}</p>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </section>
    """
  end
end
