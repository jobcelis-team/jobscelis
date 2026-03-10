defmodule StreamflixCore.Platform.ObanIdempotencyPurgeWorker do
  @moduledoc """
  Oban cron worker that clears expired idempotency keys from events.

  Runs daily. Sets `idempotency_key` to NULL on events older than the TTL
  (default 7 days), freeing the key for reuse without deleting the event.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 1,
    unique: [period: 3600]

  import Ecto.Query
  require Logger

  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.WebhookEvent

  @default_ttl_days 7

  @impl true
  def perform(_job) do
    cutoff =
      DateTime.utc_now()
      |> DateTime.truncate(:microsecond)
      |> DateTime.add(-@default_ttl_days, :day)

    {count, _} =
      from(e in WebhookEvent,
        where: not is_nil(e.idempotency_key),
        where: e.inserted_at < ^cutoff
      )
      |> Repo.update_all(set: [idempotency_key: nil])

    Logger.info("Idempotency purge complete",
      worker: "ObanIdempotencyPurgeWorker",
      keys_cleared: count
    )

    :ok
  end
end
