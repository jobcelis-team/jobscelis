defmodule StreamflixWebWeb.PlayerLive do
  use StreamflixWebWeb, :live_view

  alias StreamflixCatalog
  alias StreamflixStreaming

  @impl true
  def mount(%{"id" => id} = params, _session, socket) do
    case StreamflixCatalog.get_content(id) do
      {:ok, content} ->
        season = Map.get(params, "season", "1") |> String.to_integer()
        episode = Map.get(params, "episode", "1") |> String.to_integer()

        socket =
          socket
          |> assign(:page_title, "Viendo: #{content.title}")
          |> assign(:content, content)
          |> assign(:season, season)
          |> assign(:episode, episode)
          |> assign(:playing, false)
          |> assign(:current_time, 0)
          |> assign(:duration, 0)
          |> assign(:volume, 100)
          |> assign(:muted, false)
          |> assign(:fullscreen, false)
          |> assign(:show_controls, true)
          |> assign(:quality, "1080p")
          |> assign(:available_qualities, ["480p", "720p", "1080p", "4K"])
          |> assign(:playback_session, nil)
          |> assign(:video_url, get_video_url(content))

        {:ok, socket}

      {:error, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "Contenido no encontrado")
          |> redirect(to: ~p"/browse")

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("play", _, socket) do
    {:noreply, assign(socket, :playing, true)}
  end

  @impl true
  def handle_event("pause", _, socket) do
    {:noreply, assign(socket, :playing, false)}
  end

  @impl true
  def handle_event("toggle_play", _, socket) do
    {:noreply, assign(socket, :playing, !socket.assigns.playing)}
  end

  @impl true
  def handle_event("progress", %{"currentTime" => current_time, "duration" => duration}, socket) do
    socket =
      socket
      |> assign(:current_time, current_time)
      |> assign(:duration, duration)

    {:noreply, socket}
  end

  @impl true
  def handle_event("seek", %{"time" => time}, socket) do
    {:noreply, push_event(socket, "seek", %{time: time})}
  end

  @impl true
  def handle_event("set_volume", %{"volume" => volume}, socket) do
    {:noreply, assign(socket, :volume, volume)}
  end

  @impl true
  def handle_event("toggle_mute", _, socket) do
    {:noreply, assign(socket, :muted, !socket.assigns.muted)}
  end

  @impl true
  def handle_event("toggle_fullscreen", _, socket) do
    {:noreply, assign(socket, :fullscreen, !socket.assigns.fullscreen)}
  end

  @impl true
  def handle_event("change_quality", %{"quality" => quality}, socket) do
    {:noreply, assign(socket, :quality, quality)}
  end

  @impl true
  def handle_event("show_controls", _, socket) do
    {:noreply, assign(socket, :show_controls, true)}
  end

  @impl true
  def handle_event("noop", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("hide_controls", _, socket) do
    if socket.assigns.playing do
      {:noreply, assign(socket, :show_controls, false)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class="fixed inset-0 bg-black"
      phx-mousemove="show_controls"
      phx-click="toggle_play"
    >
      <!-- Video Player -->
      <video
        id="video-player"
        phx-hook="VideoPlayer"
        class="w-full h-full object-contain"
        poster={@content.backdrop_url || "/images/default-backdrop.svg"}
        autoplay={@playing}
      >
        <source src={@video_url} type="application/x-mpegURL" />
        <source src={@video_url} type="video/mp4" />
        Tu navegador no soporta el elemento de video.
      </video>

      <!-- Controls Overlay -->
      <div
        class={"absolute inset-0 transition-opacity duration-300 #{if @show_controls, do: "opacity-100", else: "opacity-0 pointer-events-none"}"}
        phx-click="toggle_play"
      >
        <!-- Top Bar -->
        <div class="absolute top-0 left-0 right-0 p-4 bg-gradient-to-b from-black/80 to-transparent">
          <div class="flex items-center justify-between">
            <a
              href={"/title/#{@content.id}"}
              class="text-white hover:text-gray-300 flex items-center"
              phx-click="noop"
            >
              <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
              </svg>
            </a>
            <div class="text-white text-lg font-medium">
              <%= @content.title %>
              <%= if @content.type == :series do %>
                <span class="text-gray-400">- T<%= @season %>:E<%= @episode %></span>
              <% end %>
            </div>
            <div></div>
          </div>
        </div>

        <!-- Center Play Button -->
        <div class="absolute inset-0 flex items-center justify-center">
          <button
            class={"w-20 h-20 bg-white/20 hover:bg-white/30 rounded-full flex items-center justify-center transition #{if @playing, do: "opacity-0", else: "opacity-100"}"}
            phx-click="toggle_play"
          >
            <svg class="w-12 h-12 text-white ml-1" fill="currentColor" viewBox="0 0 24 24">
              <path d="M8 5v14l11-7z" />
            </svg>
          </button>
        </div>

        <!-- Bottom Controls -->
        <div class="absolute bottom-0 left-0 right-0 p-4 bg-gradient-to-t from-black/80 to-transparent">
          <!-- Progress Bar -->
          <div class="mb-4" phx-click="noop">
            <div class="relative h-1 bg-gray-600 rounded-full cursor-pointer group">
              <div
                class="absolute h-full bg-red-600 rounded-full"
                style={"width: #{progress_percent(@current_time, @duration)}%"}
              ></div>
              <div
                class="absolute h-3 w-3 bg-red-600 rounded-full -top-1 opacity-0 group-hover:opacity-100 transition"
                style={"left: #{progress_percent(@current_time, @duration)}%"}
              ></div>
            </div>
            <div class="flex justify-between text-xs text-gray-400 mt-1">
              <span><%= format_time(@current_time) %></span>
              <span><%= format_time(@duration) %></span>
            </div>
          </div>

          <!-- Control Buttons -->
          <div class="flex items-center justify-between" phx-click="noop">
            <div class="flex items-center space-x-4">
              <!-- Play/Pause -->
              <button phx-click="toggle_play" class="text-white hover:text-gray-300">
                <%= if @playing do %>
                  <svg class="w-8 h-8" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z" />
                  </svg>
                <% else %>
                  <svg class="w-8 h-8" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M8 5v14l11-7z" />
                  </svg>
                <% end %>
              </button>

              <!-- Skip Back -->
              <button class="text-white hover:text-gray-300" phx-click="seek" phx-value-time={max(0, @current_time - 10)}>
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12.066 11.2a1 1 0 000 1.6l5.334 4A1 1 0 0019 16V8a1 1 0 00-1.6-.8l-5.333 4zM4.066 11.2a1 1 0 000 1.6l5.334 4A1 1 0 0011 16V8a1 1 0 00-1.6-.8l-5.334 4z" />
                </svg>
              </button>

              <!-- Skip Forward -->
              <button class="text-white hover:text-gray-300" phx-click="seek" phx-value-time={@current_time + 10}>
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.933 12.8a1 1 0 000-1.6L6.6 7.2A1 1 0 005 8v8a1 1 0 001.6.8l5.333-4zM19.933 12.8a1 1 0 000-1.6l-5.333-4A1 1 0 0013 8v8a1 1 0 001.6.8l5.333-4z" />
                </svg>
              </button>

              <!-- Volume -->
              <div class="flex items-center space-x-2">
                <button phx-click="toggle_mute" class="text-white hover:text-gray-300">
                  <%= if @muted || @volume == 0 do %>
                    <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z" />
                    </svg>
                  <% else %>
                    <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z" />
                    </svg>
                  <% end %>
                </button>
                <input
                  type="range"
                  min="0"
                  max="100"
                  value={@volume}
                  phx-change="set_volume"
                  name="volume"
                  class="w-20 h-1 bg-gray-600 rounded-lg appearance-none cursor-pointer"
                />
              </div>
            </div>

            <div class="flex items-center space-x-4">
              <!-- Quality -->
              <select
                phx-change="change_quality"
                name="quality"
                class="bg-transparent text-white border border-gray-600 rounded px-2 py-1 text-sm"
              >
                <%= for q <- @available_qualities do %>
                  <option value={q} selected={q == @quality}><%= q %></option>
                <% end %>
              </select>

              <!-- Fullscreen -->
              <button phx-click="toggle_fullscreen" class="text-white hover:text-gray-300">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" />
                </svg>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helpers
  defp get_video_url(content) do
    # Return demo video URL or actual streaming URL
    content.video_url || "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
  end

  defp progress_percent(current, duration) when duration > 0 do
    Float.round(current / duration * 100, 2)
  end
  defp progress_percent(_, _), do: 0

  defp format_time(seconds) when is_number(seconds) do
    total_seconds = trunc(seconds)
    hours = div(total_seconds, 3600)
    minutes = div(rem(total_seconds, 3600), 60)
    secs = rem(total_seconds, 60)

    if hours > 0 do
      :io_lib.format("~2..0B:~2..0B:~2..0B", [hours, minutes, secs]) |> to_string()
    else
      :io_lib.format("~2..0B:~2..0B", [minutes, secs]) |> to_string()
    end
  end
  defp format_time(_), do: "00:00"
end
