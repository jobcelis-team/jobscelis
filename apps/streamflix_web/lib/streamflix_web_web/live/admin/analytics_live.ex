defmodule StreamflixWebWeb.Admin.AnalyticsLive do
  use StreamflixWebWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Analíticas")
      |> assign(:period, "7d")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100">
      <.admin_sidebar active="analytics" />

      <div class="ml-64 p-8">
        <div class="flex justify-between items-center mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Analíticas</h1>
          <select class="border border-gray-300 rounded-lg px-4 py-2">
            <option value="7d">Últimos 7 días</option>
            <option value="30d">Últimos 30 días</option>
            <option value="90d">Últimos 90 días</option>
            <option value="1y">Último año</option>
          </select>
        </div>

        <!-- Metrics Grid -->
        <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <div class="bg-white rounded-lg shadow p-6">
            <p class="text-sm text-gray-500 mb-1">Reproducciones</p>
            <p class="text-3xl font-bold">1.2M</p>
            <p class="text-sm text-green-500">+15.3%</p>
          </div>
          <div class="bg-white rounded-lg shadow p-6">
            <p class="text-sm text-gray-500 mb-1">Horas vistas</p>
            <p class="text-3xl font-bold">456K</p>
            <p class="text-sm text-green-500">+8.7%</p>
          </div>
          <div class="bg-white rounded-lg shadow p-6">
            <p class="text-sm text-gray-500 mb-1">Usuarios activos</p>
            <p class="text-3xl font-bold">12.4K</p>
            <p class="text-sm text-green-500">+5.2%</p>
          </div>
          <div class="bg-white rounded-lg shadow p-6">
            <p class="text-sm text-gray-500 mb-1">Tasa de retención</p>
            <p class="text-3xl font-bold">87%</p>
            <p class="text-sm text-red-500">-1.3%</p>
          </div>
        </div>

        <!-- Charts -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-lg font-semibold mb-4">Reproducciones por día</h2>
            <div class="h-64 flex items-end justify-between gap-1">
              <%= for value <- chart_data() do %>
                <div class="flex-1 bg-blue-500 rounded-t" style={"height: #{value}%"}></div>
              <% end %>
            </div>
          </div>
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-lg font-semibold mb-4">Dispositivos</h2>
            <div class="space-y-4">
              <div>
                <div class="flex justify-between mb-1"><span>Smart TV</span><span>45%</span></div>
                <div class="h-2 bg-gray-200 rounded-full"><div class="h-full bg-blue-500 rounded-full w-[45%]"></div></div>
              </div>
              <div>
                <div class="flex justify-between mb-1"><span>Móvil</span><span>30%</span></div>
                <div class="h-2 bg-gray-200 rounded-full"><div class="h-full bg-green-500 rounded-full w-[30%]"></div></div>
              </div>
              <div>
                <div class="flex justify-between mb-1"><span>Web</span><span>15%</span></div>
                <div class="h-2 bg-gray-200 rounded-full"><div class="h-full bg-purple-500 rounded-full w-[15%]"></div></div>
              </div>
              <div>
                <div class="flex justify-between mb-1"><span>Tablet</span><span>10%</span></div>
                <div class="h-2 bg-gray-200 rounded-full"><div class="h-full bg-yellow-500 rounded-full w-[10%]"></div></div>
              </div>
            </div>
          </div>
        </div>

        <!-- Top Content -->
        <div class="bg-white rounded-lg shadow">
          <div class="p-6 border-b">
            <h2 class="text-lg font-semibold">Contenido más visto</h2>
          </div>
          <table class="w-full">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">#</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Título</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Tipo</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Reproducciones</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Horas</th>
              </tr>
            </thead>
            <tbody class="divide-y">
              <%= for {content, idx} <- Enum.with_index(top_content(), 1) do %>
                <tr>
                  <td class="px-6 py-4 font-medium"><%= idx %></td>
                  <td class="px-6 py-4"><%= content.title %></td>
                  <td class="px-6 py-4"><%= content.type %></td>
                  <td class="px-6 py-4"><%= content.views %></td>
                  <td class="px-6 py-4"><%= content.hours %></td>
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

  defp chart_data, do: [45, 62, 78, 55, 89, 95, 72, 68, 82, 91, 76, 84, 69, 77]

  defp top_content do
    [
      %{title: "El Último Viaje", type: "Película", views: "125K", hours: "187K"},
      %{title: "Misterios del Mar", type: "Serie", views: "98K", hours: "456K"},
      %{title: "Ciudad Nocturna", type: "Serie", views: "87K", hours: "324K"},
      %{title: "Aventuras Espaciales", type: "Película", views: "76K", hours: "114K"},
      %{title: "El Secreto", type: "Película", views: "65K", hours: "97K"}
    ]
  end
end
