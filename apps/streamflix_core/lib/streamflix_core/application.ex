defmodule StreamflixCore.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      StreamflixCore.Repo,
      StreamflixCore.Vault,
      {Task.Supervisor, name: StreamflixCore.TaskSupervisor},
      {Phoenix.PubSub, name: StreamflixCore.PubSub},
      {Cachex, name: :platform_cache},
      {Finch, name: StreamflixCore.Finch, pools: %{default: [size: 25, count: 1]}},
      {Oban, Application.fetch_env!(:streamflix_core, Oban)},
      StreamflixCore.Platform.Scheduler
    ]

    opts = [strategy: :one_for_one, name: StreamflixCore.Supervisor]

    Logger.info("[StreamflixCore] Starting application...")
    Logger.info("[StreamflixCore] Node: #{Node.self()}")

    result = Supervisor.start_link(children, opts)

    # Run initial health check so the dashboard shows correct status immediately
    schedule_initial_health_check()

    result
  end

  defp schedule_initial_health_check do
    Task.Supervisor.start_child(StreamflixCore.TaskSupervisor, fn ->
      # Small delay to ensure all services are fully initialized
      Process.sleep(3_000)

      case StreamflixCore.Uptime.perform_health_check() do
        {:ok, check} ->
          Logger.info("[StreamflixCore] Initial health check: #{check.status}")

        {:error, reason} ->
          Logger.warning("[StreamflixCore] Initial health check failed: #{inspect(reason)}")
      end
    end)
  end
end
