defmodule StreamflixWebWeb.Api.V1.StreamController do
  use StreamflixWebWeb, :controller

  alias StreamflixStreaming

  action_fallback StreamflixWebWeb.FallbackController

  @doc """
  Returns the media playlist for a specific quality.
  """
  def media_playlist(conn, %{"session_id" => session_id, "quality" => quality}) do
    case StreamflixStreaming.get_media_playlist(session_id, quality) do
      {:ok, playlist} ->
        conn
        |> put_resp_content_type("application/vnd.apple.mpegurl")
        |> send_resp(200, playlist)

      {:error, :session_not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Returns a video segment.
  """
  def segment(conn, %{"session_id" => session_id, "quality" => quality, "segment" => segment}) do
    case StreamflixStreaming.get_segment(session_id, quality, segment) do
      {:ok, data, content_type} ->
        conn
        |> put_resp_content_type(content_type)
        |> send_resp(200, data)

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
