defmodule StreamflixCore.Platform.ObanDeliveryWorker do
  @moduledoc """
  Oban worker for webhook deliveries. Queue: :delivery.
  Backoff: 1 min → 5 min → 15 min → 1 h (spec).
  """
  use Oban.Worker, queue: :delivery, max_attempts: 5

  @backoff_seconds [60, 300, 900, 3600]

  @impl true
  def backoff(%Oban.Job{attempt: attempt}) do
    Enum.at(@backoff_seconds, attempt - 1, 3600)
  end

  @impl true
  def perform(%Oban.Job{args: args}) do
    delivery_id = args["delivery_id"] || args[:delivery_id]
    case StreamflixCore.Platform.DeliveryWorker.run(delivery_id) do
      {:ok, _} -> :ok
      {:error, _} -> :error
    end
  end
end
