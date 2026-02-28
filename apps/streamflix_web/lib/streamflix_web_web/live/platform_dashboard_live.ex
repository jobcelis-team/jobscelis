defmodule StreamflixWebWeb.PlatformDashboardLive do
  use StreamflixWebWeb, :live_view

  alias StreamflixCore.Platform

  @impl true
  def mount(_params, session, socket) do
    user = socket.assigns.current_user
    project = Platform.get_project_by_user_id(user.id)
    api_key = if project, do: Platform.get_api_key_for_project(project.id), else: nil
    events = if project, do: Platform.list_events(project.id, limit: 20), else: []
    webhooks = if project, do: Platform.list_webhooks(project.id), else: []
    jobs = if project, do: Platform.list_jobs(project.id, include_inactive: true), else: []
    deliveries = if project, do: Platform.list_deliveries(project_id: project.id, limit: 30), else: []

    # Check if we have a fresh API key from registration
    {new_token, token_source} =
      case session["fresh_api_key"] do
        fresh_key when is_binary(fresh_key) and fresh_key != "" ->
          # Only use if prefix still matches (prevents stale key after regeneration)
          if api_key && String.starts_with?(fresh_key, api_key.prefix) do
            {fresh_key, :registration}
          else
            {nil, nil}
          end

        _ ->
          {nil, nil}
      end

    socket =
      socket
      |> assign(:project, project)
      |> assign(:api_key, api_key)
      |> assign(:events, events)
      |> assign(:webhooks, webhooks)
      |> assign(:jobs, jobs)
      |> assign(:deliveries, deliveries)
      |> assign(:test_topic, "")
      |> assign(:test_payload, "{}")
      |> assign(:new_token, new_token)
      |> assign(:token_source, token_source)
      |> assign(:token_visible, true)
      |> assign(:editing_project_name, false)
      |> assign(:job_modal, nil)
      |> assign(:job_runs_modal, nil)
      |> assign(:job_form, nil)
      |> assign(:page_title, "Jobcelis Dashboard")
      |> assign(:active_page, :dashboard)

    {:ok, socket}
  end

  @impl true
  def handle_event("send_test", %{"topic" => topic, "payload" => payload_str} = _params, socket) do
    project = socket.assigns.project
    payload = case Jason.decode(payload_str) do
      {:ok, map} when is_map(map) -> map
      _ -> %{}
    end
    body = if topic != "", do: Map.put(payload, "topic", topic), else: payload

    result = Platform.create_event(project.id, body)
    socket = case result do
      {:ok, event} ->
        events = [event | Platform.list_events(project.id, limit: 19)]
        put_flash(socket, :info, gettext("Event sent. ID: %{id}", id: event.id))
        assign(socket, :events, events)
      {:error, _} ->
        put_flash(socket, :error, gettext("Failed to send event"))
        socket
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_project_name", _params, socket) do
    {:noreply, assign(socket, :editing_project_name, true)}
  end

  @impl true
  def handle_event("cancel_edit_project_name", _params, socket) do
    {:noreply, assign(socket, :editing_project_name, false)}
  end

  @impl true
  def handle_event("update_project_name", %{"name" => name}, socket) do
    project = socket.assigns.project
    name = String.trim(name)
    socket =
      if name == "" do
        put_flash(socket, :error, gettext("El nombre no puede estar vacío."))
        |> assign(:editing_project_name, false)
      else
        case Platform.update_project(project, %{name: name}) do
          {:ok, updated} ->
            socket
            |> put_flash(:info, gettext("Nombre del proyecto actualizado."))
            |> assign(:project, updated)
            |> assign(:editing_project_name, false)
          {:error, _} ->
            put_flash(socket, :error, gettext("No se pudo actualizar el nombre."))
            |> assign(:editing_project_name, false)
        end
      end
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_token_visibility", _params, socket) do
    {:noreply, assign(socket, :token_visible, !socket.assigns.token_visible)}
  end

  @impl true
  def handle_event("regenerate_token", _params, socket) do
    project = socket.assigns.project
    case Platform.regenerate_api_key(project.id) do
      {:ok, _api_key, raw_key} ->
        api_key = Platform.get_api_key_for_project(project.id)
        socket =
          socket
          |> put_flash(:info, gettext("Token regenerado correctamente."))
          |> assign(:api_key, api_key)
          |> assign(:new_token, raw_key)
          |> assign(:token_source, :regenerated)
          |> assign(:token_visible, true)
        {:noreply, socket}
      _ ->
        {:noreply, put_flash(socket, :error, gettext("No se pudo regenerar el token."))}
    end
  end

  # Jobs: open create modal
  @impl true
  def handle_event("new_job", _, socket) do
    project = socket.assigns.project
    if project do
      form = to_form(%{
        "name" => "",
        "schedule_type" => "daily",
        "schedule_hour" => "0",
        "schedule_minute" => "0",
        "schedule_day_of_week" => "1",
        "schedule_day_of_month" => "1",
        "schedule_cron" => "0 0 * * *",
        "action_type" => "emit_event",
        "action_topic" => "",
        "action_payload" => "{}",
        "action_url" => "",
        "action_method" => "POST"
      })
      {:noreply,
       socket
       |> assign(:job_modal, :new)
       |> assign(:job_form, form)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("edit_job", %{"id" => id}, socket) do
    project = socket.assigns.project
    job = project && Platform.get_job(id)
    if job && job.project_id == project.id do
      sc = job.schedule_config || %{}
      ac = job.action_config || %{}
      form = to_form(%{
        "name" => job.name || "",
        "schedule_type" => job.schedule_type || "daily",
        "schedule_hour" => to_str(Map.get(sc, "hour", 0)),
        "schedule_minute" => to_str(Map.get(sc, "minute", 0)),
        "schedule_day_of_week" => to_str(Map.get(sc, "day_of_week", 1)),
        "schedule_day_of_month" => to_str(Map.get(sc, "day_of_month", 1)),
        "schedule_cron" => Map.get(sc, "expr") || Map.get(sc, "expression") || "0 0 * * *",
        "action_type" => job.action_type || "emit_event",
        "action_topic" => Map.get(ac, "topic") || "",
        "action_payload" => (ac["payload"] && Jason.encode!(ac["payload"])) || "{}",
        "action_url" => Map.get(ac, "url") || "",
        "action_method" => Map.get(ac, "method") || "POST",
        "status" => job.status || "active"
      })
      {:noreply,
       socket
       |> assign(:job_modal, {:edit, job.id})
       |> assign(:job_form, form)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_job_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:job_modal, nil)
     |> assign(:job_form, nil)}
  end

  @impl true
  def handle_event("save_job", params, socket) do
    project = socket.assigns.project
    if !project do
      {:noreply, socket}
    else
      schedule_config = build_schedule_config(params)
      action_config = build_action_config(params)
      attrs = %{
        "name" => params["name"] || "",
        "schedule_type" => params["schedule_type"] || "daily",
        "schedule_config" => schedule_config,
        "action_type" => params["action_type"] || "emit_event",
        "action_config" => action_config
      }
      attrs = if match?({:edit, _}, socket.assigns.job_modal), do: Map.put(attrs, "status", params["status"] || "active"), else: attrs

      result = case socket.assigns.job_modal do
        :new -> Platform.create_job(project.id, attrs)
        {:edit, id} ->
          job_id = params["job_id"] || id
          job = Platform.get_job(job_id)
          if job && job.project_id == project.id, do: Platform.update_job(job, attrs), else: {:error, nil}
      end

      socket = case result do
        {:ok, _job} ->
          jobs = Platform.list_jobs(project.id, include_inactive: true)
          socket
          |> put_flash(:info, gettext("Job guardado."))
          |> assign(:jobs, jobs)
          |> assign(:job_modal, nil)
          |> assign(:job_form, nil)
        {:error, _} ->
          put_flash(socket, :error, gettext("Error al guardar el job."))
      end
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_job_runs", %{"id" => id}, socket) do
    project = socket.assigns.project
    job = project && Platform.get_job(id)
    if job && job.project_id == project.id do
      runs = Platform.list_job_runs(job.id, limit: 50)
      {:noreply,
       socket
       |> assign(:job_runs_modal, %{job: job, runs: runs})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_job_runs_modal", _, socket) do
    {:noreply, assign(socket, :job_runs_modal, nil)}
  end

  @impl true
  def handle_event("deactivate_job", %{"id" => id}, socket) do
    project = socket.assigns.project
    job = project && Platform.get_job(id)
    if job && job.project_id == project.id do
      Platform.set_job_inactive(job)
      jobs = Platform.list_jobs(project.id, include_inactive: true)
      {:noreply,
       socket
       |> put_flash(:info, gettext("Job desactivado."))
       |> assign(:jobs, jobs)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("retry_delivery", %{"id" => id}, socket) do
    project = socket.assigns.project
    if project do
      case Platform.retry_delivery(project.id, id) do
        {:ok, _} ->
          deliveries = Platform.list_deliveries(project_id: project.id, limit: 30)
          {:noreply,
           socket
           |> put_flash(:info, gettext("Reintento encolado."))
           |> assign(:deliveries, deliveries)}
        {:error, :not_found} ->
          {:noreply, put_flash(socket, :error, gettext("Entrega no encontrada."))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={:platform} current_user={@current_user} locale={@locale} active_page={@active_page}>
      <div>
        <h1 class="text-xl sm:text-2xl font-bold text-slate-900 mb-6 sm:mb-8"><%= gettext("Dashboard") %></h1>

        <%= if @project do %>
          <div class="space-y-6 sm:space-y-8">
            <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 overflow-hidden">
              <h2 class="text-lg font-semibold text-slate-900 mb-2"><%= gettext("Proyecto") %></h2>
              <%= if @editing_project_name do %>
                <.form for={%{}} id="project-name-form" phx-submit="update_project_name" class="flex flex-wrap items-center gap-2">
                  <.input
                    type="text"
                    name="name"
                    value={@project.name}
                    class="w-full max-w-xs px-3 py-2 bg-white border border-slate-300 rounded-lg text-slate-900"
                    placeholder={gettext("Nombre del proyecto")}
                  />
                  <button type="submit" phx-disable-with={gettext("Guardando...")} class="px-3 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-sm font-medium disabled:opacity-70 disabled:cursor-not-allowed">
                    <%= gettext("Guardar") %>
                  </button>
                  <button type="button" phx-click="cancel_edit_project_name" class="px-3 py-2 bg-slate-200 hover:bg-slate-300 text-slate-800 rounded-lg text-sm font-medium">
                    <%= gettext("Cancelar") %>
                  </button>
                </.form>
              <% else %>
                <p class="text-slate-600">
                  <strong>{@project.name}</strong>
                  <button type="button" phx-click="edit_project_name" class="ml-2 text-indigo-600 hover:text-indigo-700 text-sm font-medium">
                    <%= gettext("Editar nombre") %>
                  </button>
                </p>
              <% end %>
              <p class="text-slate-500 text-sm font-mono mt-1 break-all">{@project.id}</p>
            </section>

            <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 overflow-hidden">
              <h2 class="text-lg font-semibold text-slate-900 mb-1"><%= gettext("API Token") %></h2>
              <p class="text-slate-500 text-xs sm:text-sm mb-3 break-words"><%= gettext("Header:") %> <code class="bg-slate-100 px-1 rounded text-xs break-all">Authorization: Bearer &lt;token&gt;</code> <%= gettext("o") %> <code class="bg-slate-100 px-1 rounded text-xs">X-Api-Key</code></p>

              <%!-- State 1: Fresh token from registration --%>
              <%= if @new_token && @token_source == :registration do %>
                <div class="rounded-lg border-2 border-emerald-300 bg-emerald-50 p-3 sm:p-4">
                  <div class="flex items-center gap-2 mb-3">
                    <.icon name="hero-check-circle" class="w-5 h-5 text-emerald-600" />
                    <span class="text-emerald-800 font-medium text-sm"><%= gettext("Tu API token ha sido creado. Cópialo y guárdalo ahora.") %></span>
                  </div>
                  <div class="flex items-stretch gap-0 overflow-hidden rounded-lg border border-emerald-200 bg-white">
                    <input
                      id="token-input"
                      type="text"
                      readonly
                      value={if @token_visible, do: @new_token, else: String.duplicate("•", 38)}
                      data-real-value={@new_token}
                      class="flex-1 min-w-0 font-mono text-sm px-4 py-3 bg-transparent border-0 text-slate-900 focus:ring-0"
                      phx-no-feedback
                    />
                    <button
                      type="button"
                      phx-click="toggle_token_visibility"
                      class="p-3 border-l border-emerald-200 bg-white hover:bg-slate-50 text-slate-500 hover:text-slate-700 transition"
                      title={if @token_visible, do: gettext("Ocultar"), else: gettext("Mostrar")}
                      aria-label={if @token_visible, do: gettext("Ocultar token"), else: gettext("Mostrar token")}
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
                      class="p-3 border-l border-emerald-200 bg-white hover:bg-slate-50 text-slate-500 hover:text-emerald-600 transition"
                      title={gettext("Copiar token")}
                      aria-label={gettext("Copiar token")}
                    >
                      <span data-copy-icon><.icon name="hero-clipboard-document" class="w-5 h-5" /></span>
                      <span data-check-icon class="hidden"><.icon name="hero-check" class="w-5 h-5 text-emerald-600" /></span>
                    </button>
                  </div>
                </div>
                <div class="mt-3 flex items-center gap-3">
                  <button
                    phx-click="regenerate_token"
                    phx-disable-with={gettext("Regenerando...")}
                    data-confirm={gettext("¿Regenerar token? El token actual dejará de funcionar.")}
                    type="button"
                    class="px-4 py-2 bg-slate-200 hover:bg-slate-300 text-slate-800 rounded-lg font-medium text-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
                  >
                    <%= gettext("Regenerar token") %>
                  </button>
                </div>

              <%!-- State 2: Regenerated token --%>
              <% else %>
              <%= if @new_token && @token_source == :regenerated do %>
                <div class="rounded-lg border-2 border-amber-300 bg-amber-50 p-3 sm:p-4">
                  <div class="flex items-center gap-2 mb-3">
                    <.icon name="hero-exclamation-triangle" class="w-5 h-5 text-amber-600" />
                    <span class="text-amber-800 font-medium text-sm"><%= gettext("El token anterior ha sido revocado. Copia y guarda el nuevo.") %></span>
                  </div>
                  <div class="flex items-stretch gap-0 overflow-hidden rounded-lg border border-amber-200 bg-white">
                    <input
                      id="token-input"
                      type="text"
                      readonly
                      value={if @token_visible, do: @new_token, else: String.duplicate("•", 38)}
                      data-real-value={@new_token}
                      class="flex-1 min-w-0 font-mono text-sm px-4 py-3 bg-transparent border-0 text-slate-900 focus:ring-0"
                      phx-no-feedback
                    />
                    <button
                      type="button"
                      phx-click="toggle_token_visibility"
                      class="p-3 border-l border-amber-200 bg-white hover:bg-slate-50 text-slate-500 hover:text-slate-700 transition"
                      title={if @token_visible, do: gettext("Ocultar"), else: gettext("Mostrar")}
                      aria-label={if @token_visible, do: gettext("Ocultar token"), else: gettext("Mostrar token")}
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
                      class="p-3 border-l border-amber-200 bg-white hover:bg-slate-50 text-slate-500 hover:text-amber-600 transition"
                      title={gettext("Copiar token")}
                      aria-label={gettext("Copiar token")}
                    >
                      <span data-copy-icon><.icon name="hero-clipboard-document" class="w-5 h-5" /></span>
                      <span data-check-icon class="hidden"><.icon name="hero-check" class="w-5 h-5 text-amber-600" /></span>
                    </button>
                  </div>
                </div>
                <div class="mt-3 flex items-center gap-3">
                  <button
                    phx-click="regenerate_token"
                    phx-disable-with={gettext("Regenerando...")}
                    data-confirm={gettext("¿Regenerar token? El token actual dejará de funcionar.")}
                    type="button"
                    class="px-4 py-2 bg-slate-200 hover:bg-slate-300 text-slate-800 rounded-lg font-medium text-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
                  >
                    <%= gettext("Regenerar token") %>
                  </button>
                </div>

              <%!-- State 3: Prefix only (no full token available) --%>
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
                <p class="text-slate-500 text-sm mt-2"><%= gettext("Solo se muestra el prefijo. Regenera para obtener el token completo.") %></p>
                <button
                  phx-click="regenerate_token"
                  phx-disable-with={gettext("Regenerando...")}
                  data-confirm={gettext("¿Regenerar token? El token actual dejará de funcionar.")}
                  type="button"
                  class="mt-3 px-4 py-2 bg-slate-200 hover:bg-slate-300 text-slate-800 rounded-lg font-medium text-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
                >
                  <%= gettext("Regenerar token") %>
                </button>

              <%!-- State 4: No API key at all --%>
              <% else %>
                <p class="text-slate-600 mb-3"><%= gettext("No hay API token. Genera uno para empezar.") %></p>
                <button
                  phx-click="regenerate_token"
                  phx-disable-with={gettext("Generando...")}
                  type="button"
                  class="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg font-medium text-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
                >
                  <%= gettext("Generar token") %>
                </button>
              <% end %>
              <% end %>
              <% end %>
            </section>

            <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 overflow-hidden">
              <h2 class="text-lg font-semibold text-slate-900 mb-4"><%= gettext("Enviar evento de prueba") %></h2>
              <.form for={%{}} id="test-event-form" phx-submit="send_test" class="space-y-3 sm:max-w-lg">
                <.input type="text" name="topic" id="test-topic" value={@test_topic} placeholder={gettext("Topic (opcional)")} class="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg text-slate-900 placeholder-slate-400 font-mono text-sm" />
                <.input type="textarea" name="payload" id="test-payload" value={@test_payload} class="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg text-slate-900 placeholder-slate-400 font-mono text-sm" />
                <button type="submit" phx-disable-with={gettext("Enviando...")} class="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg font-medium text-sm transition disabled:opacity-70 disabled:cursor-not-allowed">
                  <%= gettext("Enviar") %>
                </button>
              </.form>
            </section>

            <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 overflow-hidden">
              <h2 class="text-lg font-semibold text-slate-900 mb-4"><%= gettext("Eventos recientes") %></h2>
              <div class="overflow-x-auto rounded-lg border border-slate-200">
                <table class="min-w-full">
                  <thead>
                    <tr class="bg-slate-50 border-b border-slate-200">
                      <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">ID</th>
                      <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700"><%= gettext("Topic") %></th>
                      <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700"><%= gettext("Estado") %></th>
                      <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700 hidden sm:table-cell"><%= gettext("Fecha") %></th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for e <- @events do %>
                      <tr class="border-b border-slate-100 last:border-0">
                        <td class="px-3 sm:px-4 py-2 sm:py-3 font-mono text-xs sm:text-sm text-slate-600">{String.slice(e.id, 0, 8)}...</td>
                        <td class="px-3 sm:px-4 py-2 sm:py-3 text-sm text-slate-700 truncate max-w-[8rem] sm:max-w-none">{e.topic || "—"}</td>
                        <td class="px-3 sm:px-4 py-2 sm:py-3"><span class="px-2 py-0.5 rounded text-xs font-medium bg-slate-100 text-slate-700">{e.status}</span></td>
                        <td class="px-3 sm:px-4 py-2 sm:py-3 text-sm text-slate-600 hidden sm:table-cell">{format_dt(e.occurred_at)}</td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </section>

            <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 overflow-hidden">
              <h2 class="text-lg font-semibold text-slate-900 mb-4"><%= gettext("Webhooks") %></h2>
              <div class="overflow-x-auto rounded-lg border border-slate-200">
                <table class="min-w-full">
                  <thead>
                    <tr class="bg-slate-50 border-b border-slate-200">
                      <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">URL</th>
                      <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700"><%= gettext("Estado") %></th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for w <- @webhooks do %>
                      <tr class="border-b border-slate-100 last:border-0">
                        <td class="px-3 sm:px-4 py-2 sm:py-3 font-mono text-xs sm:text-sm text-slate-600 truncate max-w-[12rem] sm:max-w-none">{w.url}</td>
                        <td class="px-3 sm:px-4 py-2 sm:py-3"><span class="px-2 py-0.5 rounded text-xs font-medium bg-slate-100 text-slate-700">{w.status}</span></td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </section>

            <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 overflow-hidden">
              <div class="flex flex-wrap items-center justify-between gap-3 sm:gap-4 mb-4 sm:mb-6">
                <h2 class="text-lg font-semibold text-slate-900"><%= gettext("Jobs") %></h2>
                <button
                  type="button"
                  phx-click="new_job"
                  phx-disable-with={gettext("Cargando...")}
                  class="inline-flex items-center gap-2 px-3 sm:px-4 py-2 sm:py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl font-medium text-sm shadow-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
                >
                  <.icon name="hero-plus" class="w-4 h-4" />
                  <%= gettext("Nuevo job") %>
                </button>
              </div>
              <div class="overflow-x-auto rounded-xl border border-slate-200">
                <table class="min-w-full divide-y divide-slate-200">
                  <thead>
                    <tr class="bg-slate-50/80">
                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider"><%= gettext("Nombre") %></th>
                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider hidden sm:table-cell"><%= gettext("Programación") %></th>
                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider hidden sm:table-cell"><%= gettext("Acción") %></th>
                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider"><%= gettext("Estado") %></th>
                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-right text-xs font-semibold text-slate-600 uppercase tracking-wider"><%= gettext("Acciones") %></th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-slate-100">
                    <%= for j <- @jobs do %>
                      <tr class="hover:bg-slate-50/50 transition">
                        <td class="px-3 sm:px-5 py-3 sm:py-4 font-medium text-slate-800 text-sm">{j.name}</td>
                        <td class="px-3 sm:px-5 py-3 sm:py-4 text-sm text-slate-600 hidden sm:table-cell">{j.schedule_type}</td>
                        <td class="px-3 sm:px-5 py-3 sm:py-4 text-sm text-slate-600 hidden sm:table-cell">{j.action_type}</td>
                        <td class="px-3 sm:px-5 py-3 sm:py-4">
                          <span class={["inline-flex px-2 sm:px-2.5 py-0.5 sm:py-1 rounded-lg text-xs font-medium", if(j.status == "active", do: "bg-emerald-100 text-emerald-800", else: "bg-slate-200 text-slate-600")]}>
                            {j.status}
                          </span>
                        </td>
                        <td class="px-3 sm:px-5 py-3 sm:py-4 text-right">
                          <div class="flex flex-col sm:flex-row sm:inline-flex gap-1 sm:gap-2 items-end sm:items-center">
                            <button phx-click="edit_job" phx-value-id={j.id} phx-disable-with={gettext("Cargando...")} class="text-indigo-600 hover:text-indigo-700 font-medium text-xs sm:text-sm disabled:opacity-70"><%= gettext("Editar") %></button>
                            <button phx-click="show_job_runs" phx-value-id={j.id} phx-disable-with={gettext("Cargando...")} class="text-slate-600 hover:text-slate-700 font-medium text-xs sm:text-sm disabled:opacity-70"><%= gettext("Runs") %></button>
                            <%= if j.status == "active" do %>
                              <button phx-click="deactivate_job" phx-value-id={j.id} phx-disable-with={gettext("Desactivando...")} class="text-red-600 hover:text-red-700 font-medium text-xs sm:text-sm disabled:opacity-70"><%= gettext("Desactivar") %></button>
                            <% end %>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </section>

            <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 overflow-hidden">
              <h2 class="text-lg font-semibold text-slate-900 mb-4 sm:mb-6"><%= gettext("Entregas") %></h2>
              <div class="overflow-x-auto rounded-xl border border-slate-200">
                <table class="min-w-full divide-y divide-slate-200">
                  <thead>
                    <tr class="bg-slate-50/80">
                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider"><%= gettext("Evento / Topic") %></th>
                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider hidden md:table-cell"><%= gettext("Webhook") %></th>
                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider"><%= gettext("Estado") %></th>
                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider hidden lg:table-cell"><%= gettext("Intento") %></th>
                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider hidden sm:table-cell"><%= gettext("HTTP") %></th>
                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider hidden sm:table-cell"><%= gettext("Fecha") %></th>
                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-right text-xs font-semibold text-slate-600 uppercase tracking-wider"><%= gettext("Acciones") %></th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-slate-100">
                    <%= for d <- @deliveries do %>
                      <tr class="hover:bg-slate-50/50 transition">
                        <td class="px-3 sm:px-5 py-3 sm:py-4 text-xs sm:text-sm text-slate-600 font-mono truncate max-w-[8rem] sm:max-w-none">{if d.event, do: d.event.topic || String.slice(d.event_id, 0, 8), else: String.slice(d.event_id, 0, 8)}</td>
                        <td class="px-3 sm:px-5 py-3 sm:py-4 font-mono text-xs text-slate-600 max-w-[14rem] truncate hidden md:table-cell">{if d.webhook, do: d.webhook.url, else: d.webhook_id}</td>
                        <td class="px-3 sm:px-5 py-3 sm:py-4"><span class={["inline-flex px-2 sm:px-2.5 py-0.5 sm:py-1 rounded-lg text-xs font-medium", if(d.status == "success", do: "bg-emerald-100 text-emerald-800", else: if(d.status == "pending", do: "bg-amber-100 text-amber-800", else: "bg-red-100 text-red-800"))]}>{d.status}</span></td>
                        <td class="px-3 sm:px-5 py-3 sm:py-4 text-sm text-slate-600 hidden lg:table-cell">{d.attempt_number}</td>
                        <td class="px-3 sm:px-5 py-3 sm:py-4 text-sm text-slate-600 font-mono hidden sm:table-cell">{d.response_status || "—"}</td>
                        <td class="px-3 sm:px-5 py-3 sm:py-4 text-sm text-slate-600 hidden sm:table-cell">{format_dt(d.inserted_at)}</td>
                        <td class="px-3 sm:px-5 py-3 sm:py-4 text-right">
                          <%= if d.status != "success" and d.status != "pending" do %>
                            <button phx-click="retry_delivery" phx-value-id={d.id} phx-disable-with={gettext("Reintentando...")} class="text-indigo-600 hover:text-indigo-700 font-medium text-xs sm:text-sm disabled:opacity-70"><%= gettext("Reintentar") %></button>
                          <% end %>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </section>

            <%!-- Job form modal: backdrop and modal are siblings so clicking inside modal doesn't close --%>
            <%= if @job_modal do %>
              <div class="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6" id="job-modal-container">
                <div class="absolute inset-0 bg-slate-900/60 backdrop-blur-sm transition-opacity" phx-click="close_job_modal" id="job-modal-backdrop" aria-hidden="true"></div>
                <div class="relative z-10 w-full max-w-3xl max-h-[90vh] overflow-hidden bg-white rounded-2xl shadow-2xl flex flex-col border border-slate-200/50" id="job-modal-content" role="dialog" aria-modal="true" aria-labelledby="job-modal-title">
                  <div class="flex-shrink-0 px-4 sm:px-6 py-4 sm:py-5 border-b border-slate-200 bg-slate-50/80 flex justify-between items-center">
                    <h2 id="job-modal-title" class="text-lg sm:text-xl font-semibold text-slate-900"><%= if @job_modal == :new, do: gettext("Nuevo job"), else: gettext("Editar job") %></h2>
                    <button type="button" phx-click="close_job_modal" class="p-2 -m-2 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-200/60 transition" aria-label={gettext("Cerrar")}>
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
                        <label class="block text-sm font-medium text-slate-700 mb-1.5"><%= gettext("Nombre") %></label>
                        <input type="text" name="name" value={p["name"]} required class="w-full border border-slate-300 rounded-xl px-3 sm:px-4 py-2 sm:py-2.5 text-slate-900 placeholder-slate-400 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition text-sm sm:text-base" placeholder={gettext("Ej: Reporte diario")} />
                      </div>

                      <div class="border-t border-slate-200 pt-6">
                        <h3 class="text-sm font-semibold text-slate-800 mb-4"><%= gettext("Programación") %></h3>
                        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                          <div>
                            <label class="block text-sm font-medium text-slate-600 mb-1.5"><%= gettext("Tipo") %></label>
                            <select name="schedule_type" class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 bg-white focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500">
                              <option value="daily" selected={p["schedule_type"] == "daily"}><%= gettext("Diario") %></option>
                              <option value="weekly" selected={p["schedule_type"] == "weekly"}><%= gettext("Semanal") %></option>
                              <option value="monthly" selected={p["schedule_type"] == "monthly"}><%= gettext("Mensual") %></option>
                              <option value="cron" selected={p["schedule_type"] == "cron"}><%= gettext("Cron") %></option>
                            </select>
                          </div>
                          <div>
                            <label class="block text-sm font-medium text-slate-600 mb-1.5"><%= gettext("Hora (0-23)") %></label>
                            <input type="number" name="schedule_hour" value={p["schedule_hour"]} min="0" max="23" class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" />
                          </div>
                          <div>
                            <label class="block text-sm font-medium text-slate-600 mb-1.5"><%= gettext("Minuto") %></label>
                            <input type="number" name="schedule_minute" value={p["schedule_minute"]} min="0" max="59" class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" />
                          </div>
                          <div>
                            <label class="block text-sm font-medium text-slate-600 mb-1.5"><%= gettext("Día semana (1-7, 1=Lun)") %></label>
                            <input type="number" name="schedule_day_of_week" value={p["schedule_day_of_week"]} min="1" max="7" class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" />
                          </div>
                          <div>
                            <label class="block text-sm font-medium text-slate-600 mb-1.5"><%= gettext("Día del mes (1-31)") %></label>
                            <input type="number" name="schedule_day_of_month" value={p["schedule_day_of_month"]} min="1" max="31" class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" />
                          </div>
                          <div>
                            <label class="block text-sm font-medium text-slate-600 mb-1.5"><%= gettext("Expresión cron") %></label>
                            <input type="text" name="schedule_cron" value={p["schedule_cron"]} placeholder="0 0 * * *" class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 font-mono text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" />
                          </div>
                        </div>
                      </div>

                      <div class="border-t border-slate-200 pt-6">
                        <h3 class="text-sm font-semibold text-slate-800 mb-4"><%= gettext("Acción") %></h3>
                        <div class="space-y-4">
                          <div>
                            <label class="block text-sm font-medium text-slate-600 mb-1.5"><%= gettext("Tipo de acción") %></label>
                            <select name="action_type" class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 bg-white focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500">
                              <option value="emit_event" selected={p["action_type"] == "emit_event"}><%= gettext("Emitir evento") %></option>
                              <option value="post_url" selected={p["action_type"] == "post_url"}><%= gettext("POST URL") %></option>
                            </select>
                          </div>
                          <div>
                            <label class="block text-sm font-medium text-slate-600 mb-1.5"><%= gettext("Topic (emit_event)") %></label>
                            <input type="text" name="action_topic" value={p["action_topic"]} class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 placeholder-slate-400 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" placeholder="mi.topic" />
                          </div>
                          <div>
                            <label class="block text-sm font-medium text-slate-600 mb-1.5"><%= gettext("Payload JSON (emit_event)") %></label>
                            <textarea name="action_payload" rows="4" class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 font-mono text-sm placeholder-slate-400 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500">{p["action_payload"]}</textarea>
                          </div>
                          <div>
                            <label class="block text-sm font-medium text-slate-600 mb-1.5"><%= gettext("URL (post_url)") %></label>
                            <input type="url" name="action_url" value={p["action_url"]} class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 placeholder-slate-400 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" placeholder="https://..." />
                          </div>
                          <div>
                            <label class="block text-sm font-medium text-slate-600 mb-1.5"><%= gettext("Método HTTP") %></label>
                            <select name="action_method" class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 bg-white focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500">
                              <option value="POST" selected={p["action_method"] == "POST"}>POST</option>
                              <option value="GET">GET</option>
                              <option value="PUT">PUT</option>
                              <option value="PATCH">PATCH</option>
                            </select>
                          </div>
                          <%= if @job_modal != :new do %>
                            <div>
                              <label class="block text-sm font-medium text-slate-600 mb-1.5"><%= gettext("Estado") %></label>
                              <select name="status" class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 bg-white focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500">
                                <option value="active" selected={p["status"] == "active"}><%= gettext("Activo") %></option>
                                <option value="inactive" selected={p["status"] == "inactive"}><%= gettext("Inactivo") %></option>
                              </select>
                            </div>
                          <% end %>
                        </div>
                      </div>

                      <div class="flex flex-wrap justify-end gap-3 pt-4 border-t border-slate-200">
                        <button type="button" phx-click="close_job_modal" class="px-5 py-2.5 border border-slate-300 rounded-xl text-slate-700 hover:bg-slate-50 font-medium transition"><%= gettext("Cancelar") %></button>
                        <button type="submit" phx-disable-with={gettext("Guardando...")} class="px-5 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl font-medium shadow-sm transition disabled:opacity-70 disabled:cursor-not-allowed"><%= gettext("Guardar") %></button>
                      </div>
                    </div>
                  </.form>
                </div>
              </div>
            <% end %>

            <%!-- Job runs modal: backdrop and modal siblings --%>
            <%= if @job_runs_modal do %>
              <div class="fixed inset-0 z-50 flex items-center justify-center p-4" id="job-runs-modal-container">
                <div class="absolute inset-0 bg-slate-900/60 backdrop-blur-sm" phx-click="close_job_runs_modal" aria-hidden="true"></div>
                <div class="relative z-10 w-full max-w-2xl max-h-[80vh] overflow-hidden bg-white rounded-2xl shadow-2xl flex flex-col border border-slate-200/50 mx-4" role="dialog" aria-modal="true">
                  <div class="p-4 border-b flex justify-between items-center">
                    <h2 class="text-lg font-semibold text-slate-900"><%= gettext("Runs: %{name}", name: @job_runs_modal.job.name) %></h2>
                    <button type="button" phx-click="close_job_runs_modal" class="text-slate-400 hover:text-slate-600"><.icon name="hero-x-mark" class="w-6 h-6" /></button>
                  </div>
                  <div class="overflow-y-auto flex-1 p-4">
                    <table class="min-w-full">
                      <thead>
                        <tr class="bg-slate-50 border-b">
                          <th class="px-4 py-2 text-left text-sm font-medium text-slate-700"><%= gettext("Ejecutado") %></th>
                          <th class="px-4 py-2 text-left text-sm font-medium text-slate-700"><%= gettext("Estado") %></th>
                          <th class="px-4 py-2 text-left text-sm font-medium text-slate-700"><%= gettext("Resultado") %></th>
                        </tr>
                      </thead>
                      <tbody>
                        <%= for r <- @job_runs_modal.runs do %>
                          <tr class="border-b border-slate-100">
                            <td class="px-4 py-2 text-sm text-slate-600">{format_dt(r.executed_at)}</td>
                            <td class="px-4 py-2"><span class={["px-2 py-0.5 rounded text-xs", if(r.status == "success", do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800")]}>{r.status}</span></td>
                            <td class="px-4 py-2 text-sm text-slate-600">{if r.result, do: Jason.encode!(r.result), else: "—"}</td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                    <%= if @job_runs_modal.runs == [] do %>
                      <p class="text-slate-500 py-4"><%= gettext("Sin ejecuciones aún.") %></p>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <p class="text-slate-600"><%= gettext("No hay proyecto para tu cuenta. Contacta soporte.") %></p>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp to_str(n) when is_integer(n), do: Integer.to_string(n)
  defp to_str(s) when is_binary(s), do: s
  defp to_str(_), do: "0"

  defp build_schedule_config(params) do
    type = params["schedule_type"] || "daily"
    case type do
      "daily" -> %{"hour" => parse_int(params["schedule_hour"], 0), "minute" => parse_int(params["schedule_minute"], 0)}
      "weekly" -> %{"day_of_week" => parse_int(params["schedule_day_of_week"], 1), "hour" => parse_int(params["schedule_hour"], 0), "minute" => parse_int(params["schedule_minute"], 0)}
      "monthly" -> %{"day_of_month" => parse_int(params["schedule_day_of_month"], 1), "hour" => parse_int(params["schedule_hour"], 0), "minute" => parse_int(params["schedule_minute"], 0)}
      "cron" -> %{"expr" => params["schedule_cron"] || "0 0 * * *"}
      _ -> %{}
    end
  end

  defp build_action_config(params) do
    type = params["action_type"] || "emit_event"
    case type do
      "emit_event" ->
        payload = case Jason.decode(params["action_payload"] || "{}") do
          {:ok, m} -> m
          _ -> %{}
        end
        %{"topic" => params["action_topic"] || "", "payload" => payload}
      "post_url" -> %{"url" => params["action_url"] || "", "method" => params["action_method"] || "POST"}
      _ -> %{}
    end
  end

  defp parse_int(s, d) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> n
      _ -> d
    end
  end
  defp parse_int(_, d), do: d

  defp format_dt(nil), do: "—"
  defp format_dt(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
end
