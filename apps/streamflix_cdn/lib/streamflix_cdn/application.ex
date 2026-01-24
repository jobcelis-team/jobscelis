defmodule StreamflixCdn.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      # HTTP connection pool for Azure requests
      {Finch, name: StreamflixCdn.Finch}
    ]

    opts = [strategy: :one_for_one, name: StreamflixCdn.Supervisor]

    Logger.info("[StreamflixCdn] Starting...")
    Logger.info("[StreamflixCdn] Azure Account: #{get_azure_account()}")

    Supervisor.start_link(children, opts)
  end

  defp get_azure_account do
    Application.get_env(:streamflix_cdn, :azure_account, "not_configured")
  end
end
