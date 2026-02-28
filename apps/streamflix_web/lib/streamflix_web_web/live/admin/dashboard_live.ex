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
    <.admin_layout active="dashboard" current_user_role={@current_user_role}>
      <h1 class="text-2xl sm:text-3xl font-bold text-gray-900 mb-6 sm:mb-8"><%= gettext("Dashboard") %></h1>

      <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4 sm:gap-6 mb-6 sm:mb-8">
        <div class="bg-white rounded-lg shadow p-4 sm:p-6">
          <p class="text-sm text-gray-500"><%= gettext("Usuarios") %></p>
          <p class="text-2xl font-bold">{@stats.total_users}</p>
        </div>
        <div class="bg-white rounded-lg shadow p-4 sm:p-6">
          <p class="text-sm text-gray-500"><%= gettext("Proyectos") %></p>
          <p class="text-2xl font-bold">{@stats.total_projects}</p>
        </div>
        <div class="bg-white rounded-lg shadow p-4 sm:p-6">
          <p class="text-sm text-gray-500"><%= gettext("Eventos (total)") %></p>
          <p class="text-2xl font-bold">{@stats.total_events}</p>
        </div>
      </div>

      <div class="bg-white rounded-lg shadow overflow-hidden">
        <div class="p-4 sm:p-6 border-b flex flex-col sm:flex-row sm:justify-between sm:items-center gap-2">
          <h2 class="text-lg font-semibold"><%= gettext("Usuarios recientes") %></h2>
          <.link navigate="/admin/users" class="text-blue-600 hover:underline text-sm"><%= gettext("Ver todos") %></.link>
        </div>
        <div class="divide-y">
          <%= for user <- @recent_users do %>
            <div class="p-3 sm:p-4 flex items-center justify-between gap-3">
              <div class="min-w-0">
                <p class="font-medium truncate"><%= user.name || user.email %></p>
                <p class="text-sm text-gray-500 truncate"><%= user.email %></p>
              </div>
              <span class="px-2 py-1 rounded text-xs bg-gray-100 shrink-0"><%= user.role %></span>
            </div>
          <% end %>
        </div>
      </div>
    </.admin_layout>
    """
  end

  def admin_layout(assigns) do
    assigns = assign_new(assigns, :inner_block, fn -> [] end)

    ~H"""
    <div class="min-h-screen bg-gray-100">
      <%!-- Mobile backdrop --%>
      <div
        id="admin-backdrop"
        class="fixed inset-0 bg-black/50 z-30 hidden md:hidden"
        phx-click={JS.add_class("-translate-x-full", to: "#admin-sidebar") |> JS.add_class("hidden", to: "#admin-backdrop")}
      ></div>

      <%!-- Sidebar --%>
      <aside
        id="admin-sidebar"
        class="fixed left-0 inset-y-0 w-64 bg-gray-900 text-white z-40 -translate-x-full md:translate-x-0 transition-transform duration-200"
      >
        <%!-- Mobile close button --%>
        <button
          class="md:hidden absolute top-4 right-4 p-1 text-gray-400 hover:text-white rounded-lg hover:bg-gray-800 transition"
          phx-click={JS.add_class("-translate-x-full", to: "#admin-sidebar") |> JS.add_class("hidden", to: "#admin-backdrop")}
          aria-label={gettext("Cerrar menú")}
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>
        </button>

        <div class="p-6">
          <.link navigate="/" class="flex items-center gap-2 text-white text-xl font-bold" aria-label={gettext("Jobcelis - Ir al inicio")}>
            <img src={~p"/images/logo.png"} alt="" class="h-8 w-auto" width="32" height="32" />
            Jobcelis
          </.link>
          <p class="text-gray-500 text-sm mt-1"><%= gettext("Panel Admin") %></p>
          <%= if @current_user_role do %>
            <span class={"inline-block mt-2 px-2 py-0.5 rounded text-xs font-medium #{if @current_user_role == "superadmin", do: "bg-amber-600 text-white", else: "bg-gray-600 text-gray-200"}"}>
              <%= if @current_user_role == "superadmin", do: "Superadmin", else: gettext("Admin") %>
            </span>
          <% end %>
        </div>
        <nav class="mt-6">
          <.link navigate="/admin" class={"flex items-center px-6 py-3 text-sm #{if @active == "dashboard", do: "bg-gray-800 text-white", else: "text-gray-400 hover:bg-gray-800 hover:text-white transition"}"}>
            <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" /></svg>
            <%= gettext("Dashboard") %>
          </.link>
          <.link navigate="/admin/users" class={"flex items-center px-6 py-3 text-sm #{if @active == "users", do: "bg-gray-800 text-white", else: "text-gray-400 hover:bg-gray-800 hover:text-white transition"}"}>
            <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" /></svg>
            <%= gettext("Usuarios") %>
          </.link>
          <.link navigate="/admin/projects" class={"flex items-center px-6 py-3 text-sm #{if @active == "projects", do: "bg-gray-800 text-white", else: "text-gray-400 hover:bg-gray-800 hover:text-white transition"}"}>
            <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z" /></svg>
            <%= gettext("Proyectos") %>
          </.link>
          <.link navigate="/admin/settings" class={"flex items-center px-6 py-3 text-sm #{if @active == "settings", do: "bg-gray-800 text-white", else: "text-gray-400 hover:bg-gray-800 hover:text-white transition"}"}>
            <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.066 2.573c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.573 1.066c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.066-2.573c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
            <%= gettext("Configuración") %>
          </.link>
        </nav>
        <div class="absolute bottom-0 left-0 right-0 p-6 border-t border-gray-800">
          <.link navigate="/platform" class="text-gray-400 hover:text-white text-sm transition"><%= gettext("Ir al dashboard") %></.link>
          <button phx-click="logout" phx-disable-with={gettext("Cargando...")} class="block mt-2 text-gray-400 hover:text-white w-full text-left text-sm transition disabled:opacity-70">
            <%= gettext("Cerrar sesión") %>
          </button>
        </div>
      </aside>

      <%!-- Content area --%>
      <div class="md:ml-64 min-h-screen flex flex-col">
        <%!-- Mobile header --%>
        <div class="md:hidden sticky top-0 z-20 bg-white border-b border-gray-200 px-4 py-3 flex items-center gap-3">
          <button
            class="p-2 rounded-lg text-gray-600 hover:bg-gray-100 transition"
            phx-click={JS.remove_class("-translate-x-full", to: "#admin-sidebar") |> JS.remove_class("hidden", to: "#admin-backdrop")}
            aria-label={gettext("Abrir menú")}
          >
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" /></svg>
          </button>
          <span class="font-semibold text-gray-900"><%= gettext("Admin") %></span>
        </div>

        <div class="p-4 sm:p-6 md:p-8 flex-1">
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
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
