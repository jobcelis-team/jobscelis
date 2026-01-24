defmodule StreamflixWebWeb.SearchLive do
  use StreamflixWebWeb, :live_view

  alias StreamflixCatalog

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Buscar")
      |> assign(:query, "")
      |> assign(:results, [])
      |> assign(:loading, false)
      |> assign(:genres, [])
      |> assign(:selected_genre, nil)
      |> assign(:selected_type, nil)

    if connected?(socket) do
      send(self(), :load_genres)
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"q" => query}, _uri, socket) when query != "" do
    send(self(), {:search, query})
    {:noreply, assign(socket, :query, query)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(:load_genres, socket) do
    genres = StreamflixCatalog.list_genres()
    {:noreply, assign(socket, :genres, genres)}
  end

  @impl true
  def handle_info({:search, query}, socket) do
    results = StreamflixCatalog.search(query,
      type: socket.assigns.selected_type,
      genre: socket.assigns.selected_genre
    )
    {:noreply, socket |> assign(:results, results) |> assign(:loading, false)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket = assign(socket, :loading, true)
    send(self(), {:search, query})
    {:noreply, push_patch(socket, to: ~p"/search?q=#{query}")}
  end

  @impl true
  def handle_event("filter_genre", %{"genre" => genre}, socket) do
    genre = if genre == "", do: nil, else: genre
    socket = assign(socket, :selected_genre, genre)

    if socket.assigns.query != "" do
      send(self(), {:search, socket.assigns.query})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_type", %{"type" => type}, socket) do
    type = if type == "", do: nil, else: String.to_atom(type)
    socket = assign(socket, :selected_type, type)

    if socket.assigns.query != "" do
      send(self(), {:search, socket.assigns.query})
    end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-black text-white">
      <!-- Navigation -->
      <nav class="fixed top-0 left-0 right-0 z-50 bg-black/90 backdrop-blur">
        <div class="container mx-auto px-4 py-4 flex items-center justify-between">
          <a href="/browse" class="text-red-600 text-3xl font-bold">STREAMFLIX</a>
          <a href="/browse" class="text-gray-400 hover:text-white">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </a>
        </div>
      </nav>

      <div class="pt-24 pb-12 container mx-auto px-4">
        <!-- Search Input -->
        <form phx-submit="search" class="mb-8">
          <div class="relative max-w-2xl mx-auto">
            <input
              type="text"
              name="query"
              value={@query}
              placeholder="Buscar películas, series, géneros..."
              class="w-full bg-gray-800 border border-gray-700 rounded-lg px-6 py-4 pl-14 text-lg text-white placeholder-gray-400 focus:outline-none focus:border-red-600"
              autofocus
              phx-debounce="300"
            />
            <svg class="absolute left-5 top-1/2 -translate-y-1/2 w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
          </div>
        </form>

        <!-- Filters -->
        <div class="flex flex-wrap gap-4 mb-8 justify-center">
          <select
            phx-change="filter_type"
            name="type"
            class="bg-gray-800 border border-gray-700 rounded px-4 py-2 text-white"
          >
            <option value="">Todos los tipos</option>
            <option value="movie" selected={@selected_type == :movie}>Películas</option>
            <option value="series" selected={@selected_type == :series}>Series</option>
          </select>

          <select
            phx-change="filter_genre"
            name="genre"
            class="bg-gray-800 border border-gray-700 rounded px-4 py-2 text-white"
          >
            <option value="">Todos los géneros</option>
            <%= for genre <- @genres do %>
              <option value={genre.slug} selected={@selected_genre == genre.slug}><%= genre.name %></option>
            <% end %>
          </select>
        </div>

        <!-- Results -->
        <%= if @loading do %>
          <div class="flex justify-center py-12">
            <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-red-600"></div>
          </div>
        <% else %>
          <%= if @query != "" && length(@results) == 0 do %>
            <div class="text-center py-12">
              <svg class="w-16 h-16 mx-auto text-gray-600 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <p class="text-xl text-gray-400">No se encontraron resultados para "<%= @query %>"</p>
              <p class="text-gray-500 mt-2">Intenta con otros términos de búsqueda</p>
            </div>
          <% else %>
            <%= if @query == "" do %>
              <div class="text-center py-12">
                <svg class="w-16 h-16 mx-auto text-gray-600 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
                <p class="text-xl text-gray-400">Busca tu película o serie favorita</p>
              </div>
            <% else %>
              <p class="text-gray-400 mb-6"><%= length(@results) %> resultados para "<%= @query %>"</p>
              <div class="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4">
                <%= for item <- @results do %>
                  <a href={"/title/#{item.id}"} class="group">
                    <div class="relative overflow-hidden rounded-lg">
                      <img
                        src={item.poster_url || "/images/default-poster.svg"}
                        alt={item.title}
                        class="w-full h-64 object-cover transition-transform duration-300 group-hover:scale-105"
                      />
                      <div class="absolute inset-0 bg-black/0 group-hover:bg-black/40 transition-colors duration-300 flex items-center justify-center">
                        <svg
                          class="w-12 h-12 text-white opacity-0 group-hover:opacity-100 transition-opacity duration-300"
                          fill="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path d="M8 5v14l11-7z" />
                        </svg>
                      </div>
                    </div>
                    <p class="mt-2 text-sm text-gray-300 truncate"><%= item.title %></p>
                    <p class="text-xs text-gray-500"><%= item.release_year %> • <%= if item.type == :movie, do: "Película", else: "Serie" %></p>
                  </a>
                <% end %>
              </div>
            <% end %>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end
end
