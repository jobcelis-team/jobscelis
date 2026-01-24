defmodule StreamflixStreaming.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      # Session Registry
      {Registry, keys: :unique, name: StreamflixStreaming.SessionRegistry},

      # Session Supervisor
      {DynamicSupervisor, name: StreamflixStreaming.SessionSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: StreamflixStreaming.Supervisor]

    Logger.info("[StreamflixStreaming] Starting...")

    Supervisor.start_link(children, opts)
  end
end
