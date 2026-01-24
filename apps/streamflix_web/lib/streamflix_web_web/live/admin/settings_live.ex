defmodule StreamflixWebWeb.Admin.SettingsLive do
  use StreamflixWebWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Configuración")
      |> assign(:settings, default_settings())

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100">
      <.admin_sidebar active="settings" />

      <div class="ml-64 p-8">
        <h1 class="text-3xl font-bold text-gray-900 mb-8">Configuración</h1>

        <div class="space-y-6">
          <!-- General Settings -->
          <div class="bg-white rounded-lg shadow">
            <div class="p-6 border-b">
              <h2 class="text-lg font-semibold">General</h2>
            </div>
            <div class="p-6 space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Nombre de la plataforma</label>
                <input type="text" value={@settings.platform_name} class="w-full border border-gray-300 rounded-lg px-4 py-2" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Email de soporte</label>
                <input type="email" value={@settings.support_email} class="w-full border border-gray-300 rounded-lg px-4 py-2" />
              </div>
              <div class="flex items-center justify-between">
                <div>
                  <p class="font-medium">Modo mantenimiento</p>
                  <p class="text-sm text-gray-500">Desactiva el acceso público temporalmente</p>
                </div>
                <label class="relative inline-flex items-center cursor-pointer">
                  <input type="checkbox" checked={@settings.maintenance_mode} class="sr-only peer" />
                  <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-red-600"></div>
                </label>
              </div>
            </div>
          </div>

          <!-- Streaming Settings -->
          <div class="bg-white rounded-lg shadow">
            <div class="p-6 border-b">
              <h2 class="text-lg font-semibold">Streaming</h2>
            </div>
            <div class="p-6 space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Calidad por defecto</label>
                <select class="w-full border border-gray-300 rounded-lg px-4 py-2">
                  <option value="auto">Automática</option>
                  <option value="4k">4K Ultra HD</option>
                  <option value="1080p">1080p Full HD</option>
                  <option value="720p">720p HD</option>
                  <option value="480p">480p SD</option>
                </select>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Streams simultáneos máximos</label>
                <input type="number" value={@settings.max_streams} class="w-full border border-gray-300 rounded-lg px-4 py-2" />
              </div>
              <div class="flex items-center justify-between">
                <div>
                  <p class="font-medium">Permitir descargas</p>
                  <p class="text-sm text-gray-500">Usuarios pueden descargar contenido offline</p>
                </div>
                <label class="relative inline-flex items-center cursor-pointer">
                  <input type="checkbox" checked={@settings.allow_downloads} class="sr-only peer" />
                  <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-red-600"></div>
                </label>
              </div>
            </div>
          </div>

          <!-- Storage Settings -->
          <div class="bg-white rounded-lg shadow">
            <div class="p-6 border-b">
              <h2 class="text-lg font-semibold">Almacenamiento (Azure)</h2>
            </div>
            <div class="p-6 space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Azure Storage Account</label>
                <input type="text" value={@settings.azure_account} class="w-full border border-gray-300 rounded-lg px-4 py-2" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">CDN Endpoint</label>
                <input type="text" value={@settings.cdn_endpoint} class="w-full border border-gray-300 rounded-lg px-4 py-2" />
              </div>
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Container Videos</label>
                  <input type="text" value={@settings.container_videos} class="w-full border border-gray-300 rounded-lg px-4 py-2" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Container Thumbnails</label>
                  <input type="text" value={@settings.container_thumbnails} class="w-full border border-gray-300 rounded-lg px-4 py-2" />
                </div>
              </div>
            </div>
          </div>

          <!-- Pricing -->
          <div class="bg-white rounded-lg shadow">
            <div class="p-6 border-b">
              <h2 class="text-lg font-semibold">Precios</h2>
            </div>
            <div class="p-6">
              <div class="grid grid-cols-3 gap-6">
                <div class="border rounded-lg p-4">
                  <h3 class="font-medium mb-2">Básico</h3>
                  <div class="flex items-center gap-2">
                    <span>$</span>
                    <input type="number" value="8.99" step="0.01" class="w-24 border border-gray-300 rounded px-2 py-1" />
                    <span>/mes</span>
                  </div>
                </div>
                <div class="border rounded-lg p-4">
                  <h3 class="font-medium mb-2">Estándar</h3>
                  <div class="flex items-center gap-2">
                    <span>$</span>
                    <input type="number" value="13.99" step="0.01" class="w-24 border border-gray-300 rounded px-2 py-1" />
                    <span>/mes</span>
                  </div>
                </div>
                <div class="border rounded-lg p-4">
                  <h3 class="font-medium mb-2">Premium</h3>
                  <div class="flex items-center gap-2">
                    <span>$</span>
                    <input type="number" value="17.99" step="0.01" class="w-24 border border-gray-300 rounded px-2 py-1" />
                    <span>/mes</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Save Button -->
          <div class="flex justify-end">
            <button class="bg-red-600 hover:bg-red-700 text-white px-8 py-3 rounded-lg font-medium">
              Guardar cambios
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp admin_sidebar(assigns), do: StreamflixWebWeb.Admin.DashboardLive.admin_sidebar(assigns)

  defp default_settings do
    %{
      platform_name: "StreamFlix",
      support_email: "soporte@streamflix.com",
      maintenance_mode: false,
      max_streams: 4,
      allow_downloads: true,
      azure_account: "streamflix",
      cdn_endpoint: "https://streamflix.blob.core.windows.net",
      container_videos: "videos",
      container_thumbnails: "thumbnails"
    }
  end
end
