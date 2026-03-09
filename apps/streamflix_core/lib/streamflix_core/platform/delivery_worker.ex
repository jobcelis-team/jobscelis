defmodule StreamflixCore.Platform.DeliveryWorker do
  @moduledoc """
  Executes webhook deliveries by POSTing payloads to configured URLs.
  Uses Req with explicit timeouts to prevent blocking.
  """
  require Logger

  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.Delivery
  alias StreamflixCore.Platform

  @connect_timeout 5_000
  @receive_timeout 15_000

  @doc """
  Executes the delivery: POSTs to the webhook URL, updates status to success/failed.
  Returns `{:ok, delivery}` or `{:error, reason}`.
  """
  def run(nil), do: {:error, :not_found}
  def run(delivery_id) when not is_binary(delivery_id), do: {:error, :invalid_id}

  def run(delivery_id) do
    delivery =
      Repo.get(Delivery, delivery_id)
      |> Repo.preload([:event, :webhook])

    case delivery do
      nil ->
        Logger.warning("Delivery not found",
          worker: "DeliveryWorker",
          delivery_id: delivery_id
        )

        {:error, :not_found}

      %{status: "success"} ->
        {:ok, delivery}

      %{event: nil} ->
        Logger.warning("Delivery has no event",
          worker: "DeliveryWorker",
          delivery_id: delivery_id
        )

        mark_failed(delivery, nil, "missing event")

      %{webhook: nil} ->
        Logger.warning("Delivery has no webhook",
          worker: "DeliveryWorker",
          delivery_id: delivery_id
        )

        mark_failed(delivery, nil, "missing webhook")

      %{webhook: %{status: "inactive"}} ->
        Logger.info("Webhook inactive, skipping delivery",
          worker: "DeliveryWorker",
          delivery_id: delivery_id
        )

        {:ok, delivery}

      d ->
        # GDPR: skip delivery if project owner has restricted/objected processing
        project = Repo.get(StreamflixCore.Schemas.Project, d.event.project_id)

        if project && !Platform.user_processing_allowed?(project.user_id) do
          Logger.info("Skipping delivery, user processing restricted",
            worker: "DeliveryWorker",
            delivery_id: delivery_id
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

    Logger.info("Starting webhook delivery",
      worker: "DeliveryWorker",
      delivery_id: delivery.id,
      webhook_id: webhook.id,
      event_id: event.id,
      url: url
    )

    opts = [
      json: body,
      headers: headers,
      receive_timeout: @receive_timeout,
      pool_timeout: @connect_timeout,
      finch: StreamflixCore.Finch
    ]

    # Resolve destination IP before request
    destination_ip = resolve_destination_ip(url)

    # Store request details for logging
    request_info = %{
      request_headers: flatten_headers(headers),
      request_body: truncate_body(body_json, 10_000),
      destination_ip: destination_ip
    }

    start_time = System.monotonic_time(:millisecond)

    case Req.post(url, opts) do
      {:ok, %{status: status} = resp} when status >= 200 and status < 300 ->
        latency_ms = System.monotonic_time(:millisecond) - start_time

        Logger.info("Delivery succeeded",
          worker: "DeliveryWorker",
          delivery_id: delivery.id,
          webhook_id: webhook.id,
          event_id: event.id,
          status: status,
          duration_ms: latency_ms
        )

        mark_success(delivery, status, resp, latency_ms, request_info)

      {:ok, %{status: status} = resp} ->
        latency_ms = System.monotonic_time(:millisecond) - start_time

        Logger.warning("Delivery got non-2xx response",
          worker: "DeliveryWorker",
          delivery_id: delivery.id,
          webhook_id: webhook.id,
          event_id: event.id,
          status: status,
          duration_ms: latency_ms
        )

        resp_body = format_response_body(resp)

        mark_failed(
          delivery,
          status,
          resp_body,
          latency_ms,
          flatten_headers(resp.headers),
          request_info
        )

      {:error, reason} ->
        latency_ms = System.monotonic_time(:millisecond) - start_time

        Logger.error("Delivery failed with error",
          worker: "DeliveryWorker",
          delivery_id: delivery.id,
          webhook_id: webhook.id,
          event_id: event.id,
          error: inspect(reason),
          duration_ms: latency_ms
        )

        mark_failed(delivery, nil, inspect(reason), latency_ms, nil, request_info)
    end
  end

  defp build_headers(webhook, body_json) do
    base = [
      {"content-type", "application/json"}
    ]

    # Add HMAC-SHA256 signature header when webhook has a secret configured
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

  @max_response_body 10_000

  defp format_response_body(%{body: body}) when is_binary(body) do
    if String.length(body) > @max_response_body,
      do: String.slice(body, 0, @max_response_body) <> "...",
      else: body
  end

  defp format_response_body(%{body: body}) when is_map(body) or is_list(body) do
    json = Jason.encode!(body)

    if String.length(json) > @max_response_body,
      do: String.slice(json, 0, @max_response_body) <> "...",
      else: json
  end

  defp format_response_body(%{body: body}), do: inspect(body)

  defp mark_success(delivery, status, resp, latency_ms, request_info) do
    result =
      delivery
      |> Delivery.changeset(
        Map.merge(
          %{
            status: "success",
            attempt_number: delivery.attempt_number + 1,
            response_status: status,
            response_body: format_response_body(resp),
            response_headers: flatten_headers(resp.headers),
            response_latency_ms: latency_ms,
            next_retry_at: nil
          },
          request_info
        )
      )
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

  defp mark_failed(
         delivery,
         status,
         reason,
         latency_ms \\ nil,
         resp_headers \\ nil,
         request_info \\ %{}
       ) do
    new_attempt = delivery.attempt_number + 1
    max_attempts = get_max_attempts(delivery)

    delivery
    |> Delivery.changeset(
      Map.merge(
        %{
          status: "failed",
          attempt_number: new_attempt,
          response_status: status,
          response_body: reason,
          response_latency_ms: latency_ms,
          response_headers: resp_headers,
          next_retry_at: nil
        },
        request_info
      )
    )
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

      Logger.warning("Delivery moved to Dead Letter Queue",
        worker: "DeliveryWorker",
        delivery_id: delivery.id,
        webhook_id: delivery.webhook_id,
        event_id: delivery.event_id,
        attempts: delivery.attempt_number
      )
    end
  end

  defp resolve_destination_ip(url) do
    uri = URI.parse(url)

    case :inet.getaddr(to_charlist(uri.host || ""), :inet) do
      {:ok, ip} -> :inet.ntoa(ip) |> to_string()
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp truncate_body(body, max_length) when is_binary(body) do
    if String.length(body) > max_length do
      String.slice(body, 0, max_length) <> "..."
    else
      body
    end
  end

  @dialyzer {:nowarn_function, flatten_headers: 1}
  defp flatten_headers(%{} = headers), do: headers

  defp flatten_headers(headers) when is_list(headers) do
    Map.new(headers, fn {k, v} -> {to_string(k), to_string(v)} end)
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
