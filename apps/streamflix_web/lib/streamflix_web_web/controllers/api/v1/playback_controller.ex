defmodule StreamflixWebWeb.Api.V1.PlaybackController do
  use StreamflixWebWeb, :controller

  alias StreamflixStreaming

  action_fallback StreamflixWebWeb.FallbackController

  @doc """
  Starts a new playback session.
  """
  def start(conn, %{"content_id" => content_id} = params) do
    user = conn.assigns.current_user
    profile_id = params["profile_id"]

    opts = [
      episode_id: params["episode_id"],
      device_type: params["device_type"] || "web",
      start_position: params["start_position"] || 0
    ]

    case StreamflixStreaming.start_playback(user.id, profile_id, content_id, opts) do
      {:ok, session_id} ->
        {:ok, manifest} = StreamflixStreaming.get_manifest(session_id)

        conn
        |> put_status(:created)
        |> json(%{
          session_id: session_id,
          manifest_url: "/api/v1/playback/#{session_id}/manifest",
          manifest: manifest
        })

      {:error, :max_streams_reached} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Maximum concurrent streams reached for your plan"})

      {:error, :video_not_ready} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Video not available"})
    end
  end

  @doc """
  Updates playback position (heartbeat).
  """
  def heartbeat(conn, %{"session_id" => session_id, "position" => position}) do
    StreamflixStreaming.report_position(session_id, position)

    # Report bandwidth if provided
    if bandwidth = conn.params["bandwidth"] do
      StreamflixStreaming.report_bandwidth(session_id, bandwidth)
    end

    conn
    |> put_status(:ok)
    |> json(%{status: "ok"})
  end

  @doc """
  Stops a playback session.
  """
  def stop(conn, %{"session_id" => session_id}) do
    StreamflixStreaming.end_playback(session_id)

    conn
    |> put_status(:ok)
    |> json(%{status: "stopped"})
  end

  @doc """
  Gets the HLS master manifest for a session.
  """
  def manifest(conn, %{"session_id" => session_id}) do
    case StreamflixStreaming.get_manifest(session_id) do
      {:ok, manifest} ->
        conn
        |> put_resp_content_type("application/vnd.apple.mpegurl")
        |> send_resp(200, manifest)

      {:error, :session_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Session not found"})
    end
  end
end
