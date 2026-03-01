defmodule StreamflixCore.Platform.ObanDeliveryWorker do
  @moduledoc """
  Oban worker for webhook deliveries. Queue: :delivery.
  Supports per-webhook retry policies via retry_config.
  Default backoff: 1 min → 5 min → 15 min → 1 h.
  """
  use Oban.Worker, queue: :delivery, max_attempts: 20

  @default_backoff [60, 300, 900, 3600]
  @default_max_attempts 5

  @impl true
  def backoff(%Oban.Job{args: args, attempt: attempt}) do
    delays = get_retry_delays(args["delivery_id"])
    Enum.at(delays, attempt - 1, List.last(delays))
  end

  @impl true
  def perform(%Oban.Job{args: args, attempt: attempt}) do
    delivery_id = args["delivery_id"] || args[:delivery_id]
    max = get_max_attempts(delivery_id)

    if attempt > max do
      # Exceeded custom max_attempts, stop retrying
      :ok
    else
      case StreamflixCore.Platform.DeliveryWorker.run(delivery_id) do
        {:ok, _} -> :ok
        {:error, _} -> :error
      end
    end
  end

  defp get_retry_config(delivery_id) do
    case StreamflixCore.Repo.get(StreamflixCore.Schemas.Delivery, delivery_id) do
      nil -> %{}
      d ->
        case StreamflixCore.Repo.get(StreamflixCore.Schemas.Webhook, d.webhook_id) do
          nil -> %{}
          w -> w.retry_config || %{}
        end
    end
  end

  defp get_retry_delays(delivery_id) do
    config = get_retry_config(delivery_id)
    case config["backoff_seconds"] do
      delays when is_list(delays) and delays != [] -> delays
      _ -> @default_backoff
    end
  end

  defp get_max_attempts(delivery_id) do
    config = get_retry_config(delivery_id)
    config["max_attempts"] || @default_max_attempts
  end
end
