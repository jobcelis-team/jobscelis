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
  @circuit_reset_seconds 300

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

      notify_circuit_open(webhook)
    else
      webhook
      |> Webhook.changeset(%{consecutive_failures: new_failures})
      |> Repo.update()
    end

    :ok
  end

  defp circuit_expired?(%Webhook{circuit_opened_at: nil}), do: true

  defp circuit_expired?(%Webhook{circuit_opened_at: opened_at}) do
    diff = DateTime.diff(DateTime.utc_now(), opened_at, :second)
    diff >= @circuit_reset_seconds
  end

  defp notify_circuit_open(webhook) do
    notify_project_owner(
      webhook,
      "circuit_open",
      "Circuit breaker abierto",
      "El webhook #{webhook.url} ha sido pausado tras #{@failure_threshold} fallos consecutivos. Se reintentará en #{div(@circuit_reset_seconds, 60)} minutos."
    )
  end

  defp notify_circuit_closed(webhook) do
    notify_project_owner(
      webhook,
      "circuit_closed",
      "Circuit breaker cerrado",
      "El webhook #{webhook.url} se ha recuperado y está recibiendo entregas nuevamente."
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
    end
  end
end
