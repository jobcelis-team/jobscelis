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
    account = Application.get_env(:streamflix_cdn, :azure_account)
    key = Application.get_env(:streamflix_cdn, :azure_key)

    if is_nil(account) || is_nil(key) do
      Logger.error("[Azure] Account or key not configured")
      {:error, :not_configured}
    else
      content_type = Keyword.get(opts, :content_type, "application/octet-stream")
      content_length = byte_size(data)

      url = blob_url(container, blob_name)
      headers = build_headers("PUT", container, blob_name, content_length: content_length, content_type: content_type) ++ [
        {"x-ms-blob-type", "BlockBlob"},
        {"Content-Type", content_type},
        {"Content-Length", to_string(content_length)}
      ]

      Logger.info("[Azure] Uploading to #{url}")
      Logger.debug("[Azure] Container: #{container}, Blob: #{blob_name}, Size: #{content_length} bytes")

      case Req.put(url, body: data, headers: headers) do
        {:ok, %{status: status}} when status in [200, 201] ->
          Logger.info("[Azure] Successfully uploaded #{container}/#{blob_name}")
          {:ok, url}

        {:ok, %{status: status, body: body}} ->
          Logger.error("[Azure] Upload failed: #{status} - #{inspect(body)}")
          {:error, {:http_error, status, body}}

        {:error, reason} ->
          Logger.error("[Azure] Upload error: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  @doc """
  Uploads a file from disk.
  For large files (>4MB), uses block upload for better reliability.
  """
  def upload_file(container, blob_name, file_path, opts \\ []) do
    # TEMPORARY: Disable block upload to test simple upload
    # TODO: Fix block upload authentication and re-enable
    case File.read(file_path) do
      {:ok, data} ->
        size = byte_size(data)
        Logger.info("[Azure] File size #{size} bytes, using simple upload (block upload temporarily disabled)")
        content_type = Keyword.get(opts, :content_type, guess_content_type(file_path))

        if size > 100_000_000 do
          Logger.warning("[Azure] File is larger than 100MB (#{size} bytes). Upload may fail or be slow.")
        end

        upload(container, blob_name, data, content_type: content_type)

      {:error, reason} ->
        {:error, {:file_error, reason}}
    end
  end

  @doc """
  Uploads a large file in blocks (chunks).
  Azure supports up to 50,000 blocks of 100MB each.
  """
  defp upload_file_in_blocks(container, blob_name, file_path, content_type) do
    account = Application.get_env(:streamflix_cdn, :azure_account)
    key = Application.get_env(:streamflix_cdn, :azure_key)

    if is_nil(account) || is_nil(key) do
      Logger.error("[Azure] Account or key not configured")
      {:error, :not_configured}
    else
      block_size = 4_000_000  # 4MB blocks
      url = blob_url(container, blob_name)

      Logger.info("[Azure] Starting block upload to #{url}")

      # Read and upload file in blocks
      case upload_blocks(file_path, container, blob_name, block_size) do
        {:ok, block_ids} ->
          # Commit all blocks
          Logger.info("[Azure] Uploaded #{length(block_ids)} blocks, committing...")
          commit_blocks(container, blob_name, block_ids, content_type)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp upload_blocks(file_path, container, blob_name, block_size) do
    account = Application.get_env(:streamflix_cdn, :azure_account)
    key = Application.get_env(:streamflix_cdn, :azure_key)

    case File.open(file_path, [:read, :binary]) do
      {:ok, file} ->
        block_ids = upload_blocks_loop(file, container, blob_name, block_size, account, key, [], 0)
        File.close(file)
        {:ok, block_ids}

      {:error, reason} ->
        {:error, {:file_error, reason}}
    end
  end

  defp upload_blocks_loop(file, container, blob_name, block_size, account, key, block_ids, block_num) do
    case IO.binread(file, block_size) do
      :eof ->
        Enum.reverse(block_ids)

      data when is_binary(data) ->
        # Generate block ID (must be base64 encoded and same length for all blocks)
        block_id = generate_block_id(block_num)

        Logger.info("[Azure] Uploading block #{block_num} (#{byte_size(data)} bytes)")

        case put_block(container, blob_name, block_id, data, account, key) do
          :ok ->
            upload_blocks_loop(file, container, blob_name, block_size, account, key, [block_id | block_ids], block_num + 1)

          {:error, reason} ->
            Logger.error("[Azure] Failed to upload block #{block_num}: #{inspect(reason)}")
            Enum.reverse(block_ids)
        end
    end
  end

  defp generate_block_id(block_num) do
    # Block ID must be base64 encoded and consistent length
    # Using 10-digit zero-padded number
    block_num
    |> Integer.to_string()
    |> String.pad_leading(10, "0")
    |> Base.encode64()
  end

  defp put_block(container, blob_name, block_id, data, account, key) do
    url = "#{blob_url(container, blob_name)}?comp=block&blockid=#{URI.encode(block_id)}"
    content_length = byte_size(data)

    # Canonicalized query string for signature
    query_params = "blockid:#{block_id}\ncomp:block"

    headers = build_headers("PUT", container, blob_name,
      content_length: content_length,
      content_type: "application/octet-stream",
      query_params: query_params
    ) ++ [
      {"Content-Length", to_string(content_length)},
      {"Content-Type", "application/octet-stream"}
    ]

    case Req.put(url, body: data, headers: headers) do
      {:ok, %{status: status}} when status in [200, 201] ->
        :ok

      {:ok, %{status: status, body: body}} ->
        Logger.error("[Azure] Put block failed: #{status} - #{inspect(body)}")
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp commit_blocks(container, blob_name, block_ids, content_type) do
    account = Application.get_env(:streamflix_cdn, :azure_account)
    key = Application.get_env(:streamflix_cdn, :azure_key)

    if length(block_ids) == 0 do
      Logger.error("[Azure] Cannot commit 0 blocks")
      {:error, :no_blocks_uploaded}
    else
      url = "#{blob_url(container, blob_name)}?comp=blocklist"

      # Build XML body with block list
      block_list_xml = build_block_list_xml(block_ids)
      content_length = byte_size(block_list_xml)

      # Canonicalized query string for signature
      query_params = "comp:blocklist"

      # Include x-ms-blob-content-type in the canonicalized headers for signature
      extra_headers = ["x-ms-blob-content-type:#{content_type}"]

      headers = build_headers("PUT", container, blob_name,
        content_length: content_length,
        content_type: "text/plain; charset=UTF-8",
        query_params: query_params,
        extra_headers: extra_headers
      ) ++ [
        {"Content-Length", to_string(content_length)},
        {"Content-Type", "text/plain; charset=UTF-8"},
        {"x-ms-blob-content-type", content_type}
      ]

      Logger.info("[Azure] Committing #{length(block_ids)} blocks")
      Logger.debug("[Azure] Block list XML length: #{content_length} bytes")

      case Req.put(url, body: block_list_xml, headers: headers) do
        {:ok, %{status: status}} when status in [200, 201] ->
          final_url = blob_url(container, blob_name)
          Logger.info("[Azure] Successfully committed blocks for #{container}/#{blob_name}")
          {:ok, final_url}

        {:ok, %{status: status, body: body}} ->
          Logger.error("[Azure] Commit blocks failed: #{status} - #{inspect(body)}")
          {:error, {:http_error, status, body}}

        {:error, reason} ->
          Logger.error("[Azure] Commit blocks error: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp build_block_list_xml(block_ids) do
    blocks = Enum.map(block_ids, fn block_id ->
      "  <Latest>#{block_id}</Latest>"
    end)
    |> Enum.join("\n")

    """
    <?xml version="1.0" encoding="utf-8"?>
    <BlockList>
    #{blocks}
    </BlockList>
    """
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

  @doc """
  Generates a SAS (Shared Access Signature) URL for a blob with read-only access.
  Valid for the specified duration (in seconds, default 3600 = 1 hour).
  """
  def generate_sas_url(container, blob_name, opts \\ []) do
    require Logger
    account = Application.get_env(:streamflix_cdn, :azure_account)
    key = Application.get_env(:streamflix_cdn, :azure_key)

    if is_nil(account) || is_nil(key) do
      Logger.error("[Azure SAS] Account or key not configured")
      {:error, :not_configured}
    else
      # Duration in seconds (default 1 hour)
      duration = Keyword.get(opts, :duration, 3600)

      # Calculate expiry time (start 5 minutes ago to account for clock skew)
      start_time = DateTime.utc_now() |> DateTime.add(-300, :second)
      expiry_time = DateTime.add(start_time, duration + 300, :second)

      # Format times for SAS - Azure expects ISO 8601 format: YYYY-MM-DDTHH:MM:SSZ
      # For the string to sign, use format WITH colons (ISO 8601 standard)
      # For the query string, URI.encode_query will handle URL encoding
      start_iso = start_time 
        |> DateTime.truncate(:second) 
        |> DateTime.to_iso8601()
        
      expiry_iso = expiry_time 
        |> DateTime.truncate(:second) 
        |> DateTime.to_iso8601()

      # SAS parameters
      signed_permissions = "r"  # Read only
      signed_resource = "b"     # Blob
      signed_version = "2021-08-06"

      # Canonicalized resource: /blob/account/container/blobname
      # IMPORTANT: Must be URL-decoded, no trailing slash, exact format
      canonicalized_resource = "/blob/#{account}/#{container}/#{String.trim(blob_name)}"

      # Build string to sign for Blob Service SAS (version 2021-08-06)
      # According to Azure docs: https://learn.microsoft.com/en-us/rest/api/storageservices/create-service-sas
      # Format: signedpermissions\nsignedstart\nsignedexpiry\ncanonicalizedresource\n
      #         signedidentifier\nsignedIP\nsignedProtocol\nsignedversion\n
      #         signedResource\nsignedSnapshotTime\nsignedEncryptionScope\n
      #         rscc\nrscd\nrsce\nrscl\nrsct
      # IMPORTANT: Dates must be in ISO 8601 format: YYYY-MM-DDTHH:MM:SSZ (with colons, NOT URL-encoded)
      # IMPORTANT: The string to sign must NOT have a trailing newline
      # IMPORTANT: Each field must be separated by a single \n character
      string_to_sign = [
        signed_permissions,           # signedpermissions
        start_iso,                    # signedstart (ISO 8601: YYYY-MM-DDTHH:MM:SSZ)
        expiry_iso,                   # signedexpiry (ISO 8601: YYYY-MM-DDTHH:MM:SSZ)
        canonicalized_resource,       # canonicalizedresource (must be URL-decoded, no trailing slash)
        "",                           # signedidentifier
        "",                           # signedIP
        "https",                      # signedProtocol
        signed_version,               # signedversion
        "",                           # signedResource (empty for service SAS)
        "",                           # signedSnapshotTime
        "",                           # signedEncryptionScope
        "",                           # rscc (Cache-Control)
        "",                           # rscd (Content-Disposition)
        "",                           # rsce (Content-Encoding)
        "",                           # rscl (Content-Language)
        ""                            # rsct (Content-Type) - last field, no trailing newline
      ] |> Enum.join("\n") |> String.trim_trailing()

      Logger.info("[Azure SAS] Constructing SAS token for #{container}/#{blob_name}")
      Logger.info("[Azure SAS] Start time: #{start_iso}, Expiry time: #{expiry_iso}")
      Logger.info("[Azure SAS] Canonicalized resource: #{canonicalized_resource}")
      
      # Log the string to sign for debugging (replace newlines with \n for readability)
      # Also log each field separately to verify completeness
      string_to_sign_debug = string_to_sign |> String.replace("\n", "\\n")
      Logger.debug("[Azure SAS] String to sign (escaped): #{string_to_sign_debug}")
      Logger.debug("[Azure SAS] String to sign length: #{String.length(string_to_sign)} bytes")
      Logger.debug("[Azure SAS] String to sign fields count: #{length(String.split(string_to_sign, "\n"))}")
      
      # Verify string to sign has all 16 fields as required by Azure
      fields = String.split(string_to_sign, "\n")
      field_count = length(fields)
      Logger.debug("[Azure SAS] String to sign has #{field_count} fields (expected 16)")
      
      if field_count != 16 do
        Logger.error("[Azure SAS] ERROR: String to sign has #{field_count} fields, expected 16!")
        Logger.error("[Azure SAS] All fields: #{inspect(fields, limit: :infinity)}")
        Logger.error("[Azure SAS] Full string to sign (hex): #{string_to_sign |> :erlang.term_to_binary() |> Base.encode16()}")
      else
        Logger.debug("[Azure SAS] ✓ String to sign has correct number of fields (16)")
        # Log each field for verification
        Logger.debug("[Azure SAS] Field breakdown:")
        Enum.with_index(fields, 1)
        |> Enum.each(fn {field, idx} ->
          Logger.debug("[Azure SAS]   Field #{idx}: #{inspect(field)}")
        end)
      end

      # Generate signature
      signature = sign(string_to_sign, key)

      Logger.info("[Azure SAS] Signature generated (length: #{String.length(signature)} chars)")
      Logger.debug("[Azure SAS] Signature value: #{signature}")

      # Build SAS query string - URI.encode_query will handle URL encoding
      # IMPORTANT: Dates in query string are URL-encoded (colons become %3A)
      # IMPORTANT: Signature must be URL-encoded (Base64 characters like +, /, = need encoding)
      sas_params = URI.encode_query(%{
        "sp" => signed_permissions,
        "st" => start_iso,  # Will be URL-encoded: 2026-01-25T02:35:33Z -> 2026-01-25T02%3A35%3A33Z
        "se" => expiry_iso, # Will be URL-encoded
        "sv" => signed_version,
        "sr" => signed_resource,
        "sig" => signature  # Will be URL-encoded (Base64 characters like +, /, =)
      })

      # Return URL with SAS token
      url = "#{blob_url(container, blob_name)}?#{sas_params}"
      Logger.info("[Azure SAS] Generated SAS URL for #{container}/#{blob_name}")
      Logger.debug("[Azure SAS] Final URL: #{url}")
      url
    end
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

  defp build_headers(method, container, blob_name, opts \\ []) do
    account = Application.get_env(:streamflix_cdn, :azure_account)
    key = Application.get_env(:streamflix_cdn, :azure_key)

    if is_nil(account) || is_nil(key) do
      Logger.error("[Azure] Account or key not configured in build_headers")
      []
    else
      timestamp = DateTime.utc_now()
      |> Calendar.strftime("%a, %d %b %Y %H:%M:%S GMT")

      content_length = Keyword.get(opts, :content_length, "")
      content_type = Keyword.get(opts, :content_type, "")
      query_params = Keyword.get(opts, :query_params, "")
      extra_headers = Keyword.get(opts, :extra_headers, [])

      # Build string to sign
      string_to_sign = build_string_to_sign(method, container, blob_name, timestamp, account, content_length, content_type, query_params, extra_headers)

      # Generate signature
      signature = sign(string_to_sign, key)

      # Log para debugging (solo en desarrollo)
      if Application.get_env(:streamflix_cdn, :debug_azure_auth, false) do
        Logger.debug("[Azure] String to sign:\n#{inspect(string_to_sign)}")
        Logger.debug("[Azure] Signature: #{signature}")
      end

      [
        {"x-ms-date", timestamp},
        {"x-ms-version", "2021-08-06"},
        {"Authorization", "SharedKey #{account}:#{signature}"}
      ]
    end
  end

  defp build_string_to_sign(method, container, blob_name, timestamp, account, content_length, content_type, query_params \\ "", extra_headers \\ []) do
    # Azure Blob Storage signature string format for SharedKey authentication
    resource = "/#{account}/#{container}"
    resource = if blob_name != "", do: "#{resource}/#{blob_name}", else: resource

    # Add canonicalized query parameters if present
    resource = if query_params != "" do
      "#{resource}\n#{query_params}"
    else
      resource
    end

    # Build canonicalized headers (must be sorted alphabetically)
    # Don't include x-ms-blob-type for block operations
    is_block_operation = String.contains?(query_params, "comp=block")

    headers_list = if is_block_operation do
      # Block operations: don't include x-ms-blob-type
      base_headers = [
        "x-ms-date:#{timestamp}",
        "x-ms-version:2021-08-06"
      ]
      # Add any extra x-ms-* headers
      base_headers ++ extra_headers
    else
      # Regular blob upload
      base_headers = [
        "x-ms-blob-type:BlockBlob",
        "x-ms-date:#{timestamp}",
        "x-ms-version:2021-08-06"
      ]
      base_headers ++ extra_headers
    end

    canonicalized_headers = headers_list
    |> Enum.sort()
    |> Enum.join("\n")

    # Convert content_length to string, empty if 0 or ""
    content_length_str = case content_length do
      0 -> ""
      "" -> ""
      n when is_integer(n) -> to_string(n)
      s when is_binary(s) -> s
    end

    # Build the string to sign according to Azure Blob Storage spec
    # Format: VERB\nContent-Encoding\nContent-Language\nContent-Length\nContent-MD5\nContent-Type\nDate\nIf-Modified-Since\nIf-Match\nIf-None-Match\nIf-Unmodified-Since\nRange\nCanonicalizedHeaders\nCanonicalizedResource
    [
      method,                    # VERB
      "",                        # Content-Encoding
      "",                        # Content-Language
      content_length_str,        # Content-Length
      "",                        # Content-MD5
      content_type,              # Content-Type
      "",                        # Date (use x-ms-date instead)
      "",                        # If-Modified-Since
      "",                        # If-Match
      "",                        # If-None-Match
      "",                        # If-Unmodified-Since
      "",                        # Range
      canonicalized_headers,     # CanonicalizedHeaders
      resource                   # CanonicalizedResource
    ]
    |> Enum.join("\n")
  end

  defp sign(string_to_sign, key) do
    require Logger
    
    # Azure Storage Key from connection string is base64 encoded
    # The key MUST be decoded from base64 before using it for HMAC
    decoded_key = case Base.decode64(key) do
      {:ok, decoded} -> 
        Logger.debug("[Azure] Successfully decoded base64 key (length: #{byte_size(decoded)} bytes)")
        decoded
      :error -> 
        # If decoding fails, log error and try using key directly (shouldn't happen with valid Azure key)
        Logger.error("[Azure] Key decode failed - Azure Storage keys should be base64 encoded")
        # Still try to use it, but this will likely fail
        key
    end

    # Generate HMAC-SHA256 signature
    # The string_to_sign must be UTF-8 encoded
    # Ensure the string is properly encoded as UTF-8
    string_bytes = :unicode.characters_to_binary(string_to_sign, :utf8)
    signature = :crypto.mac(:hmac, :sha256, decoded_key, string_bytes)
      |> Base.encode64()
    
    Logger.debug("[Azure] String to sign bytes length: #{byte_size(string_bytes)}")
    Logger.debug("[Azure] Generated signature (first 20 chars): #{String.slice(signature, 0..19)}...")
    Logger.debug("[Azure] Full signature: #{signature}")
    signature
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
