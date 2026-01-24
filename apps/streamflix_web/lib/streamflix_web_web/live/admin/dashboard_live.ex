defmodule StreamflixWebWeb.Admin.DashboardLive do
  use StreamflixWebWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Admin Dashboard")
      |> assign(:stats, get_stats())
      |> assign(:recent_users, [])
      |> assign(:recent_content, [])

    if connected?(socket) do
      send(self(), :load_data)
      :timer.send_interval(30_000, self(), :refresh_stats)
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(:load_data, socket) do
    socket =
      socket
      |> assign(:stats, get_stats())
      |> assign(:recent_users, get_recent_users())
      |> assign(:recent_content, get_recent_content())

    {:noreply, socket}
  end

  @impl true
  def handle_info(:refresh_stats, socket) do
    {:noreply, assign(socket, :stats, get_stats())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100">
      <.admin_sidebar active="dashboard" />

      <div class="ml-64 p-8">
        <h1 class="text-3xl font-bold text-gray-900 mb-8">Dashboard</h1>

        <!-- Stats Grid -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <.stat_card
            title="Usuarios Totales"
            value={@stats.total_users}
            icon="users"
            color="blue"
            change="+12%"
          />
          <.stat_card
            title="Contenido Total"
            value={@stats.total_content}
            icon="film"
            color="purple"
            change="+5%"
          />
          <.stat_card
            title="Streams Activos"
            value={@stats.active_streams}
            icon="play"
            color="green"
            change="+23%"
          />
          <.stat_card
            title="Ingresos Mensuales"
            value={"$#{@stats.monthly_revenue}"}
            icon="currency"
            color="yellow"
            change="+8%"
          />
        </div>

        <!-- Charts Row -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-lg font-semibold mb-4">Usuarios por Día</h2>
            <div class="h-64 flex items-end justify-between gap-2">
              <%= for {day, value} <- weekly_data() do %>
                <div class="flex-1 flex flex-col items-center">
                  <div
                    class="w-full bg-blue-500 rounded-t transition-all duration-500"
                    style={"height: #{value}%"}
                  ></div>
                  <span class="text-xs text-gray-500 mt-2"><%= day %></span>
                </div>
              <% end %>
            </div>
          </div>

          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-lg font-semibold mb-4">Contenido por Género</h2>
            <div class="space-y-3">
              <%= for {genre, percent} <- genre_data() do %>
                <div>
                  <div class="flex justify-between text-sm mb-1">
                    <span><%= genre %></span>
                    <span><%= percent %>%</span>
                  </div>
                  <div class="h-2 bg-gray-200 rounded-full overflow-hidden">
                    <div class="h-full bg-purple-500 rounded-full" style={"width: #{percent}%"}></div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Tables Row -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <!-- Recent Users -->
          <div class="bg-white rounded-lg shadow">
            <div class="p-6 border-b flex justify-between items-center">
              <h2 class="text-lg font-semibold">Usuarios Recientes</h2>
              <a href="/admin/users" class="text-blue-600 hover:underline text-sm">Ver todos</a>
            </div>
            <div class="divide-y">
              <%= for user <- @recent_users do %>
                <div class="p-4 flex items-center justify-between">
                  <div class="flex items-center gap-3">
                    <div class="w-10 h-10 rounded-full bg-gray-300 flex items-center justify-center">
                      <span class="text-gray-600 font-medium"><%= String.first(user.name) %></span>
                    </div>
                    <div>
                      <p class="font-medium"><%= user.name %></p>
                      <p class="text-sm text-gray-500"><%= user.email %></p>
                    </div>
                  </div>
                  <span class={"px-2 py-1 rounded text-xs #{subscription_color(user.subscription)}"}><%= user.subscription %></span>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Recent Content -->
          <div class="bg-white rounded-lg shadow">
            <div class="p-6 border-b flex justify-between items-center">
              <h2 class="text-lg font-semibold">Contenido Reciente</h2>
              <a href="/admin/content" class="text-blue-600 hover:underline text-sm">Ver todo</a>
            </div>
            <div class="divide-y">
              <%= for content <- @recent_content do %>
                <div class="p-4 flex items-center justify-between">
                  <div class="flex items-center gap-3">
                    <div class="w-16 h-10 rounded bg-gray-200 overflow-hidden">
                      <img src={content.thumbnail || "/images/default-poster.svg"} alt="" class="w-full h-full object-cover" />
                    </div>
                    <div>
                      <p class="font-medium"><%= content.title %></p>
                      <p class="text-sm text-gray-500"><%= content.type %> • <%= content.year %></p>
                    </div>
                  </div>
                  <span class={"px-2 py-1 rounded text-xs #{status_color(content.status)}"}><%= content.status %></span>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Components
  defp stat_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow p-6">
      <div class="flex items-center justify-between mb-4">
        <div class={"w-12 h-12 rounded-lg flex items-center justify-center #{bg_color(@color)}"}>
          <.stat_icon name={@icon} />
        </div>
        <span class="text-green-500 text-sm font-medium"><%= @change %></span>
      </div>
      <p class="text-2xl font-bold text-gray-900"><%= @value %></p>
      <p class="text-sm text-gray-500"><%= @title %></p>
    </div>
    """
  end

  defp stat_icon(%{name: "users"} = assigns) do
    ~H"""
    <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
    </svg>
    """
  end

  defp stat_icon(%{name: "film"} = assigns) do
    ~H"""
    <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4v16M17 4v16M3 8h4m10 0h4M3 12h18M3 16h4m10 0h4M4 20h16a1 1 0 001-1V5a1 1 0 00-1-1H4a1 1 0 00-1 1v14a1 1 0 001 1z" />
    </svg>
    """
  end

  defp stat_icon(%{name: "play"} = assigns) do
    ~H"""
    <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" />
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    """
  end

  defp stat_icon(%{name: "currency"} = assigns) do
    ~H"""
    <svg class="w-6 h-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    """
  end

  defp stat_icon(assigns), do: ~H""

  def admin_sidebar(assigns) do
    ~H"""
    <aside class="fixed left-0 top-0 bottom-0 w-64 bg-gray-900 text-white">
      <div class="p-6">
        <a href="/admin" class="text-red-500 text-2xl font-bold">STREAMFLIX</a>
        <p class="text-gray-500 text-sm">Panel de Admin</p>
      </div>

      <nav class="mt-6">
        <.sidebar_link href="/admin" icon="dashboard" label="Dashboard" active={@active == "dashboard"} />
        <.sidebar_link href="/admin/content" icon="content" label="Contenido" active={@active == "content"} />
        <.sidebar_link href="/admin/users" icon="users" label="Usuarios" active={@active == "users"} />
        <.sidebar_link href="/admin/analytics" icon="analytics" label="Analíticas" active={@active == "analytics"} />
        <.sidebar_link href="/admin/settings" icon="settings" label="Configuración" active={@active == "settings"} />
      </nav>

      <div class="absolute bottom-0 left-0 right-0 p-6 border-t border-gray-800">
        <a href="/browse" class="flex items-center text-gray-400 hover:text-white">
          <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 17l-5-5m0 0l5-5m-5 5h12" />
          </svg>
          Volver a StreamFlix
        </a>
      </div>
    </aside>
    """
  end

  defp sidebar_link(assigns) do
    ~H"""
    <a
      href={@href}
      class={"flex items-center px-6 py-3 transition #{if @active, do: "bg-gray-800 text-white border-r-4 border-red-500", else: "text-gray-400 hover:bg-gray-800 hover:text-white"}"}
    >
      <.sidebar_icon name={@icon} />
      <span class="ml-3"><%= @label %></span>
    </a>
    """
  end

  defp sidebar_icon(%{name: "dashboard"} = assigns) do
    ~H"""
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
    </svg>
    """
  end

  defp sidebar_icon(%{name: "content"} = assigns) do
    ~H"""
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4v16M17 4v16M3 8h4m10 0h4M3 12h18M3 16h4m10 0h4M4 20h16a1 1 0 001-1V5a1 1 0 00-1-1H4a1 1 0 00-1 1v14a1 1 0 001 1z" />
    </svg>
    """
  end

  defp sidebar_icon(%{name: "users"} = assigns) do
    ~H"""
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
    </svg>
    """
  end

  defp sidebar_icon(%{name: "analytics"} = assigns) do
    ~H"""
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
    </svg>
    """
  end

  defp sidebar_icon(%{name: "settings"} = assigns) do
    ~H"""
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
    </svg>
    """
  end

  defp sidebar_icon(assigns), do: ~H""

  # Helpers
  defp bg_color("blue"), do: "bg-blue-100"
  defp bg_color("purple"), do: "bg-purple-100"
  defp bg_color("green"), do: "bg-green-100"
  defp bg_color("yellow"), do: "bg-yellow-100"
  defp bg_color(_), do: "bg-gray-100"

  defp subscription_color("Premium"), do: "bg-purple-100 text-purple-800"
  defp subscription_color("Standard"), do: "bg-blue-100 text-blue-800"
  defp subscription_color("Basic"), do: "bg-gray-100 text-gray-800"
  defp subscription_color(_), do: "bg-gray-100 text-gray-800"

  defp status_color("Publicado"), do: "bg-green-100 text-green-800"
  defp status_color("Borrador"), do: "bg-yellow-100 text-yellow-800"
  defp status_color("Procesando"), do: "bg-blue-100 text-blue-800"
  defp status_color(_), do: "bg-gray-100 text-gray-800"

  # Load real data from database
  defp get_stats do
    import Ecto.Query
    alias StreamflixCore.Repo
    alias StreamflixAccounts.Schemas.User
    alias StreamflixCatalog.Schemas.Content

    total_users = Repo.aggregate(User, :count)
    total_content = Repo.aggregate(Content, :count)
    
    # Active streams would come from session manager in production
    active_streams = 0
    
    # Monthly revenue would come from payment system in production
    monthly_revenue = "0"

    %{
      total_users: total_users,
      total_content: total_content,
      active_streams: active_streams,
      monthly_revenue: monthly_revenue
    }
  end

  defp get_recent_users do
    import Ecto.Query
    alias StreamflixCore.Repo
    alias StreamflixAccounts.Schemas.User

    User
    |> order_by([u], desc: u.inserted_at)
    |> limit(5)
    |> Repo.all()
    |> Enum.map(fn user ->
      subscription = StreamflixAccounts.get_active_subscription(user.id)
      %{
        name: user.name,
        email: user.email,
        subscription: subscription && String.capitalize(subscription.plan) || "Sin Plan"
      }
    end)
  end

  defp get_recent_content do
    import Ecto.Query
    alias StreamflixCore.Repo
    alias StreamflixCatalog.Schemas.Content

    Content
    |> order_by([c], desc: c.inserted_at)
    |> limit(5)
    |> Repo.all()
    |> Enum.map(fn content ->
      %{
        title: content.title,
        type: if(content.type == "movie", do: "Película", else: "Serie"),
        year: to_string(content.release_year || "N/A"),
        status: status_label_es(content.status),
        thumbnail: content.poster_url
      }
    end)
  end

  defp status_label_es("published"), do: "Publicado"
  defp status_label_es("draft"), do: "Borrador"
  defp status_label_es("processing"), do: "Procesando"
  defp status_label_es(_), do: "Desconocido"

  defp weekly_data do
    # In production, this would come from analytics
    # For now, return empty data - will show zeros in chart
    [{"Lun", 0}, {"Mar", 0}, {"Mié", 0}, {"Jue", 0}, {"Vie", 0}, {"Sáb", 0}, {"Dom", 0}]
  end

  defp genre_data do
    import Ecto.Query
    alias StreamflixCore.Repo
    alias StreamflixCatalog.Schemas.Genre

    genres = Genre
    |> join(:left, [g], cg in "content_genres", on: cg.genre_id == g.id)
    |> group_by([g], [g.id, g.name])
    |> select([g, cg], {g.name, count(cg.content_id)})
    |> order_by([g, cg], desc: count(cg.content_id))
    |> limit(6)
    |> Repo.all()

    if Enum.empty?(genres) do
      [{"Sin datos", 0}]
    else
      genres
    end
  end
end
