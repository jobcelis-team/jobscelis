defmodule StreamflixCore.Platform.ObanUptimeWorker do
  @moduledoc """
  Oban worker that runs health checks every 5 minutes.
  Records results in uptime_checks table and notifies admins on degraded/unhealthy status.
  """
  use Oban.Worker, queue: :default, max_attempts: 1, unique: [period: 300]

  require Logger

  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Notifications

  @impl true
  def perform(_job) do
    case StreamflixCore.Uptime.perform_health_check() do
      {:ok, check} ->
        if check.status in ["degraded", "unhealthy"] do
          notify_admins(check)
        end

        :ok

      {:error, reason} ->
        Logger.error("[ObanUptimeWorker] Failed to perform health check: #{inspect(reason)}")
        :ok
    end
  end

  defp notify_admins(check) do
    admin_ids = get_admin_user_ids()

    Enum.each(admin_ids, fn user_id ->
      Notifications.create(%{
        user_id: user_id,
        type: "system_health",
        title: "Estado del sistema: #{check.status}",
        message: "El sistema está #{check.status}. Checks: #{inspect(check.checks)}",
        metadata: %{"status" => check.status, "checks" => check.checks}
      })
    end)
  end

  defp get_admin_user_ids do
    from(u in "users",
      where: u.role in ["admin", "superadmin"] and u.status == "active",
      select: u.id
    )
    |> Repo.all()
  end
end
