defmodule Jobcelis.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Finch, name: Jobcelis.Finch}
    ]

    opts = [strategy: :one_for_one, name: Jobcelis.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
