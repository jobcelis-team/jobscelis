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
        do_deliver(d)
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
      connect_options: [timeout: @connect_timeout]
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
    delivery
    |> Delivery.changeset(%{
      status: "success",
      attempt_number: delivery.attempt_number + 1,
      response_status: status,
      response_body: nil,
      next_retry_at: nil
    })
    |> Repo.update()
  end

  defp mark_failed(delivery, status, reason) do
    delivery
    |> Delivery.changeset(%{
      status: "failed",
      attempt_number: delivery.attempt_number + 1,
      response_status: status,
      response_body: reason,
      next_retry_at: nil
    })
    |> Repo.update()
    |> case do
      {:ok, d} -> {:error, {:failed, d}}
      err -> err
    end
  end
end
