defmodule StreamflixCore.Platform.Jobs do
  @moduledoc """
  Job management: CRUD, scheduling, cron matching, job runs.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{Job, JobRun}

  def create_job(project_id, attrs) do
    attrs = Map.merge(attrs, %{"project_id" => project_id})

    %Job{}
    |> Job.changeset(attrs)
    |> Repo.insert()
  end

  def list_jobs(project_id, opts \\ []) do
    include_inactive = Keyword.get(opts, :include_inactive, false)

    Job
    |> where([j], j.project_id == ^project_id)
    |> maybe_filter_active(include_inactive)
    |> order_by([j], desc: j.inserted_at)
    |> Repo.all()
  end

  def get_job(id), do: Repo.get_uuid(Job, id)
  def get_job!(id), do: Repo.get!(Job, id)

  def update_job(%Job{} = job, attrs) do
    job
    |> Job.changeset(attrs)
    |> Repo.update()
  end

  def set_job_inactive(%Job{} = job) do
    update_job(job, %{status: "inactive"})
  end

  @doc """
  Active jobs due in the minute containing `at` (UTC). Matching is done per whole
  minute; the scheduler calls this once for every minute, catching up on any it
  missed, so exact matching never skips or double-fires a run.
  """
  def list_jobs_to_run_now(at \\ DateTime.utc_now()) do
    slot = minute_slot(at)

    Job
    |> where([j], j.status == "active")
    |> Repo.all()
    |> Enum.filter(&job_due?(&1, slot))
  end

  @doc "Truncates a datetime to the start of its minute (UTC)."
  def minute_slot(%DateTime{} = at) do
    %{DateTime.truncate(at, :second) | second: 0}
  end

  @doc false
  def job_due?(%Job{} = job, %DateTime{} = slot) do
    cfg = job.schedule_config || %{}
    date = DateTime.to_date(slot)
    time_ok = cfg_int(cfg, "hour", 0) == slot.hour and cfg_int(cfg, "minute", 0) == slot.minute

    case job.schedule_type || "daily" do
      "daily" ->
        time_ok

      "weekly" ->
        dow = cfg_int(cfg, "day_of_week", nil)
        # Accept both 0 and 7 for Sunday
        dow_ok = dow == nil or rem(dow, 7) == rem(Date.day_of_week(date), 7)
        dow_ok and time_ok

      "monthly" ->
        # Day 29-31 runs on the last day of shorter months instead of being skipped
        dom = cfg_int(cfg, "day_of_month", nil)
        dom_ok = dom == nil or min(dom, Date.days_in_month(date)) == date.day
        dom_ok and time_ok

      "cron" ->
        cron_matches?(Map.get(cfg, "expr") || Map.get(cfg, "expression"), slot)

      _ ->
        false
    end
  end

  defp cfg_int(cfg, key, default) do
    case Map.get(cfg, key) do
      n when is_integer(n) ->
        n

      s when is_binary(s) ->
        case Integer.parse(s) do
          {n, ""} -> n
          _ -> default
        end

      _ ->
        default
    end
  end

  def cron_matches?(expr, %DateTime{} = at) when is_binary(expr) do
    case Crontab.CronExpression.Parser.parse(expr) do
      {:ok, cron} -> Crontab.DateChecker.matches_date?(cron, DateTime.to_naive(minute_slot(at)))
      {:error, _} -> false
    end
  end

  def cron_matches?(_expr, _at), do: false

  @doc """
  Calculate next N execution times for a cron expression.
  Returns list of DateTime structs.
  """
  def next_cron_executions(cron_expr, count \\ 5) when is_binary(cron_expr) do
    case Crontab.CronExpression.Parser.parse(cron_expr) do
      {:ok, cron} ->
        # Start at the next whole minute: the current minute has already begun, and starting
        # from "now" could return it as a run time that is already in the past.
        now = NaiveDateTime.utc_now()
        next_minute = %{now | second: 0, microsecond: {0, 0}} |> NaiveDateTime.add(60)

        Crontab.Scheduler.get_next_run_dates(cron, next_minute)
        |> Enum.take(count)
        |> Enum.map(&DateTime.from_naive!(&1, "Etc/UTC"))

      {:error, _} ->
        []
    end
  end

  def list_job_runs(job_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    JobRun
    |> where([r], r.job_id == ^job_id)
    |> order_by([r], desc: r.executed_at)
    |> limit(^limit)
    |> Repo.all()
  end

  defp maybe_filter_active(query, true), do: query
  defp maybe_filter_active(query, false), do: where(query, [x], x.status == "active")
end
