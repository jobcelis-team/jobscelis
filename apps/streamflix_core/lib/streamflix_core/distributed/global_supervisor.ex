defmodule StreamflixCore.Distributed.GlobalSupervisor do
  @moduledoc """
  Distributed DynamicSupervisor using Horde.

  Provides automatic distribution of child processes across all nodes
  in the cluster. When a node goes down, processes are automatically
  restarted on other nodes.

  ## Example

      # Start a child process (will be placed on optimal node)
      {:ok, pid} = GlobalSupervisor.start_child({MyWorker, [arg1, arg2]})

      # The process will be registered globally and can be accessed from any node

  """

  use Horde.DynamicSupervisor
  require Logger

  @doc """
  Starts the global supervisor.
  """
  def start_link(_opts) do
    Horde.DynamicSupervisor.start_link(
      __MODULE__,
      [
        strategy: :one_for_one,
        distribution_strategy: Horde.UniformQuorumDistribution,
        process_redistribution: :active
      ],
      name: __MODULE__
    )
  end

  @impl true
  def init(opts) do
    [members: members()]
    |> Keyword.merge(opts)
    |> Horde.DynamicSupervisor.init()
  end

  # ============================================
  # PUBLIC API
  # ============================================

  @doc """
  Starts a child process under the distributed supervisor.
  """
  def start_child(child_spec) do
    Horde.DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @doc """
  Terminates a child process.
  """
  def terminate_child(pid) do
    Horde.DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  @doc """
  Returns all running children.
  """
  def which_children do
    Horde.DynamicSupervisor.which_children(__MODULE__)
  end

  @doc """
  Returns count of running children.
  """
  def count_children do
    Horde.DynamicSupervisor.count_children(__MODULE__)
  end

  # ============================================
  # CLUSTER MEMBERSHIP
  # ============================================

  @doc """
  Returns all supervisor members (nodes).
  """
  def members do
    [Node.self() | Node.list()]
    |> Enum.map(&{__MODULE__, &1})
  end

  @doc """
  Updates cluster membership when nodes join/leave.
  """
  def update_members do
    Horde.Cluster.set_members(__MODULE__, members())
  end
end
