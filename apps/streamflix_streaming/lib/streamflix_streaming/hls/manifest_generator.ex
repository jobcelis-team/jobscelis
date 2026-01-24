defmodule StreamflixStreaming.HLS.ManifestGenerator do
  @moduledoc """
  Generates HLS manifests (master and media playlists).
  """

  @quality_info %{
    "240p" => %{bandwidth: 400_000, resolution: "426x240"},
    "360p" => %{bandwidth: 800_000, resolution: "640x360"},
    "480p" => %{bandwidth: 1_200_000, resolution: "854x480"},
    "720p" => %{bandwidth: 2_500_000, resolution: "1280x720"},
    "1080p" => %{bandwidth: 5_000_000, resolution: "1920x1080"},
    "1440p" => %{bandwidth: 8_000_000, resolution: "2560x1440"},
    "4k" => %{bandwidth: 15_000_000, resolution: "3840x2160"}
  }

  @doc """
  Generates the master playlist with all available qualities.
  """
  def generate_master(video, opts \\ []) do
    session_id = Keyword.get(opts, :session_id)
    available_qualities = Keyword.get(opts, :available_qualities, video.qualities)

    streams =
      available_qualities
      |> Enum.sort_by(&quality_order/1)
      |> Enum.map(fn quality ->
        info = Map.get(@quality_info, quality, %{bandwidth: 1_000_000, resolution: "854x480"})

        """
        #EXT-X-STREAM-INF:BANDWIDTH=#{info.bandwidth},RESOLUTION=#{info.resolution},NAME="#{quality}"
        /api/v1/stream/#{session_id}/#{quality}/playlist.m3u8
        """
      end)
      |> Enum.join("")

    """
    #EXTM3U
    #EXT-X-VERSION:3
    #{streams}
    """
  end

  @doc """
  Generates a media playlist for a specific quality.
  """
  def generate_media(video, quality, opts \\ []) do
    session_id = Keyword.get(opts, :session_id)
    duration = video.duration_seconds || 0
    segment_duration = 6  # 6 seconds per segment

    num_segments = ceil(duration / segment_duration)

    segments =
      0..(num_segments - 1)
      |> Enum.map(fn i ->
        seg_duration = min(segment_duration, duration - (i * segment_duration))

        """
        #EXTINF:#{Float.round(seg_duration * 1.0, 3)},
        /api/v1/stream/#{session_id}/#{quality}/segment_#{i}.ts
        """
      end)
      |> Enum.join("")

    """
    #EXTM3U
    #EXT-X-VERSION:3
    #EXT-X-TARGETDURATION:#{segment_duration}
    #EXT-X-MEDIA-SEQUENCE:0
    #EXT-X-PLAYLIST-TYPE:VOD
    #{segments}#EXT-X-ENDLIST
    """
  end

  @doc """
  Generates a live/sliding window playlist (for live streaming).
  """
  def generate_live_playlist(stream_id, segments) do
    segment_entries =
      segments
      |> Enum.map(fn seg ->
        """
        #EXTINF:#{seg.duration},
        /api/v1/live/#{stream_id}/segment_#{seg.sequence}.ts
        """
      end)
      |> Enum.join("")

    first_sequence = List.first(segments)[:sequence] || 0

    """
    #EXTM3U
    #EXT-X-VERSION:3
    #EXT-X-TARGETDURATION:6
    #EXT-X-MEDIA-SEQUENCE:#{first_sequence}
    #{segment_entries}
    """
  end

  # ============================================
  # PRIVATE FUNCTIONS
  # ============================================

  defp quality_order(quality) do
    order = %{
      "240p" => 1,
      "360p" => 2,
      "480p" => 3,
      "720p" => 4,
      "1080p" => 5,
      "1440p" => 6,
      "4k" => 7
    }

    Map.get(order, quality, 0)
  end
end
