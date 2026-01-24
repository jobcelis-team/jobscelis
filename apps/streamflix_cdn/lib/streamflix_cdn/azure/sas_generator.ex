defmodule StreamflixCdn.Azure.SasGenerator do
  @moduledoc """
  Generates Shared Access Signatures (SAS) for Azure Blob Storage.
  SAS tokens provide secure, time-limited access to blobs.
  """

  @doc """
  Generates a SAS URL for a blob.
  """
  def generate_url(container, blob_name, ttl_minutes \\ 60) do
    token = generate_token(container, blob_name, ttl_minutes)
    "#{StreamflixCdn.Azure.BlobClient.blob_url(container, blob_name)}?#{token}"
  end

  @doc """
  Generates a SAS token for a blob.
  """
  def generate_token(container, blob_name, ttl_minutes) do
    account = Application.get_env(:streamflix_cdn, :azure_account)
    key = Application.get_env(:streamflix_cdn, :azure_key)

    now = DateTime.utc_now()
    expiry = DateTime.add(now, ttl_minutes * 60, :second)

    # Format dates for SAS
    start_time = format_sas_time(now)
    expiry_time = format_sas_time(expiry)

    # SAS parameters
    params = %{
      "sv" => "2021-08-06",           # Signed version
      "ss" => "b",                     # Signed service (blob)
      "srt" => "o",                    # Signed resource type (object)
      "sp" => "r",                     # Signed permissions (read)
      "st" => start_time,              # Start time
      "se" => expiry_time,             # Expiry time
      "spr" => "https"                 # Signed protocol
    }

    # Build string to sign
    string_to_sign = build_sas_string_to_sign(params, account, container, blob_name)

    # Generate signature
    signature = sign(string_to_sign, key)

    # Build query string
    params
    |> Map.put("sig", signature)
    |> URI.encode_query()
  end

  @doc """
  Generates a SAS token for container-level access.
  """
  def generate_container_token(container, ttl_minutes, permissions \\ "rl") do
    account = Application.get_env(:streamflix_cdn, :azure_account)
    key = Application.get_env(:streamflix_cdn, :azure_key)

    now = DateTime.utc_now()
    expiry = DateTime.add(now, ttl_minutes * 60, :second)

    start_time = format_sas_time(now)
    expiry_time = format_sas_time(expiry)

    params = %{
      "sv" => "2021-08-06",
      "ss" => "b",
      "srt" => "co",
      "sp" => permissions,
      "st" => start_time,
      "se" => expiry_time,
      "spr" => "https"
    }

    string_to_sign = build_sas_string_to_sign(params, account, container, "")
    signature = sign(string_to_sign, key)

    params
    |> Map.put("sig", signature)
    |> URI.encode_query()
  end

  # ============================================
  # PRIVATE FUNCTIONS
  # ============================================

  defp format_sas_time(datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
    |> String.replace("+00:00", "Z")
  end

  defp build_sas_string_to_sign(params, account, container, blob_name) do
    resource =
      if blob_name == "" do
        "/blob/#{account}/#{container}"
      else
        "/blob/#{account}/#{container}/#{blob_name}"
      end

    [
      params["sp"],           # Permissions
      params["st"],           # Start time
      params["se"],           # Expiry time
      resource,               # Canonicalized resource
      "",                     # Signed identifier
      "",                     # Signed IP
      params["spr"],          # Signed protocol
      params["sv"],           # Signed version
      params["srt"],          # Signed resource type
      "",                     # Signed snapshot time
      "",                     # rscc
      "",                     # rscd
      "",                     # rsce
      "",                     # rscl
      ""                      # rsct
    ]
    |> Enum.join("\n")
  end

  defp sign(string_to_sign, key) do
    decoded_key = Base.decode64!(key)

    :crypto.mac(:hmac, :sha256, decoded_key, string_to_sign)
    |> Base.encode64()
    |> URI.encode_www_form()
  end
end
