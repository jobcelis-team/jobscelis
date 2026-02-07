defmodule StreamflixCore.Platform.ObanDeliveryWorker do
  @moduledoc """
  Oban worker for webhook deliveries. Queue: :delivery.
  Enqueue with: Oban.insert(StreamflixCore.Platform.ObanDeliveryWorker.new(%{delivery_id: id}))
  """
  use Oban.Worker, queue: :delivery, max_attempts: 5

  @impl true
  def perform(%Oban.Job{args: args}) do
    delivery_id = args["delivery_id"] || args[:delivery_id]
    case StreamflixCore.Platform.DeliveryWorker.run(delivery_id) do
      {:ok, _} -> :ok
      {:error, _} -> :error
    end
  end
end
