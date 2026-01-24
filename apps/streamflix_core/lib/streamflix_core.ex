defmodule StreamflixCore do
  @moduledoc """
  StreamflixCore - Core domain module for the StreamFlix platform.

  This module provides:
  - Event Sourcing infrastructure
  - CQRS patterns
  - Distributed system utilities
  - Shared domain logic

  ## Architecture

  StreamflixCore follows a domain-driven design with event sourcing:

  - **Events**: Immutable facts that have happened in the system
  - **Aggregates**: Domain entities that process commands and emit events
  - **Projections**: Read models built from events
  - **Sagas**: Long-running processes that coordinate multiple aggregates

  ## Distributed Features

  - **Horde**: Distributed process registry and supervisor
  - **CRDTs**: Conflict-free replicated data types for distributed state
  - **PubSub**: Cross-node event broadcasting
  """

  @doc """
  Generates a new UUID v4.
  """
  def generate_id do
    UUID.uuid4()
  end

  @doc """
  Returns current UTC datetime.
  """
  def now do
    DateTime.utc_now()
  end

  @doc """
  Returns the current node name.
  """
  def current_node do
    Node.self()
  end

  @doc """
  Returns all connected nodes in the cluster.
  """
  def cluster_nodes do
    [Node.self() | Node.list()]
  end

  @doc """
  Broadcasts an event to all subscribers.
  """
  def broadcast(topic, event) do
    Phoenix.PubSub.broadcast(StreamflixCore.PubSub, topic, event)
  end

  @doc """
  Subscribes the current process to a topic.
  """
  def subscribe(topic) do
    Phoenix.PubSub.subscribe(StreamflixCore.PubSub, topic)
  end
end
