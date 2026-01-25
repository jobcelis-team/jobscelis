#!/usr/bin/env elixir

# Script para crear contenedores en Azure Blob Storage
# Ejecutar con: mix run scripts/create_containers.exs

defmodule AzureContainerCreator do
  require Logger

  @containers [
    %{name: "videos", access: "private"},
    %{name: "thumbnails", access: "blob"},
    %{name: "manifests", access: "private"},
    %{name: "originals", access: "private"}
  ]

  def run do
    Logger.info("=== Creando Contenedores de Azure Blob Storage ===")

    account = Application.get_env(:streamflix_cdn, :azure_account)
    key = Application.get_env(:streamflix_cdn, :azure_key)

    Logger.info("Account configurado: #{inspect(account)}")
    Logger.info("Key configurado: #{if key, do: "Sí (#{String.length(key)} chars)", else: "No"}")

    if is_nil(account) || is_nil(key) || account == "" || key == "" do
      Logger.error("Error: AZURE_STORAGE_ACCOUNT o AZURE_STORAGE_KEY no están configurados")
      Logger.error("Verifica que las variables estén en el archivo .env y que el servidor esté corriendo")
      System.halt(1)
    end

    Logger.info("Cuenta de Azure: #{account}")

    Enum.each(@containers, fn container ->
      create_container(account, key, container.name, container.access)
      Process.sleep(500)  # Pequeña pausa entre peticiones
    end)

    Logger.info("\n=== Proceso completado ===")
    Logger.info("\nVerifica los contenedores en Azure Portal:")
    Logger.info("https://portal.azure.com")
  end

  defp create_container(account, key, container_name, access_level) do
    Logger.info("\n----------------------------------------")
    Logger.info("Creando contenedor: #{container_name} (acceso: #{access_level})...")

    url = "https://#{account}.blob.core.windows.net/#{container_name}?restype=container"
    timestamp = DateTime.utc_now() |> Calendar.strftime("%a, %d %b %Y %H:%M:%S GMT")

    # Build string to sign para crear contenedor
    string_to_sign = build_string_to_sign_for_container("PUT", account, container_name, timestamp, access_level)

    Logger.debug("String to sign:\n#{string_to_sign}")

    # Generate signature
    signature = sign(string_to_sign, key)

    headers = [
      {"x-ms-date", timestamp},
      {"x-ms-version", "2021-08-06"},
      {"x-ms-blob-public-access", access_level},
      {"Content-Length", "0"},
      {"Authorization", "SharedKey #{account}:#{signature}"}
    ]

    Logger.info("Enviando petición PUT a: #{url}")

    case Req.put(url, headers: headers) do
      {:ok, %{status: 201}} ->
        Logger.info("✓ Contenedor '#{container_name}' creado exitosamente")

      {:ok, %{status: 409, body: body}} ->
        Logger.warning("⚠ Contenedor '#{container_name}' ya existe")
        Logger.debug("Respuesta: #{inspect(body)}")

      {:ok, %{status: status, body: body}} ->
        Logger.error("✗ Error al crear contenedor '#{container_name}': HTTP #{status}")
        Logger.error("Respuesta: #{inspect(body)}")

      {:error, reason} ->
        Logger.error("✗ Error de conexión al crear '#{container_name}': #{inspect(reason)}")
    end
  end

  defp build_string_to_sign_for_container(method, account, container_name, timestamp, access_level) do
    # Canonicalized resource para crear contenedor
    resource = "/#{account}/#{container_name}\nrestype:container"

    # Canonicalized headers ordenados alfabéticamente
    canonicalized_headers = [
      "x-ms-blob-public-access:#{access_level}",
      "x-ms-date:#{timestamp}",
      "x-ms-version:2021-08-06"
    ]
    |> Enum.sort()
    |> Enum.join("\n")

    # String to sign según especificación de Azure
    [
      method,                    # VERB
      "",                        # Content-Encoding
      "",                        # Content-Language
      "0",                       # Content-Length
      "",                        # Content-MD5
      "",                        # Content-Type
      "",                        # Date (usamos x-ms-date)
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
    decoded_key = case Base.decode64(key) do
      {:ok, decoded} ->
        decoded
      :error ->
        Logger.warning("No se pudo decodificar la key como base64, usando directamente")
        key
    end

    :crypto.mac(:hmac, :sha256, decoded_key, string_to_sign)
    |> Base.encode64()
  end
end

# Esperar a que la aplicación esté iniciada
Process.sleep(2000)

AzureContainerCreator.run()
