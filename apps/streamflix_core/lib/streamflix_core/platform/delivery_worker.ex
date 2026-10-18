defmodule StreamflixCore.Platform.DeliveryWorker do
  @moduledoc """
  Executes webhook deliveries by POSTing payloads to configured URLs.
  Uses Req with explicit timeouts to prevent blocking.
  """
  require Logger

  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.Delivery
  alias StreamflixCore.Platform
  alias StreamflixCore.Platform.UrlGuard

  @connect_timeout 5_000
  @receive_timeout 15_000

  # Client errors that retrying cannot fix: dead-lettered on the first failure
  @no_retry_statuses [400, 401, 403, 404, 422]

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

        mark_skipped(delivery, "skipped: webhook inactive")

      d ->
        # GDPR: skip delivery if project owner has restricted/objected processing
        project = Repo.get(StreamflixCore.Schemas.Project, d.event.project_id)

        if project && !Platform.user_processing_allowed?(project.user_id) do
          Logger.info("Skipping delivery, user processing restricted",
            worker: "DeliveryWorker",
            delivery_id: delivery_id
          )

          mark_skipped(d, "skipped: processing restricted (GDPR)")
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

    # Pipeline deliveries carry their transformed payload; batch deliveries all events
    body = Platform.delivery_body(webhook, event, delivery.payload_override)
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
      finch: StreamflixCore.Finch,
      redirect: false
    ]

    # Resolve destination IP before request
    destination_ip = resolve_destination_ip(url)

    # Store request details for logging
    request_info = %{
      request_headers: flatten_headers(headers),
      request_body: truncate_body(body_json, 10_000),
      destination_ip: destination_ip
    }

    # SSRF guard: re-checked at send time (DNS may have changed since the URL
    # was saved); redirects are never followed.
    case UrlGuard.check(url) do
      {:error, reason} ->
        Logger.warning("Delivery blocked: destination not allowed",
          worker: "DeliveryWorker",
          delivery_id: delivery.id,
          webhook_id: webhook.id
        )

        mark_blocked(delivery, "blocked: destination " <> UrlGuard.message(reason), request_info)

      :ok ->
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

            mark_failed(delivery, nil, describe_error(reason), latency_ms, nil, request_info)
        end
    end
  end

  # Human-readable reason for a request that got no HTTP response. It is shown in the
  # dashboard and the DLQ, so raw structs like %Req.TransportError{} are avoided.
  @transport_reasons %{
    timeout: "timeout (no response from the endpoint)",
    econnrefused: "connection refused",
    nxdomain: "host not found (DNS lookup failed)",
    closed: "connection closed by the endpoint",
    ehostunreach: "host unreachable",
    enetunreach: "network unreachable"
  }

  @doc false
  def describe_error(%Req.TransportError{reason: reason} = error) do
    "Connection error: " <> Map.get(@transport_reasons, reason, Exception.message(error))
  end

  def describe_error(error) when is_exception(error), do: Exception.message(error)
  def describe_error(error) when is_binary(error), do: error
  def describe_error(error), do: inspect(error)

  # Headers the platform controls; custom webhook headers cannot override them
  @reserved_headers ~w(content-type content-length host x-signature transfer-encoding connection)

  defp build_headers(webhook, body_json) do
    custom =
      (webhook.headers || %{})
      |> Enum.filter(fn {k, v} -> is_binary(k) and is_binary(v) and k != "" end)
      |> Enum.map(fn {k, v} -> {String.downcase(String.trim(k)), v} end)
      |> Enum.reject(fn {k, _} -> k in @reserved_headers end)

    base = [{"content-type", "application/json"} | custom]

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

        evt = delivery.event || Repo.get(StreamflixCore.Schemas.WebhookEvent, delivery.event_id)

        if evt do
          StreamflixCore.TelemetryEvents.delivery_success(
            evt.project_id,
            delivery.webhook_id,
            evt.topic,
            latency_ms
          )
        end

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

        event = delivery.event || Repo.get(StreamflixCore.Schemas.WebhookEvent, delivery.event_id)

        if event do
          StreamflixCore.TelemetryEvents.delivery_failure(
            event.project_id,
            delivery.webhook_id,
            event.topic
          )
        end

        # Dead-letter when retries are exhausted, or right away for client errors
        # that retrying cannot fix. The caller stops retrying in that case.
        if new_attempt >= max_attempts or status in @no_retry_statuses do
          move_to_dlq(d, status, reason)
          {:error, {:dead_lettered, d}}
        else
          {:error, {:failed, d}}
        end

      err ->
        err
    end
  end

  # Destination rejected by the SSRF guard: nothing was sent and retrying will
  # not help, so the delivery goes straight to the DLQ (owner gets notified).
  defp mark_blocked(delivery, reason, request_info) do
    changes =
      Map.merge(
        %{status: "failed", attempt_number: delivery.attempt_number + 1, response_body: reason},
        Map.take(request_info, [:request_headers, :request_body])
      )

    case delivery |> Delivery.changeset(changes) |> Repo.update() do
      {:ok, d} ->
        broadcast_delivery(d)
        move_to_dlq(d, nil, reason)
        {:error, {:dead_lettered, d}}

      error ->
        error
    end
  end

  # Delivery intentionally not sent (webhook inactive, processing restricted):
  # record why instead of leaving it "pending" forever. Not a webhook failure,
  # so neither the circuit breaker nor the DLQ are involved.
  defp mark_skipped(delivery, reason) do
    case delivery
         |> Delivery.changeset(%{status: "failed", response_body: reason})
         |> Repo.update() do
      {:ok, d} ->
        broadcast_delivery(d)
        {:ok, d}

      error ->
        error
    end
  end

  # Capped at the Oban job max_attempts (20) so the DLQ is always reached
  @oban_max_attempts 20

  defp get_max_attempts(delivery) do
    configured =
      case Repo.get(StreamflixCore.Schemas.Webhook, delivery.webhook_id) do
        nil -> 5
        w -> (w.retry_config || %{})["max_attempts"] || 5
      end

    if is_integer(configured), do: configured |> max(1) |> min(@oban_max_attempts), else: 5
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
        original_payload: delivery.payload_override || event.payload || %{},
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
