defmodule StreamflixWebWeb.MyListLive do
  use StreamflixWebWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Mi Lista")
      |> assign(:items, [])
      |> assign(:loading, true)

    if connected?(socket) do
      send(self(), :load_list)
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(:load_list, socket) do
    # TODO: Load from user's actual list
    # For now, return empty list
    items = []

    socket =
      socket
      |> assign(:items, items)
      |> assign(:loading, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("remove", %{"id" => _id}, socket) do
    # TODO: Remove from list
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-black text-white">
      <!-- Navigation -->
      <nav class="fixed top-0 left-0 right-0 z-50 bg-gradient-to-b from-black to-transparent">
        <div class="container mx-auto px-4 py-4 flex items-center justify-between">
          <div class="flex items-center space-x-8">
            <a href="/browse" class="text-red-600 text-3xl font-bold">STREAMFLIX</a>
            <div class="hidden md:flex space-x-6">
              <a href="/browse" class="text-gray-400 hover:text-white">Home</a>
              <a href="/browse?type=series" class="text-gray-400 hover:text-white">Series</a>
              <a href="/browse?type=movie" class="text-gray-400 hover:text-white">Películas</a>
              <a href="/my-list" class="text-white">Mi Lista</a>
            </div>
          </div>
          <div class="flex items-center space-x-4">
            <a href="/search" class="text-white hover:text-gray-300">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
            </a>
            <a href="/profiles" class="w-8 h-8 rounded bg-gray-600"></a>
          </div>
        </div>
      </nav>

      <div class="pt-24 pb-12 container mx-auto px-4">
        <h1 class="text-3xl font-bold mb-8">Mi Lista</h1>

        <%= if @loading do %>
          <div class="flex justify-center py-12">
            <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-red-600"></div>
          </div>
        <% else %>
          <%= if length(@items) == 0 do %>
            <div class="text-center py-20">
              <svg class="w-24 h-24 mx-auto text-gray-600 mb-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
              </svg>
              <h2 class="text-2xl font-semibold mb-2">Tu lista está vacía</h2>
              <p class="text-gray-400 mb-6">Agrega películas y series para verlas más tarde</p>
              <a href="/browse" class="inline-block bg-red-600 hover:bg-red-700 text-white px-8 py-3 rounded font-medium transition">
                Explorar contenido
              </a>
            </div>
          <% else %>
            <div class="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4">
              <%= for item <- @items do %>
                <div class="group relative">
                  <a href={"/title/#{item.id}"}>
                    <div class="relative overflow-hidden rounded-lg">
                      <img
                        src={item.poster_url || "/images/default-poster.svg"}
                        alt={item.title}
                        class="w-full h-64 object-cover transition-transform duration-300 group-hover:scale-105"
                      />
                    </div>
                    <p class="mt-2 text-sm text-gray-300 truncate"><%= item.title %></p>
                  </a>
                  <button
                    phx-click="remove"
                    phx-value-id={item.id}
                    class="absolute top-2 right-2 bg-black/70 hover:bg-black p-1 rounded-full opacity-0 group-hover:opacity-100 transition"
                  >
                    <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end
end
