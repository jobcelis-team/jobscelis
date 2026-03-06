defmodule StreamflixCore.Platform.Events do
  @moduledoc """
  Event management: create, list, idempotency, delayed events, schema validation.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{WebhookEvent, Delivery, BatchItem}

  def create_event(project_id, body) when is_map(body) do
    # GDPR: check if project owner allows processing
    project = StreamflixCore.Platform.Projects.get_project(project_id)

    if project && !user_processing_allowed?(project.user_id) do
      {:error, :processing_restricted}
    else
      # Extract idempotency_key before topic/payload extraction
      idempotency_key =
        Map.get(body, "idempotency_key") || Map.get(body, :idempotency_key)

      # Idempotency: return existing event if key already used
      if idempotency_key do
        case Repo.one(
               from(e in WebhookEvent,
                 where: e.project_id == ^project_id and e.idempotency_key == ^idempotency_key
               )
             ) do
          %WebhookEvent{} = existing -> {:ok, existing}
          nil -> do_create_event(project_id, body, idempotency_key)
        end
      else
        do_create_event(project_id, body, nil)
      end
    end
  end

  def create_event(_project_id, _), do: {:error, :invalid_payload}

  defp do_create_event(project_id, body, idempotency_key) do
    {topic, payload} = extract_topic_and_payload(body)
    occurred_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    # Schema validation (opt-in: no schema = pass)
    case StreamflixCore.Platform.EventSchemas.validate_event_payload(project_id, topic, payload) do
      :ok -> :ok
      {:error, _} = err -> throw(err)
    end

    # Parse deliver_at for delayed events
    deliver_at = parse_deliver_at(body)

    # Compute SHA256 hash of canonical payload
    payload_hash =
      :crypto.hash(:sha256, Jason.encode!(payload))
      |> Base.encode16(case: :lower)

    attrs = %{
      project_id: project_id,
      topic: topic,
      payload: payload,
      status: "active",
      occurred_at: occurred_at,
      deliver_at: deliver_at,
      payload_hash: payload_hash,
      idempotency_key: idempotency_key
    }

    with {:ok, event} <- insert_event(attrs) do
      # Skip immediate delivery if future deliver_at
      if is_nil(deliver_at) or DateTime.compare(deliver_at, DateTime.utc_now()) != :gt do
        create_deliveries_for_event(event)
      end

      broadcast(project_id, {:event_created, event})
      {:ok, event}
    end
  catch
    {:error, {:schema_validation, _errors}} = err -> err
  end

  defp parse_deliver_at(body) do
    raw = Map.get(body, "deliver_at") || Map.get(body, :deliver_at)

    case raw do
      nil ->
        nil

      str when is_binary(str) ->
        case DateTime.from_iso8601(str) do
          {:ok, dt, _} -> DateTime.truncate(dt, :microsecond)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  @doc false
  def extract_topic_and_payload(body) do
    case Map.get(body, "topic") || Map.get(body, :topic) do
      nil ->
        {nil, body}

      t when is_binary(t) ->
        {t, Map.delete(Map.new(body, fn {k, v} -> {to_string(k), v} end), "topic")}

      _ ->
        {nil, body}
    end
  end

  defp insert_event(attrs) do
    %WebhookEvent{}
    |> WebhookEvent.changeset(attrs)
    |> Repo.insert()
  end

  defp create_deliveries_for_event(event) do
    alias StreamflixCore.Schemas.Delivery, as: DeliverySchema

    webhooks = StreamflixCore.Platform.Webhooks.list_active_webhooks_for_project(event.project_id)

    matching =
      Enum.filter(webhooks, &StreamflixCore.Platform.Webhooks.webhook_matches_event?(&1, event))

    Enum.each(matching, fn w ->
      batch_config = w.batch_config || %{}

      if batch_config["enabled"] == true do
        # Add to batch queue instead of immediate delivery
        %BatchItem{}
        |> BatchItem.changeset(%{webhook_id: w.id, event_id: event.id})
        |> Repo.insert()
      else
        case %DeliverySchema{}
             |> DeliverySchema.changeset(%{
               event_id: event.id,
               webhook_id: w.id,
               status: "pending",
               attempt_number: 0
             })
             |> Repo.insert() do
          {:ok, delivery} ->
            Oban.insert(
              StreamflixCore.Platform.ObanDeliveryWorker.new(%{
                delivery_id: delivery.id,
                retry_config: w.retry_config || %{}
              })
            )

          _ ->
            :ok
        end
      end
    end)

    :ok
  end

  def list_events(project_id, opts \\ []) do
    include_inactive = Keyword.get(opts, :include_inactive, false)
    limit = Keyword.get(opts, :limit, 50)
    topic = Keyword.get(opts, :topic)

    WebhookEvent
    |> where([e], e.project_id == ^project_id)
    |> maybe_filter_active(include_inactive)
    |> maybe_filter_topic(topic)
    |> order_by([e], desc: e.occurred_at)
    |> limit(^limit)
    |> Repo.all()
  end

  defp maybe_filter_topic(query, nil), do: query
  defp maybe_filter_topic(query, topic), do: where(query, [e], e.topic == ^topic)

  @doc """
  Full-text search on event payloads using GIN index (jsonb_path_ops).
  Searches for events whose payload contains the given key-value pair.
  """
  def search_events(project_id, query_params, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    base =
      WebhookEvent
      |> where([e], e.project_id == ^project_id and e.status == "active")

    base =
      Enum.reduce(query_params, base, fn {key, value}, q ->
        json_fragment = Jason.encode!(%{key => value})
        where(q, [e], fragment("? @> ?::jsonb", e.payload, ^json_fragment))
      end)

    base
    |> order_by([e], desc: e.occurred_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_event(id), do: Repo.get(WebhookEvent, id)
  def get_event!(id), do: Repo.get!(WebhookEvent, id)

  def list_topics_used(project_id) do
    WebhookEvent
    |> where(
      [e],
      e.project_id == ^project_id and e.status == "active" and not is_nil(e.topic) and
        e.topic != ""
    )
    |> distinct(true)
    |> select([e], e.topic)
    |> order_by([e], asc: e.topic)
    |> Repo.all()
  end

  def set_event_inactive(%WebhookEvent{} = event) do
    event
    |> WebhookEvent.changeset(%{status: "inactive"})
    |> Repo.update()
  end

  # ---------- Batch Ingestion ----------

  @max_batch_size 1000

  @doc """
  Ingest a batch of events for a project.

  Accepts up to #{@max_batch_size} events. Each event is validated individually;
  one bad event does not reject the entire batch.

  Returns `{:ok, %{accepted: N, rejected: N, events: [...]}}`.
  """
  def create_events_batch(project_id, events) when is_list(events) do
    if length(events) > @max_batch_size do
      {:error, :batch_too_large}
    else
      project = StreamflixCore.Platform.Projects.get_project(project_id)

      if project && !user_processing_allowed?(project.user_id) do
        {:error, :processing_restricted}
      else
        results = Enum.map(events, &process_single_batch_event(project_id, &1))

        accepted = Enum.count(results, &(&1.status == "accepted"))
        rejected = Enum.count(results, &(&1.status == "rejected"))

        {:ok, %{accepted: accepted, rejected: rejected, events: results}}
      end
    end
  end

  def create_events_batch(_project_id, _events), do: {:error, :invalid_payload}

  defp process_single_batch_event(project_id, event_map) when is_map(event_map) do
    case create_event(project_id, event_map) do
      {:ok, event} ->
        %{id: event.id, topic: event.topic, status: "accepted"}

      {:error, _reason} ->
        topic =
          Map.get(event_map, "topic") || Map.get(event_map, :topic)

        %{id: nil, topic: topic, status: "rejected"}
    end
  end

  defp process_single_batch_event(_project_id, _invalid) do
    %{id: nil, topic: nil, status: "rejected"}
  end

  # ---------- Delayed Events ----------

  def process_delayed_events() do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    events =
      from(e in WebhookEvent,
        as: :event,
        where: not is_nil(e.deliver_at) and e.deliver_at <= ^now and e.status == "active",
        where: not exists(from(d in Delivery, where: d.event_id == parent_as(:event).id))
      )
      |> Repo.all()

    Enum.each(events, fn event ->
      create_deliveries_for_event(event)
      broadcast(event.project_id, {:delayed_event_delivered, event})
    end)

    {:ok, length(events)}
  end

  # ---------- GDPR ----------

  @doc false
  def user_processing_allowed?(user_id) when is_binary(user_id) do
    case Repo.one(
           from(u in "users",
             where: u.id == type(^user_id, :binary_id),
             select: %{
               status: u.status,
               processing_consent: u.processing_consent
             }
           )
         ) do
      nil -> true
      %{status: "restricted"} -> false
      %{processing_consent: false} -> false
      _ -> true
    end
  end

  def user_processing_allowed?(_), do: true

  # ---------- Helpers ----------

  defp maybe_filter_active(query, true), do: query
  defp maybe_filter_active(query, false), do: where(query, [x], x.status == "active")

  @pubsub StreamflixCore.PubSub

  defp broadcast(project_id, message) do
    Phoenix.PubSub.broadcast(@pubsub, "project:#{project_id}", message)
  end
end
