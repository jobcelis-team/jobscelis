defmodule StreamflixCore.Distributed.ClusterManager do
  @moduledoc """
  Manages cluster topology and node connections.

  Responsibilities:
  - Monitor node connections/disconnections
  - Update Horde membership on topology changes
  - Broadcast cluster events
  - Health checks for nodes
  """

  use GenServer
  require Logger

  @check_interval 5_000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # ============================================
  # PUBLIC API
  # ============================================

  @doc """
  Returns current cluster status.
  """
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Returns list of all connected nodes.
  """
  def nodes do
    [Node.self() | Node.list()]
  end

  @doc """
  Returns count of nodes in cluster.
  """
  def node_count do
    length(nodes())
  end

  @doc """
  Checks if a specific node is connected.
  """
  def node_connected?(node_name) do
    node_name in Node.list() or node_name == Node.self()
  end

  @doc """
  Forces a cluster status refresh.
  """
  def refresh do
    GenServer.cast(__MODULE__, :refresh)
  end

  # ============================================
  # CALLBACKS
  # ============================================

  @impl true
  def init(_) do
    # Monitor node events
    :net_kernel.monitor_nodes(true)

    state = %{
      connected_nodes: Node.list(),
      last_check: DateTime.utc_now(),
      node_history: []
    }

    Logger.info("[ClusterManager] Started on #{Node.self()}")
    Logger.info("[ClusterManager] Connected nodes: #{inspect(Node.list())}")

    schedule_check()

    {:ok, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      current_node: Node.self(),
      connected_nodes: Node.list(),
      total_nodes: node_count(),
      last_check: state.last_check,
      uptime: System.system_time(:second)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast(:refresh, state) do
    update_horde_membership()
    {:noreply, %{state | last_check: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:nodeup, node}, state) do
    Logger.info("[ClusterManager] Node joined: #{node}")

    # Update Horde membership
    update_horde_membership()

    # Broadcast node up event
    Phoenix.PubSub.broadcast(
      StreamflixCore.PubSub,
      "cluster",
      {:node_up, node}
    )

    new_history = [{:up, node, DateTime.utc_now()} | state.node_history] |> Enum.take(100)

    {:noreply, %{state |
      connected_nodes: Node.list(),
      node_history: new_history
    }}
  end

  @impl true
  def handle_info({:nodedown, node}, state) do
    Logger.warning("[ClusterManager] Node left: #{node}")

    # Update Horde membership
    update_horde_membership()

    # Broadcast node down event
    Phoenix.PubSub.broadcast(
      StreamflixCore.PubSub,
      "cluster",
      {:node_down, node}
    )

    new_history = [{:down, node, DateTime.utc_now()} | state.node_history] |> Enum.take(100)

    {:noreply, %{state |
      connected_nodes: Node.list(),
      node_history: new_history
    }}
  end

  @impl true
  def handle_info(:check, state) do
    # Periodic health check
    current_nodes = Node.list()

    if current_nodes != state.connected_nodes do
      Logger.info("[ClusterManager] Topology changed: #{inspect(current_nodes)}")
      update_horde_membership()
    end

    schedule_check()

    {:noreply, %{state |
      connected_nodes: current_nodes,
      last_check: DateTime.utc_now()
    }}
  end

  # ============================================
  # PRIVATE FUNCTIONS
  # ============================================

  defp update_horde_membership do
    # Update GlobalRegistry membership
    StreamflixCore.Distributed.GlobalRegistry.update_members()

    # Update GlobalSupervisor membership
    StreamflixCore.Distributed.GlobalSupervisor.update_members()

    Logger.debug("[ClusterManager] Updated Horde membership")
  end

  defp schedule_check do
    Process.send_after(self(), :check, @check_interval)
  end
end
