defmodule StreamflixCore.Platform.Scheduler do
  @moduledoc """
  Runs every minute and enqueues Oban jobs for platform scheduled jobs (daily/weekly/monthly).
  """
  use GenServer
  require Logger
  alias StreamflixCore.Platform

  @interval 60 * 1000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_) do
    schedule_next()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:tick, state) do
    jobs = Platform.list_jobs_to_run_now()

    for job <- jobs do
      case Oban.insert(StreamflixCore.Platform.ObanScheduledJobWorker.new(%{job_id: job.id})) do
        {:ok, _} -> Logger.debug("Scheduled job #{job.id} enqueued")
        {:error, reason} -> Logger.warning("Failed to enqueue job #{job.id}: #{inspect(reason)}")
      end
    end

    schedule_next()
    {:noreply, state}
  end

  defp schedule_next() do
    Process.send_after(self(), :tick, @interval)
  end
end
