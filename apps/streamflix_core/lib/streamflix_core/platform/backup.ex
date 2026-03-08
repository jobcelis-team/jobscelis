defmodule StreamflixCore.Platform.Backup do
  @moduledoc """
  Servicio de backup automatizado de la base de datos usando pg_dump.
  Comprime con gzip y aplica política de retención (elimina backups antiguos).
  Si Azure Blob Storage está configurado, sube el backup al contenedor "backups"
  y elimina el archivo local temporal. En caso contrario, mantiene el archivo local.
  """
  require Logger

  alias StreamflixCore.Repo
  alias StreamflixCore.Services.AzureStorage

  @doc """
  Ejecuta un backup completo de la base de datos.
  Retorna {:ok, %{file: path, size: bytes, storage: "azure"|"local"}} o {:error, reason}.
  """
  def run do
    config = Application.get_env(:streamflix_core, :backup, [])
    enabled = Keyword.get(config, :enabled, true)

    if enabled do
      perform_backup(config)
    else
      Logger.info("[Backup] Backups deshabilitados por configuración")
      {:ok, :disabled}
    end
  end

  @doc """
  Elimina backups más antiguos que retention_days.
  """
  def cleanup do
    config = Application.get_env(:streamflix_core, :backup, [])
    backup_path = Keyword.get(config, :backup_path, "priv/backups")
    retention_days = Keyword.get(config, :retention_days, 30)

    if AzureStorage.configured?() do
      cleanup_azure_backups(retention_days)
    else
      cleanup_old_backups(backup_path, retention_days)
    end
  end

  @doc """
  Retorna información sobre el último backup disponible.
  """
  def last_backup_info do
    if AzureStorage.configured?() do
      last_backup_info_azure()
    else
      last_backup_info_local()
    end
  end

  # --- Private ---

  defp perform_backup(config) do
    backup_path = Keyword.get(config, :backup_path, "priv/backups")
    pg_dump_path = Keyword.get(config, :pg_dump_path, "pg_dump")

    File.mkdir_p!(backup_path)

    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y%m%d_%H%M%S")
    env_prefix = backup_env_prefix()
    filename = "#{env_prefix}/streamflix_#{timestamp}.sql.gz"
    local_filename = "streamflix_#{env_prefix}_#{timestamp}.sql.gz"
    filepath = Path.join(backup_path, local_filename)

    case build_pg_dump_env() do
      {:ok, env} ->
        case run_pg_dump(pg_dump_path, filepath, env) do
          {:ok, result} ->
            maybe_upload_to_azure(result, filename, filepath)

          error ->
            error
        end

      {:error, reason} ->
        Logger.error("[Backup] No se pudo obtener configuración de BD: #{reason}")
        {:error, reason}
    end
  end

  defp maybe_upload_to_azure(result, filename, filepath) do
    if AzureStorage.configured?() do
      azure_config = Application.get_env(:streamflix_core, :azure_storage, [])
      container = Keyword.get(azure_config, :container_backups, "backups")

      Logger.info("[Backup] Subiendo #{filename} a Azure Blob Storage (#{container})...")

      case File.read(filepath) do
        {:ok, body} ->
          case AzureStorage.upload_blob(container, filename, body) do
            {:ok, _resp} ->
              File.rm(filepath)
              Logger.info("[Backup] Subido a Azure y archivo local eliminado")
              {:ok, Map.put(result, :storage, "azure")}

            {:error, reason} ->
              Logger.warning(
                "[Backup] Fallo al subir a Azure: #{inspect(reason)}. Se conserva archivo local."
              )

              {:ok, Map.put(result, :storage, "local")}
          end

        {:error, reason} ->
          Logger.warning(
            "[Backup] No se pudo leer archivo para subir a Azure: #{inspect(reason)}"
          )

          {:ok, Map.put(result, :storage, "local")}
      end
    else
      {:ok, Map.put(result, :storage, "local")}
    end
  end

  defp last_backup_info_azure do
    azure_config = Application.get_env(:streamflix_core, :azure_storage, [])
    container = Keyword.get(azure_config, :container_backups, "backups")
    prefix = "#{backup_env_prefix()}/streamflix_"

    case AzureStorage.list_blobs(container, prefix: prefix) do
      {:ok, blobs} ->
        case Enum.sort_by(blobs, & &1.name, :desc) do
          [latest | _] ->
            {:ok,
             %{
               filename: latest.name,
               size: latest.size,
               storage: "azure",
               last_modified: latest.last_modified
             }}

          [] ->
            {:ok, nil}
        end

      {:error, _reason} ->
        {:ok, nil}
    end
  end

  defp last_backup_info_local do
    config = Application.get_env(:streamflix_core, :backup, [])
    backup_path = Keyword.get(config, :backup_path, "priv/backups")

    case list_backups(backup_path) do
      [latest | _] -> {:ok, Map.put(latest, :storage, "local")}
      [] -> {:ok, nil}
    end
  end

  defp cleanup_azure_backups(retention_days) do
    azure_config = Application.get_env(:streamflix_core, :azure_storage, [])
    container = Keyword.get(azure_config, :container_backups, "backups")
    prefix = "#{backup_env_prefix()}/streamflix_"

    case AzureStorage.list_blobs(container, prefix: prefix) do
      {:ok, blobs} ->
        deleted =
          blobs
          |> Enum.filter(fn blob ->
            case parse_blob_timestamp(blob.name) do
              {:ok, blob_time} ->
                cutoff = DateTime.utc_now() |> DateTime.add(-retention_days * 86_400, :second)
                DateTime.compare(blob_time, cutoff) == :lt

              :error ->
                false
            end
          end)
          |> Enum.map(fn blob ->
            AzureStorage.delete_blob(container, blob.name)
            blob.name
          end)

        if deleted != [] do
          Logger.info("[Backup] Limpieza Azure: #{length(deleted)} backups antiguos eliminados")
        end

        {:ok, length(deleted)}

      {:error, reason} ->
        Logger.error("[Backup] Error al listar blobs de Azure para limpieza: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_blob_timestamp(name) do
    # Extraer timestamp de "streamflix_20260303_020000.sql.gz"
    case Regex.run(~r/streamflix_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})/, name) do
      [_, y, mo, d, h, mi, s] ->
        case DateTime.new(
               Date.new!(String.to_integer(y), String.to_integer(mo), String.to_integer(d)),
               Time.new!(String.to_integer(h), String.to_integer(mi), String.to_integer(s))
             ) do
          {:ok, dt} -> {:ok, dt}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp build_pg_dump_env do
    repo_config = Repo.config()

    cond do
      # Si hay URL, parsearla
      url = repo_config[:url] ->
        parse_database_url(url)

      # Si hay config individual
      repo_config[:hostname] ->
        {:ok,
         %{
           host: repo_config[:hostname] || "localhost",
           port: to_string(repo_config[:port] || 5432),
           database: repo_config[:database] || "postgres",
           username: repo_config[:username] || "postgres",
           password: repo_config[:password] || ""
         }}

      true ->
        {:error, "No database configuration found"}
    end
  end

  defp parse_database_url(url) do
    # Convertir ecto:// a postgresql:// para parsing
    url = String.replace(url, ~r/^ecto:\/\//, "postgresql://")

    uri = URI.parse(url)

    userinfo = uri.userinfo || ""

    {username, password} =
      case String.split(userinfo, ":", parts: 2) do
        [user, pass] -> {user, pass}
        [user] -> {user, ""}
        _ -> {"postgres", ""}
      end

    {:ok,
     %{
       host: uri.host || "localhost",
       port: to_string(uri.port || 5432),
       database: String.trim_leading(uri.path || "/postgres", "/"),
       username: URI.decode(username),
       password: URI.decode(password)
     }}
  rescue
    e -> {:error, "Error parsing DATABASE_URL: #{inspect(e)}"}
  end

  defp run_pg_dump(pg_dump_path, filepath, db_env) do
    # pg_dump con gzip piped
    args = [
      "-h",
      db_env.host,
      "-p",
      db_env.port,
      "-U",
      db_env.username,
      "-d",
      db_env.database,
      "--no-owner",
      "--no-acl",
      "--format=custom",
      "--compress=6",
      "-f",
      filepath
    ]

    env = [{"PGPASSWORD", db_env.password}]

    Logger.info("[Backup] Iniciando backup: #{Path.basename(filepath)}")
    started_at = System.monotonic_time(:millisecond)

    case System.cmd(pg_dump_path, args, env: env, stderr_to_stdout: true) do
      {_output, 0} ->
        duration_ms = System.monotonic_time(:millisecond) - started_at
        %{size: size} = File.stat!(filepath)

        Logger.info(
          "[Backup] Completado: #{Path.basename(filepath)} " <>
            "(#{format_bytes(size)}, #{duration_ms}ms)"
        )

        {:ok, %{file: filepath, size: size, duration_ms: duration_ms}}

      {output, exit_code} ->
        # Limpiar archivo parcial si existe
        File.rm(filepath)

        Logger.error(
          "[Backup] pg_dump falló (exit #{exit_code}): #{String.slice(output, 0, 500)}"
        )

        {:error, "pg_dump exit code #{exit_code}: #{String.slice(output, 0, 200)}"}
    end
  rescue
    e in ErlangError ->
      Logger.error("[Backup] pg_dump no encontrado o no ejecutable: #{inspect(e)}")
      {:error, "pg_dump not found or not executable"}
  end

  defp cleanup_old_backups(backup_path, retention_days) do
    cutoff = DateTime.utc_now() |> DateTime.add(-retention_days * 86_400, :second)

    case File.ls(backup_path) do
      {:ok, files} ->
        deleted =
          files
          |> Enum.filter(&String.starts_with?(&1, "streamflix_"))
          |> Enum.filter(fn file ->
            filepath = Path.join(backup_path, file)

            case File.stat(filepath, time: :posix) do
              {:ok, %{mtime: mtime}} ->
                file_time = DateTime.from_unix!(mtime)
                DateTime.compare(file_time, cutoff) == :lt

              _ ->
                false
            end
          end)
          |> Enum.map(fn file ->
            filepath = Path.join(backup_path, file)
            File.rm(filepath)
            file
          end)

        if deleted != [] do
          Logger.info("[Backup] Limpieza: #{length(deleted)} backups antiguos eliminados")
        end

        {:ok, length(deleted)}

      {:error, :enoent} ->
        {:ok, 0}

      {:error, reason} ->
        Logger.error("[Backup] Error al listar directorio de backups: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp list_backups(backup_path) do
    case File.ls(backup_path) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.starts_with?(&1, "streamflix_"))
        |> Enum.sort(:desc)
        |> Enum.map(fn file ->
          filepath = Path.join(backup_path, file)

          case File.stat(filepath) do
            {:ok, stat} ->
              %{
                file: filepath,
                filename: file,
                size: stat.size,
                created_at: stat.mtime
              }

            _ ->
              nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp backup_env_prefix do
    case System.get_env("PHX_HOST") do
      "jobcelis.com" -> "production"
      nil -> "local"
      _other -> "staging"
    end
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"
end
