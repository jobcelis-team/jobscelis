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

    Supervisor.start_link(children, opts)
  end
end
