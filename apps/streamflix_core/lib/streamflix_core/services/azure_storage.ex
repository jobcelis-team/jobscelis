defmodule StreamflixCore.Services.AzureStorage do
  @moduledoc """
  Cliente de Azure Blob Storage con autenticación SharedKey (HMAC-SHA256).
  Usa Req con el pool Finch existente. No requiere dependencias nuevas.
  """
  require Logger

  @api_version "2021-08-06"

  @doc """
  Retorna true si las credenciales de Azure están configuradas.
  """
  def configured? do
    config = Application.get_env(:streamflix_core, :azure_storage, [])
    account = Keyword.get(config, :account)
    key = Keyword.get(config, :key)
    is_binary(account) and account != "" and is_binary(key) and key != ""
  end

  @doc """
  Sube un blob al contenedor especificado.
  Retorna {:ok, %{status: 201}} o {:error, reason}.
  """
  def upload_blob(container, blob_name, body, content_type \\ "application/octet-stream") do
    {account, key} = credentials!()
    url = blob_url(account, container, blob_name)
    content_length = byte_size(body)
    timestamp = format_timestamp()

    headers_map = %{
      "x-ms-blob-type" => "BlockBlob",
      "x-ms-date" => timestamp,
      "x-ms-version" => @api_version
    }

    string_to_sign =
      build_string_to_sign(
        "PUT",
        content_length,
        content_type,
        headers_map,
        "/#{account}/#{container}/#{blob_name}"
      )

    signature = sign(string_to_sign, key)

    headers =
      [
        {"x-ms-blob-type", "BlockBlob"},
        {"x-ms-date", timestamp},
        {"x-ms-version", @api_version},
        {"Content-Type", content_type},
        {"Content-Length", to_string(content_length)},
        {"Authorization", "SharedKey #{account}:#{signature}"}
      ]

    case Req.put(url, headers: headers, body: body, connect_options: [timeout: 30_000], receive_timeout: 120_000) do
      {:ok, %{status: 201} = resp} ->
        Logger.info("[AzureStorage] Blob subido: #{container}/#{blob_name}")
        {:ok, resp}

      {:ok, %{status: status, body: resp_body}} ->
        Logger.error("[AzureStorage] Error al subir blob: HTTP #{status} — #{inspect(resp_body)}")
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        Logger.error("[AzureStorage] Error de conexión: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Lista blobs en un contenedor con prefijo opcional.
  Retorna {:ok, [%{name: ..., size: ..., last_modified: ...}]} o {:error, reason}.
  """
  def list_blobs(container, opts \\ []) do
    {account, key} = credentials!()
    prefix = Keyword.get(opts, :prefix)

    query_params = "restype=container&comp=list" <> if(prefix, do: "&prefix=#{prefix}", else: "")
    url = "https://#{account}.blob.core.windows.net/#{container}?#{query_params}"
    timestamp = format_timestamp()

    headers_map = %{
      "x-ms-date" => timestamp,
      "x-ms-version" => @api_version
    }

    # Canonicalized resource includes query params sorted alphabetically
    canon_resource =
      if prefix do
        "/#{account}/#{container}\ncomp:list\nprefix:#{prefix}\nrestype:container"
      else
        "/#{account}/#{container}\ncomp:list\nrestype:container"
      end

    string_to_sign = build_string_to_sign("GET", 0, "", headers_map, canon_resource)
    signature = sign(string_to_sign, key)

    headers = [
      {"x-ms-date", timestamp},
      {"x-ms-version", @api_version},
      {"Authorization", "SharedKey #{account}:#{signature}"}
    ]

    case Req.get(url, headers: headers, connect_options: [timeout: 15_000], receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, parse_blob_list(body)}

      {:ok, %{status: status, body: body}} ->
        Logger.error("[AzureStorage] Error al listar blobs: HTTP #{status} — #{inspect(body)}")
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        Logger.error("[AzureStorage] Error de conexión al listar: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Elimina un blob del contenedor.
  Retorna :ok o {:error, reason}.
  """
  def delete_blob(container, blob_name) do
    {account, key} = credentials!()
    url = blob_url(account, container, blob_name)
    timestamp = format_timestamp()

    headers_map = %{
      "x-ms-date" => timestamp,
      "x-ms-version" => @api_version
    }

    string_to_sign =
      build_string_to_sign("DELETE", 0, "", headers_map, "/#{account}/#{container}/#{blob_name}")

    signature = sign(string_to_sign, key)

    headers = [
      {"x-ms-date", timestamp},
      {"x-ms-version", @api_version},
      {"Authorization", "SharedKey #{account}:#{signature}"}
    ]

    case Req.delete(url, headers: headers, connect_options: [timeout: 15_000], receive_timeout: 30_000) do
      {:ok, %{status: 202}} ->
        Logger.info("[AzureStorage] Blob eliminado: #{container}/#{blob_name}")
        :ok

      {:ok, %{status: status, body: body}} ->
        Logger.error("[AzureStorage] Error al eliminar blob: HTTP #{status} — #{inspect(body)}")
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        Logger.error("[AzureStorage] Error de conexión al eliminar: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # --- Private helpers ---

  defp credentials! do
    config = Application.get_env(:streamflix_core, :azure_storage, [])
    account = Keyword.fetch!(config, :account)
    key = Keyword.fetch!(config, :key)
    {account, key}
  end

  defp blob_url(account, container, blob_name) do
    "https://#{account}.blob.core.windows.net/#{container}/#{blob_name}"
  end

  defp format_timestamp do
    DateTime.utc_now() |> Calendar.strftime("%a, %d %b %Y %H:%M:%S GMT")
  end

  defp build_string_to_sign(method, content_length, content_type, headers_map, canonicalized_resource) do
    cl = if content_length == 0, do: "", else: to_string(content_length)

    canonicalized_headers =
      headers_map
      |> Enum.sort_by(fn {k, _v} -> k end)
      |> Enum.map(fn {k, v} -> "#{k}:#{v}" end)
      |> Enum.join("\n")

    [
      method,
      "",                     # Content-Encoding
      "",                     # Content-Language
      cl,                     # Content-Length
      "",                     # Content-MD5
      content_type,           # Content-Type
      "",                     # Date
      "",                     # If-Modified-Since
      "",                     # If-Match
      "",                     # If-None-Match
      "",                     # If-Unmodified-Since
      "",                     # Range
      canonicalized_headers,
      canonicalized_resource
    ]
    |> Enum.join("\n")
  end

  defp sign(string_to_sign, key) do
    decoded_key =
      case Base.decode64(key) do
        {:ok, decoded} -> decoded
        :error -> key
      end

    :crypto.mac(:hmac, :sha256, decoded_key, string_to_sign)
    |> Base.encode64()
  end

  defp parse_blob_list(xml) when is_binary(xml) do
    # Extraer cada <Blob>...</Blob> y parsear sus campos
    ~r/<Blob>(.+?)<\/Blob>/s
    |> Regex.scan(xml)
    |> Enum.map(fn [_full, blob_xml] ->
      name = extract_xml_tag(blob_xml, "Name")
      size = extract_xml_tag(blob_xml, "Content-Length")
      last_modified = extract_xml_tag(blob_xml, "Last-Modified")

      if name && size do
        %{
          name: name,
          size: String.to_integer(size),
          last_modified: last_modified || ""
        }
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_blob_list(_), do: []

  defp extract_xml_tag(xml, tag) do
    case Regex.run(~r/<#{tag}>([^<]*)<\/#{tag}>/, xml) do
      [_, value] -> value
      _ -> nil
    end
  end
end
