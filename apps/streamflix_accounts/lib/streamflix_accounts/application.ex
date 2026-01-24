defmodule StreamflixAccounts.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      # Session Manager
      StreamflixAccounts.Services.SessionManager,

      # Profile Supervisor (one GenServer per active profile)
      {DynamicSupervisor, name: StreamflixAccounts.ProfileSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: StreamflixAccounts.Supervisor]

    Logger.info("[StreamflixAccounts] Starting...")

    Supervisor.start_link(children, opts)
  end
end
