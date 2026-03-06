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

  def get_job(id), do: Repo.get(Job, id)
  def get_job!(id), do: Repo.get!(Job, id)

  def update_job(%Job{} = job, attrs) do
    job
    |> Job.changeset(attrs)
    |> Repo.update()
  end

  def set_job_inactive(%Job{} = job) do
    update_job(job, %{status: "inactive"})
  end

  def list_jobs_to_run_now() do
    now = DateTime.utc_now()
    today_sec = now.hour * 3600 + now.minute * 60 + now.second
    date = DateTime.to_date(now)
    day_of_week = Date.day_of_week(date)
    day_of_month = date.day
    month = date.month
    minute = now.minute
    hour = now.hour

    Job
    |> where([j], j.status == "active")
    |> Repo.all()
    |> Enum.filter(fn j ->
      cfg = j.schedule_config || %{}
      type = j.schedule_type || "daily"

      case type do
        "daily" ->
          h = Map.get(cfg, "hour", 0)
          m = Map.get(cfg, "minute", 0)
          target_sec = h * 3600 + m * 60
          target_sec == today_sec or abs(target_sec - today_sec) < 60

        "weekly" ->
          dow = Map.get(cfg, "day_of_week")
          h = Map.get(cfg, "hour", 0)
          min_cfg = Map.get(cfg, "minute", 0)
          dow_ok = dow == nil or dow == day_of_week or (dow == 0 and day_of_week == 7)
          time_ok = h == hour and min_cfg == minute
          dow_ok and time_ok

        "monthly" ->
          dom = Map.get(cfg, "day_of_month")
          h = Map.get(cfg, "hour", 0)
          min_cfg = Map.get(cfg, "minute", 0)
          dom_ok = dom == nil or dom == day_of_month
          time_ok = h == hour and min_cfg == minute
          dom_ok and time_ok

        "cron" ->
          expr = Map.get(cfg, "expr") || Map.get(cfg, "expression")
          cron_matches?(expr, minute, hour, day_of_month, month, day_of_week)

        _ ->
          false
      end
    end)
  end

  def cron_matches?(nil, _min, _h, _dom, _mon, _dow), do: false

  def cron_matches?(expr, min, hour, day_of_month, month, day_of_week) when is_binary(expr) do
    parts = String.split(expr, ~r/\s+/, trim: true)

    if length(parts) >= 5 do
      [min_s, hour_s, dom_s, mon_s, dow_s] = Enum.take(parts, 5)

      cron_field_match?(min_s, min, 0, 59) and
        cron_field_match?(hour_s, hour, 0, 23) and
        cron_field_match?(dom_s, day_of_month, 1, 31) and
        cron_field_match?(mon_s, month, 1, 12) and
        cron_field_match?(dow_s, day_of_week, 1, 7)
    else
      false
    end
  end

  def cron_matches?(_, _min, _h, _dom, _mon, _dow), do: false

  defp cron_field_match?("*", _val, _lo, _hi), do: true

  defp cron_field_match?(str, val, _lo, _hi) do
    case Integer.parse(str) do
      {n, _} -> n == val
      _ -> false
    end
  end

  @doc """
  Calculate next N execution times for a cron expression.
  Returns list of DateTime structs.
  """
  def next_cron_executions(cron_expr, count \\ 5) when is_binary(cron_expr) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    # Start from the next full minute
    start = DateTime.add(now, 60 - now.second, :second)

    Stream.iterate(start, fn dt -> DateTime.add(dt, 60, :second) end)
    |> Stream.filter(fn dt ->
      date = DateTime.to_date(dt)

      cron_matches?(
        cron_expr,
        dt.minute,
        dt.hour,
        date.day,
        date.month,
        Date.day_of_week(date)
      )
    end)
    |> Enum.take(count)
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
