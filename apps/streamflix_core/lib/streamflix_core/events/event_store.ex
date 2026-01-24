defmodule StreamflixCore.Events.EventStore do
  @moduledoc """
  Persistent Event Store backed by PostgreSQL.

  Provides:
  - Append-only event storage
  - Event replay by aggregate
  - Idempotency (duplicate events are ignored)
  - Cross-node event distribution
  """

  use GenServer
  require Logger

  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.EventRecord

  @doc """
  Starts the EventStore GenServer.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # ============================================
  # PUBLIC API
  # ============================================

  @doc """
  Appends an event to the store.
  Returns :ok if successful, :already_exists if duplicate, or {:error, reason}.
  """
  def append(event) do
    GenServer.call(__MODULE__, {:append, event})
  end

  @doc """
  Appends multiple events atomically.
  """
  def append_all(events) when is_list(events) do
    GenServer.call(__MODULE__, {:append_all, events})
  end

  @doc """
  Checks if an event exists by ID.
  """
  def exists?(event_id) do
    GenServer.call(__MODULE__, {:exists, event_id})
  end

  @doc """
  Loads all events for an aggregate.
  """
  def load_events(aggregate_type, aggregate_id) do
    GenServer.call(__MODULE__, {:load, aggregate_type, aggregate_id})
  end

  @doc """
  Loads events by type.
  """
  def events_by_type(event_type, opts \\ []) do
    GenServer.call(__MODULE__, {:by_type, event_type, opts})
  end

  @doc """
  Returns all events in order.
  """
  def all_events(opts \\ []) do
    GenServer.call(__MODULE__, {:all, opts})
  end

  @doc """
  Streams events for replay.
  """
  def stream_events(opts \\ []) do
    GenServer.call(__MODULE__, {:stream, opts})
  end

  @doc """
  Returns the count of events.
  """
  def count do
    GenServer.call(__MODULE__, :count)
  end

  # ============================================
  # CALLBACKS
  # ============================================

  @impl true
  def init(_) do
    Logger.info("[EventStore] Initialized with PostgreSQL backend")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:append, event}, _from, state) do
    result = do_append(event)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:append_all, events}, _from, state) do
    result = Repo.transaction(fn ->
      Enum.each(events, fn event ->
        case do_append(event) do
          :ok -> :ok
          :already_exists -> :ok
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
    end)

    case result do
      {:ok, _} -> {:reply, :ok, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:exists, event_id}, _from, state) do
    exists = Repo.exists?(from e in EventRecord, where: e.event_id == ^event_id)
    {:reply, exists, state}
  end

  @impl true
  def handle_call({:load, aggregate_type, aggregate_id}, _from, state) do
    events =
      EventRecord
      |> where([e], e.aggregate_type == ^to_string(aggregate_type))
      |> where([e], e.aggregate_id == ^aggregate_id)
      |> order_by([e], asc: e.version)
      |> Repo.all()
      |> Enum.map(&EventRecord.to_domain_event/1)
      |> Enum.filter(& &1)

    {:reply, events, state}
  end

  @impl true
  def handle_call({:by_type, event_type, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    events =
      EventRecord
      |> where([e], e.event_type == ^to_string(event_type))
      |> order_by([e], desc: e.inserted_at)
      |> limit(^limit)
      |> offset(^offset)
      |> Repo.all()
      |> Enum.map(&EventRecord.to_domain_event/1)
      |> Enum.filter(& &1)

    {:reply, events, state}
  end

  @impl true
  def handle_call({:all, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 1000)
    offset = Keyword.get(opts, :offset, 0)

    events =
      EventRecord
      |> order_by([e], asc: e.inserted_at)
      |> limit(^limit)
      |> offset(^offset)
      |> Repo.all()
      |> Enum.map(&EventRecord.to_domain_event/1)
      |> Enum.filter(& &1)

    {:reply, events, state}
  end

  @impl true
  def handle_call({:stream, opts}, _from, state) do
    batch_size = Keyword.get(opts, :batch_size, 100)

    stream =
      EventRecord
      |> order_by([e], asc: e.inserted_at)
      |> Repo.stream(max_rows: batch_size)

    {:reply, stream, state}
  end

  @impl true
  def handle_call(:count, _from, state) do
    count = Repo.aggregate(EventRecord, :count)
    {:reply, count, state}
  end

  # ============================================
  # PRIVATE FUNCTIONS
  # ============================================

  defp do_append(event) do
    event_id = Map.get(event, :event_id) || UUID.uuid4()

    case Repo.get(EventRecord, event_id) do
      nil ->
        record = EventRecord.from_domain_event(event)
        changeset = EventRecord.changeset(record, %{})

        case Repo.insert(changeset) do
          {:ok, _} ->
            Logger.debug("[EventStore] Saved event #{event_id}")
            # Broadcast event to other processes
            broadcast_event(event)
            :ok

          {:error, changeset} ->
            Logger.error("[EventStore] Failed to save event: #{inspect(changeset.errors)}")
            {:error, changeset.errors}
        end

      _existing ->
        :already_exists
    end
  end

  defp broadcast_event(event) do
    event_type = StreamflixCore.Events.event_type(event)
    Phoenix.PubSub.broadcast(StreamflixCore.PubSub, "events", {:event, event})
    Phoenix.PubSub.broadcast(StreamflixCore.PubSub, "events:#{event_type}", {:event, event})
  end
end
