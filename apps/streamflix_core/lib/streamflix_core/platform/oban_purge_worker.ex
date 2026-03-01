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
  alias StreamflixCore.Schemas.{Delivery, JobRun, SandboxEndpoint, SandboxRequest, DeadLetter}

  @delivery_retention_days 90
  @job_run_retention_days 90
  @dead_letter_retention_days 30

  @impl true
  def perform(_job) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    delivery_cutoff = DateTime.add(now, -@delivery_retention_days, :day)
    job_run_cutoff = DateTime.add(now, -@job_run_retention_days, :day)
    dead_letter_cutoff = DateTime.add(now, -@dead_letter_retention_days, :day)

    # Purge old successful deliveries
    {del_count, _} =
      from(d in Delivery,
        where: d.status == "success" and d.inserted_at < ^delivery_cutoff
      )
      |> Repo.delete_all()

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

    Logger.info(
      "[PurgeWorker] Purged: #{del_count} deliveries, #{run_count} job_runs, " <>
        "#{sandbox_count} sandbox endpoints (#{req_count} requests), #{dlq_count} dead letters"
    )

    :ok
  end
end
