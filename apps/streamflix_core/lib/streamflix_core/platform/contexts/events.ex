defmodule StreamflixCore.Platform.Events do
  @moduledoc """
  Event management: create, list, idempotency, delayed events, schema validation.
  """
  import Ecto.Query
  require Logger
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
      cond do
        not (is_nil(idempotency_key) or (is_binary(idempotency_key) and idempotency_key != "")) ->
          {:error, :invalid_idempotency_key}

        match?({:error, _}, parse_deliver_at(body)) ->
          {:error, :invalid_deliver_at}

        idempotency_key ->
          case Repo.one(
                 from(e in WebhookEvent,
                   where: e.project_id == ^project_id and e.idempotency_key == ^idempotency_key
                 )
               ) do
            %WebhookEvent{} = existing -> {:ok, existing}
            nil -> do_create_event(project_id, body, idempotency_key)
          end

        true ->
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

    # Parse deliver_at for delayed events (already validated in create_event/2)
    {:ok, deliver_at} = parse_deliver_at(body)

    # Compute SHA256 hash of canonical payload
    payload_hash =
      :crypto.hash(:sha256, Jason.encode!(payload))
      |> Base.encode16(case: :lower)

    deliver_now? =
      is_nil(deliver_at) or DateTime.compare(deliver_at, DateTime.utc_now()) != :gt

    attrs = %{
      project_id: project_id,
      topic: topic,
      payload: payload,
      status: "active",
      occurred_at: occurred_at,
      deliver_at: deliver_at,
      # A past deliver_at is dispatched right away: keep the delayed worker off it
      dispatched_at: if(deliver_at && deliver_now?, do: occurred_at),
      payload_hash: payload_hash,
      idempotency_key: idempotency_key
    }

    with {:ok, event} <- insert_event(attrs) do
      # Skip immediate delivery if future deliver_at
      if deliver_now? do
        create_deliveries_for_event(event)
      end

      StreamflixCore.TelemetryEvents.event_created(project_id, topic)
      broadcast(project_id, {:event_created, event})
      {:ok, event}
    end
  catch
    {:error, {:schema_validation, _errors}} = err -> err
  end

  # An unparseable deliver_at is an error: silently ignoring it would deliver a
  # scheduled event immediately.
  defp parse_deliver_at(body) do
    case Map.get(body, "deliver_at") || Map.get(body, :deliver_at) do
      nil -> {:ok, nil}
      str when is_binary(str) -> parse_iso_datetime(str)
      _ -> {:error, :invalid_deliver_at}
    end
  end

  defp parse_iso_datetime(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} ->
        {:ok, DateTime.truncate(dt, :microsecond)}

      # Timestamps without offset (e.g. Python's naive isoformat()) are treated as UTC
      {:error, :missing_offset} ->
        case NaiveDateTime.from_iso8601(str) do
          {:ok, naive} ->
            {:ok, naive |> DateTime.from_naive!("Etc/UTC") |> DateTime.truncate(:microsecond)}

          _ ->
            {:error, :invalid_deliver_at}
        end

      _ ->
        {:error, :invalid_deliver_at}
    end
  end

  # Request-level control fields: they configure the event, they are not part of its payload.
  @control_fields ~w(topic deliver_at idempotency_key)

  @doc false
  def extract_topic_and_payload(body) do
    string_body = Map.new(body, fn {k, v} -> {to_string(k), v} end)

    case Map.get(string_body, "topic") do
      t when is_binary(t) ->
        {t, unwrap_envelope(Map.drop(string_body, @control_fields))}

      _ ->
        {nil, unwrap_envelope(Map.drop(string_body, @control_fields -- ["topic"]))}
    end
  end

  # The SDKs and the CLI send {"topic": ..., "payload": {...}}, while raw API calls send the
  # fields flat. Accept both: a body whose only field is a "payload" object is that object.
  defp unwrap_envelope(%{"payload" => payload} = body)
       when is_map(payload) and map_size(body) == 1,
       do: payload

  defp unwrap_envelope(body), do: body

  defp insert_event(attrs) do
    %WebhookEvent{}
    |> WebhookEvent.changeset(attrs)
    |> Repo.insert()
  end

  defp create_deliveries_for_event(event) do
    alias StreamflixCore.Platform.{Pipelines, Webhooks}

    webhooks = Webhooks.list_active_webhooks_for_project(event.project_id)
    webhooks_by_id = Map.new(webhooks, &{&1.id, &1})

    # Pipelines whose topics match and whose target webhook is active take over
    # delivery for that webhook: the event goes through the pipeline steps instead.
    pipelines =
      event.project_id
      |> Pipelines.matching_pipelines(event.topic)
      |> Enum.filter(&Map.has_key?(webhooks_by_id, &1.webhook_id))

    piped_webhook_ids = MapSet.new(pipelines, & &1.webhook_id)

    webhooks
    |> Enum.reject(&MapSet.member?(piped_webhook_ids, &1.id))
    |> Enum.filter(&Webhooks.webhook_matches_event?(&1, event))
    |> Enum.each(&deliver_direct(event, &1))

    Enum.each(pipelines, &deliver_through_pipeline(event, &1, webhooks_by_id[&1.webhook_id]))

    :ok
  end

  defp deliver_direct(event, webhook) do
    batch_config = webhook.batch_config || %{}

    if batch_config["enabled"] == true do
      # Add to batch queue instead of immediate delivery
      %BatchItem{}
      |> BatchItem.changeset(%{webhook_id: webhook.id, event_id: event.id})
      |> Repo.insert()
    else
      enqueue_delivery(event, webhook, nil, 0)
    end
  end

  defp deliver_through_pipeline(event, pipeline, webhook) do
    alias StreamflixCore.Platform.Pipelines

    case Pipelines.execute_steps(pipeline.steps || [], event.payload || %{}) do
      {:ok, payload} ->
        override = if payload == event.payload, do: nil, else: payload
        enqueue_delivery(event, webhook, override, Pipelines.total_delay_seconds(pipeline.steps))

      {:filtered, _reason} ->
        :skipped
    end
  end

  defp enqueue_delivery(event, webhook, payload_override, delay_seconds) do
    alias StreamflixCore.Schemas.Delivery, as: DeliverySchema

    case %DeliverySchema{}
         |> DeliverySchema.changeset(%{
           event_id: event.id,
           webhook_id: webhook.id,
           status: "pending",
           attempt_number: 0,
           payload_override: payload_override
         })
         |> Repo.insert() do
      {:ok, delivery} ->
        job_opts = if delay_seconds > 0, do: [schedule_in: delay_seconds], else: []

        %{delivery_id: delivery.id, retry_config: webhook.retry_config || %{}}
        |> StreamflixCore.Platform.ObanDeliveryWorker.new(job_opts)
        |> Oban.insert()

      {:error, changeset} ->
        Logger.error("Failed to create delivery",
          event_id: event.id,
          webhook_id: webhook.id,
          error: inspect(changeset.errors)
        )

        {:error, changeset}
    end
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

  @doc "Number of active events of a project that occurred since the given datetime."
  def count_events_since(project_id, %DateTime{} = since) do
    WebhookEvent
    |> where([e], e.project_id == ^project_id and e.status == "active")
    |> where([e], e.occurred_at >= ^since)
    |> Repo.aggregate(:count)
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

  @doc """
  Dashboard search: an exact event ID, or a case-insensitive partial topic match
  over all of the project's active events (not only the most recent ones).
  """
  def search_events_by_text(project_id, text, limit \\ 50) when is_binary(text) do
    base =
      WebhookEvent
      |> where([e], e.project_id == ^project_id and e.status == "active")
      |> order_by([e], desc: e.occurred_at)
      |> limit(^limit)

    case Ecto.UUID.cast(text) do
      {:ok, id} ->
        base |> where([e], e.id == ^id) |> Repo.all()

      :error ->
        pattern = "%" <> String.replace(text, ["\\", "%", "_"], &("\\" <> &1)) <> "%"
        base |> where([e], ilike(e.topic, ^pattern)) |> Repo.all()
    end
  end

  def get_event(id), do: Repo.get_uuid(WebhookEvent, id)
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
        where: is_nil(e.dispatched_at),
        where: not exists(from(d in Delivery, where: d.event_id == parent_as(:event).id))
      )
      |> Repo.all()

    dispatched =
      Enum.count(events, fn event ->
        # Claim the event first: events matching no webhook (or batch-only
        # webhooks) produce no Delivery rows and would otherwise be re-processed
        # on every run. The conditional update also prevents double dispatch.
        {claimed, _} =
          from(e in WebhookEvent, where: e.id == ^event.id and is_nil(e.dispatched_at))
          |> Repo.update_all(set: [dispatched_at: now])

        if claimed == 1 do
          create_deliveries_for_event(event)
          broadcast(event.project_id, {:delayed_event_delivered, event})
          true
        else
          false
        end
      end)

    {:ok, dispatched}
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
