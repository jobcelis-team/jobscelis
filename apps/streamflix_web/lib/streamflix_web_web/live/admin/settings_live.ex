defmodule StreamflixWebWeb.Admin.SettingsLive do
  use StreamflixWebWeb, :live_view

  alias StreamflixCore.Settings

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Configuración")
      |> assign(:settings, load_settings())
      |> assign(:pricing, load_pricing())

    {:ok, socket}
  end

  @impl true
  def handle_event("save_settings", params, socket) do
    # Save general settings
    Settings.set("platform.name", params["platform_name"], category: "platform")
    Settings.set("platform.support_email", params["support_email"], category: "platform")
    Settings.set("platform.maintenance_mode", params["maintenance_mode"] == "true", category: "platform", value_type: "boolean")
    
    # Save streaming settings
    Settings.set("streaming.default_quality", params["default_quality"], category: "streaming")
    Settings.set("streaming.max_streams", String.to_integer(params["max_streams"] || "4"), category: "streaming", value_type: "integer")
    Settings.set("streaming.allow_downloads", params["allow_downloads"] == "true", category: "streaming", value_type: "boolean")
    
    # Save storage settings
    Settings.set("platform.azure_account", params["azure_account"], category: "platform")
    Settings.set("platform.cdn_endpoint", params["cdn_endpoint"], category: "platform")
    Settings.set("storage.container_videos", params["container_videos"], category: "storage")
    Settings.set("storage.container_thumbnails", params["container_thumbnails"], category: "storage")
    
    # Save pricing
    Settings.set_plan_price("basic", String.to_float(params["price_basic"] || "8.99"))
    Settings.set_plan_price("standard", String.to_float(params["price_standard"] || "13.99"))
    Settings.set_plan_price("premium", String.to_float(params["price_premium"] || "17.99"))

    socket =
      socket
      |> assign(:settings, load_settings())
      |> assign(:pricing, load_pricing())
      |> put_flash(:info, "Configuración guardada exitosamente")

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100">
      <.admin_sidebar active="settings" />

      <div class="ml-64 p-8">
        <h1 class="text-3xl font-bold text-gray-900 mb-8">Configuración</h1>

        <form id="settings-form" phx-submit="save_settings">
          <div class="space-y-6">
            <!-- General Settings -->
            <div class="bg-white rounded-lg shadow">
              <div class="p-6 border-b">
                <h2 class="text-lg font-semibold">General</h2>
              </div>
              <div class="p-6 space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Nombre de la plataforma</label>
                  <input type="text" name="platform_name" value={@settings.platform_name} class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Email de soporte</label>
                  <input type="email" name="support_email" value={@settings.support_email} class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white" />
                </div>
                <div class="flex items-center justify-between">
                  <div>
                    <p class="font-medium">Modo mantenimiento</p>
                    <p class="text-sm text-gray-500">Desactiva el acceso público temporalmente</p>
                  </div>
                  <label class="relative inline-flex items-center cursor-pointer">
                    <input type="checkbox" name="maintenance_mode" checked={@settings.maintenance_mode} class="sr-only peer" value="true" />
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
                <select name="default_quality" class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white">
                  <option value="auto" selected={@settings.default_quality == "auto"}>Automática</option>
                  <option value="4k" selected={@settings.default_quality == "4k"}>4K Ultra HD</option>
                  <option value="1080p" selected={@settings.default_quality == "1080p"}>1080p Full HD</option>
                  <option value="720p" selected={@settings.default_quality == "720p"}>720p HD</option>
                  <option value="480p" selected={@settings.default_quality == "480p"}>480p SD</option>
                </select>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Streams simultáneos máximos</label>
                <input type="number" name="max_streams" value={@settings.max_streams} class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white" />
              </div>
              <div class="flex items-center justify-between">
                <div>
                  <p class="font-medium">Permitir descargas</p>
                  <p class="text-sm text-gray-500">Usuarios pueden descargar contenido offline</p>
                </div>
                <label class="relative inline-flex items-center cursor-pointer">
                  <input type="checkbox" name="allow_downloads" checked={@settings.allow_downloads} class="sr-only peer" value="true" />
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
                <input type="text" name="azure_account" value={@settings.azure_account} class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">CDN Endpoint</label>
                <input type="text" name="cdn_endpoint" value={@settings.cdn_endpoint} class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white" />
              </div>
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Container Videos</label>
                  <input type="text" name="container_videos" value={@settings.container_videos} class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Container Thumbnails</label>
                  <input type="text" name="container_thumbnails" value={@settings.container_thumbnails} class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white" />
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
                    <input type="number" name="price_basic" value={Float.to_string(@pricing.basic)} step="0.01" class="w-24 border border-gray-300 rounded px-2 py-1 text-gray-900 bg-white" />
                    <span>/mes</span>
                  </div>
                </div>
                <div class="border rounded-lg p-4">
                  <h3 class="font-medium mb-2">Estándar</h3>
                  <div class="flex items-center gap-2">
                    <span>$</span>
                    <input type="number" name="price_standard" value={Float.to_string(@pricing.standard)} step="0.01" class="w-24 border border-gray-300 rounded px-2 py-1 text-gray-900 bg-white" />
                    <span>/mes</span>
                  </div>
                </div>
                <div class="border rounded-lg p-4">
                  <h3 class="font-medium mb-2">Premium</h3>
                  <div class="flex items-center gap-2">
                    <span>$</span>
                    <input type="number" name="price_premium" value={Float.to_string(@pricing.premium)} step="0.01" class="w-24 border border-gray-300 rounded px-2 py-1 text-gray-900 bg-white" />
                    <span>/mes</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

            <!-- Save Button -->
            <div class="flex justify-end">
              <button type="submit" class="bg-red-600 hover:bg-red-700 text-white px-8 py-3 rounded-lg font-medium">
                Guardar cambios
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>
    """
  end

  defp admin_sidebar(assigns), do: StreamflixWebWeb.Admin.DashboardLive.admin_sidebar(assigns)

  defp load_settings do
    %{
      platform_name: Settings.get("platform.name", "StreamFlix"),
      support_email: Settings.get("platform.support_email", "soporte@streamflix.com"),
      maintenance_mode: Settings.get("platform.maintenance_mode", false),
      default_quality: Settings.get("streaming.default_quality", "auto"),
      max_streams: Settings.get("streaming.max_streams", 4),
      allow_downloads: Settings.get("streaming.allow_downloads", true),
      azure_account: Settings.get("platform.azure_account", "streamflix"),
      cdn_endpoint: Settings.get("platform.cdn_endpoint", "https://streamflix.blob.core.windows.net"),
      container_videos: Settings.get("storage.container_videos", "videos"),
      container_thumbnails: Settings.get("storage.container_thumbnails", "thumbnails")
    }
  end

  defp load_pricing do
    %{
      basic: Settings.get_plan_price("basic"),
      standard: Settings.get_plan_price("standard"),
      premium: Settings.get_plan_price("premium")
    }
  end
end
