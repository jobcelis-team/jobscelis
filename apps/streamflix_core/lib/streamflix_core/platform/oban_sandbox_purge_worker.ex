defmodule StreamflixCore.Platform.ObanSandboxPurgeWorker do
  @moduledoc """
  Oban cron worker that deletes expired sandbox endpoints and their captured
  requests every day (sandbox endpoints live 24 hours).
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 1,
    unique: [period: 3600]

  require Logger

  @impl true
  def perform(_job) do
    {endpoints, requests} = StreamflixCore.Platform.Sandbox.purge_expired()

    Logger.info("Sandbox purge completed",
      worker: "SandboxPurgeWorker",
      sandbox_endpoints_purged: endpoints,
      sandbox_requests_purged: requests
    )

    :ok
  end
end
