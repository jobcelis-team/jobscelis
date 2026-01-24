defmodule StreamflixWebWeb.AccountLive do
  use StreamflixWebWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Cuenta")
      |> assign(:user, demo_user())
      |> assign(:subscription, demo_subscription())

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100 text-gray-900">
      <!-- Header -->
      <header class="bg-white border-b">
        <div class="container mx-auto px-4 py-4 flex items-center justify-between">
          <a href="/browse" class="text-red-600 text-3xl font-bold">STREAMFLIX</a>
          <div class="flex items-center space-x-4">
            <span class="text-gray-600"><%= @user.email %></span>
            <a href="/profiles" class="w-8 h-8 rounded bg-red-600"></a>
          </div>
        </div>
      </header>

      <main class="container mx-auto px-4 py-8 max-w-4xl">
        <h1 class="text-3xl font-medium mb-8">Cuenta</h1>

        <!-- Membership -->
        <section class="bg-white rounded-lg shadow mb-6">
          <div class="p-6 border-b">
            <h2 class="text-xl font-medium text-gray-500 mb-4">MEMBRESÍA Y FACTURACIÓN</h2>

            <div class="flex justify-between items-start">
              <div>
                <p class="font-semibold"><%= @user.email %></p>
                <p class="text-gray-500">Contraseña: ********</p>
              </div>
              <div class="space-y-2 text-right">
                <a href="#" class="block text-blue-600 hover:underline">Cambiar email</a>
                <a href="#" class="block text-blue-600 hover:underline">Cambiar contraseña</a>
              </div>
            </div>
          </div>

          <div class="p-6 border-b">
            <div class="flex justify-between items-center">
              <div>
                <p class="text-gray-500">Próximo cobro: <%= @subscription.next_billing_date %></p>
                <p class="font-semibold">$<%= @subscription.price %>/mes</p>
              </div>
              <a href="#" class="text-blue-600 hover:underline">Administrar método de pago</a>
            </div>
          </div>

          <div class="p-6">
            <div class="flex justify-between items-center">
              <span>Facturación electrónica</span>
              <a href="#" class="text-blue-600 hover:underline">Ver historial</a>
            </div>
          </div>
        </section>

        <!-- Plan -->
        <section class="bg-white rounded-lg shadow mb-6">
          <div class="p-6">
            <h2 class="text-xl font-medium text-gray-500 mb-4">DETALLES DEL PLAN</h2>

            <div class="flex justify-between items-center">
              <div>
                <p class="font-semibold"><%= @subscription.plan_name %></p>
                <div class="flex items-center gap-2 mt-1">
                  <span class="bg-gray-200 px-2 py-0.5 rounded text-sm">Ultra HD</span>
                  <span class="bg-gray-200 px-2 py-0.5 rounded text-sm">HDR</span>
                </div>
              </div>
              <a href="#" class="text-blue-600 hover:underline">Cambiar plan</a>
            </div>
          </div>
        </section>

        <!-- Security -->
        <section class="bg-white rounded-lg shadow mb-6">
          <div class="p-6">
            <h2 class="text-xl font-medium text-gray-500 mb-4">SEGURIDAD Y PRIVACIDAD</h2>

            <div class="space-y-4">
              <div class="flex justify-between items-center">
                <span>Controlar acceso a dispositivos</span>
                <a href="#" class="text-blue-600 hover:underline">Administrar</a>
              </div>
              <div class="flex justify-between items-center">
                <span>Cerrar sesión en todos los dispositivos</span>
                <button class="text-blue-600 hover:underline">Cerrar sesión</button>
              </div>
              <div class="flex justify-between items-center">
                <span>Descargar tu información personal</span>
                <a href="#" class="text-blue-600 hover:underline">Descargar</a>
              </div>
            </div>
          </div>
        </section>

        <!-- Profiles -->
        <section class="bg-white rounded-lg shadow">
          <div class="p-6">
            <h2 class="text-xl font-medium text-gray-500 mb-4">PERFILES</h2>

            <div class="space-y-4">
              <%= for profile <- @user.profiles do %>
                <div class="flex items-center justify-between py-2 border-b last:border-0">
                  <div class="flex items-center gap-4">
                    <div class={"w-12 h-12 rounded flex items-center justify-center #{profile.color}"}>
                      <span class="text-xl text-white font-bold"><%= String.first(profile.name) %></span>
                    </div>
                    <div>
                      <p class="font-medium"><%= profile.name %></p>
                      <p class="text-sm text-gray-500"><%= profile.type %></p>
                    </div>
                  </div>
                  <a href="#" class="text-blue-600 hover:underline">Editar</a>
                </div>
              <% end %>
            </div>
          </div>
        </section>

        <!-- Cancel -->
        <div class="mt-8 text-center">
          <a href="#" class="text-gray-500 hover:text-gray-700">Cancelar membresía</a>
        </div>
      </main>
    </div>
    """
  end

  defp demo_user do
    %{
      email: "usuario@example.com",
      profiles: [
        %{name: "Principal", color: "bg-red-600", type: "Todos los públicos"},
        %{name: "Niños", color: "bg-yellow-500", type: "Niños"},
        %{name: "Invitado", color: "bg-blue-600", type: "Todos los públicos"}
      ]
    }
  end

  defp demo_subscription do
    %{
      plan_name: "Premium",
      price: "17.99",
      next_billing_date: "15 de febrero, 2026"
    }
  end
end
