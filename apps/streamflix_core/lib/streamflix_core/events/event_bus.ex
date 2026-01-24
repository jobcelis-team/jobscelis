defmodule StreamflixCore.Events.EventBus do
  @moduledoc """
  Event Bus for publishing and subscribing to domain events.

  Provides:
  - Publish events to interested subscribers
  - Subscribe to specific event types
  - Cross-node event distribution via Phoenix.PubSub
  """

  use GenServer
  require Logger

  @doc """
  Starts the EventBus GenServer.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # ============================================
  # PUBLIC API
  # ============================================

  @doc """
  Publishes an event to all subscribers.
  The event is also persisted to the EventStore.
  """
  def publish(event) do
    GenServer.call(__MODULE__, {:publish, event})
  end

  @doc """
  Publishes an event without persisting (for internal use).
  """
  def broadcast(event) do
    GenServer.cast(__MODULE__, {:broadcast, event})
  end

  @doc """
  Subscribes the calling process to events of a specific type.
  """
  def subscribe(event_type) when is_atom(event_type) do
    topic = event_topic(event_type)
    Phoenix.PubSub.subscribe(StreamflixCore.PubSub, topic)
  end

  @doc """
  Subscribes to all events.
  """
  def subscribe_all do
    Phoenix.PubSub.subscribe(StreamflixCore.PubSub, "events")
  end

  @doc """
  Unsubscribes from a specific event type.
  """
  def unsubscribe(event_type) when is_atom(event_type) do
    topic = event_topic(event_type)
    Phoenix.PubSub.unsubscribe(StreamflixCore.PubSub, topic)
  end

  @doc """
  Registers a handler module for a specific event type.
  The handler module must implement handle_event/1.
  """
  def register_handler(event_type, handler_module) do
    GenServer.call(__MODULE__, {:register_handler, event_type, handler_module})
  end

  @doc """
  Lists all registered handlers.
  """
  def handlers do
    GenServer.call(__MODULE__, :list_handlers)
  end

  # ============================================
  # CALLBACKS
  # ============================================

  @impl true
  def init(_) do
    # Subscribe to all events to dispatch to handlers
    Phoenix.PubSub.subscribe(StreamflixCore.PubSub, "events")

    state = %{
      handlers: %{},
      event_count: 0
    }

    Logger.info("[EventBus] Initialized")
    {:ok, state}
  end

  @impl true
  def handle_call({:publish, event}, _from, state) do
    # Persist event
    result = StreamflixCore.Events.EventStore.append(event)

    case result do
      :ok ->
        # Broadcast to subscribers
        do_broadcast(event)
        new_state = %{state | event_count: state.event_count + 1}
        {:reply, :ok, new_state}

      :already_exists ->
        {:reply, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:register_handler, event_type, handler_module}, _from, state) do
    type_key = normalize_event_type(event_type)
    handlers = Map.get(state.handlers, type_key, [])
    new_handlers = Map.put(state.handlers, type_key, [handler_module | handlers] |> Enum.uniq())

    Logger.info("[EventBus] Registered handler #{handler_module} for #{type_key}")

    {:reply, :ok, %{state | handlers: new_handlers}}
  end

  @impl true
  def handle_call(:list_handlers, _from, state) do
    {:reply, state.handlers, state}
  end

  @impl true
  def handle_cast({:broadcast, event}, state) do
    do_broadcast(event)
    {:noreply, state}
  end

  @impl true
  def handle_info({:event, event}, state) do
    # Dispatch to registered handlers
    dispatch_to_handlers(event, state.handlers)
    {:noreply, state}
  end

  # ============================================
  # PRIVATE FUNCTIONS
  # ============================================

  defp do_broadcast(event) do
    event_type = StreamflixCore.Events.event_type(event)

    # Broadcast to specific topic
    Phoenix.PubSub.broadcast(
      StreamflixCore.PubSub,
      event_topic(event_type),
      {:event, event}
    )

    # Also broadcast to aggregate-specific topic if applicable
    if aggregate_id = get_aggregate_id(event) do
      Phoenix.PubSub.broadcast(
        StreamflixCore.PubSub,
        "aggregate:#{aggregate_id}",
        {:event, event}
      )
    end
  end

  defp dispatch_to_handlers(event, handlers) do
    event_type = normalize_event_type(event.__struct__)

    handlers
    |> Map.get(event_type, [])
    |> Enum.each(fn handler ->
      Task.Supervisor.async_nolink(
        StreamflixCore.TaskSupervisor,
        fn ->
          try do
            handler.handle_event(event)
          rescue
            e ->
              Logger.error("[EventBus] Handler #{handler} failed: #{inspect(e)}")
          end
        end
      )
    end)
  end

  defp event_topic(event_type) when is_atom(event_type) do
    "events:#{normalize_event_type(event_type)}"
  end

  defp event_topic(event_type) when is_binary(event_type) do
    "events:#{event_type}"
  end

  defp normalize_event_type(module) when is_atom(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  defp get_aggregate_id(event) do
    cond do
      Map.has_key?(event, :user_id) -> event.user_id
      Map.has_key?(event, :content_id) -> event.content_id
      Map.has_key?(event, :profile_id) -> event.profile_id
      Map.has_key?(event, :subscription_id) -> event.subscription_id
      true -> nil
    end
  end
end
