defmodule StreamflixCore.Platform.DeliveryWorker do
  @moduledoc """
  Performs a single delivery: build body from webhook config, sign with HMAC, POST to URL.
  """
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.Delivery
  alias StreamflixCore.Platform

  @timeout_ms 10_000
  @max_response_body 64 * 1024

  def run(delivery_id) do
    delivery = Repo.get(Delivery, delivery_id) |> Repo.preload([:event, :webhook])
    if delivery && delivery.status == "pending" do
      do_deliver(delivery)
    else
      {:error, :not_found_or_not_pending}
    end
  end

  defp do_deliver(%Delivery{} = delivery) do
    body = Platform.build_webhook_body(delivery.webhook, delivery.event)
    body_json = Jason.encode!(body)
    secret = delivery.webhook.secret_encrypted || ""
    signature = sign_hmac(body_json, secret)
    url = delivery.webhook.url
    headers = build_headers(delivery, signature)

    case Req.post(url,
           body: body_json,
           headers: headers,
           receive_timeout: @timeout_ms,
           max_body: @max_response_body
         ) do
      {:ok, %{status: status} = resp} when status >= 200 and status < 300 ->
        update_delivery_success(delivery, status, resp)
        {:ok, status}

      {:ok, %{status: status} = resp} ->
        resp_body = resp_body_truncated(resp)
        update_delivery_failed(delivery, status, resp_body)
        {:error, {:http, status}}

      {:error, reason} ->
        update_delivery_failed(delivery, nil, inspect(reason))
        {:error, reason}
    end
  end

  defp build_headers(delivery, signature) do
    [
      {"content-type", "application/json"},
      {"x-event-id", delivery.event_id},
      {"x-delivery-id", delivery.id},
      {"x-signature", "sha256=" <> signature}
    ]
    |> add_custom_headers(delivery.webhook.headers)
  end

  defp add_custom_headers(list, nil), do: list
  defp add_custom_headers(list, headers) when is_map(headers) do
    extra = Enum.map(headers, fn {k, v} -> {to_string(k), to_string(v)} end)
    list ++ extra
  end
  defp add_custom_headers(list, _), do: list

  defp sign_hmac(body, secret) do
    Base.encode64(:crypto.mac(:hmac, :sha256, secret, body), padding: false)
  end

  defp resp_body_truncated(%{body: body}) when is_binary(body) do
    String.slice(body, 0, @max_response_body)
  end
  defp resp_body_truncated(_), do: nil

  defp update_delivery_success(delivery, status, _resp) do
    attrs = %{
      status: "success",
      attempt_number: delivery.attempt_number + 1,
      response_status: status
    }
    delivery |> Delivery.changeset(attrs) |> Repo.update()
  end

  defp update_delivery_failed(delivery, status, response_body) do
    attrs = %{
      status: "failed",
      attempt_number: delivery.attempt_number + 1,
      response_status: status,
      response_body: response_body
    }
    delivery |> Delivery.changeset(attrs) |> Repo.update()
  end
end
