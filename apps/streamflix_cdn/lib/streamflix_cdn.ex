defmodule StreamflixCdn do
  @moduledoc """
  StreamflixCdn - Azure Blob Storage and CDN integration.

  This module provides:
  - Video upload to Azure Blob Storage
  - Signed URL generation (SAS tokens)
  - CDN routing
  - Video segment delivery
  """

  alias StreamflixCdn.Azure.BlobClient
  alias StreamflixCdn.Azure.SasGenerator

  # ============================================
  # VIDEO OPERATIONS
  # ============================================

  @doc """
  Uploads a video file to Azure Blob Storage.
  """
  def upload_video(content_id, file_path, opts \\ []) do
    quality = Keyword.get(opts, :quality, "original")
    container = container_for(:videos)

    blob_name = "#{content_id}/#{quality}/video.mp4"

    case BlobClient.upload_file(container, blob_name, file_path) do
      {:ok, url} ->
        {:ok, %{url: url, blob_name: blob_name}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Uploads an HLS segment.
  """
  def upload_segment(content_id, quality, segment_number, data) do
    container = container_for(:videos)
    blob_name = "#{content_id}/#{quality}/segment_#{segment_number}.ts"

    BlobClient.upload(container, blob_name, data, content_type: "video/mp2t")
  end

  @doc """
  Uploads an HLS manifest.
  """
  def upload_manifest(content_id, quality, manifest_content) do
    container = container_for(:manifests)

    blob_name =
      if quality == "master" do
        "#{content_id}/master.m3u8"
      else
        "#{content_id}/#{quality}/playlist.m3u8"
      end

    BlobClient.upload(container, blob_name, manifest_content,
      content_type: "application/vnd.apple.mpegurl"
    )
  end

  @doc """
  Uploads a thumbnail image.
  """
  def upload_thumbnail(content_id, image_data, opts \\ []) do
    type = Keyword.get(opts, :type, "poster")  # poster, backdrop, thumbnail
    container = container_for(:thumbnails)
    blob_name = "#{content_id}/#{type}.jpg"

    BlobClient.upload(container, blob_name, image_data, content_type: "image/jpeg")
  end

  # ============================================
  # URL GENERATION
  # ============================================

  @doc """
  Generates a signed URL for video playback.
  Valid for the specified TTL (default 4 hours).
  """
  def get_video_url(content_id, quality, opts \\ []) do
    ttl_minutes = Keyword.get(opts, :ttl_minutes, 240)
    container = container_for(:videos)
    blob_name = "#{content_id}/#{quality}/video.mp4"

    SasGenerator.generate_url(container, blob_name, ttl_minutes)
  end

  @doc """
  Generates a signed URL for a video segment.
  """
  def get_segment_url(content_id, quality, segment_number, opts \\ []) do
    ttl_minutes = Keyword.get(opts, :ttl_minutes, 60)
    container = container_for(:videos)
    blob_name = "#{content_id}/#{quality}/segment_#{segment_number}.ts"

    SasGenerator.generate_url(container, blob_name, ttl_minutes)
  end

  @doc """
  Generates a signed URL for the manifest.
  """
  def get_manifest_url(content_id, quality \\ "master", opts \\ []) do
    ttl_minutes = Keyword.get(opts, :ttl_minutes, 240)
    container = container_for(:manifests)

    blob_name =
      if quality == "master" do
        "#{content_id}/master.m3u8"
      else
        "#{content_id}/#{quality}/playlist.m3u8"
      end

    SasGenerator.generate_url(container, blob_name, ttl_minutes)
  end

  @doc """
  Gets the public URL for a thumbnail (thumbnails are public).
  """
  def get_thumbnail_url(content_id, type \\ "poster") do
    container = container_for(:thumbnails)
    blob_name = "#{content_id}/#{type}.jpg"

    BlobClient.public_url(container, blob_name)
  end

  # ============================================
  # DOWNLOAD OPERATIONS
  # ============================================

  @doc """
  Downloads a video segment.
  """
  def get_segment(content_id, quality, segment_number) do
    container = container_for(:videos)
    blob_name = "#{content_id}/#{quality}/segment_#{segment_number}.ts"

    BlobClient.download(container, blob_name)
  end

  # ============================================
  # MANAGEMENT OPERATIONS
  # ============================================

  @doc """
  Lists all blobs for a content item.
  """
  def list_content_blobs(content_id) do
    container = container_for(:videos)
    BlobClient.list_blobs(container, prefix: "#{content_id}/")
  end

  @doc """
  Deletes all blobs for a content item.
  """
  def delete_content(content_id) do
    # Delete from all containers
    for container_type <- [:videos, :manifests, :thumbnails] do
      container = container_for(container_type)
      BlobClient.delete_prefix(container, "#{content_id}/")
    end

    :ok
  end

  @doc """
  Checks if video exists.
  """
  def video_exists?(content_id, quality) do
    container = container_for(:videos)
    blob_name = "#{content_id}/#{quality}/video.mp4"

    BlobClient.exists?(container, blob_name)
  end

  # ============================================
  # PRIVATE FUNCTIONS
  # ============================================

  defp container_for(type) do
    containers = Application.get_env(:streamflix_cdn, :containers, %{})
    Map.get(containers, type, "streamflix-#{type}")
  end
end
