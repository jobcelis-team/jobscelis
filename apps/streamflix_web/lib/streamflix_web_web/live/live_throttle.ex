defmodule StreamflixWebWeb.LiveThrottle do
  @moduledoc """
  Small per-user, per-action throttle for LiveView events that cause side
  effects (sending test events, outbound HTTP calls, invitations...).

  Counts are kept in Cachex per fixed one-minute window. The limit defaults to
  10 per minute and can be changed with
  `config :streamflix_web, :live_throttle_per_minute, n`.
  """

  @cache :platform_cache
  @default_limit 10

  @doc "Returns :ok, or {:error, :throttled} once the user exceeded the limit."
  def check(user_id, action) do
    limit = Application.get_env(:streamflix_web, :live_throttle_per_minute, @default_limit)
    bucket = div(System.system_time(:second), 60)
    key = {:live_throttle, user_id, action, bucket}

    case Cachex.incr(@cache, key, 1) do
      {:ok, 1} ->
        Cachex.expire(@cache, key, :timer.seconds(120))
        :ok

      {:ok, count} when count > limit ->
        {:error, :throttled}

      _ ->
        # Fail open if the cache is unavailable
        :ok
    end
  end
end
