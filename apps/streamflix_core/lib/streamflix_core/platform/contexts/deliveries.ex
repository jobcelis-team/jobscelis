defmodule StreamflixCore.Platform.Deliveries do
  @moduledoc """
  Delivery management: list, retry, body building.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{Delivery, WebhookEvent}

  def list_deliveries(opts \\ []) do
    event_id = Keyword.get(opts, :event_id)
    webhook_id = Keyword.get(opts, :webhook_id)
    status = Keyword.get(opts, :status)
    project_id = Keyword.get(opts, :project_id)
    limit = Keyword.get(opts, :limit, 50)

    event_ids_query =
      if project_id do
        from(e in WebhookEvent, where: e.project_id == ^project_id, select: e.id)
      else
        nil
      end

    base =
      Delivery
      |> maybe_where(:event_id, event_id)
      |> maybe_where(:webhook_id, webhook_id)
      |> maybe_where(:status, status)
      |> maybe_where_event_in_subquery(event_ids_query)
      |> order_by([d], desc: d.inserted_at)
      |> limit(^limit)

    base
    |> preload([:event, :webhook])
    |> Repo.all()
  end

  defp maybe_where_event_in_subquery(query, nil), do: query

  defp maybe_where_event_in_subquery(query, event_ids_query),
    do: where(query, [d], d.event_id in subquery(event_ids_query))

  defp maybe_where(query, _field, nil), do: query
  defp maybe_where(query, field, value), do: where(query, [d], field(d, ^field) == ^value)

  @doc """
  Success rate (0.0–100.0) of finished deliveries (success or failed) for a
  project since the given datetime. Pending deliveries are not counted.
  """
  def success_rate_since(project_id, %DateTime{} = since) do
    counts =
      from(d in Delivery,
        join: e in WebhookEvent,
        on: e.id == d.event_id,
        where: e.project_id == ^project_id and d.inserted_at >= ^since,
        where: d.status in ["success", "failed"],
        select: %{
          total: count(d.id),
          success: filter(count(d.id), d.status == "success")
        }
      )
      |> Repo.one()

    case counts do
      %{total: total, success: success} when total > 0 -> Float.round(success / total * 100, 1)
      _ -> 0.0
    end
  end

  def get_delivery(id), do: Repo.get_uuid(Delivery, id)
  def get_delivery!(id), do: Repo.get!(Delivery, id)

  def update_delivery_to_pending(%Delivery{} = d) do
    d
    |> Delivery.changeset(%{
      status: "pending",
      attempt_number: d.attempt_number + 1,
      response_status: nil,
      response_body: nil,
      response_headers: nil,
      response_latency_ms: nil,
      request_headers: nil,
      request_body: nil,
      destination_ip: nil,
      next_retry_at: nil
    })
    |> Repo.update()
  end

  def retry_delivery(project_id, delivery_id) do
    case Repo.get_uuid(Delivery, delivery_id) |> Repo.preload([:event, :webhook]) do
      nil ->
        {:error, :not_found}

      d ->
        event = d.event || StreamflixCore.Platform.Events.get_event(d.event_id)

        cond do
          is_nil(event) or event.project_id != project_id ->
            {:error, :not_found}

          # Re-sending a delivery the receiver already accepted would duplicate it
          d.status == "success" ->
            {:error, :already_succeeded}

          true ->
            retry_config = (d.webhook && d.webhook.retry_config) || %{}
            cancel_pending_jobs(d.id)

            with {:ok, updated} <- update_delivery_to_pending(d),
                 {:ok, _job} <-
                   Oban.insert(
                     StreamflixCore.Platform.ObanDeliveryWorker.new(%{
                       delivery_id: updated.id,
                       retry_config: retry_config
                     })
                   ) do
              {:ok, updated}
            end
        end
    end
  end

  # An automatic retry may already be scheduled: without cancelling it, a manual
  # retry runs the delivery twice and burns two attempts per failure.
  defp cancel_pending_jobs(delivery_id) do
    from(j in Oban.Job,
      where: j.worker == "StreamflixCore.Platform.ObanDeliveryWorker",
      where: j.state in ["available", "scheduled", "retryable"],
      where: fragment("?->>'delivery_id' = ?", j.args, ^delivery_id)
    )
    |> Oban.cancel_all_jobs()
  end

  @batch_key "__jobcelis_batch__"

  @doc "Wraps already-built webhook bodies so a single delivery sends them as one batch."
  def batch_override(bodies) when is_list(bodies), do: %{@batch_key => bodies}

  @doc """
  Body for a delivery: a batch envelope when the delivery carries a batch, the
  pipeline-transformed payload when it has an override, the event otherwise.
  """
  def delivery_body(_webhook, _event, %{@batch_key => bodies}) when is_list(bodies) do
    %{"batch" => true, "batch_size" => length(bodies), "events" => bodies}
  end

  def delivery_body(webhook, event, override) when is_map(override),
    do: build_webhook_body(webhook, %{event | payload: override})

  def delivery_body(webhook, event, _override), do: build_webhook_body(webhook, event)

  def build_webhook_body(webhook, event) do
    config = webhook.body_config || %{}
    mode = config["body_mode"] || "full"
    payload = event.payload || %{}

    base =
      case mode do
        "pick" ->
          keys = config["body_pick"] || []
          Enum.reduce(keys, %{}, fn k, acc -> Map.put(acc, k, payload[k]) end)

        _ ->
          payload
      end

    rename = config["body_rename"] || %{}

    base =
      Enum.reduce(rename, base, fn {from_k, to_k}, acc ->
        case Map.get(acc, from_k) do
          nil -> acc
          v -> acc |> Map.delete(from_k) |> Map.put(to_k, v)
        end
      end)

    extra = config["body_extra"] || %{}
    base = Map.merge(base, extra)

    Map.merge(base, %{
      "event_id" => event.id,
      "topic" => event.topic,
      "occurred_at" => event.occurred_at
    })
  end
end
