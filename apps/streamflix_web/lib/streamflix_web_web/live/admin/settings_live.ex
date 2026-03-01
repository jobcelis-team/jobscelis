defmodule StreamflixWebWeb.Admin.SettingsLive do
  use StreamflixWebWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    socket =
      socket
      |> assign(:page_title, gettext("Configuración"))
      |> assign(:current_user_role, user.role)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_layout active="settings" current_user_role={@current_user_role}>
      <h1 class="text-2xl sm:text-3xl font-bold text-gray-900 mb-6 sm:mb-8">
        {gettext("Configuración")}
      </h1>

      <div class="bg-white rounded-lg shadow p-4 sm:p-6">
        <p class="text-gray-600">
          {gettext(
            "La configuración de la plataforma (base de datos, Oban, etc.) se gestiona desde config/config.exs y config/runtime.exs."
          )}
        </p>

        <p class="text-gray-600 mt-4">
          {gettext("Para usuarios, proyectos, webhooks y eventos utiliza el dashboard en")} <.link
            navigate="/platform"
            class="text-indigo-600 hover:underline"
          >/platform</.link>.
        </p>
      </div>
    </.admin_layout>
    """
  end

  defp admin_layout(assigns), do: StreamflixWebWeb.Admin.DashboardLive.admin_layout(assigns)
end
