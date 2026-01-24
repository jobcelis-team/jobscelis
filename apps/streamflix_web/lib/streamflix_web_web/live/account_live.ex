defmodule StreamflixWebWeb.AccountLive do
  use StreamflixWebWeb, :live_view

  alias StreamflixAccounts
  alias StreamflixCore.Settings

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    
    # Load user with profiles
    user_with_profiles = StreamflixAccounts.get_user_with_profiles(user.id)
    
    # Get active subscription
    subscription = StreamflixAccounts.get_active_subscription(user.id)
    
    socket =
      socket
      |> assign(:page_title, "Cuenta")
      |> assign(:user, user_with_profiles)
      |> assign(:subscription, format_subscription(subscription))
      |> assign(:loading, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("logout", _, socket) do
    {:noreply, redirect(socket, to: "/logout", external: true)}
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
                <button phx-click="logout" class="text-blue-600 hover:underline">Cerrar sesión</button>
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
              <%= if Enum.empty?(@user.profiles || []) do %>
                <p class="text-gray-500">No hay perfiles creados. <a href="/profiles" class="text-blue-600 hover:underline">Crear perfil</a></p>
              <% else %>
                <%= for profile <- @user.profiles do %>
                  <div class="flex items-center justify-between py-2 border-b last:border-0">
                    <div class="flex items-center gap-4">
                      <div class={"w-12 h-12 rounded flex items-center justify-center #{profile_color(profile)}"}>
                        <span class="text-xl text-white font-bold"><%= String.first(profile.name || "?") %></span>
                      </div>
                      <div>
                        <p class="font-medium"><%= profile.name %></p>
                        <p class="text-sm text-gray-500"><%= profile_type_label(profile) %></p>
                      </div>
                    </div>
                    <a href="/profiles" class="text-blue-600 hover:underline">Editar</a>
                  </div>
                <% end %>
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

  defp format_subscription(nil) do
    %{
      plan_name: "Sin Plan",
      price: "0.00",
      next_billing_date: "N/A"
    }
  end

  defp format_subscription(subscription) do
    plan_name = String.capitalize(subscription.plan || "Sin Plan")
    price = get_plan_price(subscription.plan)
    
    next_billing_date = 
      if subscription.current_period_end do
        format_date(subscription.current_period_end)
      else
        "N/A"
      end

    %{
      plan_name: plan_name,
      price: price,
      next_billing_date: next_billing_date
    }
  end

  defp get_plan_price(plan) do
    price = Settings.get_plan_price(plan)
    :erlang.float_to_binary(price, [{:decimals, 2}])
  end

  defp format_date(date) do
    Calendar.strftime(date, "%d de %B, %Y")
  end

  defp profile_color(profile) do
    # Generate color based on profile name hash
    colors = ["bg-red-600", "bg-blue-600", "bg-green-600", "bg-yellow-500", "bg-purple-600", "bg-pink-600"]
    index = :erlang.phash2(profile.name || "default") |> rem(length(colors))
    Enum.at(colors, index)
  end

  defp profile_type_label(profile) do
    cond do
      profile.is_kids -> "Niños"
      profile.maturity_level == "all" -> "Todos los públicos"
      profile.maturity_level == "pg" -> "PG"
      profile.maturity_level == "pg13" -> "PG-13"
      profile.maturity_level == "r" -> "R"
      profile.maturity_level == "nc17" -> "NC-17"
      true -> "Todos los públicos"
    end
  end
end
