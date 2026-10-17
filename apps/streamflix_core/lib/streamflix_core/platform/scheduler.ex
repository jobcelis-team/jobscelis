defmodule StreamflixCore.Platform.Scheduler do
  @moduledoc """
  Runs every minute and enqueues Oban jobs for platform scheduled jobs (daily/weekly/monthly/cron).
  """
  use GenServer
  require Logger
  alias StreamflixCore.Platform

  # Missed minutes (deploy, long GC pause, slow tick) are caught up to this limit
  @max_catch_up 10

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_) do
    schedule_next()
    {:ok, %{last_slot: nil}}
  end

  @impl true
  def handle_info(:tick, state) do
    current = Platform.minute_slot(DateTime.utc_now())

    current
    |> slots_to_run(state.last_slot)
    |> Enum.each(&enqueue_slot/1)

    schedule_next()
    {:noreply, %{state | last_slot: current}}
  end

  @doc false
  def slots_to_run(current, nil), do: [current]

  def slots_to_run(current, last) do
    missed = div(DateTime.diff(current, last, :second), 60)

    cond do
      missed <= 0 -> []
      true -> for n <- (min(missed, @max_catch_up) - 1)..0//-1, do: DateTime.add(current, -n * 60)
    end
  end

  defp enqueue_slot(slot) do
    for job <- Platform.list_jobs_to_run_now(slot) do
      args = %{job_id: job.id, slot: DateTime.to_iso8601(slot)}

      case Oban.insert(StreamflixCore.Platform.ObanScheduledJobWorker.new(args)) do
        {:ok, _} ->
          Logger.debug("Scheduled job enqueued", worker: "Scheduler", job_id: job.id)

        {:error, reason} ->
          Logger.warning("Failed to enqueue scheduled job",
            worker: "Scheduler",
            job_id: job.id,
            error: inspect(reason)
          )
      end
    end
  end

  # Tick shortly after each minute boundary instead of every 60s from the last
  # tick, which drifted and could skip a whole minute.
  defp schedule_next() do
    now = DateTime.utc_now()
    ms_into_minute = now.second * 1000 + div(elem(now.microsecond, 0), 1000)
    Process.send_after(self(), :tick, 60_000 - ms_into_minute + 500)
  end
end
