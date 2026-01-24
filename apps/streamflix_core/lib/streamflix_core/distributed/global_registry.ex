defmodule StreamflixCore.Distributed.GlobalRegistry do
  @moduledoc """
  Distributed process registry using Horde.

  Provides location-transparent process registration across all nodes
  in the cluster. Processes registered here can be accessed from any node.

  ## Example

      # Register a process
      {:ok, pid} = GenServer.start_link(MyServer, [], name: via_tuple("my_server"))

      # Access from any node
      GenServer.call(via_tuple("my_server"), :get_state)

  """

  use Horde.Registry

  @doc """
  Starts the global registry.
  """
  def start_link(_opts) do
    Horde.Registry.start_link(__MODULE__, [keys: :unique], name: __MODULE__)
  end

  @doc """
  Child spec for supervision tree.
  """
  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[]]},
      type: :supervisor
    }
  end

  @impl true
  def init(opts) do
    [members: members()]
    |> Keyword.merge(opts)
    |> Horde.Registry.init()
  end

  # ============================================
  # PUBLIC API
  # ============================================

  @doc """
  Creates a via tuple for process registration/lookup.
  """
  def via_tuple(key) do
    {:via, Horde.Registry, {__MODULE__, key}}
  end

  @doc """
  Looks up a process by key.
  """
  def lookup(key) do
    case Horde.Registry.lookup(__MODULE__, key) do
      [{pid, _value}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Returns all registered processes.
  """
  def all do
    Horde.Registry.select(__MODULE__, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}])
  end

  @doc """
  Returns the count of registered processes.
  """
  def count do
    Horde.Registry.count(__MODULE__)
  end

  @doc """
  Registers a process with metadata.
  """
  def register(key, value \\ nil) do
    Horde.Registry.register(__MODULE__, key, value)
  end

  @doc """
  Unregisters a process.
  """
  def unregister(key) do
    Horde.Registry.unregister(__MODULE__, key)
  end

  # ============================================
  # CLUSTER MEMBERSHIP
  # ============================================

  @doc """
  Returns all registry members (nodes).
  """
  def members do
    [Node.self() | Node.list()]
    |> Enum.map(&{__MODULE__, &1})
  end

  @doc """
  Updates cluster membership when nodes join/leave.
  Called by ClusterManager when topology changes.
  """
  def update_members do
    Horde.Cluster.set_members(__MODULE__, members())
  end
end
