defmodule StreamflixCore.Platform.ObanDeliveryWorker do
  @moduledoc """
  Oban worker for webhook deliveries. Queue: :delivery.
  Supports per-webhook retry policies via retry_config embedded in job args.
  Default backoff: 1 min → 5 min → 15 min → 1 h.
  """
  use Oban.Worker, queue: :delivery, max_attempts: 20

  @default_backoff [60, 300, 900, 3600]
  @default_max_attempts 5

  # Client errors that should not be retried
  @no_retry_statuses [400, 401, 403, 404, 422]

  @impl true
  def backoff(%Oban.Job{args: args, attempt: attempt}) do
    config = args["retry_config"] || %{}

    delays =
      case config["backoff_seconds"] do
        delays when is_list(delays) and delays != [] -> delays
        _ -> @default_backoff
      end

    Enum.at(delays, attempt - 1, List.last(delays))
  end

  @impl true
  def perform(%Oban.Job{args: args, attempt: attempt}) do
    delivery_id = args["delivery_id"] || args[:delivery_id]
    config = args["retry_config"] || %{}
    max = config["max_attempts"] || @default_max_attempts

    if attempt > max do
      :ok
    else
      case StreamflixCore.Platform.DeliveryWorker.run(delivery_id) do
        {:ok, _} -> :ok
        {:error, :circuit_open} -> {:snooze, 300}
        {:error, {:failed, %{response_status: status}}} when status in @no_retry_statuses -> :ok
        {:error, _} -> :error
      end
    end
  end
end
