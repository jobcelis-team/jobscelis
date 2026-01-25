defmodule StreamflixWebWeb.BrowseLive do
  use StreamflixWebWeb, :live_view

  alias StreamflixCatalog
  alias StreamflixAccounts

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      send(self(), :load_content)
    end

    socket =
      socket
      |> assign(:page_title, "Home")
      |> assign(:loading, true)
      |> assign(:trending, [])
      |> assign(:new_releases, [])
      |> assign(:top_rated, [])
      |> assign(:by_genre, %{})
      |> assign(:genres, [])
      |> assign(:continue_watching, [])

    {:ok, socket}
  end

  @impl true
  def handle_event("logout", _, socket) do
    # Redirect to logout endpoint
    {:noreply, redirect(socket, to: "/logout", external: true)}
  end

  @impl true
  def handle_info(:load_content, socket) do
    trending = StreamflixCatalog.get_trending(limit: 10)
    new_releases = StreamflixCatalog.get_new_releases(limit: 10)
    top_rated = StreamflixCatalog.get_top_rated(limit: 10)
    genres = StreamflixCatalog.list_genres()

    by_genre =
      genres
      |> Enum.take(5)
      |> Enum.map(fn genre ->
        {genre.slug, StreamflixCatalog.list_by_genre(genre.slug, per_page: 10)}
      end)
      |> Map.new()

    profile = get_current_profile(socket.assigns.current_user, socket.assigns.current_profile)
    continue_watching = if profile do
      StreamflixCatalog.get_continue_watching(profile.id, limit: 20)
    else
      []
    end

    socket =
      socket
      |> assign(:loading, false)
      |> assign(:trending, trending)
      |> assign(:new_releases, new_releases)
      |> assign(:top_rated, top_rated)
      |> assign(:genres, genres)
      |> assign(:by_genre, by_genre)
      |> assign(:continue_watching, continue_watching)

    {:noreply, socket}
  end

  defp get_current_profile(nil, _), do: nil
  defp get_current_profile(user, current_profile) do
    if current_profile do
      current_profile
    else
      profiles = StreamflixAccounts.list_profiles(user.id)
      List.first(profiles)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-black text-white">
      <!-- Navigation -->
      <nav class="fixed top-0 left-0 right-0 z-50 bg-gradient-to-b from-black to-transparent">
        <div class="container mx-auto px-4 py-4 flex items-center justify-between">
          <div class="flex items-center space-x-8">
            <span class="text-red-600 text-3xl font-bold">STREAMFLIX</span>
            <div class="hidden md:flex space-x-6">
              <a href="/browse" class="text-white hover:text-gray-300">Home</a>
              <a href="/browse?type=series" class="text-gray-400 hover:text-white">TV Shows</a>
              <a href="/browse?type=movie" class="text-gray-400 hover:text-white">Movies</a>
              <a href="/my-list" class="text-gray-400 hover:text-white">My List</a>
            </div>
          </div>
          <div class="flex items-center space-x-4">
            <a href="/search" class="text-white hover:text-gray-300">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
            </a>
            <a href="/account" class="text-white hover:text-gray-300">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
              </svg>
            </a>
            <%= if @current_user && @current_user.role == "admin" do %>
              <a href="/admin" class="text-white hover:text-gray-300">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                </svg>
              </a>
            <% end %>
            <button
              phx-click="logout"
              class="text-white hover:text-gray-300"
              title="Cerrar sesión"
            >
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
              </svg>
            </button>
          </div>
        </div>
      </nav>

      <!-- Hero Section -->
      <section class="relative h-[80vh] flex items-end pb-20">
        <%= if featured = List.first(@trending) do %>
          <div
            class="absolute inset-0 bg-cover bg-center"
            style={"background-image: url('#{featured.backdrop_url || "/images/default-backdrop.svg"}')"}
          >
            <div class="absolute inset-0 bg-gradient-to-t from-black via-black/50 to-transparent"></div>
          </div>
          <div class="relative container mx-auto px-4">
            <h1 class="text-5xl font-bold mb-4"><%= featured.title %></h1>
            <p class="text-lg max-w-2xl mb-6 text-gray-300"><%= featured.description %></p>
            <div class="flex space-x-4">
              <a
                href={"/watch/#{featured.id}"}
                class="bg-white text-black px-8 py-3 rounded font-semibold flex items-center hover:bg-gray-200"
              >
                <svg class="w-6 h-6 mr-2" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M8 5v14l11-7z" />
                </svg>
                Play
              </a>
              <a
                href={"/title/#{featured.id}"}
                class="bg-gray-500/70 text-white px-8 py-3 rounded font-semibold flex items-center hover:bg-gray-500"
              >
                <svg class="w-6 h-6 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                More Info
              </a>
            </div>
          </div>
        <% end %>
      </section>

      <!-- Content Rows -->
      <section class="relative -mt-20 pb-20 space-y-8">
        <%= if @loading do %>
          <div class="container mx-auto px-4">
            <div class="animate-pulse space-y-8">
              <%= for _ <- 1..3 do %>
                <div>
                  <div class="h-6 bg-gray-700 rounded w-48 mb-4"></div>
                  <div class="flex space-x-4">
                    <%= for _ <- 1..6 do %>
                      <div class="w-48 h-72 bg-gray-700 rounded"></div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% else %>
          <%= if Enum.empty?(@trending) and Enum.empty?(@new_releases) do %>
            <!-- No content message -->
            <div class="container mx-auto px-4 py-20 text-center">
              <svg class="w-24 h-24 mx-auto text-gray-600 mb-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4v16M17 4v16M3 8h4m10 0h4M3 12h18M3 16h4m10 0h4M4 20h16a1 1 0 001-1V5a1 1 0 00-1-1H4a1 1 0 00-1 1v14a1 1 0 001 1z" />
              </svg>
              <h2 class="text-2xl font-bold text-white mb-4">No hay contenido disponible</h2>
              <p class="text-gray-400 mb-8">Agrega películas y series desde el panel de administración.</p>
              <a href="/admin/content" class="bg-red-600 hover:bg-red-700 text-white px-8 py-3 rounded font-medium transition">
                Ir al Panel de Admin
              </a>
            </div>
          <% else %>
            <!-- Continuar viendo -->
            <%= if not Enum.empty?(@continue_watching) do %>
              <.continue_watching_row items={@continue_watching} />
            <% end %>

            <!-- Trending Now -->
            <%= if not Enum.empty?(@trending) do %>
              <.content_row title="Trending Now" items={@trending} />
            <% end %>

            <!-- New Releases -->
            <%= if not Enum.empty?(@new_releases) do %>
              <.content_row title="New Releases" items={@new_releases} />
            <% end %>

            <!-- Top Rated -->
            <%= if not Enum.empty?(@top_rated) do %>
              <.content_row title="Top Rated" items={@top_rated} />
            <% end %>

            <!-- By Genre -->
            <%= for {genre_slug, items} <- @by_genre, not Enum.empty?(items) do %>
              <.content_row title={genre_title(genre_slug, @genres)} items={items} />
            <% end %>
          <% end %>
        <% end %>
      </section>
    </div>
    """
  end

  # ============================================
  # COMPONENTS
  # ============================================

  defp content_row(assigns) do
    ~H"""
    <div class="container mx-auto px-4">
      <h2 class="text-xl font-semibold mb-4"><%= @title %></h2>
      <div class="flex space-x-4 overflow-x-auto pb-4 scrollbar-hide">
        <%= for item <- @items do %>
          <.content_card item={item} />
        <% end %>
      </div>
    </div>
    """
  end

  defp continue_watching_row(assigns) do
    ~H"""
    <div class="container mx-auto px-4">
      <h2 class="text-xl font-semibold mb-4">Continuar viendo</h2>
      <div class="flex space-x-4 overflow-x-auto pb-4 scrollbar-hide">
        <%= for wh <- @items, wh.content do %>
          <.continue_watching_card history={wh} />
        <% end %>
      </div>
    </div>
    """
  end

  defp continue_watching_card(assigns) do
    history = assigns.history
    content = history.content
    watch_href = if history.episode_id do
      "/watch/#{content.id}?episode_id=#{history.episode_id}"
    else
      "/watch/#{content.id}"
    end
    progress_pct = if history.duration_seconds && history.duration_seconds > 0 do
      min(100, max(0, round(history.progress_seconds / history.duration_seconds * 100)))
    else
      0
    end

    assigns =
      assigns
      |> assign(:content, content)
      |> assign(:watch_href, watch_href)
      |> assign(:progress_pct, progress_pct)

    ~H"""
    <a href={@watch_href} class="flex-shrink-0 w-48 group">
      <div class="relative overflow-hidden rounded-lg">
        <img
          src={@content.poster_url || "/images/default-poster.svg"}
          alt={@content.title}
          class="w-full h-72 object-cover transition-transform duration-300 group-hover:scale-105"
        />
        <div class="absolute bottom-0 left-0 right-0 h-1 bg-gray-700">
          <div class="h-full bg-red-600 transition-all" style={"width: #{@progress_pct}%"}></div>
        </div>
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
      <p class="mt-2 text-sm text-gray-300 truncate"><%= @content.title %></p>
    </a>
    """
  end

  defp content_card(assigns) do
    ~H"""
    <a
      href={"/title/#{@item.id}"}
      class="flex-shrink-0 w-48 group"
    >
      <div class="relative overflow-hidden rounded-lg">
        <img
          src={@item.poster_url || "/images/default-poster.svg"}
          alt={@item.title}
          class="w-full h-72 object-cover transition-transform duration-300 group-hover:scale-105"
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
      <p class="mt-2 text-sm text-gray-300 truncate"><%= @item.title %></p>
    </a>
    """
  end

  # ============================================
  # HELPERS
  # ============================================

  defp genre_title(slug, genres) do
    case Enum.find(genres, &(&1.slug == slug)) do
      nil -> String.capitalize(slug)
      genre -> genre.name
    end
  end
end
