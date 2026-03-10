defmodule StreamflixCore.RateLimiter do
  @moduledoc """
  ETS-based sliding window rate limiter for outbound webhook deliveries.
  Tracks per-webhook request counts within configurable time windows.
  """
  use GenServer

  require Logger

  @table :webhook_rate_limiter
  @default_max_per_second 50
  @default_max_per_minute 3_000
  @cleanup_interval :timer.minutes(5)

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Check if a webhook delivery is allowed under the rate limit.
  Returns `:ok` if allowed, `{:error, :rate_limited}` if throttled.
  """
  def check_rate(webhook_id, rate_limit_config \\ %{}) do
    now = System.system_time(:millisecond)
    max_per_second = rate_limit_config["max_per_second"] || @default_max_per_second
    max_per_minute = rate_limit_config["max_per_minute"] || @default_max_per_minute

    second_key = {webhook_id, :second, div(now, 1_000)}
    minute_key = {webhook_id, :minute, div(now, 60_000)}

    second_count = get_count(second_key)
    minute_count = get_count(minute_key)

    cond do
      second_count >= max_per_second -> {:error, :rate_limited}
      minute_count >= max_per_minute -> {:error, :rate_limited}
      true -> :ok
    end
  end

  @doc """
  Record a delivery attempt for rate limiting purposes.
  Call this after check_rate returns :ok, just before sending.
  """
  def record_request(webhook_id) do
    now = System.system_time(:millisecond)
    second_key = {webhook_id, :second, div(now, 1_000)}
    minute_key = {webhook_id, :minute, div(now, 60_000)}

    increment(second_key)
    increment(minute_key)
    :ok
  end

  @doc """
  Check if a webhook is currently being throttled.
  """
  def throttled?(webhook_id, rate_limit_config \\ %{}) do
    check_rate(webhook_id, rate_limit_config) == {:error, :rate_limited}
  end

  ## Server callbacks

  @impl true
  def init(_opts) do
    :ets.new(@table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_stale_entries()
    schedule_cleanup()
    {:noreply, state}
  end

  ## Private

  defp get_count(key) do
    case :ets.lookup(@table, key) do
      [{^key, count}] -> count
      [] -> 0
    end
  end

  defp increment(key) do
    try do
      :ets.update_counter(@table, key, {2, 1})
    rescue
      ArgumentError -> :ets.insert(@table, {key, 1})
    end
  end

  defp cleanup_stale_entries do
    now = System.system_time(:millisecond)
    current_second = div(now, 1_000)
    current_minute = div(now, 60_000)

    :ets.foldl(
      fn
        {{wid, :second, sec} = key, _count}, acc when sec < current_second - 2 ->
          _ = wid
          :ets.delete(@table, key)
          acc

        {{wid, :minute, min} = key, _count}, acc when min < current_minute - 2 ->
          _ = wid
          :ets.delete(@table, key)
          acc

        _, acc ->
          acc
      end,
      nil,
      @table
    )
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
end
