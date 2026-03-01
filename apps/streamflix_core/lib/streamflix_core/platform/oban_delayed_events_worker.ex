defmodule StreamflixCore.Platform.ObanDelayedEventsWorker do
  @moduledoc """
  Oban cron worker that processes delayed events whose deliver_at has passed.
  Runs every minute.
  """
  use Oban.Worker, queue: :default, max_attempts: 1

  @impl Oban.Worker
  def perform(_job) do
    StreamflixCore.Platform.process_delayed_events()
    :ok
  end
end
