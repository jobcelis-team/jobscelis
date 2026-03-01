defmodule StreamflixWebWeb.ConnCase do
  @moduledoc """
  Test case for tests that require setting up a connection.
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint StreamflixWebWeb.Endpoint

      use StreamflixWebWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import StreamflixWebWeb.ConnCase
      import StreamflixCore.Factory
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(StreamflixCore.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc "Creates a project and returns a conn with API key set"
  def setup_api_conn(%{conn: conn}) do
    project = StreamflixCore.Factory.insert(:project)
    token = "test_token_#{System.unique_integer([:positive])}"
    hash = Base.encode16(:crypto.hash(:sha256, token), case: :lower)

    project
    |> Ecto.Changeset.change(%{api_key_hash: hash, api_key_prefix: String.slice(token, 0, 8)})
    |> StreamflixCore.Repo.update!()

    conn = put_req_header(conn, "x-api-key", token)
    %{conn: conn, project: project, api_token: token}
  end
end
