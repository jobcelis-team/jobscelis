defmodule StreamflixCore.Platform.ObanBackupVerificationWorker do
  @moduledoc """
  Oban cron worker that verifies the latest backup is valid and recent.
  Scheduled monthly on the 1st at 5am (config.exs).
  Checks that a backup exists and is not older than the configured threshold.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: 86_400]

  require Logger

  alias StreamflixCore.Platform.Backup
  alias StreamflixCore.Audit

  @max_backup_age_hours 26

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Starting backup verification", worker: "BackupVerificationWorker")

    case Backup.last_backup_info() do
      {:ok, nil} ->
        Logger.warning("No backups found during verification",
          worker: "BackupVerificationWorker"
        )

        Audit.record("system.backup_verification_failed",
          metadata: %{reason: "no_backups_found"}
        )

        :ok

      {:ok, info} ->
        verify_backup_age(info)

      {:error, reason} ->
        Logger.error("Backup verification failed",
          worker: "BackupVerificationWorker",
          error: to_string(reason)
        )

        Audit.record("system.backup_verification_failed",
          metadata: %{reason: to_string(reason)}
        )

        :ok
    end
  end

  defp verify_backup_age(info) do
    last_modified = get_last_modified(info)
    age_hours = age_in_hours(last_modified)

    if age_hours <= @max_backup_age_hours do
      Logger.info("Backup verification passed",
        worker: "BackupVerificationWorker",
        file: info[:filename] || Path.basename(info[:file] || ""),
        age_hours: age_hours,
        storage: info[:storage]
      )

      Audit.record("system.backup_verification_passed",
        metadata: %{
          filename: info[:filename] || Path.basename(info[:file] || ""),
          age_hours: age_hours,
          size_bytes: info[:size],
          storage: info[:storage]
        }
      )

      :ok
    else
      Logger.warning("Backup is too old",
        worker: "BackupVerificationWorker",
        age_hours: age_hours,
        file: info[:filename] || Path.basename(info[:file] || "")
      )

      Audit.record("system.backup_verification_stale",
        metadata: %{
          filename: info[:filename] || Path.basename(info[:file] || ""),
          age_hours: age_hours,
          threshold_hours: @max_backup_age_hours
        }
      )

      :ok
    end
  end

  defp get_last_modified(%{last_modified: lm}) when is_binary(lm) do
    case DateTime.from_iso8601(lm) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp get_last_modified(%{last_modified: %DateTime{} = dt}), do: dt

  defp get_last_modified(%{created_at: {{y, mo, d}, {h, mi, s}}}) do
    case DateTime.new(Date.new!(y, mo, d), Time.new!(h, mi, s)) do
      {:ok, dt} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp get_last_modified(_), do: DateTime.utc_now()

  defp age_in_hours(datetime) do
    DateTime.diff(DateTime.utc_now(), datetime, :hour)
  end
end
