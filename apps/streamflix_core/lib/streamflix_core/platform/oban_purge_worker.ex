defmodule StreamflixCore.Platform.ObanPurgeWorker do
  @moduledoc """
  Oban cron worker that purges old data weekly:
  - Successful deliveries and events past the project's retention (default 90 days)
  - Audit logs past the project's `audit_logs_days` (default 365 days)
  - Job runs older than 90 days
  - Uptime checks older than 30 days
  - Expired sandbox endpoints and their requests
  - Resolved dead letters older than 30 days

  Deletes run in batches, so no statement holds a long transaction or a large
  cascade on the shared database.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 1,
    unique: [period: 3600]

  import Ecto.Query
  require Logger

  alias StreamflixCore.Repo

  alias StreamflixCore.Schemas.{
    Delivery,
    JobRun,
    DeadLetter,
    Project,
    WebhookEvent
  }

  @default_retention_days 90
  @default_audit_log_retention_days 365
  @job_run_retention_days 90
  @dead_letter_retention_days 30
  @uptime_check_retention_days 30
  @delete_batch 5_000

  @impl true
  def perform(_job) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    job_run_cutoff = DateTime.add(now, -@job_run_retention_days, :day)
    dead_letter_cutoff = DateTime.add(now, -@dead_letter_retention_days, :day)

    # Purge deliveries, events and audit logs per project with custom retention
    del_count = purge_deliveries_per_project(now)
    event_count = purge_events_per_project(now)
    audit_count = purge_audit_logs_per_project(now)

    # Purge old job runs
    run_count =
      delete_in_batches(JobRun, from(r in JobRun, where: r.executed_at < ^job_run_cutoff))

    # uptime_checks.inserted_at is a naive (UTC) timestamp
    uptime_cutoff =
      now |> DateTime.add(-@uptime_check_retention_days, :day) |> DateTime.to_naive()

    uptime_count =
      delete_in_batches(
        StreamflixCore.Schemas.UptimeCheck,
        from(u in StreamflixCore.Schemas.UptimeCheck, where: u.inserted_at < ^uptime_cutoff)
      )

    # Purge expired sandbox endpoints and their requests (also done daily by
    # ObanSandboxPurgeWorker)
    {sandbox_count, req_count} = StreamflixCore.Platform.Sandbox.purge_expired(now)

    # Purge old resolved dead letters
    {dlq_count, _} =
      from(dl in DeadLetter,
        where: dl.resolved == true and dl.resolved_at < ^dead_letter_cutoff
      )
      |> Repo.delete_all()

    Logger.info("Purge completed",
      worker: "PurgeWorker",
      deliveries_purged: del_count,
      events_purged: event_count,
      job_runs_purged: run_count,
      sandbox_endpoints_purged: sandbox_count,
      sandbox_requests_purged: req_count,
      dead_letters_purged: dlq_count,
      audit_logs_purged: audit_count,
      uptime_checks_purged: uptime_count
    )

    :ok
  end

  defp purge_deliveries_per_project(now) do
    projects =
      Repo.all(from(p in Project, select: {p.id, p.retention_days, p.retention_policy}))

    Enum.reduce(projects, 0, fn {project_id, retention_days, retention_policy}, acc ->
      days = delivery_retention(retention_policy, retention_days)

      if days == 0 do
        acc
      else
        cutoff = DateTime.add(now, -days, :day)

        webhook_ids = StreamflixCore.Platform.Deliveries.project_webhook_ids(project_id)

        count =
          delete_in_batches(
            Delivery,
            from(d in Delivery,
              where: d.webhook_id in subquery(webhook_ids),
              where: d.status == "success" and d.inserted_at < ^cutoff
            )
          )

        acc + count
      end
    end)
  end

  defp purge_events_per_project(now) do
    projects =
      Repo.all(from(p in Project, select: {p.id, p.retention_days, p.retention_policy}))

    Enum.reduce(projects, 0, fn {project_id, retention_days, retention_policy}, acc ->
      days = event_retention(retention_policy, retention_days)

      if days == 0 do
        acc
      else
        cutoff = DateTime.add(now, -days, :day)

        # Soft-deleted (inactive) events follow the same retention
        count =
          delete_in_batches(
            WebhookEvent,
            from(e in WebhookEvent,
              where: e.project_id == ^project_id and e.inserted_at < ^cutoff
            )
          )

        acc + count
      end
    end)
  end

  defp purge_audit_logs_per_project(now) do
    projects = Repo.all(from(p in Project, select: {p.id, p.retention_policy}))

    Enum.reduce(projects, 0, fn {project_id, policy}, acc ->
      case audit_log_retention(policy) do
        0 ->
          acc

        days ->
          cutoff = DateTime.add(now, -days, :day)

          acc +
            delete_in_batches(
              StreamflixCore.Schemas.AuditLog,
              from(a in StreamflixCore.Schemas.AuditLog,
                where: a.project_id == ^project_id and a.inserted_at < ^cutoff
              )
            )
      end
    end)
  end

  # 0 keeps them forever, like the other retention settings
  defp audit_log_retention(%{"audit_logs_days" => days}) when is_integer(days), do: days
  defp audit_log_retention(_), do: @default_audit_log_retention_days

  # Deletes the rows of schema matched by query, @delete_batch at a time
  defp delete_in_batches(schema, query, total \\ 0) do
    ids = from(x in query, select: x.id, limit: @delete_batch)

    case Repo.delete_all(from(r in schema, where: r.id in subquery(ids))) do
      {0, _} -> total
      {n, _} -> delete_in_batches(schema, query, total + n)
    end
  end

  defp delivery_retention(policy, legacy_days) when is_map(policy) do
    Map.get(policy, "deliveries_days") || legacy_days || @default_retention_days
  end

  defp delivery_retention(_, legacy_days), do: legacy_days || @default_retention_days

  defp event_retention(policy, legacy_days) when is_map(policy) do
    Map.get(policy, "events_days") || legacy_days || @default_retention_days
  end

  defp event_retention(_, legacy_days), do: legacy_days || @default_retention_days
end
