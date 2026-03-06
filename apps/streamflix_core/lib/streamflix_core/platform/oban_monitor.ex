defmodule StreamflixCore.Platform.ObanMonitor do
  @moduledoc """
  Queries the oban_jobs table directly to provide a lightweight
  Oban dashboard without requiring the paid oban_web package.
  """

  import Ecto.Query
  alias StreamflixCore.Repo

  @states ~w(available scheduled executing retryable completed discarded cancelled)

  @doc "Returns a map of state => count for all queues."
  def queue_stats do
    from(j in "oban_jobs",
      group_by: [j.queue, j.state],
      select: {j.queue, j.state, count(j.id)}
    )
    |> Repo.all()
    |> Enum.group_by(&elem(&1, 0), fn {_queue, state, count} -> {state, count} end)
    |> Enum.map(fn {queue, state_counts} ->
      counts = Map.new(state_counts)
      %{queue: queue, counts: counts}
    end)
    |> Enum.sort_by(& &1.queue)
  end

  @doc "Returns aggregate counts by state across all queues."
  def state_counts do
    from(j in "oban_jobs",
      group_by: j.state,
      select: {j.state, count(j.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc "Lists recent jobs with optional filters."
  def list_jobs(opts \\ []) do
    state = Keyword.get(opts, :state)
    queue = Keyword.get(opts, :queue)
    limit = Keyword.get(opts, :limit, 50)

    query =
      from(j in "oban_jobs",
        select: %{
          id: j.id,
          state: j.state,
          queue: j.queue,
          worker: j.worker,
          args: j.args,
          attempt: j.attempt,
          max_attempts: j.max_attempts,
          errors: j.errors,
          inserted_at: j.inserted_at,
          scheduled_at: j.scheduled_at,
          attempted_at: j.attempted_at,
          completed_at: j.completed_at,
          discarded_at: j.discarded_at,
          cancelled_at: j.cancelled_at
        },
        order_by: [desc: j.inserted_at],
        limit: ^limit
      )

    query = if state, do: where(query, [j], j.state == ^state), else: query
    query = if queue, do: where(query, [j], j.queue == ^queue), else: query

    Repo.all(query)
  end

  @doc "Cancels a job by ID (sets state to cancelled)."
  def cancel_job(job_id) do
    case Oban.cancel_job(job_id) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Retries a job by ID (resets to available state)."
  def retry_job(job_id) do
    case Oban.retry_job(job_id) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Deletes completed/discarded/cancelled jobs older than given days."
  def purge_jobs(older_than_days \\ 7) do
    cutoff = NaiveDateTime.utc_now() |> NaiveDateTime.add(-older_than_days * 86_400)

    {count, _} =
      from(j in "oban_jobs",
        where: j.state in ["completed", "discarded", "cancelled"],
        where: j.inserted_at < ^cutoff
      )
      |> Repo.delete_all()

    {:ok, count}
  end

  @doc "Returns the list of known states."
  def states, do: @states

  @doc "Returns the list of distinct queues."
  def queues do
    from(j in "oban_jobs",
      distinct: true,
      select: j.queue,
      order_by: j.queue
    )
    |> Repo.all()
  end
end
