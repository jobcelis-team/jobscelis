defmodule StreamflixWebWeb.Admin.DashboardLive do
  use StreamflixWebWeb, :live_view

  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixAccounts.Schemas.User

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    socket =
      socket
      |> assign(:page_title, "Admin Dashboard")
      |> assign(:current_user_role, user.role)
      |> assign(:stats, get_stats())
      |> assign(:recent_users, get_recent_users())

    if connected?(socket) do
      send(self(), :load_data)
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(:load_data, socket) do
    {:noreply,
     socket
     |> assign(:stats, get_stats())
     |> assign(:recent_users, get_recent_users())}
  end

  @impl true
  def handle_event("logout", _, socket) do
    {:noreply, redirect(socket, to: "/logout", external: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100">
      <.admin_sidebar active="dashboard" current_user_role={@current_user_role} />

      <div class="ml-64 p-8">
        <h1 class="text-3xl font-bold text-gray-900 mb-8">Dashboard</h1>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <div class="bg-white rounded-lg shadow p-6">
            <p class="text-sm text-gray-500">Usuarios</p>
            <p class="text-2xl font-bold">{@stats.total_users}</p>
          </div>
          <div class="bg-white rounded-lg shadow p-6">
            <p class="text-sm text-gray-500">Proyectos</p>
            <p class="text-2xl font-bold">{@stats.total_projects}</p>
          </div>
          <div class="bg-white rounded-lg shadow p-6">
            <p class="text-sm text-gray-500">Eventos (total)</p>
            <p class="text-2xl font-bold">{@stats.total_events}</p>
          </div>
        </div>

        <div class="bg-white rounded-lg shadow">
          <div class="p-6 border-b flex justify-between items-center">
            <h2 class="text-lg font-semibold">Usuarios recientes</h2>
            <.link navigate="/admin/users" class="text-blue-600 hover:underline text-sm">Ver todos</.link>
          </div>
          <div class="divide-y">
            <%= for user <- @recent_users do %>
              <div class="p-4 flex items-center justify-between">
                <div>
                  <p class="font-medium"><%= user.name || user.email %></p>
                  <p class="text-sm text-gray-500"><%= user.email %></p>
                </div>
                <span class="px-2 py-1 rounded text-xs bg-gray-100"><%= user.role %></span>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def admin_sidebar(assigns) do
    ~H"""
    <aside class="fixed left-0 top-0 bottom-0 w-64 bg-gray-900 text-white">
      <div class="p-6">
        <.link navigate="/" class="text-red-500 text-2xl font-bold">Platform</.link>
        <p class="text-gray-500 text-sm mt-1">Panel Admin</p>
        <%= if @current_user_role do %>
          <span class={"inline-block mt-2 px-2 py-0.5 rounded text-xs font-medium #{if @current_user_role == "superadmin", do: "bg-amber-600 text-white", else: "bg-gray-600 text-gray-200"}"}>
            <%= if @current_user_role == "superadmin", do: "Superadmin", else: "Admin" %>
          </span>
        <% end %>
      </div>
      <nav class="mt-6">
        <.link navigate="/admin" class={"flex items-center px-6 py-3 #{if @active == "dashboard", do: "bg-gray-800 text-white", else: "text-gray-400 hover:bg-gray-800"}"}>
          Dashboard
        </.link>
        <.link navigate="/admin/users" class={"flex items-center px-6 py-3 #{if @active == "users", do: "bg-gray-800 text-white", else: "text-gray-400 hover:bg-gray-800"}"}>
          Usuarios
        </.link>
        <.link navigate="/admin/settings" class={"flex items-center px-6 py-3 #{if @active == "settings", do: "bg-gray-800 text-white", else: "text-gray-400 hover:bg-gray-800"}"}>
          Configuración
        </.link>
      </nav>
      <div class="absolute bottom-0 left-0 right-0 p-6 border-t border-gray-800">
        <.link navigate="/platform" class="text-gray-400 hover:text-white">Ir al dashboard</.link>
        <button phx-click="logout" class="block mt-2 text-gray-400 hover:text-white w-full text-left">
          Cerrar sesión
        </button>
      </div>
    </aside>
    """
  end

  defp get_stats do
    alias StreamflixCore.Schemas.{Project, WebhookEvent}
    total_users = Repo.aggregate(User, :count)
    total_projects = Repo.aggregate(Project, :count)
    total_events = Repo.aggregate(WebhookEvent, :count)
    %{total_users: total_users, total_projects: total_projects, total_events: total_events}
  end

  defp get_recent_users do
    User
    |> order_by([u], desc: u.inserted_at)
    |> limit(10)
    |> Repo.all()
    |> Enum.map(fn u -> %{name: u.name, email: u.email, role: u.role} end)
  end
end
