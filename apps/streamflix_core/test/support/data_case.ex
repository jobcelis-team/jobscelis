defmodule StreamflixCore.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias StreamflixCore.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import StreamflixCore.Factory
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(StreamflixCore.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
