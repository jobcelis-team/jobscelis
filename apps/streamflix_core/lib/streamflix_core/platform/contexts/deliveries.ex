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

  def get_delivery(id), do: Repo.get(Delivery, id)
  def get_delivery!(id), do: Repo.get!(Delivery, id)

  def update_delivery_to_pending(%Delivery{} = d) do
    d
    |> Delivery.changeset(%{
      status: "pending",
      attempt_number: d.attempt_number + 1,
      response_status: nil,
      response_body: nil,
      next_retry_at: nil
    })
    |> Repo.update()
  end

  def retry_delivery(project_id, delivery_id) do
    case Repo.get(Delivery, delivery_id) |> Repo.preload(:event) do
      nil ->
        {:error, :not_found}

      d ->
        event = d.event || StreamflixCore.Platform.Events.get_event(d.event_id)

        if is_nil(event) or event.project_id != project_id do
          {:error, :not_found}
        else
          {:ok, updated} = update_delivery_to_pending(d)
          Oban.insert(StreamflixCore.Platform.ObanDeliveryWorker.new(%{delivery_id: updated.id}))
          {:ok, updated}
        end
    end
  end

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
