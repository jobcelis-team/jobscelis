defmodule StreamflixCore.Platform.ObanDeliveryWorker do
  @moduledoc """
  Oban worker for webhook deliveries. Queue: :delivery.
  Supports per-webhook retry policies via retry_config embedded in job args.

  Backoff strategies:
  - exponential (default): base * 3^attempt + jitter
  - linear: base * attempt + jitter
  - fixed: base + jitter
  """
  use Oban.Worker, queue: :delivery, max_attempts: 20

  require Logger

  @default_base_delay 10
  @default_max_delay 3600

  @impl true
  def backoff(%Oban.Job{args: args, attempt: attempt}) do
    config = args["retry_config"] || %{}

    # Support legacy backoff_seconds list
    case config["backoff_seconds"] do
      delays when is_list(delays) and delays != [] ->
        Enum.at(delays, attempt - 1, List.last(delays))

      _ ->
        strategy = config["strategy"] || "exponential"
        base = config["base_delay_seconds"] || config["base_delay"] || @default_base_delay
        max_delay = config["max_delay_seconds"] || config["max_delay"] || @default_max_delay
        jitter? = config["jitter"] != false

        delay = calculate_delay(strategy, base, attempt)
        delay = min(delay, max_delay)
        delay = if jitter?, do: add_jitter(delay), else: delay
        max(delay, 1)
    end
  end

  defp calculate_delay("exponential", base, attempt) do
    # base * 3^(attempt-1): 10s, 30s, 90s, 270s, 810s...
    base * Integer.pow(3, attempt - 1)
  end

  defp calculate_delay("linear", base, attempt) do
    # base * attempt: 10s, 20s, 30s, 40s, 50s...
    base * attempt
  end

  defp calculate_delay("fixed", base, _attempt) do
    base
  end

  defp calculate_delay(_, base, attempt) do
    # Default to exponential
    calculate_delay("exponential", base, attempt)
  end

  defp add_jitter(delay) do
    # Add +/- 20% jitter to avoid thundering herd
    jitter_range = max(trunc(delay * 0.2), 1)
    delay + :rand.uniform(jitter_range * 2) - jitter_range
  end

  @impl true
  def perform(%Oban.Job{args: args}) do
    delivery_id = args["delivery_id"] || args[:delivery_id]

    # Attempts are counted on the delivery (attempt_number) by DeliveryWorker,
    # which dead-letters it when retry_config.max_attempts is reached. Oban's own
    # attempt counter is not used: snoozes (rate limit / circuit open) inflate it.
    case check_outbound_rate_limit(delivery_id) do
      {:error, :rate_limited} ->
        Logger.info("Delivery rate limited, snoozing",
          worker: "ObanDeliveryWorker",
          delivery_id: delivery_id
        )

        {:snooze, 5}

      :ok ->
        execute_delivery(delivery_id)
    end
  end

  defp check_outbound_rate_limit(delivery_id) do
    alias StreamflixCore.{Repo, Schemas.Delivery, RateLimiter}

    case Repo.get(Delivery, delivery_id) do
      nil ->
        :ok

      delivery ->
        webhook = Repo.get(StreamflixCore.Schemas.Webhook, delivery.webhook_id)

        if webhook do
          rate_config = webhook.rate_limit || %{}

          case RateLimiter.check_rate(webhook.id, rate_config) do
            :ok ->
              RateLimiter.record_request(webhook.id)
              :ok

            {:error, :rate_limited} ->
              {:error, :rate_limited}
          end
        else
          :ok
        end
    end
  end

  # Oban only retries on {:error, _} (a bare :error is treated as success).
  defp execute_delivery(delivery_id) do
    case StreamflixCore.Platform.DeliveryWorker.run(delivery_id) do
      {:ok, _} -> :ok
      {:error, :circuit_open} -> {:snooze, 300}
      {:error, {:dead_lettered, _}} -> {:cancel, :dead_lettered}
      {:error, reason} when reason in [:not_found, :invalid_id] -> {:cancel, reason}
      {:error, {:failed, d}} -> {:error, "delivery failed (HTTP #{d.response_status || "error"})"}
      {:error, reason} -> {:error, reason}
    end
  rescue
    e ->
      Logger.error("DeliveryWorker crashed",
        worker: "ObanDeliveryWorker",
        delivery_id: delivery_id,
        error: Exception.message(e)
      )

      {:error, Exception.message(e)}
  end
end
