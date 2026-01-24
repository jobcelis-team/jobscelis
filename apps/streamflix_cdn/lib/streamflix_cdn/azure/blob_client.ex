defmodule StreamflixCdn.Azure.BlobClient do
  @moduledoc """
  Azure Blob Storage client.
  Handles upload, download, and management of blobs.
  """

  require Logger

  # ============================================
  # UPLOAD OPERATIONS
  # ============================================

  @doc """
  Uploads data to a blob.
  """
  def upload(container, blob_name, data, opts \\ []) do
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")

    url = blob_url(container, blob_name)
    headers = build_headers("PUT", container, blob_name) ++ [
      {"x-ms-blob-type", "BlockBlob"},
      {"Content-Type", content_type},
      {"Content-Length", to_string(byte_size(data))}
    ]

    case Req.put(url, body: data, headers: headers) do
      {:ok, %{status: status}} when status in [200, 201] ->
        Logger.debug("[Azure] Uploaded #{container}/#{blob_name}")
        {:ok, url}

      {:ok, %{status: status, body: body}} ->
        Logger.error("[Azure] Upload failed: #{status} - #{body}")
        {:error, {:http_error, status}}

      {:error, reason} ->
        Logger.error("[Azure] Upload error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Uploads a file from disk.
  """
  def upload_file(container, blob_name, file_path, opts \\ []) do
    case File.read(file_path) do
      {:ok, data} ->
        content_type = Keyword.get(opts, :content_type, guess_content_type(file_path))
        upload(container, blob_name, data, content_type: content_type)

      {:error, reason} ->
        {:error, {:file_error, reason}}
    end
  end

  # ============================================
  # DOWNLOAD OPERATIONS
  # ============================================

  @doc """
  Downloads a blob.
  """
  def download(container, blob_name) do
    url = blob_url(container, blob_name)
    headers = build_headers("GET", container, blob_name)

    case Req.get(url, headers: headers) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================
  # MANAGEMENT OPERATIONS
  # ============================================

  @doc """
  Checks if a blob exists.
  """
  def exists?(container, blob_name) do
    url = blob_url(container, blob_name)
    headers = build_headers("HEAD", container, blob_name)

    case Req.head(url, headers: headers) do
      {:ok, %{status: 200}} -> true
      _ -> false
    end
  end

  @doc """
  Deletes a blob.
  """
  def delete(container, blob_name) do
    url = blob_url(container, blob_name)
    headers = build_headers("DELETE", container, blob_name)

    case Req.delete(url, headers: headers) do
      {:ok, %{status: status}} when status in [200, 202, 204] ->
        :ok

      {:ok, %{status: 404}} ->
        :ok

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes all blobs with a given prefix.
  """
  def delete_prefix(container, prefix) do
    case list_blobs(container, prefix: prefix) do
      {:ok, blobs} ->
        Enum.each(blobs, fn blob ->
          delete(container, blob.name)
        end)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists blobs in a container.
  """
  def list_blobs(container, opts \\ []) do
    prefix = Keyword.get(opts, :prefix, "")
    url = "#{container_url(container)}?restype=container&comp=list&prefix=#{prefix}"
    headers = build_headers("GET", container, "")

    case Req.get(url, headers: headers) do
      {:ok, %{status: 200, body: body}} ->
        blobs = parse_blob_list(body)
        {:ok, blobs}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================
  # URL HELPERS
  # ============================================

  @doc """
  Returns the public URL for a blob.
  """
  def public_url(container, blob_name) do
    blob_url(container, blob_name)
  end

  def blob_url(container, blob_name) do
    "#{base_url()}/#{container}/#{blob_name}"
  end

  def container_url(container) do
    "#{base_url()}/#{container}"
  end

  def base_url do
    account = Application.get_env(:streamflix_cdn, :azure_account)
    "https://#{account}.blob.core.windows.net"
  end

  # ============================================
  # PRIVATE FUNCTIONS
  # ============================================

  defp build_headers(method, container, blob_name) do
    account = Application.get_env(:streamflix_cdn, :azure_account)
    key = Application.get_env(:streamflix_cdn, :azure_key)

    timestamp = DateTime.utc_now()
    |> Calendar.strftime("%a, %d %b %Y %H:%M:%S GMT")

    # Build string to sign
    string_to_sign = build_string_to_sign(method, container, blob_name, timestamp, account)

    # Generate signature
    signature = sign(string_to_sign, key)

    [
      {"x-ms-date", timestamp},
      {"x-ms-version", "2021-08-06"},
      {"Authorization", "SharedKey #{account}:#{signature}"}
    ]
  end

  defp build_string_to_sign(method, container, blob_name, timestamp, account) do
    # Simplified signature - full implementation would include more headers
    resource = "/#{account}/#{container}"
    resource = if blob_name != "", do: "#{resource}/#{blob_name}", else: resource

    """
    #{method}



    x-ms-date:#{timestamp}
    x-ms-version:2021-08-06
    #{resource}
    """
    |> String.trim()
  end

  defp sign(string_to_sign, key) do
    decoded_key = Base.decode64!(key)

    :crypto.mac(:hmac, :sha256, decoded_key, string_to_sign)
    |> Base.encode64()
  end

  defp guess_content_type(file_path) do
    case Path.extname(file_path) do
      ".mp4" -> "video/mp4"
      ".ts" -> "video/mp2t"
      ".m3u8" -> "application/vnd.apple.mpegurl"
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".webp" -> "image/webp"
      _ -> "application/octet-stream"
    end
  end

  defp parse_blob_list(_xml_body) do
    # Simplified XML parsing - would use proper XML parser in production
    # For now, return empty list
    []
  end
end
