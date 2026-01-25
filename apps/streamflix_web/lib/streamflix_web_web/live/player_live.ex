defmodule StreamflixWebWeb.PlayerLive do
  use StreamflixWebWeb, :live_view

  alias StreamflixCatalog
  alias StreamflixCatalog.Schemas.Video
  alias StreamflixCore.Repo
  alias StreamflixAccounts

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
        user = socket.assigns.current_user
        profile = get_current_profile(user.id, socket.assigns.current_profile)

        {episode, episode_id, season_num, episode_num} =
          resolve_episode(content, params)

        {video_url, video_record} = get_video_info(content, episode)
        resume_from = get_resume_seconds(profile, content.id, episode_id)

        socket =
          socket
          |> assign(:page_title, "Viendo: #{content.title}")
          |> assign(:content, content)
          |> assign(:episode, episode)
          |> assign(:episode_id, episode_id)
          |> assign(:season_num, season_num)
          |> assign(:episode_num, episode_num)
          |> assign(:video_url, video_url)
          |> assign(:video_id, video_record && video_record.id)
          |> assign(:duration_seconds, video_record && video_record.duration_seconds)
          |> assign(:resume_from_seconds, resume_from)
          |> assign(:profile_id, profile && profile.id)

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("progress", %{"currentTime" => ct, "duration" => d}, socket) do
    profile_id = socket.assigns.profile_id
    cond do
      is_nil(profile_id) -> {:noreply, socket}
      d != d or d <= 0 -> {:noreply, socket}
      true ->
        ct_sec = trunc(ct)
        d_sec = trunc(d)
        attrs = %{
          content_id: socket.assigns.content.id,
          episode_id: socket.assigns.episode_id,
          video_id: socket.assigns.video_id,
          progress_seconds: ct_sec,
          duration_seconds: d_sec
        }
        StreamflixCatalog.update_watch_history(profile_id, attrs)
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black">
      <%!-- Hook builds video + progress bar + play/pause; no native controls --%>
      <div
        id="player-root"
        phx-hook="VideoPlayer"
        phx-update="ignore"
        data-src={@video_url}
        data-resume={@resume_from_seconds}
        class="absolute inset-0 flex flex-col"
      >
      </div>

      <%!-- Overlay: Volver + title --%>
      <div class="absolute inset-0 pointer-events-none z-10 flex flex-col">
        <div class="flex items-center justify-between p-4 bg-gradient-to-b from-black/70 to-transparent">
          <div class="pointer-events-auto">
            <.link
              navigate={~p"/title/#{@content.id}"}
              class="text-white hover:text-gray-300 flex items-center bg-black/50 hover:bg-black/70 px-3 py-2 rounded transition"
            >
              <.icon name="hero-arrow-left" class="w-6 h-6" />
              <span class="ml-2">Volver</span>
            </.link>
          </div>
          <div class="text-white text-lg font-medium bg-black/50 px-4 py-2 rounded pointer-events-none">
            {@content.title}
            <%= if @content.type == :series and @episode do %>
              <span class="text-gray-400"> — T<%= @season_num %> E<%= @episode_num %></span>
            <% end %>
          </div>
          <div class="w-24" />
        </div>
      </div>
    </div>
    """
  end

  defp get_current_profile(user_id, current_profile) do
    if current_profile do
      current_profile
    else
      profiles = StreamflixAccounts.list_profiles(user_id)
      List.first(profiles)
    end
  end

  defp resolve_episode(content, params) do
    episode_id = params["episode_id"]
    season_num = (params["season"] || "1") |> String.to_integer()
    episode_num = (params["episode"] || "1") |> String.to_integer()

    if episode_id do
      ep = StreamflixCatalog.get_episode(episode_id)
      if ep do
        season = ep.season
        {ep, ep.id, season && season.season_number, ep.episode_number}
      else
        {nil, nil, season_num, episode_num}
      end
    else
      ep = StreamflixCatalog.get_episode_by_position(content.id, season_num, episode_num)
      if ep do
        season = StreamflixCatalog.get_season(ep.season_id)
        {ep, ep.id, season && season.season_number, ep.episode_number}
      else
        {nil, nil, season_num, episode_num}
      end
    end
  end

  defp get_video_info(content, _episode) do
    video = Repo.get_by(Video, content_id: content.id)
    url = video_url_from_record(video)
    {url, video}
  end

  defp video_url_from_record(video) do
    case video do
      %Video{original_url: url} when is_binary(url) and url != "" ->
        blob_name = url |> String.split("/videos/") |> List.last()
        case blob_name do
          nil -> url
          "" -> url
          name ->
            case StreamflixCdn.video_playback_url(name) do
              playback when is_binary(playback) -> playback
              _ -> url
            end
        end
      _ ->
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
    end
  end

  defp get_resume_seconds(nil, _cid, _eid), do: nil
  defp get_resume_seconds(profile, content_id, episode_id) do
    case StreamflixCatalog.get_watch_progress(profile.id, content_id, episode_id) do
      nil -> nil
      wh -> wh.progress_seconds
    end
  end
end
