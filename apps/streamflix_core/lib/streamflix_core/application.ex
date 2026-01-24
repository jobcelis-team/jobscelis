defmodule StreamflixCore.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      # Database
      StreamflixCore.Repo,

      # PubSub for cross-node communication
      {Phoenix.PubSub, name: StreamflixCore.PubSub},

      # Local Registry
      {Registry, keys: :unique, name: StreamflixCore.Registry},

      # Distributed Registry (Horde)
      StreamflixCore.Distributed.GlobalRegistry,

      # Distributed Supervisor (Horde)
      StreamflixCore.Distributed.GlobalSupervisor,

      # Event Store
      StreamflixCore.Events.EventStore,

      # Event Bus
      StreamflixCore.Events.EventBus,

      # Cluster Manager
      StreamflixCore.Distributed.ClusterManager,

      # Cache
      StreamflixCore.Cache,

      # Background Jobs (Oban)
      {Oban, Application.fetch_env!(:streamflix_core, Oban)}
    ]

    opts = [strategy: :one_for_one, name: StreamflixCore.Supervisor]

    Logger.info("[StreamflixCore] Starting application...")
    Logger.info("[StreamflixCore] Node: #{Node.self()}")

    Supervisor.start_link(children, opts)
  end
end
