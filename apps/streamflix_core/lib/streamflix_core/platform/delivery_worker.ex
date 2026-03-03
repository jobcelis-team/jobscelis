defmodule StreamflixCore.Platform.DeliveryWorker do
  @moduledoc """
  Ejecuta la entrega de un webhook: POST a la URL con el payload.
  Usa Req con timeouts explícitos para evitar bloqueos.
  """
  require Logger

  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.Delivery
  alias StreamflixCore.Platform

  @connect_timeout 5_000
  @receive_timeout 15_000

  @doc """
  Ejecuta la entrega: POST al webhook, actualiza status success/failed.
  Retorna {:ok, delivery} o {:error, reason}.
  """
  def run(nil), do: {:error, :not_found}
  def run(delivery_id) when not is_binary(delivery_id), do: {:error, :invalid_id}

  def run(delivery_id) do
    delivery =
      Repo.get(Delivery, delivery_id)
      |> Repo.preload([:event, :webhook])

    case delivery do
      nil ->
        Logger.warning("[DeliveryWorker] Delivery not found: #{delivery_id}")
        {:error, :not_found}

      %{status: "success"} ->
        {:ok, delivery}

      %{event: nil} ->
        Logger.warning("[DeliveryWorker] Delivery #{delivery_id} has no event")
        mark_failed(delivery, nil, "missing event")

      %{webhook: nil} ->
        Logger.warning("[DeliveryWorker] Delivery #{delivery_id} has no webhook")
        mark_failed(delivery, nil, "missing webhook")

      %{webhook: %{status: "inactive"}} ->
        Logger.info("[DeliveryWorker] Webhook inactive for delivery #{delivery_id}, skipping")
        {:ok, delivery}

      d ->
        # GDPR: skip delivery if project owner has restricted/objected processing
        project = Repo.get(StreamflixCore.Schemas.Project, d.event.project_id)

        if project && !Platform.user_processing_allowed?(project.user_id) do
          Logger.info(
            "[DeliveryWorker] Skipping delivery #{delivery_id}, user processing restricted"
          )

          {:ok, delivery}
        else
          case StreamflixCore.CircuitBreaker.check_circuit(d.webhook) do
            :ok -> do_deliver(d)
            {:error, :circuit_open} -> {:error, :circuit_open}
          end
        end
    end
  end

  defp do_deliver(%Delivery{} = delivery) do
    %{event: event, webhook: webhook} = delivery
    url = webhook.url

    body = Platform.build_webhook_body(webhook, event)
    body_json = Jason.encode!(body)

    headers = build_headers(webhook, body_json)

    Logger.info("[DeliveryWorker] Starting POST to #{url} for delivery #{delivery.id}")

    # receive_timeout a nivel superior (como ScheduledJobRunner) - connect_options no aplicaba
    opts = [
      json: body,
      headers: headers,
      receive_timeout: @receive_timeout,
      connect_options: [timeout: @connect_timeout],
      finch: StreamflixCore.Finch
    ]

    case Req.post(url, opts) do
      {:ok, %{status: status} = resp} when status >= 200 and status < 300 ->
        Logger.info("[DeliveryWorker] Success #{status} for delivery #{delivery.id}")
        mark_success(delivery, status, resp)

      {:ok, %{status: status} = resp} ->
        Logger.warning("[DeliveryWorker] Non-2xx #{status} for delivery #{delivery.id}")
        resp_body = format_response_body(resp)
        mark_failed(delivery, status, resp_body)

      {:error, reason} ->
        Logger.error("[DeliveryWorker] Error for delivery #{delivery.id}: #{inspect(reason)}")
        mark_failed(delivery, nil, inspect(reason))
    end
  end

  defp build_headers(webhook, body_json) do
    base = [
      {"content-type", "application/json"}
    ]

    # X-Signature HMAC-SHA256 si hay secret
    with secret when is_binary(secret) and secret != "" <- webhook.secret_encrypted,
         sig <- compute_signature(secret, body_json) do
      [{"x-signature", "sha256=" <> sig} | base]
    else
      _ -> base
    end
  end

  defp compute_signature(secret, body) do
    :crypto.mac(:hmac, :sha256, secret, body) |> Base.encode64(padding: false)
  end

  defp format_response_body(%{body: body}) when is_binary(body) do
    if String.length(body) > 500, do: String.slice(body, 0, 500) <> "...", else: body
  end

  defp format_response_body(%{body: body}), do: inspect(body)

  defp mark_success(delivery, status, _resp) do
    result =
      delivery
      |> Delivery.changeset(%{
        status: "success",
        attempt_number: delivery.attempt_number + 1,
        response_status: status,
        response_body: nil,
        next_retry_at: nil
      })
      |> Repo.update()

    case result do
      {:ok, d} ->
        if delivery.webhook, do: StreamflixCore.CircuitBreaker.record_success(delivery.webhook)
        broadcast_delivery(d)
        {:ok, d}

      err ->
        err
    end
  end

  defp mark_failed(delivery, status, reason) do
    new_attempt = delivery.attempt_number + 1
    max_attempts = get_max_attempts(delivery)

    delivery
    |> Delivery.changeset(%{
      status: "failed",
      attempt_number: new_attempt,
      response_status: status,
      response_body: reason,
      next_retry_at: nil
    })
    |> Repo.update()
    |> case do
      {:ok, d} ->
        if delivery.webhook, do: StreamflixCore.CircuitBreaker.record_failure(delivery.webhook)
        broadcast_delivery(d)

        # Move to Dead Letter Queue if all retries exhausted
        if new_attempt >= max_attempts do
          move_to_dlq(d, status, reason)
        end

        {:error, {:failed, d}}

      err ->
        err
    end
  end

  defp get_max_attempts(delivery) do
    case Repo.get(StreamflixCore.Schemas.Webhook, delivery.webhook_id) do
      nil -> 5
      w -> (w.retry_config || %{})["max_attempts"] || 5
    end
  end

  defp move_to_dlq(delivery, _status, reason) do
    event = delivery.event || Repo.get(StreamflixCore.Schemas.WebhookEvent, delivery.event_id)
    webhook = delivery.webhook || Repo.get(StreamflixCore.Schemas.Webhook, delivery.webhook_id)

    if event do
      Platform.create_dead_letter(%{
        project_id: event.project_id,
        delivery_id: delivery.id,
        event_id: delivery.event_id,
        webhook_id: delivery.webhook_id,
        original_payload: event.payload || %{},
        last_error: reason,
        last_response_status: delivery.response_status,
        attempts_exhausted: delivery.attempt_number
      })

      # Notify project owner
      project = Repo.get(StreamflixCore.Schemas.Project, event.project_id)

      if project && project.user_id do
        StreamflixCore.Notifications.notify_dlq_entry(
          project.user_id,
          project.id,
          if(webhook, do: webhook.url, else: "unknown")
        )
      end

      Logger.warning(
        "[DeliveryWorker] Delivery #{delivery.id} moved to Dead Letter Queue after #{delivery.attempt_number} attempts"
      )
    end
  end

  defp broadcast_delivery(delivery) do
    event = delivery.event || Repo.get(StreamflixCore.Schemas.WebhookEvent, delivery.event_id)

    if event do
      Phoenix.PubSub.broadcast(
        StreamflixCore.PubSub,
        "project:#{event.project_id}",
        {:delivery_updated, delivery}
      )
    end
  end
end
