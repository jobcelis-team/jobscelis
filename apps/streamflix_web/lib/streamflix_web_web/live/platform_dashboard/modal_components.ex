defmodule StreamflixWebWeb.PlatformDashboard.ModalComponents do
  @moduledoc """
  Modal and token section render components for the Platform Dashboard.
  """
  use Phoenix.Component

  import StreamflixWebWeb.CoreComponents
  import StreamflixWebWeb.PlatformDashboard.Helpers

  use Gettext, backend: StreamflixWebWeb.Gettext

  def render_modals(assigns) do
    ~H"""
    <%!-- Event Detail Modal (#21 + #22) --%>
    <%= if @event_detail do %>
      <div class="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6">
        <div
          class="absolute inset-0 bg-black/50 backdrop-blur-sm"
          phx-click="close_event_detail"
          aria-hidden="true"
        >
        </div>
        <div
          class="relative z-10 bg-white rounded-2xl shadow-2xl w-full max-w-2xl mx-auto max-h-[90vh] overflow-y-auto"
          role="dialog"
          aria-modal="true"
        >
          <div class="px-6 pt-6 pb-4 flex items-start justify-between border-b border-slate-200">
            <div>
              <h2 class="text-lg font-semibold text-slate-900">
                {gettext("Detalle del evento")}
              </h2>
              <p class="text-xs text-slate-500 font-mono mt-1">{@event_detail.id}</p>
            </div>
            <button
              type="button"
              phx-click="close_event_detail"
              class="rounded-lg p-1.5 text-slate-400 hover:text-slate-600 hover:bg-slate-100 transition"
            >
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>
          <div class="px-6 py-4 space-y-4">
            <%!-- Event info --%>
            <div class="grid grid-cols-2 gap-3 text-sm">
              <div>
                <span class="text-slate-500">{gettext("Topic")}</span>
                <p class="font-medium text-slate-900">{@event_detail.topic || "—"}</p>
              </div>
              <div>
                <span class="text-slate-500">{gettext("Estado")}</span>
                <p>
                  <span class="px-2 py-0.5 rounded text-xs font-medium bg-slate-100 text-slate-700">
                    {@event_detail.status}
                  </span>
                </p>
              </div>
              <div>
                <span class="text-slate-500">{gettext("Fecha")}</span>
                <p class="font-medium text-slate-900">{format_dt(@event_detail.occurred_at)}</p>
              </div>
              <div>
                <span class="text-slate-500">{gettext("Hash")}</span>
                <p class="font-mono text-xs text-slate-600 truncate">
                  {@event_detail.payload_hash || "—"}
                </p>
              </div>
            </div>
            <%!-- Payload --%>
            <div>
              <span class="text-sm text-slate-500">{gettext("Payload")}</span>
              <pre class="mt-1 p-3 bg-slate-50 border border-slate-200 rounded-lg text-xs font-mono text-slate-700 overflow-x-auto max-h-40">{Jason.encode!(@event_detail.payload || %{}, pretty: true)}</pre>
            </div>
            <%!-- Delivery Timeline (#22) --%>
            <div>
              <h3 class="text-sm font-semibold text-slate-900 mb-3">
                <.icon name="hero-arrow-path" class="w-4 h-4 inline mr-1" />
                {gettext("Timeline de entregas")}
                <span class="ml-1 text-xs font-normal text-slate-500">
                  ({length(@event_deliveries)})
                </span>
              </h3>
              <%= if @event_deliveries == [] do %>
                <p class="text-sm text-slate-400">{gettext("Sin entregas para este evento.")}</p>
              <% else %>
                <div class="relative pl-6 space-y-3">
                  <div class="absolute left-2.5 top-2 bottom-2 w-0.5 bg-slate-200"></div>
                  <%= for d <- @event_deliveries do %>
                    <div class="relative">
                      <div class={"absolute -left-[14px] top-1.5 w-3 h-3 rounded-full border-2 border-white #{delivery_dot_color(d.status)}"}>
                      </div>
                      <div class="bg-slate-50 border border-slate-200 rounded-lg p-3">
                        <div class="flex items-center justify-between">
                          <div class="flex items-center gap-2">
                            <span class={[
                              "px-2 py-0.5 rounded text-xs font-medium",
                              delivery_status_class(d.status)
                            ]}>
                              {d.status}
                            </span>
                            <span class="text-xs text-slate-500">
                              {gettext("Intento")} #{d.attempt_number}
                            </span>
                            <%= if d.response_latency_ms do %>
                              <span class="text-xs text-slate-400">
                                {d.response_latency_ms}ms
                              </span>
                            <% end %>
                          </div>
                          <span class="text-xs text-slate-400">{format_dt(d.inserted_at)}</span>
                        </div>
                        <%= if d.webhook do %>
                          <p class="text-xs font-mono text-slate-500 mt-1 truncate">
                            {d.webhook.url}
                          </p>
                        <% end %>
                        <%= if d.response_status do %>
                          <p class="text-xs text-slate-500 mt-1">
                            HTTP {d.response_status}
                            <%= if d.response_body && d.response_body != "" do %>
                              —
                              <span class="text-red-600 truncate">
                                {String.slice(d.response_body || "", 0, 100)}
                              </span>
                            <% end %>
                          </p>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    <% end %>

    <%!-- Replay Modal --%>
    <%= if @replay_modal do %>
      <div class="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6">
        <div
          class="absolute inset-0 bg-slate-900/60 backdrop-blur-sm"
          phx-click="close_replay_modal"
          aria-hidden="true"
        >
        </div>
        <div class="relative z-10 w-full max-w-lg bg-white rounded-2xl shadow-2xl p-4 sm:p-6 border border-slate-200/50">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-lg font-semibold text-slate-900">{gettext("Nuevo replay")}</h2>
            <button
              type="button"
              phx-click="close_replay_modal"
              class="p-2 -m-2 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-100 transition"
            >
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>
          <.form for={%{}} id="replay-form" phx-submit="start_replay" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1">
                {gettext("Topic (opcional)")}
              </label>
              <input
                type="text"
                name="topic"
                class="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm"
                placeholder={gettext("Filtrar por topic")}
              />
            </div>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label class="block text-sm font-medium text-slate-700 mb-1">
                  {gettext("Desde")}
                </label>
                <input
                  type="datetime-local"
                  name="from_date"
                  class="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-slate-700 mb-1">
                  {gettext("Hasta")}
                </label>
                <input
                  type="datetime-local"
                  name="to_date"
                  class="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm"
                />
              </div>
            </div>
            <div class="flex justify-end gap-3 pt-2">
              <button
                type="button"
                phx-click="close_replay_modal"
                class="px-4 py-2 border border-slate-300 rounded-lg text-slate-700 hover:bg-slate-50 text-sm font-medium"
              >
                {gettext("Cancelar")}
              </button>
              <button
                type="submit"
                phx-disable-with={gettext("Iniciando...")}
                class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg text-sm font-medium"
              >
                {gettext("Iniciar replay")}
              </button>
            </div>
          </.form>
        </div>
      </div>
    <% end %>

    <%!-- Job form modal --%>
    <%= if @job_modal do %>
      <div
        class="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6"
        id="job-modal-container"
      >
        <div
          class="absolute inset-0 bg-slate-900/60 backdrop-blur-sm transition-opacity"
          phx-click="close_job_modal"
          id="job-modal-backdrop"
          aria-hidden="true"
        >
        </div>
        <div
          class="relative z-10 w-full max-w-3xl max-h-[90vh] overflow-hidden bg-white rounded-2xl shadow-2xl flex flex-col border border-slate-200/50"
          id="job-modal-content"
          role="dialog"
          aria-modal="true"
          aria-labelledby="job-modal-title"
        >
          <div class="flex-shrink-0 px-4 sm:px-6 py-4 sm:py-5 border-b border-slate-200 bg-slate-50/80 flex justify-between items-center">
            <h2 id="job-modal-title" class="text-lg sm:text-xl font-semibold text-slate-900">
              {if @job_modal == :new, do: gettext("Nuevo job"), else: gettext("Editar job")}
            </h2>
            <button
              type="button"
              phx-click="close_job_modal"
              class="p-2 -m-2 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-200/60 transition"
              aria-label={gettext("Cerrar")}
            >
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>
          <.form for={@job_form} id="job-form" phx-submit="save_job" class="flex-1 overflow-y-auto">
            <%= if @job_modal != :new do %>
              <input type="hidden" name="job_id" value={elem(@job_modal, 1)} />
            <% end %>
            <% p = @job_form.params || %{} %>
            <div class="p-4 sm:p-6 space-y-5 sm:space-y-6">
              <div>
                <label class="block text-sm font-medium text-slate-700 mb-1.5">
                  {gettext("Nombre")}
                </label>
                <input
                  type="text"
                  name="name"
                  value={p["name"]}
                  required
                  class="w-full border border-slate-300 rounded-xl px-3 sm:px-4 py-2 sm:py-2.5 text-slate-900 placeholder-slate-400 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition text-sm sm:text-base"
                  placeholder={gettext("Ej: Reporte diario")}
                />
              </div>
              <div class="border-t border-slate-200 pt-6">
                <h3 class="text-sm font-semibold text-slate-800 mb-4">{gettext("Programación")}</h3>
                <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-slate-600 mb-1.5">
                      {gettext("Tipo")}
                    </label>
                    <select
                      name="schedule_type"
                      class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 bg-white focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                    >
                      <option value="daily" selected={p["schedule_type"] == "daily"}>
                        {gettext("Diario")}
                      </option>
                      <option value="weekly" selected={p["schedule_type"] == "weekly"}>
                        {gettext("Semanal")}
                      </option>
                      <option value="monthly" selected={p["schedule_type"] == "monthly"}>
                        {gettext("Mensual")}
                      </option>
                      <option value="cron" selected={p["schedule_type"] == "cron"}>
                        {gettext("Cron")}
                      </option>
                    </select>
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-slate-600 mb-1.5">
                      {gettext("Hora (0-23)")}
                    </label>
                    <input
                      type="number"
                      name="schedule_hour"
                      value={p["schedule_hour"]}
                      min="0"
                      max="23"
                      class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-slate-600 mb-1.5">
                      {gettext("Minuto")}
                    </label>
                    <input
                      type="number"
                      name="schedule_minute"
                      value={p["schedule_minute"]}
                      min="0"
                      max="59"
                      class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-slate-600 mb-1.5">
                      {gettext("Día semana (1-7, 1=Lun)")}
                    </label>
                    <input
                      type="number"
                      name="schedule_day_of_week"
                      value={p["schedule_day_of_week"]}
                      min="1"
                      max="7"
                      class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-slate-600 mb-1.5">
                      {gettext("Día del mes (1-31)")}
                    </label>
                    <input
                      type="number"
                      name="schedule_day_of_month"
                      value={p["schedule_day_of_month"]}
                      min="1"
                      max="31"
                      class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-slate-600 mb-1.5">
                      {gettext("Expresión cron")}
                    </label>
                    <div class="flex gap-2">
                      <input
                        type="text"
                        name="schedule_cron"
                        id="cron-expr-input"
                        value={p["schedule_cron"]}
                        placeholder="0 0 * * *"
                        class="flex-1 border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 font-mono text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                      />
                      <button
                        type="button"
                        phx-click="preview_cron"
                        phx-value-expression={p["schedule_cron"]}
                        class="px-3 py-2 text-xs font-medium text-indigo-600 bg-indigo-50 hover:bg-indigo-100 rounded-xl transition shrink-0"
                      >
                        {gettext("Preview")}
                      </button>
                    </div>
                    <%= if @cron_preview != [] do %>
                      <div class="mt-2 p-3 bg-slate-50 rounded-lg border border-slate-200">
                        <p class="text-xs font-medium text-slate-500 mb-1">
                          {gettext("Próximas ejecuciones")}:
                        </p>
                        <ul class="space-y-0.5">
                          <%= for dt <- @cron_preview do %>
                            <li class="text-xs font-mono text-slate-600">{dt}</li>
                          <% end %>
                        </ul>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
              <div class="border-t border-slate-200 pt-6">
                <h3 class="text-sm font-semibold text-slate-800 mb-4">{gettext("Acción")}</h3>
                <div class="space-y-4">
                  <div>
                    <label class="block text-sm font-medium text-slate-600 mb-1.5">
                      {gettext("Tipo de acción")}
                    </label>
                    <select
                      name="action_type"
                      class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 bg-white focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                    >
                      <option value="emit_event" selected={p["action_type"] == "emit_event"}>
                        {gettext("Emitir evento")}
                      </option>
                      <option value="post_url" selected={p["action_type"] == "post_url"}>
                        {gettext("POST URL")}
                      </option>
                    </select>
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-slate-600 mb-1.5">
                      {gettext("Topic (emit_event)")}
                    </label>
                    <input
                      type="text"
                      name="action_topic"
                      value={p["action_topic"]}
                      class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 placeholder-slate-400 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                      placeholder={gettext("mi.topic")}
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-slate-600 mb-1.5">
                      {gettext("Payload JSON (emit_event)")}
                    </label>
                    <textarea
                      name="action_payload"
                      rows="4"
                      class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 font-mono text-sm placeholder-slate-400 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                    >{p["action_payload"]}</textarea>
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-slate-600 mb-1.5">
                      {gettext("URL (post_url)")}
                    </label>
                    <input
                      type="url"
                      name="action_url"
                      value={p["action_url"]}
                      class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 placeholder-slate-400 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                      placeholder="https://..."
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-slate-600 mb-1.5">
                      {gettext("Método HTTP")}
                    </label>
                    <select
                      name="action_method"
                      class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 bg-white focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                    >
                      <option value="POST" selected={p["action_method"] == "POST"}>POST</option>
                      <option value="GET">GET</option>
                      <option value="PUT">PUT</option>
                      <option value="PATCH">PATCH</option>
                    </select>
                  </div>
                  <%= if @job_modal != :new do %>
                    <div>
                      <label class="block text-sm font-medium text-slate-600 mb-1.5">
                        {gettext("Estado")}
                      </label>
                      <select
                        name="status"
                        class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 bg-white focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                      >
                        <option value="active" selected={p["status"] == "active"}>
                          {gettext("Activo")}
                        </option>
                        <option value="inactive" selected={p["status"] == "inactive"}>
                          {gettext("Inactivo")}
                        </option>
                      </select>
                    </div>
                  <% end %>
                </div>
              </div>
              <div class="flex flex-wrap justify-end gap-3 pt-4 border-t border-slate-200">
                <button
                  type="button"
                  phx-click="close_job_modal"
                  class="px-5 py-2.5 border border-slate-300 rounded-xl text-slate-700 hover:bg-slate-50 font-medium transition"
                >
                  {gettext("Cancelar")}
                </button>
                <button
                  type="submit"
                  phx-disable-with={gettext("Guardando...")}
                  class="px-5 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl font-medium shadow-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
                >
                  {gettext("Guardar")}
                </button>
              </div>
            </div>
          </.form>
        </div>
      </div>
    <% end %>

    <%!-- Job runs modal --%>
    <%= if @job_runs_modal do %>
      <div
        class="fixed inset-0 z-50 flex items-center justify-center p-4"
        id="job-runs-modal-container"
      >
        <div
          class="absolute inset-0 bg-slate-900/60 backdrop-blur-sm"
          phx-click="close_job_runs_modal"
          aria-hidden="true"
        >
        </div>
        <div
          class="relative z-10 w-full max-w-2xl max-h-[80vh] overflow-hidden bg-white rounded-2xl shadow-2xl flex flex-col border border-slate-200/50 mx-4"
          role="dialog"
          aria-modal="true"
        >
          <div class="p-4 border-b flex justify-between items-center">
            <h2 class="text-lg font-semibold text-slate-900">
              {gettext("Runs: %{name}", name: @job_runs_modal.job.name)}
            </h2>
            <button
              type="button"
              phx-click="close_job_runs_modal"
              class="p-2 -m-2 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-100 transition"
            >
              <.icon name="hero-x-mark" class="w-6 h-6" />
            </button>
          </div>
          <div class="overflow-y-auto flex-1 p-4">
            <table class="min-w-full">
              <thead>
                <tr class="bg-slate-50 border-b">
                  <th class="px-4 py-2 text-left text-sm font-medium text-slate-700">
                    {gettext("Ejecutado")}
                  </th>
                  <th class="px-4 py-2 text-left text-sm font-medium text-slate-700">
                    {gettext("Estado")}
                  </th>
                  <th class="px-4 py-2 text-left text-sm font-medium text-slate-700">
                    {gettext("Resultado")}
                  </th>
                </tr>
              </thead>
              <tbody>
                <%= for r <- @job_runs_modal.runs do %>
                  <tr class="border-b border-slate-100">
                    <td class="px-4 py-2 text-sm text-slate-600">{format_dt(r.executed_at)}</td>
                    <td class="px-4 py-2">
                      <span class={[
                        "px-2 py-0.5 rounded text-xs",
                        if(r.status == "success",
                          do: "bg-green-100 text-green-800",
                          else: "bg-red-100 text-red-800"
                        )
                      ]}>
                        {r.status}
                      </span>
                    </td>
                    <td class="px-4 py-2 text-sm text-slate-600">
                      {if r.result, do: Jason.encode!(r.result), else: "—"}
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
            <%= if @job_runs_modal.runs == [] do %>
              <p class="text-slate-500 py-4">{gettext("Sin ejecuciones aún.")}</p>
            <% end %>
          </div>
        </div>
      </div>
    <% end %>

    <%!-- Confirm regenerate token modal --%>
    <%= if @confirm_regenerate_token do %>
      <div class="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6">
        <div
          class="absolute inset-0 bg-slate-900/60 backdrop-blur-sm"
          phx-click="cancel_confirm_regenerate"
          aria-hidden="true"
        >
        </div>
        <div
          class="relative z-10 w-full max-w-md bg-white rounded-2xl shadow-2xl p-5 sm:p-6 border border-slate-200/50"
          role="dialog"
          aria-modal="true"
          aria-labelledby="confirm-regenerate-title"
        >
          <div class="flex items-start gap-4">
            <div class="flex-shrink-0 w-10 h-10 rounded-full bg-amber-100 flex items-center justify-center">
              <.icon name="hero-exclamation-triangle" class="w-5 h-5 text-amber-600" />
            </div>
            <div class="flex-1">
              <h3 id="confirm-regenerate-title" class="text-lg font-semibold text-slate-900">
                {gettext("¿Regenerar token?")}
              </h3>
              <p class="mt-2 text-sm text-slate-600">
                {gettext(
                  "El token actual dejará de funcionar inmediatamente. Asegúrate de actualizar tus integraciones con el nuevo token."
                )}
              </p>
            </div>
          </div>
          <div class="mt-6 flex justify-end gap-3">
            <button
              type="button"
              phx-click="cancel_confirm_regenerate"
              class="px-4 py-2 border border-slate-300 rounded-lg text-slate-700 hover:bg-slate-50 text-sm font-medium transition"
            >
              {gettext("Cancelar")}
            </button>
            <button
              type="button"
              phx-click="regenerate_token"
              phx-disable-with={gettext("Regenerando...")}
              class="px-4 py-2 bg-amber-600 hover:bg-amber-700 text-white rounded-lg text-sm font-medium transition disabled:opacity-70 disabled:cursor-not-allowed"
            >
              {gettext("Sí, regenerar")}
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ===== TOKEN SECTION (deduplicated) =====
  def render_token_section(assigns) do
    assigns =
      if assigns[:new_token] do
        if assigns[:token_source] == :registration do
          assigns
          |> Map.put(
            :token_wrapper_class,
            "rounded-lg border-2 border-emerald-300 bg-emerald-50 p-3 sm:p-4"
          )
          |> Map.put(:token_icon, "hero-check-circle")
          |> Map.put(:token_icon_class, "w-5 h-5 text-emerald-600")
          |> Map.put(:token_msg_class, "text-emerald-800 font-medium text-sm")
          |> Map.put(
            :token_msg,
            gettext("Tu API token ha sido creado. Cópialo y guárdalo ahora.")
          )
          |> Map.put(:token_input_border, "border-emerald-200")
        else
          assigns
          |> Map.put(
            :token_wrapper_class,
            "rounded-lg border-2 border-amber-300 bg-amber-50 p-3 sm:p-4"
          )
          |> Map.put(:token_icon, "hero-exclamation-triangle")
          |> Map.put(:token_icon_class, "w-5 h-5 text-amber-600")
          |> Map.put(:token_msg_class, "text-amber-800 font-medium text-sm")
          |> Map.put(
            :token_msg,
            gettext("El token anterior ha sido revocado. Copia y guarda el nuevo.")
          )
          |> Map.put(:token_input_border, "border-amber-200")
        end
      else
        assigns
      end

    ~H"""
    <%= if @new_token do %>
      <div class={@token_wrapper_class}>
        <div class="flex items-center gap-2 mb-3">
          <.icon name={@token_icon} class={@token_icon_class} />
          <span class={@token_msg_class}>{@token_msg}</span>
        </div>
        <div class={"flex items-stretch gap-0 overflow-hidden rounded-lg border #{@token_input_border} bg-white"}>
          <input
            id="token-input"
            type="text"
            readonly
            value={if @token_visible, do: @new_token, else: String.duplicate("•", 20)}
            data-real-value={@new_token}
            class="flex-1 min-w-0 font-mono text-sm px-4 py-3 bg-transparent border-0 text-slate-900 focus:ring-0"
            phx-no-feedback
          />
          <button
            type="button"
            phx-click="toggle_token_visibility"
            class={"p-3 border-l #{@token_input_border} bg-white hover:bg-slate-50 text-slate-500 hover:text-slate-700 transition"}
            title={if @token_visible, do: gettext("Ocultar"), else: gettext("Mostrar")}
            aria-label={
              if @token_visible, do: gettext("Ocultar token"), else: gettext("Mostrar token")
            }
          >
            <%= if @token_visible do %>
              <.icon name="hero-eye-slash" class="w-5 h-5" />
            <% else %>
              <.icon name="hero-eye" class="w-5 h-5" />
            <% end %>
          </button>
          <button
            type="button"
            id="copy-token-btn"
            phx-hook="CopyClipboard"
            data-copy-target="token-input"
            class={"p-3 border-l #{@token_input_border} bg-white hover:bg-slate-50 text-slate-500 hover:text-emerald-600 transition"}
            title={gettext("Copiar token")}
            aria-label={gettext("Copiar token")}
          >
            <span data-copy-icon><.icon name="hero-clipboard-document" class="w-5 h-5" /></span>
            <span data-check-icon class="hidden">
              <.icon name="hero-check" class="w-5 h-5 text-emerald-600" />
            </span>
          </button>
        </div>
      </div>
      <%= if can_admin_team?(@current_user_role) do %>
        <div class="mt-3 flex items-center gap-3">
          <button
            phx-click="show_confirm_regenerate"
            type="button"
            class="px-4 py-2 bg-slate-200 hover:bg-slate-300 text-slate-800 rounded-lg font-medium text-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
          >
            {gettext("Regenerar token")}
          </button>
        </div>
      <% end %>
    <% else %>
      <%= if @api_key != nil do %>
        <div class="rounded-lg border border-slate-200 bg-slate-50">
          <input
            type="text"
            readonly
            value={"#{@api_key.prefix}••••••••••"}
            class="w-full font-mono text-sm px-4 py-3 bg-transparent border-0 text-slate-600 focus:ring-0"
            aria-label={gettext("Prefijo del token")}
          />
        </div>
        <p class="text-slate-500 text-sm mt-2">
          {gettext("Solo se muestra el prefijo. Regenera para obtener el token completo.")}
        </p>
        <%= if can_admin_team?(@current_user_role) do %>
          <div class="flex flex-col sm:flex-row gap-2 mt-3">
            <button
              phx-click="show_confirm_regenerate"
              type="button"
              class="px-4 py-2 bg-slate-200 hover:bg-slate-300 text-slate-800 rounded-lg font-medium text-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
            >
              {gettext("Regenerar token")}
            </button>
          </div>
        <% end %>
        <div class="mt-4 pt-4 border-t border-slate-200 space-y-2">
          <div class="flex items-center gap-2">
            <span class="text-xs font-medium text-slate-500 uppercase">{gettext("Scopes")}:</span>
            <%= for scope <- (@api_key.scopes || ["*"]) do %>
              <span class="px-2 py-0.5 bg-indigo-50 text-indigo-700 rounded text-xs font-mono">
                {scope}
              </span>
            <% end %>
          </div>
          <div class="flex items-start gap-2">
            <span class="text-xs font-medium text-slate-500 uppercase shrink-0">
              {gettext("IPs permitidas")}:
            </span>
            <%= if @api_key.allowed_ips && @api_key.allowed_ips != [] do %>
              <div class="flex flex-wrap gap-1">
                <%= for ip <- @api_key.allowed_ips do %>
                  <span class="px-2 py-0.5 bg-emerald-50 text-emerald-700 rounded text-xs font-mono">
                    {ip}
                  </span>
                <% end %>
              </div>
            <% else %>
              <span class="text-xs text-slate-400">{gettext("Sin restricción (cualquier IP)")}</span>
            <% end %>
          </div>
        </div>
      <% else %>
        <p class="text-slate-600 mb-3">{gettext("No hay API token. Genera uno para empezar.")}</p>
        <%= if can_admin_team?(@current_user_role) do %>
          <button
            phx-click="regenerate_token"
            phx-disable-with={gettext("Generando...")}
            type="button"
            class="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg font-medium text-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
          >
            {gettext("Generar token")}
          </button>
        <% end %>
      <% end %>
    <% end %>
    """
  end
end
