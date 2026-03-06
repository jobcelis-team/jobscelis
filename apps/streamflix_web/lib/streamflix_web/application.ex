defmodule StreamflixWeb.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      maybe_prom_ex() ++
        [
          StreamflixWebWeb.Telemetry,
          {DNSCluster,
           query: Application.get_env(:streamflix_web, :dns_cluster_query) || :ignore},
          StreamflixWebWeb.Endpoint
        ]

    opts = [strategy: :one_for_one, name: StreamflixWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_prom_ex do
    repo_config = Application.get_env(:streamflix_core, StreamflixCore.Repo, [])

    if repo_config[:pool] == Ecto.Adapters.SQL.Sandbox do
      []
    else
      [StreamflixWeb.PromEx]
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    StreamflixWebWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
