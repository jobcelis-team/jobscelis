defmodule StreamflixCore.CircuitBreaker do
  @moduledoc """
  Circuit breaker for webhook deliveries.
  States: closed (normal), open (blocking), half_open (testing).
  After 5 consecutive failures, the circuit opens for 5 minutes.
  """
  require Logger

  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.Webhook
  alias StreamflixCore.Notifications

  @failure_threshold 5
  @base_reset_seconds 300
  @max_reset_seconds 7200

  @doc """
  Check if a webhook's circuit allows delivery.
  Returns :ok or {:error, :circuit_open}.
  """
  def check_circuit(%Webhook{circuit_state: "closed"}), do: :ok

  def check_circuit(%Webhook{circuit_state: "open"} = webhook) do
    if circuit_expired?(webhook) do
      # Transition to half_open — allow a test delivery
      webhook
      |> Webhook.changeset(%{circuit_state: "half_open"})
      |> Repo.update()

      :ok
    else
      {:error, :circuit_open}
    end
  end

  def check_circuit(%Webhook{circuit_state: "half_open"}), do: :ok
  def check_circuit(_webhook), do: :ok

  @doc """
  Record a successful delivery. Resets circuit to closed.
  """
  def record_success(%Webhook{} = webhook) do
    was_open = webhook.circuit_state in ["open", "half_open"]

    webhook
    |> Webhook.changeset(%{
      circuit_state: "closed",
      consecutive_failures: 0,
      circuit_opened_at: nil
    })
    |> Repo.update()

    if was_open do
      Logger.info("[CircuitBreaker] Circuit closed for webhook #{webhook.id}")
      StreamflixCore.TelemetryEvents.circuit_closed(webhook.project_id, webhook.id)
      notify_circuit_closed(webhook)
    end

    :ok
  end

  @doc """
  Record a failed delivery. Increments failure count and opens circuit if threshold reached.
  """
  def record_failure(%Webhook{} = webhook) do
    new_failures = (webhook.consecutive_failures || 0) + 1

    if new_failures >= @failure_threshold do
      now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      webhook
      |> Webhook.changeset(%{
        circuit_state: "open",
        consecutive_failures: new_failures,
        circuit_opened_at: now
      })
      |> Repo.update()

      Logger.warning(
        "[CircuitBreaker] Circuit opened for webhook #{webhook.id} after #{new_failures} failures"
      )

      StreamflixCore.TelemetryEvents.circuit_opened(webhook.project_id, webhook.id)
      notify_circuit_open(webhook)
    else
      webhook
      |> Webhook.changeset(%{consecutive_failures: new_failures})
      |> Repo.update()
    end

    :ok
  end

  defp circuit_expired?(%Webhook{circuit_opened_at: nil}), do: true

  defp circuit_expired?(%Webhook{circuit_opened_at: opened_at} = webhook) do
    failures = webhook.consecutive_failures || 0

    base =
      min(@base_reset_seconds * :math.pow(2, div(max(failures - 5, 0), 5)), @max_reset_seconds)

    jitter = :rand.uniform(30)
    diff = DateTime.diff(DateTime.utc_now(), opened_at, :second)
    diff >= trunc(base) + jitter
  end

  defp notify_circuit_open(webhook) do
    notify_project_owner(
      webhook,
      "circuit_open",
      "Circuit breaker opened",
      "Webhook #{webhook.url} has been paused after #{@failure_threshold} consecutive failures. Will retry in #{div(@base_reset_seconds, 60)} minutes."
    )
  end

  defp notify_circuit_closed(webhook) do
    notify_project_owner(
      webhook,
      "circuit_closed",
      "Circuit breaker closed",
      "Webhook #{webhook.url} has recovered and is receiving deliveries again."
    )
  end

  defp notify_project_owner(webhook, type, title, message) do
    project = Repo.get(StreamflixCore.Schemas.Project, webhook.project_id)

    if project && project.user_id do
      Notifications.create(%{
        user_id: project.user_id,
        project_id: project.id,
        type: type,
        title: title,
        message: message,
        metadata: %{"webhook_id" => webhook.id, "webhook_url" => webhook.url}
      })

      StreamflixCore.NotificationChannels.dispatch(project.id, type, %{
        "message" => message,
        "webhook_id" => webhook.id,
        "webhook_url" => webhook.url
      })
    end
  end
end
