defmodule StreamflixAccounts.Services.SessionManager do
  @moduledoc """
  Manages active streaming sessions for users.

  Enforces:
  - Maximum concurrent streams based on subscription plan
  - Session tracking across cluster nodes
  - Presence-based real-time session management
  """

  use GenServer
  require Logger

  alias StreamflixCore.Cache

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # ============================================
  # PUBLIC API
  # ============================================

  @doc """
  Starts a new streaming session.
  Returns {:ok, session_id} or {:error, reason}.
  """
  def start_session(user_id, profile_id, content_id, opts \\ []) do
    GenServer.call(__MODULE__, {:start_session, user_id, profile_id, content_id, opts})
  end

  @doc """
  Ends a streaming session.
  """
  def end_session(session_id) do
    GenServer.cast(__MODULE__, {:end_session, session_id})
  end

  @doc """
  Updates session heartbeat (keeps session alive).
  """
  def heartbeat(session_id, position) do
    GenServer.cast(__MODULE__, {:heartbeat, session_id, position})
  end

  @doc """
  Gets active sessions for a user.
  """
  def get_user_sessions(user_id) do
    GenServer.call(__MODULE__, {:get_user_sessions, user_id})
  end

  @doc """
  Counts active sessions for a user.
  """
  def active_session_count(user_id) do
    sessions = get_user_sessions(user_id)
    length(sessions)
  end

  @doc """
  Checks if user can start a new stream.
  """
  def can_start_stream?(user_id) do
    _user = StreamflixAccounts.get_user!(user_id)
    subscription = StreamflixAccounts.get_active_subscription(user_id)

    max_streams = case subscription do
      nil -> 1
      sub -> StreamflixAccounts.Schemas.Subscription.max_streams(sub)
    end

    active_session_count(user_id) < max_streams
  end

  @doc """
  Gets session details.
  """
  def get_session(session_id) do
    GenServer.call(__MODULE__, {:get_session, session_id})
  end

  # ============================================
  # CALLBACKS
  # ============================================

  @impl true
  def init(_) do
    # Periodic cleanup of stale sessions
    schedule_cleanup()

    state = %{
      sessions: %{},      # session_id => session_data
      user_sessions: %{}  # user_id => [session_ids]
    }

    Logger.info("[SessionManager] Started")

    {:ok, state}
  end

  @impl true
  def handle_call({:start_session, user_id, profile_id, content_id, opts}, _from, state) do
    if can_start_stream?(user_id) do
      session_id = generate_session_id()
      device_type = Keyword.get(opts, :device_type, "unknown")
      device_id = Keyword.get(opts, :device_id)

      session = %{
        id: session_id,
        user_id: user_id,
        profile_id: profile_id,
        content_id: content_id,
        device_type: device_type,
        device_id: device_id,
        position: 0,
        quality: "auto",
        started_at: DateTime.utc_now(),
        last_heartbeat: DateTime.utc_now(),
        node: Node.self()
      }

      # Update state
      new_sessions = Map.put(state.sessions, session_id, session)
      user_session_list = Map.get(state.user_sessions, user_id, [])
      new_user_sessions = Map.put(state.user_sessions, user_id, [session_id | user_session_list])

      # Cache for cross-node access
      Cache.put({:session, session_id}, session, ttl: :timer.hours(12))

      new_state = %{state | sessions: new_sessions, user_sessions: new_user_sessions}

      Logger.info("[SessionManager] Started session #{session_id} for user #{user_id}")

      {:reply, {:ok, session_id}, new_state}
    else
      {:reply, {:error, :max_streams_reached}, state}
    end
  end

  @impl true
  def handle_call({:get_user_sessions, user_id}, _from, state) do
    session_ids = Map.get(state.user_sessions, user_id, [])
    sessions = Enum.map(session_ids, &Map.get(state.sessions, &1)) |> Enum.filter(& &1)
    {:reply, sessions, state}
  end

  @impl true
  def handle_call({:get_session, session_id}, _from, state) do
    session = Map.get(state.sessions, session_id)
    {:reply, session, state}
  end

  @impl true
  def handle_cast({:end_session, session_id}, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:noreply, state}

      session ->
        # Remove from state
        new_sessions = Map.delete(state.sessions, session_id)
        user_session_list = Map.get(state.user_sessions, session.user_id, [])
        new_user_session_list = List.delete(user_session_list, session_id)
        new_user_sessions = Map.put(state.user_sessions, session.user_id, new_user_session_list)

        # Remove from cache
        Cache.delete({:session, session_id})

        Logger.info("[SessionManager] Ended session #{session_id}")

        {:noreply, %{state | sessions: new_sessions, user_sessions: new_user_sessions}}
    end
  end

  @impl true
  def handle_cast({:heartbeat, session_id, position}, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:noreply, state}

      session ->
        updated_session = %{session |
          position: position,
          last_heartbeat: DateTime.utc_now()
        }

        new_sessions = Map.put(state.sessions, session_id, updated_session)
        Cache.put({:session, session_id}, updated_session, ttl: :timer.hours(12))

        {:noreply, %{state | sessions: new_sessions}}
    end
  end

  @impl true
  def handle_info(:cleanup, state) do
    # Remove sessions with no heartbeat for 5+ minutes
    cutoff = DateTime.add(DateTime.utc_now(), -300, :second)

    stale_sessions =
      state.sessions
      |> Enum.filter(fn {_id, session} ->
        DateTime.compare(session.last_heartbeat, cutoff) == :lt
      end)
      |> Enum.map(fn {id, _} -> id end)

    if length(stale_sessions) > 0 do
      Logger.info("[SessionManager] Cleaning up #{length(stale_sessions)} stale sessions")
    end

    new_state = Enum.reduce(stale_sessions, state, fn session_id, acc ->
      session = Map.get(acc.sessions, session_id)

      new_sessions = Map.delete(acc.sessions, session_id)
      user_session_list = Map.get(acc.user_sessions, session.user_id, [])
      new_user_session_list = List.delete(user_session_list, session_id)
      new_user_sessions = Map.put(acc.user_sessions, session.user_id, new_user_session_list)

      Cache.delete({:session, session_id})

      %{acc | sessions: new_sessions, user_sessions: new_user_sessions}
    end)

    schedule_cleanup()

    {:noreply, new_state}
  end

  # ============================================
  # PRIVATE FUNCTIONS
  # ============================================

  defp generate_session_id do
    "sess_" <> Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, :timer.minutes(1))
  end
end
