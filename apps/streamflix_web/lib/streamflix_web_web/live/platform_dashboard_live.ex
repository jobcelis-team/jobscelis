defmodule StreamflixWebWeb.PlatformDashboardLive do
  use StreamflixWebWeb, :live_view

  alias StreamflixCore.Platform

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    project = Platform.get_project_by_user_id(user.id)
    api_key = if project, do: Platform.get_api_key_for_project(project.id), else: nil
    events = if project, do: Platform.list_events(project.id, limit: 20), else: []
    webhooks = if project, do: Platform.list_webhooks(project.id), else: []

    socket =
      socket
      |> assign(:project, project)
      |> assign(:api_key, api_key)
      |> assign(:events, events)
      |> assign(:webhooks, webhooks)
      |> assign(:test_topic, "")
      |> assign(:test_payload, "{}")
      |> assign(:new_token, nil)
      |> assign(:token_visible, true)
      |> assign(:editing_project_name, false)
      |> assign(:page_title, "Jobscelis Dashboard")

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
        put_flash(socket, :info, "Event sent. ID: #{event.id}")
        assign(socket, :events, events)
      {:error, _} ->
        put_flash(socket, :error, "Failed to send event")
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
        put_flash(socket, :error, "El nombre no puede estar vacío.")
        |> assign(:editing_project_name, false)
      else
        case Platform.update_project(project, %{name: name}) do
          {:ok, updated} ->
            socket
            |> put_flash(:info, "Nombre del proyecto actualizado.")
            |> assign(:project, updated)
            |> assign(:editing_project_name, false)
          {:error, _} ->
            put_flash(socket, :error, "No se pudo actualizar el nombre.")
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
          |> put_flash(:info, "Nuevo token generado. El token anterior ya no funciona. Guárdalo; solo se muestra esta vez.")
          |> assign(:api_key, api_key)
          |> assign(:new_token, raw_key)
          |> assign(:token_visible, true)
        {:noreply, socket}
      _ ->
        {:noreply, put_flash(socket, :error, "No se pudo regenerar el token.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={:platform} current_user={@current_user}>
      <div>
        <h1 class="text-2xl font-bold text-slate-900 mb-8">Dashboard</h1>

        <%= if @project do %>
          <div class="space-y-8">
            <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-6">
              <h2 class="text-lg font-semibold text-slate-900 mb-2">Proyecto</h2>
              <%= if @editing_project_name do %>
                <.form for={%{}} id="project-name-form" phx-submit="update_project_name" class="flex flex-wrap items-center gap-2">
                  <.input
                    type="text"
                    name="name"
                    value={@project.name}
                    class="w-full max-w-xs px-3 py-2 bg-white border border-slate-300 rounded-lg text-slate-900"
                    placeholder="Nombre del proyecto"
                  />
                  <button type="submit" class="px-3 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-sm font-medium">
                    Guardar
                  </button>
                  <button type="button" phx-click="cancel_edit_project_name" class="px-3 py-2 bg-slate-200 hover:bg-slate-300 text-slate-800 rounded-lg text-sm font-medium">
                    Cancelar
                  </button>
                </.form>
              <% else %>
                <p class="text-slate-600">
                  <strong>{@project.name}</strong>
                  <button type="button" phx-click="edit_project_name" class="ml-2 text-indigo-600 hover:text-indigo-700 text-sm font-medium">
                    Editar nombre
                  </button>
                </p>
              <% end %>
              <p class="text-slate-500 text-sm font-mono mt-1">{@project.id}</p>
            </section>

            <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-6">
              <h2 class="text-lg font-semibold text-slate-900 mb-1">API Token</h2>
              <p class="text-slate-500 text-sm mb-2">Header: <code class="bg-slate-100 px-1 rounded text-xs">Authorization: Bearer &lt;token&gt;</code> o <code class="bg-slate-100 px-1 rounded text-xs">X-Api-Key</code></p>
              <div class="bg-slate-50 border border-slate-200 rounded-lg px-3 py-2 mb-4 text-slate-600 text-sm">
                <strong class="text-slate-700">Cómo funciona:</strong> Al hacer «Regenerar token» se crea un token nuevo y se muestra <strong>solo una vez</strong>. El servidor no guarda el valor completo (por seguridad), solo un prefijo. Si recargas la página solo verás el prefijo; guarda el token cuando lo regeneres (por ejemplo en un .env o gestor de contraseñas).
              </div>
              <%= if @api_key do %>
                <div class="rounded-lg border border-slate-200 bg-slate-50 max-w-2xl">
                  <%= if @new_token do %>
                    <div class="flex items-stretch gap-0 overflow-hidden">
                      <input
                        type="text"
                        readonly
                        value={if @token_visible, do: @new_token, else: "••••••••••••••••••••••••••••••••••••••"}
                        class="flex-1 min-w-0 font-mono text-sm px-4 py-3 bg-transparent border-0 text-slate-900 focus:ring-0"
                        phx-no-feedback
                      />
                      <button
                        type="button"
                        phx-click="toggle_token_visibility"
                        class="p-3 border-l border-slate-200 bg-white hover:bg-slate-50 text-slate-500 hover:text-slate-700 transition"
                        title={if @token_visible, do: "Ocultar", else: "Mostrar"}
                        aria-label={if @token_visible, do: "Ocultar token", else: "Mostrar token"}
                      >
                        <%= if @token_visible do %>
                          <.icon name="hero-eye-slash" class="w-5 h-5" />
                        <% else %>
                          <.icon name="hero-eye" class="w-5 h-5" />
                        <% end %>
                      </button>
                    </div>
                  <% else %>
                    <input
                      type="text"
                      readonly
                      value={@api_key.prefix}
                      class="w-full font-mono text-sm px-4 py-3 bg-transparent border-0 text-slate-600 focus:ring-0"
                      aria-label="Prefijo del token (valor completo solo al regenerar)"
                    />
                  <% end %>
                </div>
                <%= if @new_token do %>
                  <p class="text-amber-700 text-sm mt-2">El token anterior ya no sirve. Solo este token es válido. Guárdalo; solo se muestra esta vez.</p>
                <% else %>
                  <p class="text-slate-500 text-sm mt-2">Solo el token actual es válido. El valor completo solo se muestra al regenerar.</p>
                <% end %>
                <button
                  phx-click="regenerate_token"
                  type="button"
                  class="mt-4 px-4 py-2 bg-slate-200 hover:bg-slate-300 text-slate-800 rounded-lg font-medium text-sm transition"
                >
                  Regenerar token
                </button>
              <% else %>
                <p class="text-slate-600 mb-3">No hay API key.</p>
                <button
                  phx-click="regenerate_token"
                  type="button"
                  class="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg font-medium text-sm transition"
                >
                  Generar token
                </button>
              <% end %>
            </section>

            <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-6">
              <h2 class="text-lg font-semibold text-slate-900 mb-4">Enviar evento de prueba</h2>
              <.form for={%{}} id="test-event-form" phx-submit="send_test" class="space-y-3 max-w-lg">
                <.input type="text" name="topic" id="test-topic" value={@test_topic} placeholder="Topic (opcional)" class="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg text-slate-900 placeholder-slate-400 font-mono text-sm" />
                <.input type="textarea" name="payload" id="test-payload" value={@test_payload} class="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg text-slate-900 placeholder-slate-400 font-mono text-sm" />
                <button type="submit" class="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg font-medium text-sm transition">
                  Enviar
                </button>
              </.form>
            </section>

            <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-6">
              <h2 class="text-lg font-semibold text-slate-900 mb-4">Eventos recientes</h2>
              <div class="overflow-x-auto rounded-lg border border-slate-200">
                <table class="min-w-full">
                  <thead>
                    <tr class="bg-slate-50 border-b border-slate-200">
                      <th class="px-4 py-3 text-left text-sm font-medium text-slate-700">ID</th>
                      <th class="px-4 py-3 text-left text-sm font-medium text-slate-700">Topic</th>
                      <th class="px-4 py-3 text-left text-sm font-medium text-slate-700">Estado</th>
                      <th class="px-4 py-3 text-left text-sm font-medium text-slate-700">Fecha</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for e <- @events do %>
                      <tr class="border-b border-slate-100 last:border-0">
                        <td class="px-4 py-3 font-mono text-sm text-slate-600">{String.slice(e.id, 0, 8)}...</td>
                        <td class="px-4 py-3 text-slate-700">{e.topic || "—"}</td>
                        <td class="px-4 py-3"><span class="px-2 py-0.5 rounded text-xs font-medium bg-slate-100 text-slate-700">{e.status}</span></td>
                        <td class="px-4 py-3 text-sm text-slate-600">{format_dt(e.occurred_at)}</td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </section>

            <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-6">
              <h2 class="text-lg font-semibold text-slate-900 mb-4">Webhooks</h2>
              <div class="overflow-x-auto rounded-lg border border-slate-200">
                <table class="min-w-full">
                  <thead>
                    <tr class="bg-slate-50 border-b border-slate-200">
                      <th class="px-4 py-3 text-left text-sm font-medium text-slate-700">URL</th>
                      <th class="px-4 py-3 text-left text-sm font-medium text-slate-700">Estado</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for w <- @webhooks do %>
                      <tr class="border-b border-slate-100 last:border-0">
                        <td class="px-4 py-3 font-mono text-sm text-slate-600">{w.url}</td>
                        <td class="px-4 py-3"><span class="px-2 py-0.5 rounded text-xs font-medium bg-slate-100 text-slate-700">{w.status}</span></td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </section>
          </div>
        <% else %>
          <p class="text-slate-600">No hay proyecto para tu cuenta. Contacta soporte.</p>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp format_dt(nil), do: "—"
  defp format_dt(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")
end
