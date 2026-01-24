defmodule StreamflixCatalog.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      # Content Server Registry
      {Registry, keys: :unique, name: StreamflixCatalog.ContentRegistry},

      # Content Server Supervisor
      {DynamicSupervisor, name: StreamflixCatalog.ContentSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: StreamflixCatalog.Supervisor]

    Logger.info("[StreamflixCatalog] Starting...")

    Supervisor.start_link(children, opts)
  end
end
