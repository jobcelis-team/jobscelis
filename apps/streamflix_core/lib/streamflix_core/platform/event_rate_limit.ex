defmodule StreamflixCore.Platform.EventRateLimit do
  @moduledoc """
  Enforces a project's `rate_limit_events_per_minute`.

  Every ingested event counts, so a batch of N events consumes N units (a batch
  is still a single API call for the API-call limit). Counters live in the
  shared cache in fixed one-minute windows. A request that would exceed the
  limit is rejected as a whole and does not consume any units.
  """

  @cache :platform_cache

  @doc """
  Consumes `count` events from the project's per-minute budget.
  Returns `:ok` or `{:error, {:rate_limited, retry_after_seconds, limit}}`.
  """
  @spec consume(%{id: term(), rate_limit_events_per_minute: integer() | nil}, pos_integer()) ::
          :ok | {:error, {:rate_limited, pos_integer(), pos_integer()}}
  def consume(%{id: project_id} = project, count) when is_integer(count) and count > 0 do
    limit = project.rate_limit_events_per_minute || 1000
    now = System.system_time(:second)
    bucket = div(now, 60)
    key = {:event_rate, project_id, bucket}
    retry_after = max((bucket + 1) * 60 - now, 1)

    case Cachex.incr(@cache, key, count) do
      {:ok, total} ->
        if total == count, do: Cachex.expire(@cache, key, :timer.seconds(120))

        if total > limit do
          Cachex.decr(@cache, key, count)
          {:error, {:rate_limited, retry_after, limit}}
        else
          :ok
        end

      # Cache unavailable: do not block ingestion
      _ ->
        :ok
    end
  end

  def consume(_project, _count), do: :ok
end
