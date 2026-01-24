defmodule StreamflixWebWeb.Admin.AnalyticsLive do
  use StreamflixWebWeb, :live_view

  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCatalog.Schemas.{Content, WatchHistory}
  alias StreamflixAccounts.Schemas.User

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Analíticas")
      |> assign(:period, "7d")
      |> assign(:loading, true)

    if connected?(socket) do
      send(self(), :load_analytics)
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(:load_analytics, socket) do
    metrics = calculate_metrics()
    chart_data = get_chart_data()
    top_content = get_top_content()
    device_stats = get_device_stats()

    socket =
      socket
      |> assign(:metrics, metrics)
      |> assign(:chart_data, chart_data)
      |> assign(:top_content, top_content)
      |> assign(:device_stats, device_stats)
      |> assign(:loading, false)

    {:noreply, socket}
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

        <%= if @loading do %>
          <div class="flex justify-center py-20">
            <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-red-600"></div>
          </div>
        <% else %>
          <!-- Metrics Grid -->
          <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
            <div class="bg-white rounded-lg shadow p-6">
              <p class="text-sm text-gray-500 mb-1">Reproducciones</p>
              <p class="text-3xl font-bold"><%= format_number(@metrics.total_plays) %></p>
              <p class="text-sm text-gray-400">Total</p>
            </div>
            <div class="bg-white rounded-lg shadow p-6">
              <p class="text-sm text-gray-500 mb-1">Horas vistas</p>
              <p class="text-3xl font-bold"><%= format_hours(@metrics.total_hours) %></p>
              <p class="text-sm text-gray-400">Total</p>
            </div>
            <div class="bg-white rounded-lg shadow p-6">
              <p class="text-sm text-gray-500 mb-1">Usuarios activos</p>
              <p class="text-3xl font-bold"><%= format_number(@metrics.active_users) %></p>
              <p class="text-sm text-gray-400">Últimos 30 días</p>
            </div>
            <div class="bg-white rounded-lg shadow p-6">
              <p class="text-sm text-gray-500 mb-1">Contenido total</p>
              <p class="text-3xl font-bold"><%= format_number(@metrics.total_content) %></p>
              <p class="text-sm text-gray-400">Publicado</p>
            </div>
          </div>

        <!-- Charts -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-lg font-semibold mb-4">Reproducciones por día</h2>
            <div class="h-64 flex items-end justify-between gap-1">
              <%= for value <- @chart_data do %>
                <div class="flex-1 bg-blue-500 rounded-t" style={"height: #{value}%"} title={to_string(value)}></div>
              <% end %>
            </div>
          </div>
          <div class="bg-white rounded-lg shadow p-6">
            <h2 class="text-lg font-semibold mb-4">Dispositivos</h2>
            <div class="space-y-4">
              <%= for {device, percentage} <- @device_stats do %>
                <div>
                  <div class="flex justify-between mb-1"><span><%= device %></span><span><%= percentage %>%</span></div>
                  <div class="h-2 bg-gray-200 rounded-full"><div class="h-full bg-blue-500 rounded-full" style={"width: #{percentage}%"}></div></div>
                </div>
              <% end %>
              <%= if Enum.empty?(@device_stats) do %>
                <p class="text-gray-400 text-center py-8">No hay datos de dispositivos</p>
              <% end %>
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
              <%= if Enum.empty?(@top_content) do %>
                <tr>
                  <td colspan="5" class="px-6 py-8 text-center text-gray-400">No hay datos disponibles</td>
                </tr>
              <% else %>
                <%= for {content, idx} <- Enum.with_index(@top_content, 1) do %>
                  <tr>
                    <td class="px-6 py-4 font-medium"><%= idx %></td>
                    <td class="px-6 py-4"><%= content.title %></td>
                    <td class="px-6 py-4"><%= content.type %></td>
                    <td class="px-6 py-4"><%= format_number(content.views) %></td>
                    <td class="px-6 py-4"><%= format_hours(content.hours) %></td>
                  </tr>
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp admin_sidebar(assigns), do: StreamflixWebWeb.Admin.DashboardLive.admin_sidebar(assigns)

  defp calculate_metrics do
    # Total plays (watch history entries)
    total_plays = Repo.aggregate(WatchHistory, :count, :id)

    # Total hours watched (sum of duration_seconds / 3600)
    total_seconds = 
      WatchHistory
      |> select([wh], sum(wh.duration_seconds))
      |> Repo.one() || 0
    
    total_hours = if is_integer(total_seconds), do: total_seconds / 3600, else: 0

    # Active users (users who logged in last 30 days)
    thirty_days_ago = DateTime.add(DateTime.utc_now(), -30, :day)
    active_users = 
      User
      |> where([u], u.last_login_at >= ^thirty_days_ago)
      |> Repo.aggregate(:count, :id)

    # Total published content
    total_content = 
      Content
      |> where([c], c.status == "published")
      |> Repo.aggregate(:count, :id)

    %{
      total_plays: total_plays,
      total_hours: total_hours,
      active_users: active_users,
      total_content: total_content
    }
  end

  defp get_chart_data do
    # Get watch history for last 14 days
    fourteen_days_ago = DateTime.add(DateTime.utc_now(), -14, :day)
    
    data = 
      WatchHistory
      |> where([wh], wh.last_watched_at >= ^fourteen_days_ago)
      |> select([wh], %{
        date: fragment("DATE(?)", wh.last_watched_at),
        count: count(wh.id)
      })
      |> group_by([wh], fragment("DATE(?)", wh.last_watched_at))
      |> order_by([wh], fragment("DATE(?)", wh.last_watched_at))
      |> Repo.all()

    # Create map of date -> count
    date_map = Enum.into(data, %{}, fn item -> 
      {Date.to_string(item.date), item.count}
    end)

    # Fill in last 14 days
    max_count = if Enum.empty?(data), do: 1, else: Enum.max_by(data, & &1.count).count

    Enum.map(0..13, fn days_ago ->
      date = Date.add(Date.utc_today(), -days_ago)
      date_str = Date.to_string(date)
      count = Map.get(date_map, date_str, 0)
      # Normalize to percentage (0-100)
      if max_count > 0, do: round((count / max_count) * 100), else: 0
    end)
    |> Enum.reverse()
  end

  defp get_top_content do
    # Get top content by view_count
    Content
    |> where([c], c.status == "published")
    |> order_by([c], desc: c.view_count)
    |> limit(10)
    |> Repo.all()
    |> Enum.map(fn content ->
      hours = if content.duration_minutes, do: (content.view_count * content.duration_minutes) / 60, else: 0
      %{
        title: content.title,
        type: if(content.type == "movie", do: "Película", else: "Serie"),
        views: content.view_count || 0,
        hours: hours
      }
    end)
  end

  defp get_device_stats do
    # For now, return empty (would need device tracking in playback_sessions)
    # In production, this would query playback_sessions for device_type
    []
  end

  defp format_number(n) when n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 1)}M"
  defp format_number(n) when n >= 1_000, do: "#{Float.round(n / 1_000, 1)}K"
  defp format_number(n), do: to_string(n)

  defp format_hours(h) when h >= 1_000_000, do: "#{Float.round(h / 1_000_000, 1)}M"
  defp format_hours(h) when h >= 1_000, do: "#{Float.round(h / 1_000, 1)}K"
  defp format_hours(h), do: "#{Float.round(h, 1)}"
end
