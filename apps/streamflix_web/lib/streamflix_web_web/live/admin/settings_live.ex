defmodule StreamflixWebWeb.Admin.SettingsLive do
  use StreamflixWebWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    socket =
      socket
      |> assign(:page_title, "Configuración")
      |> assign(:current_user_role, user.role)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100">
      <.admin_sidebar active="settings" current_user_role={@current_user_role} />

      <div class="ml-64 p-8">
        <h1 class="text-3xl font-bold text-gray-900 mb-8">Configuración</h1>

        <div class="bg-white rounded-lg shadow p-6 max-w-2xl">
          <p class="text-gray-600">
            La configuración de la plataforma (base de datos, Oban, etc.) se gestiona desde
            <code class="bg-gray-100 px-1 rounded">config/config.exs</code> y
            <code class="bg-gray-100 px-1 rounded">config/runtime.exs</code>.
          </p>
          <p class="text-gray-600 mt-4">
            Para usuarios, proyectos, webhooks y eventos utiliza el dashboard en
            <.link navigate="/platform" class="text-red-600 hover:underline">/platform</.link>.
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp admin_sidebar(assigns), do: StreamflixWebWeb.Admin.DashboardLive.admin_sidebar(assigns)
end
