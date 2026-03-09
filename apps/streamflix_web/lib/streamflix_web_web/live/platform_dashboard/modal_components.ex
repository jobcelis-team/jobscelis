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
          class="relative z-10 bg-white dark:bg-slate-800 rounded-2xl shadow-2xl w-full max-w-2xl mx-auto max-h-[90vh] overflow-y-auto"
          role="dialog"
          aria-modal="true"
        >
          <div class="px-6 pt-6 pb-4 flex items-start justify-between border-b border-slate-200 dark:border-slate-700">
            <div>
              <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
                {gettext("Detalle del evento")}
              </h2>
              <p class="text-xs text-slate-500 dark:text-slate-400 font-mono mt-1">
                {@event_detail.id}
              </p>
            </div>
            <button
              type="button"
              phx-click="close_event_detail"
              class="rounded-lg p-1.5 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 transition"
            >
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>
          <div class="px-6 py-4 space-y-4">
            <%!-- Event info --%>
            <div class="grid grid-cols-2 gap-3 text-sm">
              <div>
                <span class="text-slate-500 dark:text-slate-400">{gettext("Topic")}</span>
                <p class="font-medium text-slate-900 dark:text-slate-100">
                  {@event_detail.topic || "—"}
                </p>
              </div>
              <div>
                <span class="text-slate-500 dark:text-slate-400">{gettext("Estado")}</span>
                <p>
                  <span class="px-2 py-0.5 rounded text-xs font-medium bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-300">
                    {@event_detail.status}
                  </span>
                </p>
              </div>
              <div>
                <span class="text-slate-500 dark:text-slate-400">{gettext("Fecha")}</span>
                <p class="font-medium text-slate-900 dark:text-slate-100">
                  {format_dt(@event_detail.occurred_at)}
                </p>
              </div>
              <div>
                <span class="text-slate-500 dark:text-slate-400">{gettext("Hash")}</span>
                <p class="font-mono text-xs text-slate-600 dark:text-slate-400 truncate">
                  {@event_detail.payload_hash || "—"}
                </p>
              </div>
            </div>
            <%!-- Payload --%>
            <div>
              <span class="text-sm text-slate-500 dark:text-slate-400">{gettext("Payload")}</span>
              <pre class="mt-1 p-3 bg-slate-50 dark:bg-slate-900/50 border border-slate-200 dark:border-slate-700 rounded-lg text-xs font-mono text-slate-700 dark:text-slate-300 overflow-x-auto max-h-40">{Jason.encode!(@event_detail.payload || %{}, pretty: true)}</pre>
            </div>
            <%!-- Delivery Timeline (#22) --%>
            <div>
              <h3 class="text-sm font-semibold text-slate-900 dark:text-slate-100 mb-3">
                <.icon name="hero-arrow-path" class="w-4 h-4 inline mr-1" />
                {gettext("Timeline de entregas")}
                <span class="ml-1 text-xs font-normal text-slate-500 dark:text-slate-400">
                  ({length(@event_deliveries)})
                </span>
              </h3>
              <%= if @event_deliveries == [] do %>
                <p class="text-sm text-slate-400 dark:text-slate-500">
                  {gettext("Sin entregas para este evento.")}
                </p>
              <% else %>
                <div class="relative pl-6 space-y-3">
                  <div class="absolute left-2.5 top-2 bottom-2 w-0.5 bg-slate-200 dark:bg-slate-700">
                  </div>
                  <%= for d <- @event_deliveries do %>
                    <div class="relative">
                      <div class={"absolute -left-[14px] top-1.5 w-3 h-3 rounded-full border-2 border-white dark:border-slate-800 #{delivery_dot_color(d.status)}"}>
                      </div>
                      <div class="bg-slate-50 dark:bg-slate-900/50 border border-slate-200 dark:border-slate-700 rounded-lg p-3">
                        <div class="flex items-center justify-between">
                          <div class="flex items-center gap-2">
                            <span class={[
                              "px-2 py-0.5 rounded text-xs font-medium",
                              delivery_status_class(d.status)
                            ]}>
                              {d.status}
                            </span>
                            <span class="text-xs text-slate-500 dark:text-slate-400">
                              {gettext("Intento")} #{d.attempt_number}
                            </span>
                            <%= if d.response_latency_ms do %>
                              <span class="text-xs text-slate-400 dark:text-slate-500">
                                {d.response_latency_ms}ms
                              </span>
                            <% end %>
                          </div>
                          <span class="text-xs text-slate-400 dark:text-slate-500">
                            {format_dt(d.inserted_at)}
                          </span>
                        </div>
                        <%= if d.webhook do %>
                          <p class="text-xs font-mono text-slate-500 dark:text-slate-400 mt-1 truncate">
                            {d.webhook.url}
                          </p>
                        <% end %>
                        <%= if d.response_status do %>
                          <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
                            HTTP {d.response_status}
                            <%= if d.destination_ip do %>
                              <span class="ml-2 text-slate-400 dark:text-slate-500">
                                → {d.destination_ip}
                              </span>
                            <% end %>
                            <%= if d.response_body && d.response_body != "" do %>
                              —
                              <span class="text-red-600 dark:text-red-400 truncate">
                                {String.slice(d.response_body || "", 0, 100)}
                              </span>
                            <% end %>
                          </p>
                        <% end %>
                        <%!-- Expandable request/response details --%>
                        <details class="mt-2 text-xs">
                          <summary class="cursor-pointer text-indigo-600 dark:text-indigo-400 hover:text-indigo-700 dark:hover:text-indigo-300 font-medium">
                            {gettext("Ver detalles")}
                          </summary>
                          <div class="mt-2 space-y-2">
                            <%!-- Request Headers --%>
                            <%= if d.request_headers && d.request_headers != %{} do %>
                              <div>
                                <span class="font-semibold text-slate-600 dark:text-slate-300">
                                  {gettext("Request Headers")}
                                </span>
                                <pre class="mt-1 p-2 bg-slate-100 dark:bg-slate-900/50 border border-slate-200 dark:border-slate-700 rounded text-xs font-mono text-slate-600 dark:text-slate-400 overflow-x-auto max-h-24">{Jason.encode!(d.request_headers, pretty: true)}</pre>
                              </div>
                            <% end %>
                            <%!-- Request Body --%>
                            <%= if d.request_body do %>
                              <div>
                                <span class="font-semibold text-slate-600 dark:text-slate-300">
                                  {gettext("Request Body")}
                                </span>
                                <pre class="mt-1 p-2 bg-slate-100 dark:bg-slate-900/50 border border-slate-200 dark:border-slate-700 rounded text-xs font-mono text-slate-600 dark:text-slate-400 overflow-x-auto max-h-32">{format_json_preview(d.request_body)}</pre>
                              </div>
                            <% end %>
                            <%!-- Response Headers --%>
                            <%= if d.response_headers && d.response_headers != %{} do %>
                              <div>
                                <span class="font-semibold text-slate-600 dark:text-slate-300">
                                  {gettext("Response Headers")}
                                </span>
                                <pre class="mt-1 p-2 bg-slate-100 dark:bg-slate-900/50 border border-slate-200 dark:border-slate-700 rounded text-xs font-mono text-slate-600 dark:text-slate-400 overflow-x-auto max-h-24">{Jason.encode!(d.response_headers, pretty: true)}</pre>
                              </div>
                            <% end %>
                            <%!-- Response Body --%>
                            <%= if d.response_body do %>
                              <div>
                                <span class="font-semibold text-slate-600 dark:text-slate-300">
                                  {gettext("Response Body")}
                                </span>
                                <pre class="mt-1 p-2 bg-slate-100 dark:bg-slate-900/50 border border-slate-200 dark:border-slate-700 rounded text-xs font-mono text-slate-600 dark:text-slate-400 overflow-x-auto max-h-32">{format_json_preview(d.response_body)}</pre>
                              </div>
                            <% end %>
                          </div>
                        </details>
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

    <%!-- Replay Modal (improved with info, tooltips, dark mode) --%>
    <%= if @replay_modal do %>
      <div class="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6">
        <div
          class="absolute inset-0 bg-black/50 backdrop-blur-sm"
          phx-click="close_replay_modal"
          aria-hidden="true"
        >
        </div>
        <div
          class="relative z-10 w-full max-w-lg bg-white dark:bg-slate-800 rounded-2xl shadow-2xl border border-slate-200/50 dark:border-slate-700 max-h-[90vh] overflow-y-auto"
          role="dialog"
          aria-modal="true"
        >
          <%!-- Header --%>
          <div class="px-6 pt-6 pb-4 flex items-start justify-between border-b border-slate-200 dark:border-slate-700">
            <div>
              <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
                {gettext("Nuevo replay")}
              </h2>
              <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
                {gettext("Re-envía eventos históricos a tus webhooks.")}
              </p>
            </div>
            <button
              type="button"
              phx-click="close_replay_modal"
              class="rounded-lg p-1.5 text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 transition"
            >
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>

          <div class="px-6 pt-4">
            <%!-- Info box --%>
            <div class="flex gap-3 p-3.5 rounded-xl bg-blue-50 dark:bg-blue-900/20 border border-blue-100 dark:border-blue-800/50">
              <.icon
                name="hero-arrow-uturn-left"
                class="w-5 h-5 text-blue-500 dark:text-blue-400 flex-shrink-0 mt-0.5"
              />
              <div class="text-sm text-blue-700 dark:text-blue-300">
                <p>
                  {gettext(
                    "Un replay re-envía eventos pasados a todos tus webhooks activos. Útil para recuperar datos perdidos, probar nuevos webhooks o reprocesar eventos tras un fallo."
                  )}
                </p>
              </div>
            </div>
          </div>

          <.form for={%{}} id="replay-form" phx-submit="start_replay" class="px-6 pb-6 pt-4 space-y-4">
            <div>
              <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                {gettext("Topic")}
                <span class="font-normal text-slate-400 dark:text-slate-500 ml-1">
                  ({gettext("opcional")})
                </span>
              </label>
              <p class="text-xs text-slate-400 dark:text-slate-500 mb-1.5">
                {gettext(
                  "Si defines un topic, solo se re-enviarán los eventos de ese tipo. Vacío = todos."
                )}
              </p>
              <input
                type="text"
                name="topic"
                class="w-full border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 rounded-lg px-3 py-2.5 text-sm text-slate-900 dark:text-slate-100 placeholder-slate-400"
                placeholder="order.created"
              />
            </div>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">
                  {gettext("Desde")}
                </label>
                <input
                  type="datetime-local"
                  name="from_date"
                  class="w-full border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 rounded-lg px-3 py-2.5 text-sm text-slate-900 dark:text-slate-100"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">
                  {gettext("Hasta")}
                </label>
                <input
                  type="datetime-local"
                  name="to_date"
                  class="w-full border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 rounded-lg px-3 py-2.5 text-sm text-slate-900 dark:text-slate-100"
                />
              </div>
            </div>

            <%!-- Warning --%>
            <div class="flex gap-3 p-3 rounded-xl bg-amber-50 dark:bg-amber-900/20 border border-amber-100 dark:border-amber-800/50">
              <.icon
                name="hero-exclamation-triangle"
                class="w-5 h-5 text-amber-500 dark:text-amber-400 flex-shrink-0 mt-0.5"
              />
              <p class="text-xs text-amber-700 dark:text-amber-300">
                {gettext(
                  "Los eventos se enviarán de nuevo a todos los webhooks activos. Asegúrate de que tu servidor puede manejar eventos duplicados (idempotencia)."
                )}
              </p>
            </div>

            <div class="flex flex-col-reverse sm:flex-row sm:justify-end gap-3 pt-3 border-t border-slate-200 dark:border-slate-700">
              <button
                type="button"
                phx-click="close_replay_modal"
                class="w-full sm:w-auto px-4 py-2 border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 rounded-lg text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-600 text-sm font-medium transition"
              >
                {gettext("Cancelar")}
              </button>
              <button
                type="submit"
                phx-disable-with={gettext("Iniciando...")}
                class="w-full sm:w-auto px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg text-sm font-medium transition disabled:opacity-70"
              >
                {gettext("Iniciar replay")}
              </button>
            </div>
          </.form>
        </div>
      </div>
    <% end %>

    <%!-- Job form modal (multi-step wizard) --%>
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
          class="relative z-10 w-full max-w-2xl max-h-[90vh] overflow-hidden bg-white dark:bg-slate-800 rounded-2xl shadow-2xl flex flex-col border border-slate-200/50 dark:border-slate-700"
          id="job-modal-content"
          role="dialog"
          aria-modal="true"
          aria-labelledby="job-modal-title"
        >
          <%!-- Header --%>
          <div class="flex-shrink-0 px-4 sm:px-6 py-4 sm:py-5 border-b border-slate-200 dark:border-slate-700 bg-slate-50/80 dark:bg-slate-800/80">
            <div class="flex justify-between items-center mb-4">
              <h2
                id="job-modal-title"
                class="text-lg sm:text-xl font-semibold text-slate-900 dark:text-slate-100"
              >
                {if @job_modal == :new, do: gettext("Nuevo job"), else: gettext("Editar job")}
              </h2>
              <button
                type="button"
                phx-click="close_job_modal"
                class="p-2 -m-2 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-200/60 dark:hover:bg-slate-700 transition"
                aria-label={gettext("Cerrar")}
              >
                <.icon name="hero-x-mark" class="w-5 h-5" />
              </button>
            </div>
            <%!-- Step indicator --%>
            <div class="flex items-center gap-2">
              <button
                :for={
                  {label, num} <- [
                    {gettext("Básicos"), 1},
                    {gettext("Programación"), 2},
                    {gettext("Acción"), 3}
                  ]
                }
                type="button"
                phx-click="job_step"
                phx-value-step={num}
                class={[
                  "flex items-center gap-1.5 text-xs font-medium px-3 py-1.5 rounded-full transition",
                  if(@job_step == num,
                    do: "bg-indigo-100 text-indigo-700 dark:bg-indigo-900/50 dark:text-indigo-300",
                    else:
                      "text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-700"
                  )
                ]}
              >
                <span class={[
                  "w-5 h-5 rounded-full flex items-center justify-center text-[10px] font-bold",
                  if(@job_step == num,
                    do: "bg-indigo-600 text-white",
                    else: "bg-slate-200 text-slate-600 dark:bg-slate-600 dark:text-slate-300"
                  )
                ]}>
                  {num}
                </span>
                <span class="hidden sm:inline">{label}</span>
              </button>
            </div>
          </div>
          <%!-- Form --%>
          <.form
            for={@job_form}
            id="job-form"
            phx-submit="save_job"
            phx-change="job_form_change"
            class="flex-1 overflow-y-auto"
          >
            <%= if @job_modal != :new do %>
              <input type="hidden" name="job_id" value={elem(@job_modal, 1)} />
            <% end %>
            <% p = @job_form.params || %{} %>
            <div class="p-4 sm:p-6">
              <%!-- STEP 1: Basics --%>
              <div class={if(@job_step != 1, do: "hidden", else: "space-y-5")}>
                <div class="rounded-xl bg-indigo-50 dark:bg-indigo-900/20 border border-indigo-100 dark:border-indigo-800/50 p-4">
                  <div class="flex gap-3">
                    <.icon
                      name="hero-information-circle"
                      class="w-5 h-5 text-indigo-500 shrink-0 mt-0.5"
                    />
                    <p class="text-sm text-indigo-800 dark:text-indigo-200">
                      {gettext(
                        "Un Job es una tarea programada que se ejecuta automáticamente. Puede emitir eventos o llamar URLs externas según el horario que definas."
                      )}
                    </p>
                  </div>
                </div>

                <div>
                  <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">
                    {gettext("Nombre")} *
                  </label>
                  <input
                    type="text"
                    name="name"
                    value={p["name"]}
                    required
                    class="w-full border border-slate-300 dark:border-slate-600 rounded-xl px-4 py-2.5 text-slate-900 dark:text-slate-100 bg-white dark:bg-slate-700 placeholder-slate-400 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition"
                    placeholder={gettext("Ej: Reporte diario de ventas")}
                  />
                  <p class="mt-1.5 text-xs text-slate-500 dark:text-slate-400">
                    {gettext("Un nombre descriptivo para identificar este job.")}
                  </p>
                  <%= for err <- @job_form_errors do %>
                    <p class="mt-1 text-xs text-red-500 dark:text-red-400 flex items-center gap-1">
                      <.icon name="hero-exclamation-circle" class="w-3.5 h-3.5" />{err}
                    </p>
                  <% end %>
                </div>

                <%= if @job_modal != :new do %>
                  <div>
                    <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">
                      {gettext("Estado")}
                    </label>
                    <select
                      name="status"
                      class="w-full border border-slate-300 dark:border-slate-600 rounded-xl px-4 py-2.5 text-slate-900 dark:text-slate-100 bg-white dark:bg-slate-700 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
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

                <div class="flex justify-end pt-4">
                  <button
                    type="button"
                    phx-click="job_step"
                    phx-value-step="2"
                    class="inline-flex items-center gap-2 px-5 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl font-medium shadow-sm transition"
                  >
                    {gettext("Siguiente")}
                    <.icon name="hero-arrow-right" class="w-4 h-4" />
                  </button>
                </div>
              </div>

              <%!-- STEP 2: Schedule --%>
              <div class={if(@job_step != 2, do: "hidden", else: "space-y-5")}>
                <div>
                  <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
                    {gettext("¿Con qué frecuencia?")}
                  </label>
                  <div class="grid grid-cols-2 sm:grid-cols-4 gap-2">
                    <label
                      :for={
                        {val, label, icon} <- [
                          {"daily", gettext("Diario"), "hero-sun"},
                          {"weekly", gettext("Semanal"), "hero-calendar"},
                          {"monthly", gettext("Mensual"), "hero-calendar-days"},
                          {"cron", "Cron", "hero-command-line"}
                        ]
                      }
                      class={[
                        "flex flex-col items-center gap-1 p-3 rounded-xl border-2 cursor-pointer transition text-center",
                        if((p["schedule_type"] || "daily") == val,
                          do:
                            "border-indigo-500 bg-indigo-50 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300",
                          else:
                            "border-slate-200 dark:border-slate-600 hover:border-slate-300 dark:hover:border-slate-500 text-slate-600 dark:text-slate-400"
                        )
                      ]}
                    >
                      <input
                        type="radio"
                        name="schedule_type"
                        value={val}
                        checked={(p["schedule_type"] || "daily") == val}
                        class="sr-only"
                      />
                      <.icon name={icon} class="w-5 h-5" />
                      <span class="text-xs font-medium">{label}</span>
                    </label>
                  </div>
                </div>

                <%!-- Time fields (for daily, weekly, monthly) --%>
                <%= if (p["schedule_type"] || "daily") != "cron" do %>
                  <div class="grid grid-cols-2 gap-4">
                    <div>
                      <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">
                        {gettext("Hora")}
                      </label>
                      <select
                        name="schedule_hour"
                        class="w-full border border-slate-300 dark:border-slate-600 rounded-xl px-4 py-2.5 text-slate-900 dark:text-slate-100 bg-white dark:bg-slate-700 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                      >
                        <%= for h <- 0..23 do %>
                          <option
                            value={h}
                            selected={to_string(h) == to_string(p["schedule_hour"] || "0")}
                          >
                            {String.pad_leading(to_string(h), 2, "0")}:00
                          </option>
                        <% end %>
                      </select>
                    </div>
                    <div>
                      <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">
                        {gettext("Minuto")}
                      </label>
                      <select
                        name="schedule_minute"
                        class="w-full border border-slate-300 dark:border-slate-600 rounded-xl px-4 py-2.5 text-slate-900 dark:text-slate-100 bg-white dark:bg-slate-700 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                      >
                        <%= for m <- [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55] do %>
                          <option
                            value={m}
                            selected={to_string(m) == to_string(p["schedule_minute"] || "0")}
                          >
                            :{String.pad_leading(to_string(m), 2, "0")}
                          </option>
                        <% end %>
                      </select>
                    </div>
                  </div>
                  <p class="text-xs text-slate-500 dark:text-slate-400">
                    <.icon name="hero-globe-alt" class="w-3.5 h-3.5 inline" />
                    {gettext("Todas las horas están en UTC.")}
                  </p>
                <% end %>

                <%!-- Day of week (weekly only) --%>
                <%= if (p["schedule_type"] || "daily") == "weekly" do %>
                  <div>
                    <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">
                      {gettext("Día de la semana")}
                    </label>
                    <select
                      name="schedule_day_of_week"
                      class="w-full border border-slate-300 dark:border-slate-600 rounded-xl px-4 py-2.5 text-slate-900 dark:text-slate-100 bg-white dark:bg-slate-700 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                    >
                      <%= for {day, num} <- [{gettext("Lunes"), 1}, {gettext("Martes"), 2}, {gettext("Miércoles"), 3}, {gettext("Jueves"), 4}, {gettext("Viernes"), 5}, {gettext("Sábado"), 6}, {gettext("Domingo"), 7}] do %>
                        <option
                          value={num}
                          selected={to_string(num) == to_string(p["schedule_day_of_week"] || "1")}
                        >
                          {day}
                        </option>
                      <% end %>
                    </select>
                  </div>
                <% end %>

                <%!-- Day of month (monthly only) --%>
                <%= if (p["schedule_type"] || "daily") == "monthly" do %>
                  <div>
                    <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">
                      {gettext("Día del mes")}
                    </label>
                    <select
                      name="schedule_day_of_month"
                      class="w-full border border-slate-300 dark:border-slate-600 rounded-xl px-4 py-2.5 text-slate-900 dark:text-slate-100 bg-white dark:bg-slate-700 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                    >
                      <%= for d <- 1..31 do %>
                        <option
                          value={d}
                          selected={to_string(d) == to_string(p["schedule_day_of_month"] || "1")}
                        >
                          {d}
                        </option>
                      <% end %>
                    </select>
                  </div>
                <% end %>

                <%!-- Cron expression --%>
                <%= if (p["schedule_type"] || "daily") == "cron" do %>
                  <div>
                    <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                      {gettext("Expresión cron")}
                    </label>
                    <p class="text-xs text-slate-400 dark:text-slate-500 mb-1.5">
                      {gettext("Formato: minuto hora día-del-mes mes día-de-semana")}
                    </p>
                    <div class="flex gap-2">
                      <input
                        type="text"
                        name="schedule_cron"
                        id="cron-expr-input"
                        value={p["schedule_cron"]}
                        placeholder="0 0 * * *"
                        class="flex-1 border border-slate-300 dark:border-slate-600 rounded-xl px-4 py-2.5 text-slate-900 dark:text-slate-100 bg-white dark:bg-slate-700 font-mono text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                      />
                      <button
                        type="button"
                        phx-click="preview_cron"
                        phx-value-expression={p["schedule_cron"]}
                        class="px-3 py-2 text-xs font-medium text-indigo-600 dark:text-indigo-400 bg-indigo-50 dark:bg-indigo-900/30 hover:bg-indigo-100 dark:hover:bg-indigo-900/50 rounded-xl transition shrink-0"
                      >
                        {gettext("Preview")}
                      </button>
                    </div>
                    <%!-- Common presets --%>
                    <div class="flex flex-wrap gap-1.5 mt-2">
                      <button
                        :for={
                          {label, expr} <- [
                            {gettext("Cada hora"), "0 * * * *"},
                            {gettext("Cada 6h"), "0 */6 * * *"},
                            {gettext("Medianoche"), "0 0 * * *"},
                            {gettext("Lun-Vie 9am"), "0 9 * * 1-5"}
                          ]
                        }
                        type="button"
                        phx-click="job_form_change"
                        phx-value-schedule_cron={expr}
                        class="px-2 py-1 text-[11px] font-medium text-slate-600 dark:text-slate-400 bg-slate-100 dark:bg-slate-700 hover:bg-slate-200 dark:hover:bg-slate-600 rounded-lg transition"
                      >
                        {label}
                      </button>
                    </div>
                    <%= if @cron_preview != [] do %>
                      <div class="mt-2 p-3 bg-slate-50 dark:bg-slate-700/50 rounded-lg border border-slate-200 dark:border-slate-600">
                        <p class="text-xs font-medium text-slate-500 dark:text-slate-400 mb-1">
                          {gettext("Próximas ejecuciones")}:
                        </p>
                        <ul class="space-y-0.5">
                          <%= for dt <- @cron_preview do %>
                            <li class="text-xs font-mono text-slate-600 dark:text-slate-300">
                              {dt}
                            </li>
                          <% end %>
                        </ul>
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <div class="flex justify-between pt-4">
                  <button
                    type="button"
                    phx-click="job_step"
                    phx-value-step="1"
                    class="inline-flex items-center gap-2 px-5 py-2.5 border border-slate-300 dark:border-slate-600 rounded-xl text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700 font-medium transition"
                  >
                    <.icon name="hero-arrow-left" class="w-4 h-4" />
                    {gettext("Atrás")}
                  </button>
                  <button
                    type="button"
                    phx-click="job_step"
                    phx-value-step="3"
                    class="inline-flex items-center gap-2 px-5 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl font-medium shadow-sm transition"
                  >
                    {gettext("Siguiente")}
                    <.icon name="hero-arrow-right" class="w-4 h-4" />
                  </button>
                </div>
              </div>

              <%!-- STEP 3: Action --%>
              <div class={if(@job_step != 3, do: "hidden", else: "space-y-5")}>
                <div>
                  <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
                    {gettext("¿Qué debe hacer este job?")}
                  </label>
                  <div class="grid grid-cols-2 gap-3">
                    <label
                      :for={
                        {val, label, desc, icon} <- [
                          {"emit_event", gettext("Emitir evento"),
                           gettext("Envía un evento a tus webhooks"), "hero-bolt"},
                          {"post_url", gettext("Llamar URL"),
                           gettext("Hace un HTTP request a una URL"), "hero-globe-alt"}
                        ]
                      }
                      class={[
                        "flex flex-col gap-1 p-3 rounded-xl border-2 cursor-pointer transition",
                        if((p["action_type"] || "emit_event") == val,
                          do: "border-indigo-500 bg-indigo-50 dark:bg-indigo-900/30",
                          else:
                            "border-slate-200 dark:border-slate-600 hover:border-slate-300 dark:hover:border-slate-500"
                        )
                      ]}
                    >
                      <input
                        type="radio"
                        name="action_type"
                        value={val}
                        checked={(p["action_type"] || "emit_event") == val}
                        class="sr-only"
                      />
                      <div class="flex items-center gap-2">
                        <.icon name={icon} class="w-4 h-4 text-indigo-600 dark:text-indigo-400" />
                        <span class="text-sm font-medium text-slate-800 dark:text-slate-200">
                          {label}
                        </span>
                      </div>
                      <span class="text-xs text-slate-500 dark:text-slate-400">{desc}</span>
                    </label>
                  </div>
                </div>

                <%!-- emit_event fields --%>
                <%= if (p["action_type"] || "emit_event") == "emit_event" do %>
                  <div>
                    <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                      Topic
                    </label>
                    <p class="text-xs text-slate-400 dark:text-slate-500 mb-1.5">
                      {gettext("Usa notación con puntos, ej: order.created, report.daily")}
                    </p>
                    <input
                      type="text"
                      name="action_topic"
                      value={p["action_topic"]}
                      class="w-full border border-slate-300 dark:border-slate-600 rounded-xl px-4 py-2.5 text-slate-900 dark:text-slate-100 bg-white dark:bg-slate-700 placeholder-slate-400 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                      placeholder={gettext("ej: report.daily")}
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                      {gettext("Payload")} (JSON)
                    </label>
                    <p class="text-xs text-slate-400 dark:text-slate-500 mb-1.5">
                      {gettext("El cuerpo del evento en formato JSON.")}
                    </p>
                    <textarea
                      name="action_payload"
                      rows="3"
                      class="w-full border border-slate-300 dark:border-slate-600 rounded-xl px-4 py-2.5 text-slate-900 dark:text-slate-100 bg-white dark:bg-slate-700 font-mono text-sm placeholder-slate-400 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                    >{p["action_payload"]}</textarea>
                  </div>
                <% end %>

                <%!-- post_url fields --%>
                <%= if (p["action_type"] || "emit_event") == "post_url" do %>
                  <div>
                    <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">
                      URL
                    </label>
                    <input
                      type="url"
                      name="action_url"
                      value={p["action_url"]}
                      class="w-full border border-slate-300 dark:border-slate-600 rounded-xl px-4 py-2.5 text-slate-900 dark:text-slate-100 bg-white dark:bg-slate-700 placeholder-slate-400 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                      placeholder="https://api.example.com/webhook"
                    />
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">
                      {gettext("Método HTTP")}
                    </label>
                    <select
                      name="action_method"
                      class="w-full border border-slate-300 dark:border-slate-600 rounded-xl px-4 py-2.5 text-slate-900 dark:text-slate-100 bg-white dark:bg-slate-700 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                    >
                      <option value="POST" selected={p["action_method"] == "POST"}>POST</option>
                      <option value="GET" selected={p["action_method"] == "GET"}>GET</option>
                      <option value="PUT" selected={p["action_method"] == "PUT"}>PUT</option>
                      <option value="PATCH" selected={p["action_method"] == "PATCH"}>
                        PATCH
                      </option>
                    </select>
                  </div>
                <% end %>

                <div class="flex justify-between pt-4 border-t border-slate-200 dark:border-slate-700">
                  <button
                    type="button"
                    phx-click="job_step"
                    phx-value-step="2"
                    class="inline-flex items-center gap-2 px-5 py-2.5 border border-slate-300 dark:border-slate-600 rounded-xl text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700 font-medium transition"
                  >
                    <.icon name="hero-arrow-left" class="w-4 h-4" />
                    {gettext("Atrás")}
                  </button>
                  <button
                    type="submit"
                    phx-disable-with={gettext("Guardando...")}
                    class="inline-flex items-center gap-2 px-5 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl font-medium shadow-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
                  >
                    <.icon name="hero-check" class="w-4 h-4" />
                    {if @job_modal == :new,
                      do: gettext("Crear job"),
                      else: gettext("Guardar cambios")}
                  </button>
                </div>
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
          class="relative z-10 w-full max-w-2xl max-h-[80vh] overflow-hidden bg-white dark:bg-slate-800 rounded-2xl shadow-2xl flex flex-col border border-slate-200/50 dark:border-slate-700 mx-4"
          role="dialog"
          aria-modal="true"
        >
          <div class="p-4 border-b border-slate-200 dark:border-slate-700 flex justify-between items-center">
            <h2 class="text-lg font-semibold text-slate-900 dark:text-slate-100">
              {gettext("Runs: %{name}", name: @job_runs_modal.job.name)}
            </h2>
            <button
              type="button"
              phx-click="close_job_runs_modal"
              class="p-2 -m-2 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 transition"
            >
              <.icon name="hero-x-mark" class="w-6 h-6" />
            </button>
          </div>
          <div class="overflow-y-auto flex-1 p-4">
            <table class="min-w-full">
              <thead>
                <tr class="bg-slate-50 dark:bg-slate-900/50 border-b border-slate-200 dark:border-slate-700">
                  <th class="px-4 py-2 text-left text-sm font-medium text-slate-700 dark:text-slate-300">
                    {gettext("Ejecutado")}
                  </th>
                  <th class="px-4 py-2 text-left text-sm font-medium text-slate-700 dark:text-slate-300">
                    {gettext("Estado")}
                  </th>
                  <th class="px-4 py-2 text-left text-sm font-medium text-slate-700 dark:text-slate-300">
                    {gettext("Resultado")}
                  </th>
                </tr>
              </thead>
              <tbody>
                <%= for r <- @job_runs_modal.runs do %>
                  <tr class="border-b border-slate-100 dark:border-slate-700">
                    <td class="px-4 py-2 text-sm text-slate-600 dark:text-slate-400">
                      {format_dt(r.executed_at)}
                    </td>
                    <td class="px-4 py-2">
                      <span class={[
                        "px-2 py-0.5 rounded text-xs",
                        if(r.status == "success",
                          do: "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400",
                          else: "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400"
                        )
                      ]}>
                        {r.status}
                      </span>
                    </td>
                    <td class="px-4 py-2 text-sm text-slate-600 dark:text-slate-400">
                      {if r.result, do: Jason.encode!(r.result), else: "—"}
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
            <%= if @job_runs_modal.runs == [] do %>
              <p class="text-slate-500 dark:text-slate-400 py-4">{gettext("Sin ejecuciones aún.")}</p>
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
          class="relative z-10 w-full max-w-md bg-white dark:bg-slate-800 rounded-2xl shadow-2xl p-5 sm:p-6 border border-slate-200/50 dark:border-slate-700"
          role="dialog"
          aria-modal="true"
          aria-labelledby="confirm-regenerate-title"
        >
          <div class="flex items-start gap-4">
            <div class="flex-shrink-0 w-10 h-10 rounded-full bg-amber-100 dark:bg-amber-900/30 flex items-center justify-center">
              <.icon
                name="hero-exclamation-triangle"
                class="w-5 h-5 text-amber-600 dark:text-amber-400"
              />
            </div>
            <div class="flex-1">
              <h3
                id="confirm-regenerate-title"
                class="text-lg font-semibold text-slate-900 dark:text-slate-100"
              >
                {gettext("¿Regenerar token?")}
              </h3>
              <p class="mt-2 text-sm text-slate-600 dark:text-slate-400">
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
              class="px-4 py-2 border border-slate-300 dark:border-slate-600 rounded-lg text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-700 text-sm font-medium transition"
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
            "rounded-lg border-2 border-emerald-300 dark:border-emerald-700 bg-emerald-50 dark:bg-emerald-900/20 p-3 sm:p-4"
          )
          |> Map.put(:token_icon, "hero-check-circle")
          |> Map.put(:token_icon_class, "w-5 h-5 text-emerald-600 dark:text-emerald-400")
          |> Map.put(
            :token_msg_class,
            "text-emerald-800 dark:text-emerald-300 font-medium text-sm"
          )
          |> Map.put(
            :token_msg,
            gettext("Tu API token ha sido creado. Cópialo y guárdalo ahora.")
          )
          |> Map.put(:token_input_border, "border-emerald-200 dark:border-emerald-700")
        else
          assigns
          |> Map.put(
            :token_wrapper_class,
            "rounded-lg border-2 border-amber-300 dark:border-amber-700 bg-amber-50 dark:bg-amber-900/20 p-3 sm:p-4"
          )
          |> Map.put(:token_icon, "hero-exclamation-triangle")
          |> Map.put(:token_icon_class, "w-5 h-5 text-amber-600 dark:text-amber-400")
          |> Map.put(:token_msg_class, "text-amber-800 dark:text-amber-300 font-medium text-sm")
          |> Map.put(
            :token_msg,
            gettext("El token anterior ha sido revocado. Copia y guarda el nuevo.")
          )
          |> Map.put(:token_input_border, "border-amber-200 dark:border-amber-700")
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
        <div class={"flex items-stretch gap-0 overflow-hidden rounded-lg border #{@token_input_border} bg-white dark:bg-slate-700"}>
          <input
            id="token-input"
            type="text"
            readonly
            value={if @token_visible, do: @new_token, else: String.duplicate("•", 20)}
            data-real-value={@new_token}
            class="flex-1 min-w-0 font-mono text-sm px-4 py-3 bg-transparent border-0 text-slate-900 dark:text-slate-100 focus:ring-0"
            phx-no-feedback
          />
          <button
            type="button"
            phx-click="toggle_token_visibility"
            class={"p-3 border-l #{@token_input_border} bg-white dark:bg-slate-700 hover:bg-slate-50 dark:hover:bg-slate-600 text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 transition"}
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
            class={"p-3 border-l #{@token_input_border} bg-white dark:bg-slate-700 hover:bg-slate-50 dark:hover:bg-slate-600 text-slate-500 dark:text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 transition"}
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
            class="px-4 py-2 bg-slate-200 dark:bg-slate-700 hover:bg-slate-300 dark:hover:bg-slate-600 text-slate-800 dark:text-slate-200 rounded-lg font-medium text-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
          >
            {gettext("Regenerar token")}
          </button>
        </div>
      <% end %>
    <% else %>
      <%= if @api_key != nil do %>
        <div class="rounded-lg border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900/50">
          <input
            type="text"
            readonly
            value={"#{@api_key.prefix}••••••••••"}
            class="w-full font-mono text-sm px-4 py-3 bg-transparent border-0 text-slate-600 dark:text-slate-400 focus:ring-0"
            aria-label={gettext("Prefijo del token")}
          />
        </div>
        <p class="text-slate-500 dark:text-slate-400 text-sm mt-2">
          {gettext("Solo se muestra el prefijo. Regenera para obtener el token completo.")}
        </p>
        <%= if can_admin_team?(@current_user_role) do %>
          <div class="flex flex-col sm:flex-row gap-2 mt-3">
            <button
              phx-click="show_confirm_regenerate"
              type="button"
              class="px-4 py-2 bg-slate-200 dark:bg-slate-700 hover:bg-slate-300 dark:hover:bg-slate-600 text-slate-800 dark:text-slate-200 rounded-lg font-medium text-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
            >
              {gettext("Regenerar token")}
            </button>
          </div>
        <% end %>
        <div class="mt-4 pt-4 border-t border-slate-200 dark:border-slate-700 space-y-2">
          <div class="flex items-center gap-2">
            <span class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase">
              {gettext("Scopes")}:
            </span>
            <%= for scope <- (@api_key.scopes || ["*"]) do %>
              <span class="px-2 py-0.5 bg-indigo-50 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300 rounded text-xs font-mono">
                {scope}
              </span>
            <% end %>
          </div>
          <div class="flex items-start gap-2">
            <span class="text-xs font-medium text-slate-500 dark:text-slate-400 uppercase shrink-0">
              {gettext("IPs permitidas")}:
            </span>
            <%= if @api_key.allowed_ips && @api_key.allowed_ips != [] do %>
              <div class="flex flex-wrap gap-1">
                <%= for ip <- @api_key.allowed_ips do %>
                  <span class="px-2 py-0.5 bg-emerald-50 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-300 rounded text-xs font-mono">
                    {ip}
                  </span>
                <% end %>
              </div>
            <% else %>
              <span class="text-xs text-slate-400 dark:text-slate-500">
                {gettext("Sin restricción (cualquier IP)")}
              </span>
            <% end %>
          </div>
        </div>
      <% else %>
        <div class="text-center py-4 mb-3">
          <.icon
            name="hero-key"
            class="w-10 h-10 mx-auto mb-3 text-slate-300 dark:text-slate-600"
          />
          <p class="text-sm font-medium text-slate-600 dark:text-slate-300">
            {gettext("Sin API token")}
          </p>
          <p class="text-xs text-slate-400 dark:text-slate-500 mt-1">
            {gettext("Genera un token para autenticar tus llamadas a la API.")}
          </p>
        </div>
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
