defmodule StreamflixCore.Uptime do
  @moduledoc """
  Context for uptime monitoring. Performs health checks and stores results.
  Used by ObanUptimeWorker every 5 minutes.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.UptimeCheck

  @doc """
  Perform a full health check, measure response time, and store the result.
  Returns {:ok, uptime_check} or {:error, changeset}.
  """
  def perform_health_check do
    start = System.monotonic_time(:millisecond)

    checks = %{
      database: check_database(),
      oban: check_oban(),
      cache: check_cache(),
      backup: check_backup()
    }

    response_time_ms = System.monotonic_time(:millisecond) - start

    status =
      cond do
        checks.database != "ok" -> "unhealthy"
        checks.oban != "ok" or checks.cache != "ok" -> "degraded"
        true -> "healthy"
      end

    %UptimeCheck{}
    |> UptimeCheck.changeset(%{
      status: status,
      checks: checks,
      response_time_ms: response_time_ms,
      metadata: %{}
    })
    |> Repo.insert()
  end

  @doc """
  Calculate uptime percentage for a given period.
  Accepts :last_24h, :last_7d, or :last_30d.
  Returns %{uptime_percent, total, healthy, degraded, unhealthy}.
  """
  def calculate_uptime(period) do
    since = period_to_datetime(period)

    stats =
      UptimeCheck
      |> where([u], u.inserted_at >= ^since)
      |> select([u], %{
        total: count(u.id),
        healthy: fragment("COUNT(CASE WHEN ? = 'healthy' THEN 1 END)", u.status),
        degraded: fragment("COUNT(CASE WHEN ? = 'degraded' THEN 1 END)", u.status),
        unhealthy: fragment("COUNT(CASE WHEN ? = 'unhealthy' THEN 1 END)", u.status)
      })
      |> Repo.one()

    uptime_percent =
      if stats.total > 0 do
        ((stats.healthy + stats.degraded) / stats.total * 100)
        |> Float.round(2)
      else
        100.0
      end

    Map.put(stats, :uptime_percent, uptime_percent)
  end

  @doc "Get the latest uptime check record."
  def latest_check do
    UptimeCheck
    |> order_by([u], desc: u.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  # --- Private health checks (duplicated from HealthController, intentionally) ---

  defp check_database do
    try do
      Repo.query!("SELECT 1")
      "ok"
    rescue
      _ -> "error"
    end
  end

  defp check_oban do
    try do
      %{running: _} = Oban.check_queue(queue: :default)
      "ok"
    rescue
      _ -> "error"
    end
  end

  defp check_cache do
    try do
      case Cachex.size(:platform_cache) do
        {:ok, _} -> "ok"
        _ -> "error"
      end
    rescue
      _ -> "error"
    end
  end

  defp check_backup do
    case StreamflixCore.Platform.Backup.last_backup_info() do
      {:ok, nil} -> "no_backups"
      {:ok, _info} -> "ok"
    end
  end

  defp period_to_datetime(:last_24h), do: DateTime.utc_now() |> DateTime.add(-24 * 3600, :second)

  defp period_to_datetime(:last_7d),
    do: DateTime.utc_now() |> DateTime.add(-7 * 24 * 3600, :second)

  defp period_to_datetime(:last_30d),
    do: DateTime.utc_now() |> DateTime.add(-30 * 24 * 3600, :second)
end
