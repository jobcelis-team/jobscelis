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
    Logger.info("Starting scheduled backup", worker: "BackupWorker")

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

        case Backup.cleanup() do
          {:ok, deleted} when deleted > 0 ->
            Logger.info("Backup cleanup completed",
              worker: "BackupWorker",
              backups_deleted: deleted
            )

          _ ->
            :ok
        end

        Logger.info("Backup completed successfully",
          worker: "BackupWorker",
          file: Path.basename(file),
          size_bytes: size,
          duration_ms: duration
        )

        :ok

      {:error, reason} ->
        Audit.record("system.backup_failed",
          metadata: %{error: to_string(reason)}
        )

        Logger.error("Backup failed", worker: "BackupWorker", error: to_string(reason))
        {:error, reason}
    end
  end
end
