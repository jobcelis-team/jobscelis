defmodule StreamflixCore.Platform.Events do
  @moduledoc """
  Event management: create, list, idempotency, delayed events, schema validation.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{WebhookEvent, Delivery, BatchItem}

  def create_event(project_id, body) when is_map(body) do
    # GDPR: the project owner must allow processing
    if processing_allowed_for_project?(project_id) do
      create_allowed_event(project_id, body)
    else
      {:error, :processing_restricted}
    end
  end

  def create_event(_project_id, _), do: {:error, :invalid_payload}

  defp create_allowed_event(project_id, body) do
    # Extract idempotency_key before topic/payload extraction
    idempotency_key = Map.get(body, "idempotency_key") || Map.get(body, :idempotency_key)

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

  defp do_create_event(project_id, body, idempotency_key) do
    with {:ok, attrs, deliver_now?} <- prepare_event(project_id, body, idempotency_key) do
      ctx = fanout_context(project_id)

      # The event, its deliveries and their jobs are written in one transaction:
      # a failure can no longer leave a delivery "pending" with no job.
      result =
        Repo.transaction(fn ->
          case %WebhookEvent{} |> WebhookEvent.changeset(attrs) |> Repo.insert() do
            {:ok, event} ->
              if deliver_now?, do: insert_fanout([event], ctx)
              event

            {:error, changeset} ->
              Repo.rollback(changeset)
          end
        end)

      with {:ok, event} <- result do
        StreamflixCore.TelemetryEvents.event_created(project_id, event.topic)
        broadcast(project_id, {:event_created, event})
        {:ok, event}
      end
    end
  end

  # Validates the body and builds the event attributes (no writes).
  defp prepare_event(project_id, body, idempotency_key) do
    {topic, payload} = extract_topic_and_payload(body)

    case StreamflixCore.Platform.EventSchemas.validate_event_payload(project_id, topic, payload) do
      :ok ->
        # deliver_at was validated by the caller
        {:ok, deliver_at} = parse_deliver_at(body)
        occurred_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)
        deliver_now? = is_nil(deliver_at) or DateTime.compare(deliver_at, occurred_at) != :gt

        attrs = %{
          project_id: project_id,
          topic: topic,
          payload: payload,
          status: "active",
          occurred_at: occurred_at,
          deliver_at: deliver_at,
          # A past deliver_at is dispatched right away: keep the delayed worker off it
          dispatched_at: if(deliver_at && deliver_now?, do: occurred_at),
          payload_hash:
            payload
            |> Jason.encode!()
            |> then(&:crypto.hash(:sha256, &1))
            |> Base.encode16(case: :lower),
          idempotency_key: idempotency_key
        }

        {:ok, attrs, deliver_now?}

      {:error, _} = error ->
        error
    end
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

  # Rows per insert_all statement (PostgreSQL allows 65535 parameters)
  @insert_chunk 2_000

  # Active webhooks and pipelines of the project. Read before the transaction:
  # the cache loads misses in another process, which must not wait for the
  # connection the transaction holds.
  defp fanout_context(project_id) do
    alias StreamflixCore.Platform.{Pipelines, Webhooks}

    webhooks = Webhooks.list_active_webhooks_for_project(project_id)
    webhooks_by_id = Map.new(webhooks, &{&1.id, &1})

    pipelines =
      project_id
      |> Pipelines.active_pipelines()
      |> Enum.filter(&Map.has_key?(webhooks_by_id, &1.webhook_id))

    %{webhooks: webhooks, webhooks_by_id: webhooks_by_id, pipelines: pipelines}
  end

  # Creates the deliveries (and their delivery jobs) and batch items for events
  # of one project, in a few statements instead of one per delivery. Runs inside
  # the caller's transaction and only writes.
  defp insert_fanout([], _ctx), do: :ok

  defp insert_fanout(events, %{
         webhooks: webhooks,
         webhooks_by_id: webhooks_by_id,
         pipelines: pipelines
       }) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    {deliveries, jobs, batch_items} =
      Enum.reduce(events, {[], [], []}, fn event, acc ->
        plan_event_fanout(event, webhooks, webhooks_by_id, pipelines, now, acc)
      end)

    deliveries |> Enum.reverse() |> insert_rows(Delivery)
    batch_items |> Enum.reverse() |> insert_rows(BatchItem)

    jobs
    |> Enum.reverse()
    |> Enum.chunk_every(@insert_chunk)
    |> Enum.each(&Oban.insert_all/1)

    :ok
  end

  # Pipelines whose topics match and whose target webhook is active take over
  # delivery for that webhook: the event goes through the pipeline steps instead.
  defp plan_event_fanout(event, webhooks, webhooks_by_id, pipelines, now, acc) do
    alias StreamflixCore.Platform.{Pipelines, Webhooks}

    matching = Enum.filter(pipelines, &Webhooks.topic_matches?(&1.topics || [], event.topic))
    piped_webhook_ids = MapSet.new(matching, & &1.webhook_id)

    acc =
      webhooks
      |> Enum.reject(&MapSet.member?(piped_webhook_ids, &1.id))
      |> Enum.filter(&Webhooks.webhook_matches_event?(&1, event))
      |> Enum.reduce(acc, fn webhook, {deliveries, jobs, items} ->
        if (webhook.batch_config || %{})["enabled"] == true do
          # Added to the webhook's batch queue instead of delivered now
          item = %{
            id: Ecto.UUID.generate(),
            webhook_id: webhook.id,
            event_id: event.id,
            inserted_at: now
          }

          {deliveries, jobs, [item | items]}
        else
          {d, j} = planned_delivery(event, webhook, nil, 0, now)
          {[d | deliveries], [j | jobs], items}
        end
      end)

    Enum.reduce(matching, acc, fn pipeline, {deliveries, jobs, items} = acc ->
      case Pipelines.execute_steps(pipeline.steps || [], event.payload || %{}) do
        {:ok, payload} ->
          override = if payload == event.payload, do: nil, else: payload
          delay = Pipelines.total_delay_seconds(pipeline.steps)
          webhook = webhooks_by_id[pipeline.webhook_id]
          {d, j} = planned_delivery(event, webhook, override, delay, now)
          {[d | deliveries], [j | jobs], items}

        {:filtered, _reason} ->
          acc
      end
    end)
  end

  defp planned_delivery(event, webhook, payload_override, delay_seconds, now) do
    id = Ecto.UUID.generate()

    delivery = %{
      id: id,
      event_id: event.id,
      webhook_id: webhook.id,
      status: "pending",
      attempt_number: 0,
      payload_override: payload_override,
      inserted_at: now,
      updated_at: now
    }

    job_opts = if delay_seconds > 0, do: [schedule_in: delay_seconds], else: []

    job =
      StreamflixCore.Platform.ObanDeliveryWorker.new(
        %{delivery_id: id, retry_config: webhook.retry_config || %{}},
        job_opts
      )

    {delivery, job}
  end

  defp insert_rows([], _schema), do: :ok

  defp insert_rows(rows, schema) do
    rows
    |> Enum.chunk_every(@insert_chunk)
    |> Enum.each(&Repo.insert_all(schema, &1))
  end

  # Fan-out for one event outside a request (delayed events).
  defp create_deliveries_for_event(event) do
    ctx = fanout_context(event.project_id)
    {:ok, :ok} = Repo.transaction(fn -> insert_fanout([event], ctx) end)
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

  # 1000 is the documented API contract (docs, SDK READMEs). Batches no longer
  # amplify throughput: EventRateLimit counts every item against events/minute.
  @default_max_batch_size 1000

  @doc "Max events accepted in one batch (config `:max_event_batch_size`)."
  def max_batch_size,
    do: Application.get_env(:streamflix_core, :max_event_batch_size, @default_max_batch_size)

  @doc """
  Ingest a batch of events for a project.

  Accepts up to `max_batch_size/0` events. Each event is validated individually;
  one bad event does not reject the entire batch.

  Returns `{:ok, %{accepted: N, rejected: N, events: [...]}}`.
  """
  def create_events_batch(project_id, events) when is_list(events) do
    cond do
      length(events) > max_batch_size() -> {:error, :batch_too_large}
      not processing_allowed_for_project?(project_id) -> {:error, :processing_restricted}
      true -> {:ok, insert_batch(project_id, events)}
    end
  end

  def create_events_batch(_project_id, _events), do: {:error, :invalid_payload}

  # Validates every item in memory, then writes the new events, their
  # deliveries and delivery jobs in one transaction with a few statements,
  # instead of ~10 queries per event. Results keep the request order.
  defp insert_batch(project_id, events) do
    prepared = Enum.map(events, &prepare_batch_item(project_id, &1))
    existing = existing_by_key(project_id, prepared)
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    # A key already stored, or used earlier in this batch, returns that event
    {plan, _seen} =
      Enum.map_reduce(prepared, existing, fn
        {:rejected, topic}, seen ->
          {{:rejected, topic}, seen}

        {:ok, attrs, deliver_now?}, seen ->
          key = attrs.idempotency_key

          if key && Map.has_key?(seen, key) do
            {{:existing, seen[key]}, seen}
          else
            event = new_event(attrs, now)
            {{:new, event, deliver_now?}, if(key, do: Map.put(seen, key, event), else: seen)}
          end
      end)

    new_events = for {:new, event, _} <- plan, do: event
    to_deliver = for {:new, event, true} <- plan, do: event

    case write_batch(new_events, to_deliver, fanout_context(project_id)) do
      :ok ->
        Enum.each(new_events, fn event ->
          StreamflixCore.TelemetryEvents.event_created(project_id, event.topic)
          broadcast(project_id, {:event_created, event})
        end)

        batch_result(plan)

      # A concurrent request stored one of the idempotency keys first: fall
      # back to one transaction per event, which resolves it like create_event
      :conflict ->
        batch_result(Enum.map(events, &process_single_batch_event(project_id, &1)))
    end
  end

  defp prepare_batch_item(project_id, item) when is_map(item) do
    topic = Map.get(item, "topic") || Map.get(item, :topic)
    key = Map.get(item, "idempotency_key") || Map.get(item, :idempotency_key)

    with true <- is_nil(key) or (is_binary(key) and key != ""),
         {:ok, _} <- parse_deliver_at(item),
         {:ok, attrs, deliver_now?} <- prepare_event(project_id, item, key),
         true <- WebhookEvent.changeset(%WebhookEvent{}, attrs).valid? do
      {:ok, attrs, deliver_now?}
    else
      _ -> {:rejected, topic}
    end
  end

  defp prepare_batch_item(_project_id, _item), do: {:rejected, nil}

  defp existing_by_key(project_id, prepared) do
    keys = for({:ok, %{idempotency_key: k}, _} <- prepared, k != nil, do: k) |> Enum.uniq()

    if keys == [] do
      %{}
    else
      from(e in WebhookEvent, where: e.project_id == ^project_id and e.idempotency_key in ^keys)
      |> Repo.all()
      |> Map.new(&{&1.idempotency_key, &1})
    end
  end

  defp new_event(attrs, now) do
    %WebhookEvent{}
    |> Map.merge(attrs)
    |> Map.merge(%{id: Ecto.UUID.generate(), inserted_at: now, updated_at: now})
    |> Ecto.put_meta(state: :loaded)
  end

  @event_columns ~w(id project_id topic payload status occurred_at deliver_at dispatched_at
                    payload_hash idempotency_key inserted_at updated_at)a

  defp write_batch([], _to_deliver, _ctx), do: :ok

  defp write_batch(new_events, to_deliver, ctx) do
    {:ok, :ok} =
      Repo.transaction(fn ->
        new_events |> Enum.map(&Map.take(&1, @event_columns)) |> insert_rows(WebhookEvent)
        insert_fanout(to_deliver, ctx)
      end)

    :ok
  rescue
    e in Postgrex.Error ->
      if e.postgres[:code] == :unique_violation, do: :conflict, else: reraise(e, __STACKTRACE__)
  end

  defp batch_result(plan) do
    results =
      Enum.map(plan, fn
        {:new, event, _} -> %{id: event.id, topic: event.topic, status: "accepted"}
        {:existing, event} -> %{id: event.id, topic: event.topic, status: "accepted"}
        {:rejected, topic} -> %{id: nil, topic: topic, status: "rejected"}
        %{} = result -> result
      end)

    %{
      accepted: Enum.count(results, &(&1.status == "accepted")),
      rejected: Enum.count(results, &(&1.status == "rejected")),
      events: results
    }
  end

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

  @cache :platform_cache
  # Owner and consent rarely change and are read for every event and delivery
  @owner_ttl :timer.minutes(5)
  @processing_ttl :timer.seconds(60)

  @doc """
  Whether the owner of the project allows processing (GDPR restriction and
  objection). Cached; `invalidate_processing_cache/1` clears it when the owner
  changes their status or consent.
  """
  def processing_allowed_for_project?(project_id) do
    case project_owner_id(project_id) do
      nil -> true
      user_id -> user_processing_allowed?(user_id)
    end
  end

  defp project_owner_id(project_id) do
    fetch_cached({:project_owner, project_id}, @owner_ttl, fn ->
      Repo.one(
        from(p in StreamflixCore.Schemas.Project, where: p.id == ^project_id, select: p.user_id)
      )
    end)
  end

  @doc false
  def user_processing_allowed?(user_id) when is_binary(user_id) do
    fetch_cached({:processing_allowed, user_id}, @processing_ttl, fn ->
      case Repo.one(
             from(u in "users",
               where: u.id == type(^user_id, :binary_id),
               select: %{status: u.status, processing_consent: u.processing_consent}
             )
           ) do
        nil -> true
        %{status: "restricted"} -> false
        %{processing_consent: false} -> false
        _ -> true
      end
    end)
  end

  def user_processing_allowed?(_), do: true

  @doc "Clears the cached processing permission of a user."
  def invalidate_processing_cache(user_id) when is_binary(user_id) do
    Cachex.del(@cache, {:processing_allowed, user_id})
    :ok
  end

  def invalidate_processing_cache(_), do: :ok

  # nil is cached too (as :none), so a missing row is not looked up every time
  defp fetch_cached(key, ttl, fun) do
    case Cachex.fetch(@cache, key, fn _ -> {:commit, wrap_nil(fun.()), expire: ttl} end) do
      {status, value} when status in [:ok, :commit] -> unwrap_nil(value)
      _ -> fun.()
    end
  end

  defp wrap_nil(nil), do: :none
  defp wrap_nil(value), do: value
  defp unwrap_nil(:none), do: nil
  defp unwrap_nil(value), do: value

  # ---------- Helpers ----------

  defp maybe_filter_active(query, true), do: query
  defp maybe_filter_active(query, false), do: where(query, [x], x.status == "active")

  @pubsub StreamflixCore.PubSub

  defp broadcast(project_id, message) do
    Phoenix.PubSub.broadcast(@pubsub, "project:#{project_id}", message)
  end
end
