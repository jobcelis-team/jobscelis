defmodule StreamflixWebWeb.Admin.UsersLive do
  use StreamflixWebWeb, :live_view

  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixAccounts.Schemas.User

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Usuarios")
      |> assign(:users, [])
      |> assign(:loading, true)
      |> assign(:search, "")

    if connected?(socket) do
      send(self(), :load_users)
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(:load_users, socket) do
    users = load_users_from_db()
    
    socket =
      socket
      |> assign(:users, users)
      |> assign(:loading, false)

    {:noreply, socket}
  end

  defp load_users_from_db do
    User
    |> order_by([u], desc: u.inserted_at)
    |> limit(100)
    |> Repo.all()
    |> Enum.map(fn user ->
      subscription = StreamflixAccounts.get_active_subscription(user.id)
      %{
        id: user.id,
        name: user.name,
        email: user.email,
        plan: subscription && String.capitalize(subscription.plan) || "Sin Plan",
        registered: format_date(user.inserted_at),
        active: user.status == "active"
      }
    end)
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d %b %Y")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100">
      <.admin_sidebar active="users" />

      <div class="ml-64 p-8">
        <h1 class="text-3xl font-bold text-gray-900 mb-8">Usuarios</h1>

        <!-- Search -->
        <div class="bg-white rounded-lg shadow p-4 mb-6">
          <input
            type="text"
            placeholder="Buscar usuarios..."
            class="w-full border border-gray-300 rounded-lg px-4 py-2"
          />
        </div>

        <!-- Users Table -->
        <div class="bg-white rounded-lg shadow overflow-hidden">
          <table class="w-full">
            <thead class="bg-gray-50 border-b">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Usuario</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Plan</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Registrado</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Estado</th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Acciones</th>
              </tr>
            </thead>
            <tbody class="divide-y">
              <%= for user <- @users do %>
                <tr class="hover:bg-gray-50">
                  <td class="px-6 py-4">
                    <div class="flex items-center gap-3">
                      <div class="w-10 h-10 rounded-full bg-gray-300 flex items-center justify-center">
                        <span class="font-medium text-gray-600"><%= String.first(user.name) %></span>
                      </div>
                      <div>
                        <p class="font-medium"><%= user.name %></p>
                        <p class="text-sm text-gray-500"><%= user.email %></p>
                      </div>
                    </div>
                  </td>
                  <td class="px-6 py-4">
                    <span class={"px-2 py-1 rounded text-xs #{plan_class(user.plan)}"}><%= user.plan %></span>
                  </td>
                  <td class="px-6 py-4 text-gray-500"><%= user.registered %></td>
                  <td class="px-6 py-4">
                    <span class={"px-2 py-1 rounded text-xs #{if user.active, do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800"}"}>
                      <%= if user.active, do: "Activo", else: "Inactivo" %>
                    </span>
                  </td>
                  <td class="px-6 py-4 text-right">
                    <button class="text-blue-600 hover:text-blue-800 mr-2">Editar</button>
                    <button class="text-red-600 hover:text-red-800">Suspender</button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  defp admin_sidebar(assigns), do: StreamflixWebWeb.Admin.DashboardLive.admin_sidebar(assigns)

  defp plan_class("Premium"), do: "bg-purple-100 text-purple-800"
  defp plan_class("Standard"), do: "bg-blue-100 text-blue-800"
  defp plan_class("Basic"), do: "bg-gray-100 text-gray-800"
  defp plan_class(_), do: "bg-gray-100 text-gray-800"
end
