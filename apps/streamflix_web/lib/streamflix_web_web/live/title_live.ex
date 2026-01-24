defmodule StreamflixWebWeb.TitleLive do
  use StreamflixWebWeb, :live_view

  alias StreamflixCatalog

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case StreamflixCatalog.get_content(id) do
      nil ->
        socket =
          socket
          |> put_flash(:error, "Contenido no encontrado")
          |> redirect(to: ~p"/browse")

        {:ok, socket}

      content ->
        socket =
          socket
          |> assign(:page_title, content.title)
          |> assign(:content, content)
          |> assign(:seasons, [])
          |> assign(:selected_season, 1)
          |> assign(:episodes, [])
          |> assign(:similar, [])
          |> assign(:in_my_list, false)

        if connected?(socket) do
          send(self(), :load_additional_data)
        end

        {:ok, socket}
    end
  end

  @impl true
  def handle_info(:load_additional_data, socket) do
    content = socket.assigns.content

    # Load seasons if series
    is_series = content.type in ["series", :series]
    seasons = if is_series do
      StreamflixCatalog.get_seasons(content.id)
    else
      []
    end

    # Load episodes for first season
    episodes = if length(seasons) > 0 do
      first_season = List.first(seasons)
      StreamflixCatalog.get_episodes(first_season.id)
    else
      []
    end

    # Load similar content (same genre)
    similar = get_similar_content(content)

    socket =
      socket
      |> assign(:seasons, seasons)
      |> assign(:episodes, episodes)
      |> assign(:similar, similar)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_season", %{"season" => season}, socket) do
    season_num = String.to_integer(season)
    _season_num = season_num  # Used for filtering in future
    episodes = StreamflixCatalog.get_episodes(socket.assigns.content.id)

    socket =
      socket
      |> assign(:selected_season, season_num)
      |> assign(:episodes, episodes)

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_to_list", _, socket) do
    # TODO: Implement add to my list
    {:noreply, assign(socket, :in_my_list, true)}
  end

  @impl true
  def handle_event("remove_from_list", _, socket) do
    # TODO: Implement remove from my list
    {:noreply, assign(socket, :in_my_list, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-black text-white">
      <!-- Back Navigation -->
      <nav class="fixed top-0 left-0 right-0 z-50 bg-gradient-to-b from-black to-transparent">
        <div class="container mx-auto px-4 py-4 flex items-center justify-between">
          <div class="flex items-center space-x-8">
            <a href="/browse" class="text-red-600 text-3xl font-bold">STREAMFLIX</a>
          </div>
          <a href="/browse" class="text-white hover:text-gray-300 flex items-center">
            <svg class="w-6 h-6 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            Volver
          </a>
        </div>
      </nav>

      <!-- Hero Section -->
      <section class="relative h-[70vh] flex items-end pb-12">
        <div
          class="absolute inset-0 bg-cover bg-center"
          style={"background-image: url('#{@content.backdrop_url || "/images/default-backdrop.svg"}')"}
        >
          <div class="absolute inset-0 bg-gradient-to-t from-black via-black/60 to-transparent"></div>
          <div class="absolute inset-0 bg-gradient-to-r from-black via-transparent to-transparent"></div>
        </div>

        <div class="relative container mx-auto px-4 flex gap-8">
          <!-- Poster -->
          <div class="hidden md:block flex-shrink-0">
            <img
              src={@content.poster_url || "/images/default-poster.svg"}
              alt={@content.title}
              class="w-64 h-96 object-cover rounded-lg shadow-2xl"
            />
          </div>

          <!-- Info -->
          <div class="flex-1">
            <h1 class="text-4xl md:text-6xl font-bold mb-4"><%= @content.title %></h1>

            <div class="flex items-center space-x-4 text-sm text-gray-300 mb-4">
              <span class="text-green-500 font-semibold"><%= @content.rating || "N/A" %>% Match</span>
              <span><%= @content.release_year || "2024" %></span>
              <span class="border border-gray-500 px-2 py-0.5 rounded"><%= @content.rating || "TV-MA" %></span>
              <%= if @content.type == :movie do %>
                <span><%= format_duration(@content.duration) %></span>
              <% else %>
                <span><%= length(@seasons) %> Temporadas</span>
              <% end %>
              <span class="border border-gray-500 px-2 py-0.5 rounded text-xs">HD</span>
            </div>

            <p class="text-lg text-gray-300 max-w-2xl mb-6"><%= @content.description %></p>

            <!-- Action Buttons -->
            <div class="flex space-x-4 mb-6">
              <a
                href={"/watch/#{@content.id}"}
                class="bg-white text-black px-8 py-3 rounded font-semibold flex items-center hover:bg-gray-200 transition"
              >
                <svg class="w-6 h-6 mr-2" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M8 5v14l11-7z" />
                </svg>
                Reproducir
              </a>

              <%= if @in_my_list do %>
                <button
                  phx-click="remove_from_list"
                  class="bg-gray-500/70 text-white px-6 py-3 rounded font-semibold flex items-center hover:bg-gray-500 transition"
                >
                  <svg class="w-6 h-6 mr-2" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z" />
                  </svg>
                  En Mi Lista
                </button>
              <% else %>
                <button
                  phx-click="add_to_list"
                  class="bg-gray-500/70 text-white px-6 py-3 rounded font-semibold flex items-center hover:bg-gray-500 transition"
                >
                  <svg class="w-6 h-6 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                  </svg>
                  Mi Lista
                </button>
              <% end %>
            </div>

            <!-- Genres -->
            <div class="flex flex-wrap gap-2">
              <%= for genre <- (@content.genres || []) do %>
                <span class="bg-gray-700/50 px-3 py-1 rounded-full text-sm"><%= genre %></span>
              <% end %>
            </div>
          </div>
        </div>
      </section>

      <!-- Episodes (for series) -->
      <%= if @content.type == :series && length(@seasons) > 0 do %>
        <section class="py-8 border-t border-gray-800">
          <div class="container mx-auto px-4">
            <div class="flex items-center justify-between mb-6">
              <h2 class="text-2xl font-semibold">Episodios</h2>
              <select
                phx-change="select_season"
                name="season"
                class="bg-gray-800 border border-gray-600 rounded px-4 py-2 text-white"
              >
                <%= for season <- @seasons do %>
                  <option value={season.number} selected={season.number == @selected_season}>
                    Temporada <%= season.number %>
                  </option>
                <% end %>
              </select>
            </div>

            <div class="space-y-4">
              <%= for episode <- @episodes do %>
                <a
                  href={"/watch/#{@content.id}?season=#{@selected_season}&episode=#{episode.number}"}
                  class="flex gap-4 p-4 bg-gray-900/50 rounded-lg hover:bg-gray-800/50 transition group"
                >
                  <div class="relative flex-shrink-0 w-40 h-24">
                    <img
                      src={episode.thumbnail_url || "/images/default-episode.svg"}
                      alt={"Episodio #{episode.number}"}
                      class="w-full h-full object-cover rounded"
                    />
                    <div class="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition">
                      <div class="bg-white/90 rounded-full p-2">
                        <svg class="w-6 h-6 text-black" fill="currentColor" viewBox="0 0 24 24">
                          <path d="M8 5v14l11-7z" />
                        </svg>
                      </div>
                    </div>
                  </div>
                  <div class="flex-1">
                    <div class="flex justify-between items-start mb-1">
                      <h3 class="font-semibold"><%= episode.number %>. <%= episode.title %></h3>
                      <span class="text-sm text-gray-400"><%= format_duration(episode.duration) %></span>
                    </div>
                    <p class="text-sm text-gray-400 line-clamp-2"><%= episode.description %></p>
                  </div>
                </a>
              <% end %>
            </div>
          </div>
        </section>
      <% end %>

      <!-- Similar Content -->
      <%= if length(@similar) > 0 do %>
        <section class="py-8 border-t border-gray-800">
          <div class="container mx-auto px-4">
            <h2 class="text-2xl font-semibold mb-6">Títulos similares</h2>
            <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
              <%= for item <- @similar do %>
                <a href={"/title/#{item.id}"} class="group">
                  <div class="relative overflow-hidden rounded-lg">
                    <img
                      src={item.poster_url || "/images/default-poster.svg"}
                      alt={item.title}
                      class="w-full h-64 object-cover transition-transform duration-300 group-hover:scale-105"
                    />
                  </div>
                  <p class="mt-2 text-sm text-gray-300 truncate"><%= item.title %></p>
                </a>
              <% end %>
            </div>
          </div>
        </section>
      <% end %>
    </div>
    """
  end

  # Helpers
  defp get_similar_content(content) do
    # Get content from same genre
    case content.genres do
      [genre | _] ->
        StreamflixCatalog.list_by_genre(genre, per_page: 6)
        |> Enum.reject(&(&1.id == content.id))
        |> Enum.take(6)
      _ ->
        []
    end
  rescue
    _ -> []
  end

  defp format_duration(nil), do: ""
  defp format_duration(minutes) when is_integer(minutes) do
    hours = div(minutes, 60)
    mins = rem(minutes, 60)
    if hours > 0 do
      "#{hours}h #{mins}m"
    else
      "#{mins}m"
    end
  end
  defp format_duration(_), do: ""
end
