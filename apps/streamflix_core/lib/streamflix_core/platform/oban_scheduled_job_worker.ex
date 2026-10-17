defmodule StreamflixCore.Platform.ObanScheduledJobWorker do
  @moduledoc """
  Oban worker for platform scheduled jobs (daily/weekly/monthly). Queue: :scheduled_job.
  """
  use Oban.Worker,
    queue: :scheduled_job,
    max_attempts: 1,
    # One run per job per scheduled minute, even with several nodes ticking
    unique: [period: 300, keys: [:job_id, :slot]]

  @impl true
  def perform(%Oban.Job{args: args}) do
    job_id = args["job_id"] || args[:job_id]
    StreamflixCore.Platform.ScheduledJobRunner.run(job_id)
    :ok
  end
end
