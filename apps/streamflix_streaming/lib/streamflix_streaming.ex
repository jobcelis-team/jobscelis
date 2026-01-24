defmodule StreamflixStreaming do
  @moduledoc """
  StreamflixStreaming - Video streaming service.

  This module provides:
  - HLS manifest generation
  - Adaptive bitrate streaming
  - Playback session management
  - Progress tracking
  """

  alias StreamflixStreaming.Session.PlaybackSession
  alias StreamflixStreaming.HLS.ManifestGenerator
  alias StreamflixAccounts.Services.SessionManager

  # ============================================
  # PLAYBACK FUNCTIONS
  # ============================================

  @doc """
  Starts a new playback session.
  """
  def start_playback(user_id, profile_id, content_id, opts \\ []) do
    episode_id = Keyword.get(opts, :episode_id)
    device_type = Keyword.get(opts, :device_type, "web")
    start_position = Keyword.get(opts, :start_position, 0)

    # Verify user can start stream
    if SessionManager.can_start_stream?(user_id) do
      # Get video info
      video = get_video(content_id, episode_id)

      if video && video.status == "ready" do
        # Start session
        {:ok, session_id} = SessionManager.start_session(
          user_id,
          profile_id,
          content_id,
          device_type: device_type
        )

        # Start playback process
        {:ok, _pid} = PlaybackSession.start_link(%{
          session_id: session_id,
          user_id: user_id,
          profile_id: profile_id,
          content_id: content_id,
          episode_id: episode_id,
          video: video,
          start_position: start_position
        })

        {:ok, session_id}
      else
        {:error, :video_not_ready}
      end
    else
      {:error, :max_streams_reached}
    end
  end

  @doc """
  Ends a playback session.
  """
  def end_playback(session_id) do
    PlaybackSession.stop(session_id)
    SessionManager.end_session(session_id)
  end

  @doc """
  Gets the HLS manifest for a session.
  """
  def get_manifest(session_id) do
    case PlaybackSession.get_state(session_id) do
      nil ->
        {:error, :session_not_found}

      state ->
        manifest = ManifestGenerator.generate_master(
          state.video,
          session_id: session_id,
          available_qualities: get_available_qualities(state)
        )

        {:ok, manifest}
    end
  end

  @doc """
  Gets a media playlist for a specific quality.
  """
  def get_media_playlist(session_id, quality) do
    case PlaybackSession.get_state(session_id) do
      nil ->
        {:error, :session_not_found}

      state ->
        playlist = ManifestGenerator.generate_media(
          state.video,
          quality,
          session_id: session_id
        )

        {:ok, playlist}
    end
  end

  @doc """
  Gets a video segment.
  """
  def get_segment(session_id, quality, segment) do
    case PlaybackSession.get_state(session_id) do
      nil ->
        {:error, :session_not_found}

      state ->
        # Extract segment number from filename (e.g., "segment_5.ts" -> 5)
        segment_number = extract_segment_number(segment)
        content_id = state.video.content_id || state.content_id

        # Get segment from CDN
        case StreamflixCdn.get_segment(content_id, quality, segment_number) do
          {:ok, data} ->
            content_type = if String.ends_with?(segment, ".m4s") do
              "video/mp4"
            else
              "video/MP2T"
            end
            {:ok, data, content_type}

          error ->
            error
        end
    end
  end

  defp extract_segment_number(segment) do
    case Regex.run(~r/segment_(\d+)/, segment) do
      [_, num] -> String.to_integer(num)
      _ -> 0
    end
  end

  @doc """
  Reports current playback position.
  """
  def report_position(session_id, position) do
    PlaybackSession.update_position(session_id, position)
    SessionManager.heartbeat(session_id, position)
  end

  @doc """
  Reports bandwidth measurement for adaptive streaming.
  """
  def report_bandwidth(session_id, bandwidth_bps) do
    PlaybackSession.update_bandwidth(session_id, bandwidth_bps)
  end

  @doc """
  Gets current playback state.
  """
  def get_playback_state(session_id) do
    PlaybackSession.get_state(session_id)
  end

  # ============================================
  # PRIVATE FUNCTIONS
  # ============================================

  defp get_video(content_id, nil) do
    StreamflixCatalog.get_video_for_content(content_id)
  end

  defp get_video(_content_id, episode_id) do
    StreamflixCatalog.get_video_for_episode(episode_id)
  end

  defp get_available_qualities(state) do
    user = StreamflixAccounts.get_user!(state.user_id)
    subscription = StreamflixAccounts.get_active_subscription(user.id)

    max_quality = case subscription do
      nil -> "480p"
      %{plan: "basic"} -> "480p"
      %{plan: "standard"} -> "1080p"
      %{plan: "premium"} -> "4k"
      _ -> "480p"
    end

    filter_qualities(state.video.qualities, max_quality)
  end

  defp filter_qualities(qualities, max_quality) do
    quality_order = ["240p", "360p", "480p", "720p", "1080p", "1440p", "4k"]
    max_index = Enum.find_index(quality_order, &(&1 == max_quality)) || 2

    qualities
    |> Enum.filter(fn q ->
      idx = Enum.find_index(quality_order, &(&1 == q))
      idx && idx <= max_index
    end)
  end
end
