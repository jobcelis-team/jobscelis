defmodule StreamflixWebWeb.PlayerLive do
  use StreamflixWebWeb, :live_view

  alias StreamflixCatalog
  alias StreamflixStreaming

  @impl true
  def mount(%{"id" => id} = params, _session, socket) do
    case StreamflixCatalog.get_content(id) do
      nil ->
        socket =
          socket
          |> put_flash(:error, "Contenido no encontrado")
          |> redirect(to: ~p"/browse")

        {:ok, socket}

      content ->
        season = Map.get(params, "season", "1") |> String.to_integer()
        episode = Map.get(params, "episode", "1") |> String.to_integer()

        socket =
          socket
          |> assign(:page_title, "Viendo: #{content.title}")
          |> assign(:content, content)
          |> assign(:season, season)
          |> assign(:episode, episode)
          |> assign(:video_url, get_video_url(content))

        {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black">
      <div class="w-full h-full flex items-center justify-center">
        <video
          controls
          autoplay
          class="max-w-full max-h-full"
          style="width: 100%; height: 100%;"
        >
          <source src={@video_url} type="video/mp4" />
          Tu navegador no soporta el elemento de video.
        </video>
      </div>

      <!-- Back button -->
      <div class="absolute top-4 left-4 z-10">
        <a
          href={"/title/#{@content.id}"}
          class="text-white hover:text-gray-300 flex items-center bg-black/50 px-3 py-2 rounded"
        >
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
          </svg>
          <span class="ml-2">Volver</span>
        </a>
      </div>

      <!-- Title overlay -->
      <div class="absolute top-4 left-0 right-0 text-center z-10">
        <div class="text-white text-lg font-medium bg-black/50 inline-block px-4 py-2 rounded">
          <%= @content.title %>
          <%= if @content.type == :series do %>
            <span class="text-gray-400">- T<%= @season %>:E<%= @episode %></span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helpers
  defp get_video_url(content) do
    alias StreamflixCatalog.Schemas.Video
    alias StreamflixCore.Repo

    case Repo.get_by(Video, content_id: content.id) do
      %Video{original_url: url} when is_binary(url) and url != "" ->
        # Extract blob name from original_url (e.g. .../videos/CONTENT_ID/original/video.mp4 -> CONTENT_ID/original/video.mp4)
        blob_name =
          url
          |> String.split("/videos/")
          |> List.last()

        case blob_name do
          nil -> url
          "" -> url
          name ->
            # Use SAS from env (AZURE_VIDEOS_BASE_URL + AZURE_VIDEOS_SAS_TOKEN)
            case StreamflixCdn.video_playback_url(name) do
              playback when is_binary(playback) -> playback
              _ -> url
            end
        end

      _ ->
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
    end
  end
end
