defmodule StreamflixWebWeb.Admin.ProjectsLive do
  @moduledoc "Admin: list all projects and view one project (read-only)."
  use StreamflixWebWeb, :live_view

  alias StreamflixCore.Platform
  alias StreamflixAccounts

  @impl true
  def mount(params, _session, socket) do
    view_id = params["id"]
    page_title = if view_id, do: gettext("Proyecto"), else: gettext("Proyectos")
    socket =
      socket
      |> assign(:page_title, page_title)
      |> assign(:current_user_role, socket.assigns.current_user.role)
      |> assign(:view_id, view_id)
      |> assign(:projects, [])
      |> assign(:loading, true)
      |> assign(:project, nil)
      |> assign(:project_user_email, nil)
      |> assign(:project_events, [])
      |> assign(:project_webhooks, [])
      |> assign(:project_jobs, [])
      |> assign(:project_deliveries, [])

    if connected?(socket) do
      if view_id, do: send(self(), {:load_project, view_id}), else: send(self(), :load)
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    view_id = params["id"]
    socket = assign(socket, :view_id, view_id)

    socket =
      if view_id do
        send(self(), {:load_project, view_id})
        socket
        |> assign(:page_title, gettext("Proyecto"))
        |> assign(:loading, true)
      else
        send(self(), :load)
        assign(socket, :page_title, gettext("Proyectos"))
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info(:load, socket) do
    projects =
      Platform.list_projects(include_inactive: true)
      |> Enum.map(fn p ->
        user = if p.user_id, do: StreamflixAccounts.get_user(p.user_id), else: nil
        %{
          id: p.id,
          name: p.name,
          status: p.status,
          inserted_at: p.inserted_at,
          user_email: if(user, do: user.email, else: nil)
        }
      end)

    {:noreply,
     socket
     |> assign(:projects, projects)
     |> assign(:loading, false)}
  end

  @impl true
  def handle_info({:load_project, id}, socket) do
    project = Platform.get_project(id)
    socket =
      if project do
        events = Platform.list_events(project.id, limit: 30)
        webhooks = Platform.list_webhooks(project.id, include_inactive: true)
        jobs = Platform.list_jobs(project.id, include_inactive: true)
        deliveries = Platform.list_deliveries(project_id: project.id, limit: 30)
        user = if project.user_id, do: StreamflixAccounts.get_user(project.user_id), else: nil

        socket
        |> assign(:project, project)
        |> assign(:project_user_email, if(user, do: user.email, else: nil))
        |> assign(:project_events, events)
        |> assign(:project_webhooks, webhooks)
        |> assign(:project_jobs, jobs)
        |> assign(:project_deliveries, deliveries)
        |> assign(:loading, false)
      else
        socket
        |> put_flash(:error, gettext("Proyecto no encontrado"))
        |> assign(:project, nil)
        |> assign(:loading, false)
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100">
      <.admin_sidebar active="projects" current_user_role={@current_user_role} />

      <div class="ml-64 p-8">
        <%= if @view_id do %>
          <.project_show
            project={@project}
            user_email={@project_user_email}
            events={@project_events}
            webhooks={@project_webhooks}
            jobs={@project_jobs}
            deliveries={@project_deliveries}
            loading={@loading}
          />
        <% else %>
          <.projects_index projects={@projects} loading={@loading} />
        <% end %>
      </div>
    </div>
    """
  end

  defp projects_index(assigns) do
    ~H"""
    <h1 class="text-3xl font-bold text-gray-900 mb-8"><%= gettext("Proyectos") %></h1>

    <%= if @loading do %>
      <p class="text-gray-500"><%= gettext("Cargando...") %></p>
    <% else %>
      <div class="bg-white rounded-lg shadow overflow-hidden">
        <table class="w-full">
          <thead class="bg-gray-50 border-b">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"><%= gettext("Proyecto") %></th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"><%= gettext("Usuario") %></th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"><%= gettext("Estado") %></th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"><%= gettext("Creado") %></th>
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase"><%= gettext("Ver") %></th>
            </tr>
          </thead>
          <tbody class="divide-y">
            <%= for p <- @projects do %>
              <tr class="hover:bg-gray-50">
                <td class="px-6 py-4 font-medium text-gray-900"><%= p.name %></td>
                <td class="px-6 py-4 text-gray-600"><%= p.user_email || "—" %></td>
                <td class="px-6 py-4">
                  <span class={[
                    "px-2 py-1 rounded text-xs",
                    if(p.status == "active", do: "bg-green-100 text-green-800", else: "bg-gray-200 text-gray-700")
                  ]}>
                    <%= p.status %>
                  </span>
                </td>
                <td class="px-6 py-4 text-gray-500 text-sm"><%= format_date(p.inserted_at) %></td>
                <td class="px-6 py-4 text-right">
                  <.link navigate={"/admin/projects/#{p.id}"} class="text-blue-600 hover:underline">
                    <%= gettext("Ver") %>
                  </.link>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @projects == [] do %>
          <div class="p-8 text-center text-gray-500"><%= gettext("No hay proyectos.") %></div>
        <% end %>
      </div>
    <% end %>
    """
  end

  defp project_show(assigns) do
    ~H"""
    <div class="space-y-8">
      <.link navigate="/admin/projects" class="text-blue-600 hover:underline text-sm">
        ← <%= gettext("Volver a proyectos") %>
      </.link>

      <%= if @project do %>
        <div class="bg-white rounded-lg shadow p-6">
          <h1 class="text-2xl font-bold text-gray-900 mb-2"><%= @project.name %></h1>
          <p class="text-gray-600">
            <%= gettext("Usuario") %>: <%= @user_email || "—" %>
          </p>
          <p class="text-sm text-gray-500 mt-1">
            ID: {@project.id} · <%= gettext("Estado") %>: <%= @project.status %>
          </p>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div class="bg-white rounded-lg shadow overflow-hidden">
            <div class="p-4 border-b font-medium"><%= gettext("Eventos recientes") %> (<%= length(@events) %>)</div>
            <div class="max-h-64 overflow-y-auto divide-y">
              <%= for e <- @events do %>
                <div class="p-3 text-sm">
                  <span class="font-mono text-gray-600"><%= e.topic || "—" %></span>
                  <span class="text-gray-400 ml-2"><%= format_date(e.occurred_at) %></span>
                </div>
              <% end %>
              <%= if @events == [] do %>
                <div class="p-4 text-gray-500"><%= gettext("Sin eventos") %></div>
              <% end %>
            </div>
          </div>

          <div class="bg-white rounded-lg shadow overflow-hidden">
            <div class="p-4 border-b font-medium"><%= gettext("Webhooks") %> (<%= length(@webhooks) %>)</div>
            <div class="max-h-64 overflow-y-auto divide-y">
              <%= for w <- @webhooks do %>
                <div class="p-3 text-sm">
                  <span class={if(w.status == "active", do: "text-green-700", else: "text-gray-500")}>
                    <%= w.url %>
                  </span>
                  <span class="text-gray-400 ml-2"><%= w.status %></span>
                </div>
              <% end %>
              <%= if @webhooks == [] do %>
                <div class="p-4 text-gray-500"><%= gettext("Sin webhooks") %></div>
              <% end %>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div class="bg-white rounded-lg shadow overflow-hidden">
            <div class="p-4 border-b font-medium"><%= gettext("Jobs") %> (<%= length(@jobs) %>)</div>
            <div class="max-h-64 overflow-y-auto divide-y">
              <%= for j <- @jobs do %>
                <div class="p-3 text-sm">
                  <span><%= j.name || j.id %></span>
                  <span class="text-gray-400 ml-2"><%= j.schedule_type %> · <%= j.status %></span>
                </div>
              <% end %>
              <%= if @jobs == [] do %>
                <div class="p-4 text-gray-500"><%= gettext("Sin jobs") %></div>
              <% end %>
            </div>
          </div>

          <div class="bg-white rounded-lg shadow overflow-hidden">
            <div class="p-4 border-b font-medium"><%= gettext("Entregas recientes") %> (<%= length(@deliveries) %>)</div>
            <div class="max-h-64 overflow-y-auto divide-y">
              <%= for d <- @deliveries do %>
                <div class="p-3 text-sm flex justify-between">
                  <span><%= d.status %></span>
                  <span class="text-gray-500"><%= if d.response_status, do: d.response_status, else: "—" %></span>
                  <span class="text-gray-400"><%= format_date(d.inserted_at) %></span>
                </div>
              <% end %>
              <%= if @deliveries == [] do %>
                <div class="p-4 text-gray-500"><%= gettext("Sin entregas") %></div>
              <% end %>
            </div>
          </div>
        </div>
      <% else %>
        <%= if @loading do %>
          <p class="text-gray-500"><%= gettext("Cargando...") %></p>
        <% else %>
          <p class="text-gray-500"><%= gettext("Proyecto no encontrado.") %></p>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp admin_sidebar(assigns), do: StreamflixWebWeb.Admin.DashboardLive.admin_sidebar(assigns)

  defp format_date(nil), do: "—"
  defp format_date(datetime), do: Calendar.strftime(datetime, "%d %b %Y %H:%M")
end
