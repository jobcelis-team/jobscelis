defmodule StreamflixCore.Platform.ObanPurgeWorker do
  @moduledoc """
  Oban cron worker that purges old data weekly:
  - Successful deliveries older than 90 days
  - Job runs older than 90 days
  - Expired sandbox endpoints and their requests
  - Resolved dead letters older than 30 days
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
    SandboxEndpoint,
    SandboxRequest,
    DeadLetter,
    Project,
    WebhookEvent
  }

  @default_retention_days 90
  @job_run_retention_days 90
  @dead_letter_retention_days 30

  @impl true
  def perform(_job) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    job_run_cutoff = DateTime.add(now, -@job_run_retention_days, :day)
    dead_letter_cutoff = DateTime.add(now, -@dead_letter_retention_days, :day)

    # Purge deliveries and events per-project with custom retention
    del_count = purge_deliveries_per_project(now)
    event_count = purge_events_per_project(now)

    # Purge old job runs
    {run_count, _} =
      from(r in JobRun,
        where: r.executed_at < ^job_run_cutoff
      )
      |> Repo.delete_all()

    # Purge expired sandbox endpoints and their requests
    expired_ids =
      from(s in SandboxEndpoint,
        where: s.expires_at < ^now,
        select: s.id
      )
      |> Repo.all()

    {req_count, _} =
      if expired_ids != [] do
        from(r in SandboxRequest, where: r.endpoint_id in ^expired_ids) |> Repo.delete_all()
      else
        {0, nil}
      end

    {sandbox_count, _} =
      if expired_ids != [] do
        from(s in SandboxEndpoint, where: s.id in ^expired_ids) |> Repo.delete_all()
      else
        {0, nil}
      end

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
      dead_letters_purged: dlq_count
    )

    :ok
  end

  defp purge_deliveries_per_project(now) do
    projects = Repo.all(from(p in Project, select: {p.id, p.retention_days}))

    Enum.reduce(projects, 0, fn {project_id, retention_days}, acc ->
      days = retention_days || @default_retention_days
      cutoff = DateTime.add(now, -days, :day)

      {count, _} =
        from(d in Delivery,
          join: e in WebhookEvent,
          on: d.event_id == e.id,
          where: e.project_id == ^project_id and d.status == "success" and d.inserted_at < ^cutoff
        )
        |> Repo.delete_all()

      acc + count
    end)
  end

  defp purge_events_per_project(now) do
    projects = Repo.all(from(p in Project, select: {p.id, p.retention_days}))

    Enum.reduce(projects, 0, fn {project_id, retention_days}, acc ->
      days = retention_days || @default_retention_days
      cutoff = DateTime.add(now, -days, :day)

      {count, _} =
        from(e in WebhookEvent,
          where: e.project_id == ^project_id and e.status == "active" and e.inserted_at < ^cutoff
        )
        |> Repo.delete_all()

      acc + count
    end)
  end
end
