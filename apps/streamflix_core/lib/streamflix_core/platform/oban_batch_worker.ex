defmodule StreamflixCore.Platform.ObanBatchWorker do
  @moduledoc """
  Oban cron worker that processes batch items every 10 seconds.
  Groups accumulated events by webhook and sends them as a single POST
  when the batch window has elapsed or max_batch_size is reached.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 1,
    unique: [period: 10]

  import Ecto.Query
  require Logger

  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{Webhook, BatchItem, Delivery}
  alias StreamflixCore.Platform

  @impl true
  def perform(_job) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    # Find webhooks that have batch_config enabled
    webhooks =
      Webhook
      |> where([w], w.status == "active" and not is_nil(w.batch_config))
      |> Repo.all()
      |> Enum.filter(fn w ->
        config = w.batch_config || %{}
        config["enabled"] == true
      end)

    Enum.each(webhooks, fn webhook ->
      process_webhook_batch(webhook, now)
    end)

    :ok
  end

  defp process_webhook_batch(webhook, now) do
    config = webhook.batch_config || %{}
    window_seconds = config["window_seconds"] || 60
    max_batch_size = config["max_batch_size"] || 100

    # Single query: get count and oldest timestamp for this webhook's batch items
    stats =
      from(b in BatchItem,
        where: b.webhook_id == ^webhook.id,
        select: %{count: count(b.id), oldest: min(b.inserted_at)}
      )
      |> Repo.one()

    if stats.count > 0 do
      age_seconds = DateTime.diff(now, stats.oldest, :second)

      if age_seconds >= window_seconds or stats.count >= max_batch_size do
        flush_batch(webhook, max_batch_size)
      end
    end
  end

  defp flush_batch(webhook, max_batch_size) do
    # Get batch items up to max_batch_size
    items =
      BatchItem
      |> where([b], b.webhook_id == ^webhook.id)
      |> order_by([b], asc: b.inserted_at)
      |> limit(^max_batch_size)
      |> preload(:event)
      |> Repo.all()

    if items != [] do
      # Build batched payload
      payloads =
        Enum.map(items, fn item ->
          Platform.build_webhook_body(webhook, item.event)
        end)

      # Create a single delivery for the batch
      first_event = List.first(items).event

      case %Delivery{}
           |> Delivery.changeset(%{
             event_id: first_event.id,
             webhook_id: webhook.id,
             status: "pending",
             attempt_number: 0,
             response_body: Jason.encode!(%{batch_size: length(payloads)})
           })
           |> Repo.insert() do
        {:ok, delivery} ->
          # Send the batch via the delivery worker mechanism
          Oban.insert(
            StreamflixCore.Platform.ObanDeliveryWorker.new(%{
              delivery_id: delivery.id,
              batch_payloads: payloads
            })
          )

        _ ->
          :ok
      end

      # Clean up processed batch items
      item_ids = Enum.map(items, & &1.id)
      from(b in BatchItem, where: b.id in ^item_ids) |> Repo.delete_all()

      Logger.info("Batch flushed",
        worker: "BatchWorker",
        webhook_id: webhook.id,
        items_count: length(items)
      )
    end
  end
end
