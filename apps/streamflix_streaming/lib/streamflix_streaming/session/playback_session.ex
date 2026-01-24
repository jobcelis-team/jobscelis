defmodule StreamflixStreaming.Session.PlaybackSession do
  @moduledoc """
  GenServer that manages an active playback session.

  Tracks:
  - Current position
  - Playback quality
  - Bandwidth measurements
  - Buffer health
  """

  use GenServer, restart: :temporary
  require Logger

  alias StreamflixCore.Events
  alias StreamflixCore.Events.EventBus

  defstruct [
    :session_id,
    :user_id,
    :profile_id,
    :content_id,
    :episode_id,
    :video,
    :current_position,
    :current_quality,
    :bandwidth_bps,
    :buffer_health,
    :started_at,
    :last_activity,
    :total_watch_time
  ]

  @idle_timeout 300_000  # 5 minutes

  # ============================================
  # PUBLIC API
  # ============================================

  def start_link(opts) do
    session_id = opts[:session_id]
    GenServer.start_link(__MODULE__, opts, name: via_tuple(session_id))
  end

  def stop(session_id) do
    case GenServer.whereis(via_tuple(session_id)) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal)
    end
  end

  def get_state(session_id) do
    case GenServer.whereis(via_tuple(session_id)) do
      nil -> nil
      pid -> GenServer.call(pid, :get_state)
    end
  end

  def update_position(session_id, position) do
    GenServer.cast(via_tuple(session_id), {:update_position, position})
  end

  def update_bandwidth(session_id, bandwidth_bps) do
    GenServer.cast(via_tuple(session_id), {:update_bandwidth, bandwidth_bps})
  end

  def update_quality(session_id, quality) do
    GenServer.cast(via_tuple(session_id), {:update_quality, quality})
  end

  # ============================================
  # CALLBACKS
  # ============================================

  @impl true
  def init(opts) do
    state = %__MODULE__{
      session_id: opts[:session_id],
      user_id: opts[:user_id],
      profile_id: opts[:profile_id],
      content_id: opts[:content_id],
      episode_id: opts[:episode_id],
      video: opts[:video],
      current_position: opts[:start_position] || 0,
      current_quality: "auto",
      bandwidth_bps: 0,
      buffer_health: :good,
      started_at: DateTime.utc_now(),
      last_activity: DateTime.utc_now(),
      total_watch_time: 0
    }

    # Emit playback started event
    EventBus.publish(Events.new(Events.PlaybackStarted, %{
      session_id: state.session_id,
      user_id: state.user_id,
      profile_id: state.profile_id,
      content_id: state.content_id,
      episode_id: state.episode_id,
      device_type: "web",
      quality: state.current_quality,
      position: state.current_position
    }))

    # Schedule idle check
    schedule_idle_check()

    Logger.info("[PlaybackSession] Started session #{state.session_id}")

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:update_position, position}, state) do
    # Calculate watch time increment
    watch_increment = max(0, position - state.current_position)

    new_state = %{state |
      current_position: position,
      last_activity: DateTime.utc_now(),
      total_watch_time: state.total_watch_time + watch_increment
    }

    # Emit progress event (debounced)
    if rem(trunc(position), 30) == 0 do
      EventBus.publish(Events.new(Events.PlaybackProgress, %{
        session_id: state.session_id,
        position: position,
        quality: state.current_quality
      }))
    end

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:update_bandwidth, bandwidth_bps}, state) do
    new_quality = select_quality(bandwidth_bps, state.video.qualities)

    new_state = %{state |
      bandwidth_bps: bandwidth_bps,
      last_activity: DateTime.utc_now()
    }

    # If quality changed, emit event
    new_state =
      if new_quality != state.current_quality and state.current_quality != "auto" do
        EventBus.publish(Events.new(Events.QualityChanged, %{
          session_id: state.session_id,
          from_quality: state.current_quality,
          to_quality: new_quality,
          reason: "bandwidth"
        }))

        %{new_state | current_quality: new_quality}
      else
        new_state
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:update_quality, quality}, state) do
    new_state = %{state |
      current_quality: quality,
      last_activity: DateTime.utc_now()
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:idle_check, state) do
    idle_ms = DateTime.diff(DateTime.utc_now(), state.last_activity, :millisecond)

    if idle_ms > @idle_timeout do
      Logger.info("[PlaybackSession] Session #{state.session_id} idle, terminating")
      {:stop, :normal, state}
    else
      schedule_idle_check()
      {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    # Calculate completion percentage
    duration = state.video.duration_seconds || 1
    completed = state.current_position / duration >= 0.9

    # Emit playback ended event
    EventBus.publish(Events.new(Events.PlaybackEnded, %{
      session_id: state.session_id,
      final_position: state.current_position,
      watch_duration: state.total_watch_time,
      completed: completed
    }))

    # Update watch history
    update_watch_history(state, completed)

    Logger.info("[PlaybackSession] Session #{state.session_id} ended")

    :ok
  end

  # ============================================
  # PRIVATE FUNCTIONS
  # ============================================

  defp via_tuple(session_id) do
    {:via, Registry, {StreamflixStreaming.SessionRegistry, session_id}}
  end

  defp schedule_idle_check do
    Process.send_after(self(), :idle_check, 60_000)
  end

  defp select_quality(bandwidth_bps, available_qualities) do
    quality_bitrates = %{
      "240p" => 400_000,
      "360p" => 800_000,
      "480p" => 1_200_000,
      "720p" => 2_500_000,
      "1080p" => 5_000_000,
      "1440p" => 8_000_000,
      "4k" => 15_000_000
    }

    # Select highest quality that fits within 80% of bandwidth
    safe_bandwidth = bandwidth_bps * 0.8

    available_qualities
    |> Enum.filter(fn q ->
      bitrate = Map.get(quality_bitrates, q, 0)
      bitrate <= safe_bandwidth
    end)
    |> Enum.max_by(fn q -> Map.get(quality_bitrates, q, 0) end, fn -> "480p" end)
  end

  defp update_watch_history(state, completed) do
    # This would update the watch_history table
    # For now, we'll just log it
    progress = state.current_position / (state.video.duration_seconds || 1)

    Logger.debug("""
    [PlaybackSession] Watch history update:
      profile_id: #{state.profile_id}
      content_id: #{state.content_id}
      episode_id: #{state.episode_id}
      position: #{state.current_position}
      progress: #{Float.round(progress * 100, 1)}%
      completed: #{completed}
    """)
  end
end
