defmodule StreamflixCore.Platform.ObanBackupWorker do
  @moduledoc """
  Oban cron worker que ejecuta backup automatizado de la BD con pg_dump.
  Programado diariamente a las 2am (config.exs).
  Después del backup, limpia backups antiguos según retention_days.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: 3600]

  require Logger

  alias StreamflixCore.Platform.Backup
  alias StreamflixCore.Audit

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("[BackupWorker] Iniciando backup programado")

    case Backup.run() do
      {:ok, :disabled} ->
        :ok

      {:ok, %{file: file, size: size, duration_ms: duration, storage: storage}} ->
        Audit.record("system.backup_completed",
          metadata: %{
            file: Path.basename(file),
            size_bytes: size,
            duration_ms: duration,
            storage: storage
          }
        )

        # Limpiar backups antiguos
        case Backup.cleanup() do
          {:ok, deleted} when deleted > 0 ->
            Logger.info("[BackupWorker] Limpieza completada: #{deleted} backups eliminados")

          _ ->
            :ok
        end

        Logger.info("[BackupWorker] Backup completado exitosamente")
        :ok

      {:error, reason} ->
        Audit.record("system.backup_failed",
          metadata: %{error: to_string(reason)}
        )

        Logger.error("[BackupWorker] Backup falló: #{reason}")
        {:error, reason}
    end
  end
end
