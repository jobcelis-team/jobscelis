defmodule StreamflixCore.Platform do
  @moduledoc """
  Context for the Webhooks + Events platform: projects, API keys, events, webhooks, deliveries, jobs.
  All "delete" operations set status to inactive (soft delete).
  """
  import Ecto.Query
  alias StreamflixCore.Repo

  alias StreamflixCore.Schemas.{
    Project,
    ApiKey,
    Webhook,
    WebhookEvent,
    Delivery,
    Job,
    JobRun,
    DeadLetter,
    Replay,
    SandboxEndpoint,
    SandboxRequest,
    EventSchema,
    BatchItem
  }

  @cache :platform_cache
  @api_key_ttl :timer.seconds(60)
  @project_ttl :timer.seconds(120)
  @webhooks_ttl :timer.seconds(30)

  # ---------- Projects ----------

  def create_project(attrs) do
    user_id = attrs[:user_id] || attrs["user_id"]

    # First project for user auto-sets is_default
    is_default =
      if user_id do
        not Repo.exists?(
          from(p in Project, where: p.user_id == ^user_id and p.status == "active")
        )
      else
        false
      end

    attrs = Map.put(attrs, :is_default, Map.get(attrs, :is_default, is_default))

    case %Project{}
         |> Project.changeset(attrs)
         |> Repo.insert() do
      {:ok, project} ->
        # Auto-create owner membership
        if user_id do
          StreamflixCore.Teams.create_owner_member(project.id, user_id)
        end

        {:ok, project}

      error ->
        error
    end
  end

  def get_project(id), do: Repo.get(Project, id)
  def get_project!(id), do: Repo.get!(Project, id)

  def get_default_project_for_user(user_id) do
    cache_key = {:project_user, user_id}

    case Cachex.get(@cache, cache_key) do
      {:ok, nil} ->
        result =
          Project
          |> where([p], p.user_id == ^user_id and p.status == "active")
          |> order_by([p], desc: p.is_default, asc: p.inserted_at)
          |> limit(1)
          |> Repo.one()

        if result, do: Cachex.put(@cache, cache_key, result, ttl: @project_ttl)
        result

      {:ok, cached} ->
        cached
    end
  end

  def set_default_project(user_id, project_id) do
    Repo.transaction(fn ->
      # Unset all defaults for user
      from(p in Project, where: p.user_id == ^user_id and p.is_default == true)
      |> Repo.update_all(
        set: [
          is_default: false,
          updated_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
        ]
      )

      # Set target as default
      case Repo.get(Project, project_id) do
        nil ->
          Repo.rollback(:not_found)

        project ->
          project
          |> Project.changeset(%{is_default: true})
          |> Repo.update!()
      end
    end)
    |> case do
      {:ok, project} ->
        Cachex.del(@cache, {:project_user, user_id})
        {:ok, project}

      error ->
        error
    end
  end

  def delete_project(%Project{} = project) do
    case set_project_inactive(project) do
      {:ok, updated} ->
        # If deleted project was default, promote next one
        if project.is_default do
          next =
            Project
            |> where(
              [p],
              p.user_id == ^project.user_id and p.status == "active" and p.id != ^project.id
            )
            |> order_by([p], asc: p.inserted_at)
            |> limit(1)
            |> Repo.one()

          if next do
            next |> Project.changeset(%{is_default: true}) |> Repo.update()
          end
        end

        Cachex.del(@cache, {:project_user, project.user_id})
        {:ok, updated}

      error ->
        error
    end
  end

  def list_projects(opts \\ []) do
    include_inactive = Keyword.get(opts, :include_inactive, false)

    Project
    |> maybe_filter_active(:status, include_inactive)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  def list_projects_for_user(user_id, opts \\ []) do
    include_inactive = Keyword.get(opts, :include_inactive, false)

    Project
    |> where([p], p.user_id == ^user_id)
    |> maybe_filter_active(:status, include_inactive)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  def set_project_inactive(%Project{} = project) do
    update_project(project, %{status: "inactive"})
  end

  # ---------- API Keys ----------

  @prefix "wh_"
  @key_byte_length 32

  def create_api_key(project_id, attrs \\ %{}) do
    raw_key = generate_raw_api_key()
    prefix = String.slice(raw_key, 0, 12)
    key_hash = hash_api_key(raw_key)

    scopes = attrs["scopes"] || attrs[:scopes] || ["*"]
    allowed_ips = attrs["allowed_ips"] || attrs[:allowed_ips] || []

    case %ApiKey{}
         |> ApiKey.changeset(
           Map.merge(attrs, %{
             project_id: project_id,
             prefix: prefix,
             key_hash: key_hash,
             name: attrs["name"] || attrs[:name] || "Default",
             scopes: scopes,
             allowed_ips: allowed_ips
           })
         )
         |> Repo.insert() do
      {:ok, api_key} -> {:ok, api_key, raw_key}
      err -> err
    end
  end

  def verify_api_key(_prefix, raw_key) when is_binary(raw_key) do
    key_hash = hash_api_key(raw_key)
    cache_key = {:api_key, key_hash}

    case Cachex.get(@cache, cache_key) do
      {:ok, nil} ->
        result =
          ApiKey
          |> where([k], k.key_hash == ^key_hash and k.status == "active")
          |> join(:inner, [k], p in Project, on: p.id == k.project_id and p.status == "active")
          |> preload([k, p], project: p)
          |> Repo.one()

        if result, do: Cachex.put(@cache, cache_key, result, ttl: @api_key_ttl)
        result

      {:ok, cached} ->
        cached
    end
  end

  def get_api_key_for_project(project_id) do
    ApiKey
    |> where([k], k.project_id == ^project_id and k.status == "active")
    |> order_by([k], desc: k.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def regenerate_api_key(project_id) do
    # Preserve scopes and allowed_ips from current active key
    current_key = get_api_key_for_project(project_id)
    scopes = if current_key, do: current_key.scopes || ["*"], else: ["*"]
    allowed_ips = if current_key, do: current_key.allowed_ips || [], else: []

    # Deactivate existing keys for this project
    ApiKey
    |> where([k], k.project_id == ^project_id)
    |> Repo.update_all(
      set: [status: "inactive", updated_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)]
    )

    invalidate_api_key_cache()
    create_api_key(project_id, %{name: "Default", scopes: scopes, allowed_ips: allowed_ips})
  end

  defp generate_raw_api_key() do
    @prefix <> Base.url_encode64(:crypto.strong_rand_bytes(@key_byte_length), padding: false)
  end

  defp hash_api_key(raw) do
    :crypto.hash(:sha256, raw) |> Base.encode64(padding: false)
  end

  # ---------- Webhook Templates ----------

  @webhook_templates [
    %{
      id: "slack",
      name: "Slack",
      description: "Enviar a un canal de Slack via Incoming Webhook",
      body_config: %{
        "body_mode" => "custom",
        "template" => %{
          "text" => "Nuevo evento: {{topic}}",
          "blocks" => [
            %{
              "type" => "section",
              "text" => %{
                "type" => "mrkdwn",
                "text" => "*{{topic}}*\n```{{payload}}```"
              }
            }
          ]
        }
      },
      headers: %{"content-type" => "application/json"},
      url_placeholder: "https://hooks.slack.com/services/T.../B.../xxx"
    },
    %{
      id: "discord",
      name: "Discord",
      description: "Enviar a un canal de Discord via Webhook URL",
      body_config: %{
        "body_mode" => "custom",
        "template" => %{
          "content" => "Evento: {{topic}}",
          "embeds" => [
            %{
              "title" => "{{topic}}",
              "description" => "{{payload}}"
            }
          ]
        }
      },
      headers: %{"content-type" => "application/json"},
      url_placeholder: "https://discord.com/api/webhooks/ID/TOKEN"
    },
    %{
      id: "telegram",
      name: "Telegram Bot",
      description: "Enviar mensaje via Telegram Bot API",
      body_config: %{
        "body_mode" => "custom",
        "template" => %{
          "chat_id" => "{{CHAT_ID}}",
          "text" => "Evento {{topic}}: {{payload}}"
        }
      },
      headers: %{"content-type" => "application/json"},
      url_placeholder: "https://api.telegram.org/botTOKEN/sendMessage"
    },
    %{
      id: "generic",
      name: "Generic JSON",
      description: "Payload completo como JSON",
      body_config: %{"body_mode" => "full"},
      headers: %{"content-type" => "application/json"},
      url_placeholder: "https://your-endpoint.com/webhook"
    },
    %{
      id: "custom",
      name: "Custom",
      description: "Configurar manualmente",
      body_config: nil,
      headers: %{},
      url_placeholder: "https://your-endpoint.com/webhook"
    }
  ]

  def webhook_templates, do: @webhook_templates

  # ---------- Webhooks ----------

  def create_webhook(project_id, attrs) do
    attrs = Map.merge(attrs, %{"project_id" => project_id})

    case %Webhook{}
         |> Webhook.changeset(attrs)
         |> Repo.insert() do
      {:ok, webhook} ->
        Cachex.del(@cache, {:active_webhooks, project_id})
        {:ok, webhook}

      error ->
        error
    end
  end

  def list_webhooks(project_id, opts \\ []) do
    include_inactive = Keyword.get(opts, :include_inactive, false)

    Webhook
    |> where([w], w.project_id == ^project_id)
    |> maybe_filter_active(:status, include_inactive)
    |> order_by([w], desc: w.inserted_at)
    |> Repo.all()
  end

  def get_webhook(id), do: Repo.get(Webhook, id)
  def get_webhook!(id), do: Repo.get!(Webhook, id)

  def update_webhook(%Webhook{} = webhook, attrs) do
    case webhook
         |> Webhook.changeset(attrs)
         |> Repo.update() do
      {:ok, updated} ->
        Cachex.del(@cache, {:active_webhooks, webhook.project_id})
        {:ok, updated}

      error ->
        error
    end
  end

  def set_webhook_inactive(%Webhook{} = webhook) do
    update_webhook(webhook, %{status: "inactive"})
  end

  def list_active_webhooks_for_project(project_id) do
    cache_key = {:active_webhooks, project_id}

    case Cachex.get(@cache, cache_key) do
      {:ok, nil} ->
        result =
          Webhook
          |> where([w], w.project_id == ^project_id and w.status == "active")
          |> Repo.all()

        Cachex.put(@cache, cache_key, result, ttl: @webhooks_ttl)
        result

      {:ok, cached} ->
        cached
    end
  end

  # ---------- Events (webhook_events) ----------

  def create_event(project_id, body) when is_map(body) do
    # GDPR: check if project owner allows processing
    project = get_project(project_id)

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
    case validate_event_payload(project_id, topic, payload) do
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

  defp extract_topic_and_payload(body) do
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
    webhooks = list_active_webhooks_for_project(event.project_id)
    matching = Enum.filter(webhooks, &webhook_matches_event?(&1, event))

    Enum.each(matching, fn w ->
      batch_config = w.batch_config || %{}

      if batch_config["enabled"] == true do
        # Add to batch queue instead of immediate delivery
        %BatchItem{}
        |> BatchItem.changeset(%{webhook_id: w.id, event_id: event.id})
        |> Repo.insert()
      else
        case %Delivery{}
             |> Delivery.changeset(%{
               event_id: event.id,
               webhook_id: w.id,
               status: "pending",
               attempt_number: 0
             })
             |> Repo.insert() do
          {:ok, delivery} ->
            Oban.insert(
              StreamflixCore.Platform.ObanDeliveryWorker.new(%{delivery_id: delivery.id})
            )

          _ ->
            :ok
        end
      end
    end)

    :ok
  end

  def webhook_matches_event?(webhook, event) do
    topics_ok = topic_matches?(webhook.topics || [], event.topic)
    filters_ok = filters_match?(webhook.filters || [], event.topic, event.payload)
    topics_ok and filters_ok
  end

  defp topic_matches?([], _event_topic), do: true
  defp topic_matches?(_topics, nil), do: false

  defp topic_matches?(topics, event_topic) when is_list(topics) do
    event_topic in topics
  end

  defp filters_match?([], _topic, _payload), do: true

  defp filters_match?(filters, topic, payload) when is_list(filters) do
    combined = Map.put(payload || %{}, "topic", topic)
    Enum.all?(filters, fn f -> filter_condition_holds?(f, combined) end)
  end

  defp filters_match?(_, _, _), do: true

  defp filter_condition_holds?(%{"path" => path, "op" => op, "value" => value}, data) do
    actual = get_in(data, String.split(path, "."))

    case op do
      "eq" -> actual == value
      "neq" -> actual != value
      "gte" -> compare(actual, value, :gte)
      "lte" -> compare(actual, value, :lte)
      "gt" -> compare(actual, value, :gt)
      "lt" -> compare(actual, value, :lt)
      "in" when is_list(value) -> actual in value
      "not_in" when is_list(value) -> actual not in value
      "exists" -> exists?(actual, value)
      "contains" -> contains?(actual, value)
      _ -> true
    end
  end

  defp filter_condition_holds?(_, _), do: true

  defp exists?(actual, expect_true) do
    present = actual != nil && actual != ""
    if expect_true == true or expect_true == "true", do: present, else: not present
  end

  defp contains?(actual, value) when is_binary(actual) and is_binary(value),
    do: String.contains?(actual, value)

  defp contains?(actual, value) when is_list(actual), do: value in actual
  defp contains?(_, _), do: false

  defp compare(a, b, op) when is_number(a) and is_number(b) do
    case op do
      :gte -> a >= b
      :lte -> a <= b
      :gt -> a > b
      :lt -> a < b
      _ -> false
    end
  end

  defp compare(_, _, _), do: false

  def list_events(project_id, opts \\ []) do
    include_inactive = Keyword.get(opts, :include_inactive, false)
    limit = Keyword.get(opts, :limit, 50)
    topic = Keyword.get(opts, :topic)

    WebhookEvent
    |> where([e], e.project_id == ^project_id)
    |> maybe_filter_active(:status, include_inactive)
    |> maybe_filter_topic(topic)
    |> order_by([e], desc: e.occurred_at)
    |> limit(^limit)
    |> Repo.all()
  end

  defp maybe_filter_topic(query, nil), do: query
  defp maybe_filter_topic(query, topic), do: where(query, [e], e.topic == ^topic)

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

  # ---------- Deliveries ----------

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
    case get_delivery(delivery_id) do
      nil ->
        {:error, :not_found}

      d ->
        event = d.event || get_event(d.event_id)

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

  # ---------- Jobs ----------

  def create_job(project_id, attrs) do
    attrs = Map.merge(attrs, %{"project_id" => project_id})

    %Job{}
    |> Job.changeset(attrs)
    |> Repo.insert()
  end

  def list_jobs(project_id, opts \\ []) do
    include_inactive = Keyword.get(opts, :include_inactive, false)

    Job
    |> where([j], j.project_id == ^project_id)
    |> maybe_filter_active(:status, include_inactive)
    |> order_by([j], desc: j.inserted_at)
    |> Repo.all()
  end

  def get_job(id), do: Repo.get(Job, id)
  def get_job!(id), do: Repo.get!(Job, id)

  def update_job(%Job{} = job, attrs) do
    job
    |> Job.changeset(attrs)
    |> Repo.update()
  end

  def set_job_inactive(%Job{} = job) do
    update_job(job, %{status: "inactive"})
  end

  def list_jobs_to_run_now() do
    now = DateTime.utc_now()
    today_sec = now.hour * 3600 + now.minute * 60 + now.second
    date = DateTime.to_date(now)
    day_of_week = Date.day_of_week(date)
    day_of_month = date.day
    month = date.month
    minute = now.minute
    hour = now.hour

    Job
    |> where([j], j.status == "active")
    |> Repo.all()
    |> Enum.filter(fn j ->
      cfg = j.schedule_config || %{}
      type = j.schedule_type || "daily"

      case type do
        "daily" ->
          h = Map.get(cfg, "hour", 0)
          m = Map.get(cfg, "minute", 0)
          target_sec = h * 3600 + m * 60
          target_sec == today_sec or abs(target_sec - today_sec) < 60

        "weekly" ->
          dow = Map.get(cfg, "day_of_week")
          h = Map.get(cfg, "hour", 0)
          min_cfg = Map.get(cfg, "minute", 0)
          # day_of_week: 1=Mon..7=Sun (Calendar.ISO). Config can use 0-6 (Sun=0) or 1-7
          dow_ok = dow == nil or dow == day_of_week or (dow == 0 and day_of_week == 7)
          time_ok = h == hour and min_cfg == minute
          dow_ok and time_ok

        "monthly" ->
          dom = Map.get(cfg, "day_of_month")
          h = Map.get(cfg, "hour", 0)
          min_cfg = Map.get(cfg, "minute", 0)
          dom_ok = dom == nil or dom == day_of_month
          time_ok = h == hour and min_cfg == minute
          dom_ok and time_ok

        "cron" ->
          expr = Map.get(cfg, "expr") || Map.get(cfg, "expression")
          cron_matches?(expr, minute, hour, day_of_month, month, day_of_week)

        _ ->
          false
      end
    end)
  end

  defp cron_matches?(nil, _min, _h, _dom, _mon, _dow), do: false

  defp cron_matches?(expr, min, hour, day_of_month, month, day_of_week) when is_binary(expr) do
    parts = String.split(expr, ~r/\s+/, trim: true)

    if length(parts) >= 5 do
      [min_s, hour_s, dom_s, mon_s, dow_s] = Enum.take(parts, 5)

      cron_field_match?(min_s, min, 0, 59) and
        cron_field_match?(hour_s, hour, 0, 23) and
        cron_field_match?(dom_s, day_of_month, 1, 31) and
        cron_field_match?(mon_s, month, 1, 12) and
        cron_field_match?(dow_s, day_of_week, 1, 7)
    else
      false
    end
  end

  defp cron_matches?(_, _min, _h, _dom, _mon, _dow), do: false

  defp cron_field_match?("*", _val, _lo, _hi), do: true

  defp cron_field_match?(str, val, _lo, _hi) do
    case Integer.parse(str) do
      {n, _} -> n == val
      _ -> false
    end
  end

  @doc """
  Calculate next N execution times for a cron expression.
  Returns list of DateTime structs.
  """
  def next_cron_executions(cron_expr, count \\ 5) when is_binary(cron_expr) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    # Start from the next full minute
    start = DateTime.add(now, 60 - now.second, :second)

    Stream.iterate(start, fn dt -> DateTime.add(dt, 60, :second) end)
    |> Stream.filter(fn dt ->
      date = DateTime.to_date(dt)

      cron_matches?(
        cron_expr,
        dt.minute,
        dt.hour,
        date.day,
        date.month,
        Date.day_of_week(date)
      )
    end)
    |> Enum.take(count)
  end

  def list_job_runs(job_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    JobRun
    |> where([r], r.job_id == ^job_id)
    |> order_by([r], desc: r.executed_at)
    |> limit(^limit)
    |> Repo.all()
  end

  # ---------- Dead Letter Queue ----------

  def create_dead_letter(attrs) do
    %DeadLetter{}
    |> DeadLetter.changeset(attrs)
    |> Repo.insert()
  end

  def list_dead_letters(project_id, opts \\ []) do
    resolved = Keyword.get(opts, :resolved, false)
    limit = Keyword.get(opts, :limit, 50)

    DeadLetter
    |> where([dl], dl.project_id == ^project_id and dl.resolved == ^resolved)
    |> order_by([dl], desc: dl.inserted_at)
    |> limit(^limit)
    |> preload([:webhook, :event])
    |> Repo.all()
  end

  def get_dead_letter(id), do: Repo.get(DeadLetter, id) |> Repo.preload([:webhook, :event])

  def resolve_dead_letter(id) do
    case Repo.get(DeadLetter, id) do
      nil ->
        {:error, :not_found}

      dl ->
        dl
        |> DeadLetter.changeset(%{
          resolved: true,
          resolved_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
        })
        |> Repo.update()
    end
  end

  def retry_dead_letter(id, modified_payload \\ nil) do
    case Repo.get(DeadLetter, id) |> Repo.preload([:event, :webhook]) do
      nil ->
        {:error, :not_found}

      dl ->
        _payload = modified_payload || dl.original_payload
        webhook = dl.webhook

        if is_nil(webhook) or webhook.status == "inactive" do
          {:error, :webhook_inactive}
        else
          case %Delivery{}
               |> Delivery.changeset(%{
                 event_id: dl.event_id,
                 webhook_id: dl.webhook_id,
                 status: "pending",
                 attempt_number: 0
               })
               |> Repo.insert() do
            {:ok, delivery} ->
              Oban.insert(
                StreamflixCore.Platform.ObanDeliveryWorker.new(%{delivery_id: delivery.id})
              )

              resolve_dead_letter(id)
              {:ok, delivery}

            error ->
              error
          end
        end
    end
  end

  # ---------- Webhook Health Score ----------

  @doc "Calculate health score for a webhook based on last 24h deliveries"
  def webhook_health(webhook_id) do
    since = DateTime.utc_now() |> DateTime.add(-24, :hour) |> DateTime.truncate(:microsecond)

    stats =
      Repo.one(
        from(d in Delivery,
          where: d.webhook_id == ^webhook_id and d.inserted_at >= ^since,
          select: %{
            total: count(d.id),
            success: count(fragment("CASE WHEN ? = 'success' THEN 1 END", d.status)),
            failed: count(fragment("CASE WHEN ? = 'failed' THEN 1 END", d.status)),
            avg_latency: fragment("AVG(EXTRACT(EPOCH FROM ? - ?))", d.updated_at, d.inserted_at)
          }
        )
      )

    success_rate =
      if stats.total > 0,
        do: Float.round(stats.success / stats.total * 100, 1),
        else: 100.0

    score =
      cond do
        stats.total == 0 -> :no_data
        success_rate >= 98 -> :healthy
        success_rate >= 90 -> :degraded
        true -> :critical
      end

    %{
      score: score,
      success_rate: success_rate,
      total: stats.total,
      success: stats.success,
      failed: stats.failed,
      avg_latency: to_float_or_nil(stats.avg_latency)
    }
  end

  defp to_float_or_nil(nil), do: nil
  defp to_float_or_nil(%Decimal{} = d), do: d |> Decimal.to_float() |> Float.round(2)
  defp to_float_or_nil(f) when is_float(f), do: Float.round(f, 2)
  defp to_float_or_nil(i) when is_integer(i), do: i * 1.0

  @doc "Calculate health for all webhooks of a project"
  def webhooks_health(project_id) do
    webhooks = list_webhooks(project_id)

    Enum.map(webhooks, fn w ->
      {w.id, webhook_health(w.id)}
    end)
    |> Map.new()
  end

  # ---------- Webhook Simulator ----------

  @doc "Simulate an event: show which webhooks would match without sending"
  def simulate_event(project_id, body) when is_map(body) do
    {topic, payload} = extract_topic_and_payload(body)
    webhooks = list_active_webhooks_for_project(project_id)

    fake_event = %{
      topic: topic,
      payload: payload,
      id: "simulated",
      occurred_at: DateTime.utc_now()
    }

    matching = Enum.filter(webhooks, &webhook_matches_event?(&1, fake_event))

    Enum.map(matching, fn webhook ->
      body_to_send = build_webhook_body(webhook, fake_event)
      body_json = Jason.encode!(body_to_send)

      signature =
        if webhook.secret_encrypted && webhook.secret_encrypted != "" do
          sig =
            :crypto.mac(:hmac, :sha256, webhook.secret_encrypted, body_json)
            |> Base.encode64(padding: false)

          "sha256=#{sig}"
        else
          nil
        end

      %{
        webhook_id: webhook.id,
        webhook_url: webhook.url,
        would_send_body: body_to_send,
        would_send_headers: %{
          "content-type" => "application/json",
          "x-signature" => signature
        },
        matched_by_topics: topic in (webhook.topics || []) or webhook.topics == [],
        matched_by_filters: filters_match?(webhook.filters || [], topic, payload)
      }
    end)
  end

  def simulate_event(_project_id, _), do: {:error, :invalid_payload}

  # ---------- Event Replay ----------

  def create_replay(project_id, user_id, filters) do
    # Count matching events
    topic = filters["topic"]
    from_date = parse_replay_datetime(filters["from_date"])
    to_date = parse_replay_datetime(filters["to_date"])

    total = count_events_for_replay(project_id, topic, from_date, to_date)

    attrs = %{
      project_id: project_id,
      created_by: user_id,
      status: "pending",
      filters: filters,
      total_events: total
    }

    case %Replay{} |> Replay.changeset(attrs) |> Repo.insert() do
      {:ok, replay} ->
        Oban.insert(StreamflixCore.Platform.ObanReplayWorker.new(%{replay_id: replay.id}))
        {:ok, replay}

      error ->
        error
    end
  end

  def list_replays(project_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    Replay
    |> where([r], r.project_id == ^project_id)
    |> order_by([r], desc: r.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_replay(id), do: Repo.get(Replay, id)

  def cancel_replay(id) do
    case Repo.get(Replay, id) do
      nil ->
        {:error, :not_found}

      %{status: status} when status in ["completed", "cancelled", "failed"] ->
        {:error, :already_finished}

      replay ->
        replay
        |> Replay.changeset(%{status: "cancelled"})
        |> Repo.update()
    end
  end

  defp count_events_for_replay(project_id, topic, from_date, to_date) do
    query =
      WebhookEvent
      |> where([e], e.project_id == ^project_id and e.status == "active")

    query = if topic && topic != "", do: where(query, [e], e.topic == ^topic), else: query
    query = if from_date, do: where(query, [e], e.occurred_at >= ^from_date), else: query
    query = if to_date, do: where(query, [e], e.occurred_at <= ^to_date), else: query

    query
    |> select([e], count(e.id))
    |> Repo.one()
  end

  defp parse_replay_datetime(nil), do: nil
  defp parse_replay_datetime(""), do: nil

  defp parse_replay_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} ->
        DateTime.truncate(dt, :microsecond)

      _ ->
        case NaiveDateTime.from_iso8601(str) do
          {:ok, ndt} -> DateTime.from_naive!(ndt, "Etc/UTC") |> DateTime.truncate(:microsecond)
          _ -> nil
        end
    end
  end

  defp parse_replay_datetime(_), do: nil

  # ---------- Sandbox ----------

  def create_sandbox_endpoint(project_id, name \\ nil) do
    slug = generate_sandbox_slug()
    expires_at = DateTime.utc_now() |> DateTime.add(24, :hour) |> DateTime.truncate(:microsecond)

    %SandboxEndpoint{}
    |> SandboxEndpoint.changeset(%{
      project_id: project_id,
      slug: slug,
      name: name || "Sandbox #{slug}",
      expires_at: expires_at
    })
    |> Repo.insert()
  end

  def list_sandbox_endpoints(project_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    SandboxEndpoint
    |> where([s], s.project_id == ^project_id and s.expires_at > ^now)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  def get_sandbox_by_slug(slug) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    SandboxEndpoint
    |> where([s], s.slug == ^slug and s.expires_at > ^now)
    |> Repo.one()
  end

  def get_sandbox_endpoint(id), do: Repo.get(SandboxEndpoint, id)

  def delete_sandbox_endpoint(id) do
    case Repo.get(SandboxEndpoint, id) do
      nil -> {:error, :not_found}
      endpoint -> Repo.delete(endpoint)
    end
  end

  def record_sandbox_request(endpoint_id, attrs) do
    %SandboxRequest{}
    |> SandboxRequest.changeset(Map.put(attrs, :endpoint_id, endpoint_id))
    |> Repo.insert()
    |> case do
      {:ok, req} ->
        endpoint = Repo.get(SandboxEndpoint, endpoint_id) |> Repo.preload(:project)

        if endpoint do
          broadcast(endpoint.project_id, {:sandbox_request, req})
        end

        {:ok, req}

      error ->
        error
    end
  end

  def list_sandbox_requests(endpoint_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    SandboxRequest
    |> where([r], r.endpoint_id == ^endpoint_id)
    |> order_by([r], desc: r.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  defp generate_sandbox_slug() do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false) |> String.downcase()
  end

  # ---------- Analytics ----------

  @doc "Events per day for the last N days"
  def events_per_day(project_id, days \\ 30) do
    since = DateTime.utc_now() |> DateTime.add(-days, :day) |> DateTime.truncate(:microsecond)

    from(e in WebhookEvent,
      where: e.project_id == ^project_id and e.inserted_at >= ^since,
      group_by: fragment("DATE(?)", e.inserted_at),
      order_by: fragment("DATE(?)", e.inserted_at),
      select: %{date: fragment("DATE(?)", e.inserted_at), count: count(e.id)}
    )
    |> Repo.all()
  end

  @doc "Delivery stats (success vs failed) per day"
  def deliveries_per_day(project_id, days \\ 30) do
    since = DateTime.utc_now() |> DateTime.add(-days, :day) |> DateTime.truncate(:microsecond)

    from(d in Delivery,
      join: e in WebhookEvent,
      on: e.id == d.event_id,
      where: e.project_id == ^project_id and d.inserted_at >= ^since,
      group_by: fragment("DATE(?)", d.inserted_at),
      order_by: fragment("DATE(?)", d.inserted_at),
      select: %{
        date: fragment("DATE(?)", d.inserted_at),
        success: count(fragment("CASE WHEN ? = 'success' THEN 1 END", d.status)),
        failed: count(fragment("CASE WHEN ? = 'failed' THEN 1 END", d.status)),
        total: count(d.id)
      }
    )
    |> Repo.all()
  end

  @doc "Top topics by event volume"
  def top_topics(project_id, limit_count \\ 10) do
    from(e in WebhookEvent,
      where:
        e.project_id == ^project_id and e.status == "active" and not is_nil(e.topic) and
          e.topic != "",
      group_by: e.topic,
      order_by: [desc: count(e.id)],
      limit: ^limit_count,
      select: %{topic: e.topic, count: count(e.id)}
    )
    |> Repo.all()
  end

  @doc "Delivery stats per webhook (last 7 days)"
  def delivery_stats_by_webhook(project_id) do
    since = DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.truncate(:microsecond)

    from(d in Delivery,
      join: w in Webhook,
      on: w.id == d.webhook_id,
      where: w.project_id == ^project_id and d.inserted_at >= ^since,
      group_by: [w.id, w.url],
      select: %{
        webhook_id: w.id,
        webhook_url: w.url,
        total: count(d.id),
        success: count(fragment("CASE WHEN ? = 'success' THEN 1 END", d.status)),
        failed: count(fragment("CASE WHEN ? = 'failed' THEN 1 END", d.status))
      }
    )
    |> Repo.all()
  end

  # ---------- Event Schemas (B14) ----------

  def create_event_schema(project_id, attrs) do
    attrs = Map.merge(attrs, %{"project_id" => project_id})

    %EventSchema{}
    |> EventSchema.changeset(attrs)
    |> Repo.insert()
  end

  def list_event_schemas(project_id, opts \\ []) do
    include_inactive = Keyword.get(opts, :include_inactive, false)

    EventSchema
    |> where([s], s.project_id == ^project_id)
    |> maybe_filter_active(:status, include_inactive)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  def get_event_schema(id), do: Repo.get(EventSchema, id)

  def update_event_schema(%EventSchema{} = schema, attrs) do
    schema
    |> EventSchema.changeset(attrs)
    |> Repo.update()
  end

  def delete_event_schema(%EventSchema{} = schema) do
    update_event_schema(schema, %{status: "inactive"})
  end

  def validate_event_payload(project_id, topic, payload) do
    case topic do
      nil ->
        :ok

      "" ->
        :ok

      t ->
        schema_record =
          EventSchema
          |> where([s], s.project_id == ^project_id and s.topic == ^t and s.status == "active")
          |> order_by([s], desc: s.version)
          |> limit(1)
          |> Repo.one()

        case schema_record do
          nil ->
            :ok

          %{schema: json_schema} ->
            resolved = ExJsonSchema.Schema.resolve(json_schema)

            case ExJsonSchema.Validator.validate(resolved, payload) do
              :ok -> :ok
              {:error, errors} -> {:error, {:schema_validation, errors}}
            end
        end
    end
  end

  def dry_validate_event_payload(project_id, topic, payload) do
    validate_event_payload(project_id, topic, payload)
  end

  # ---------- Delayed Events (B10) ----------

  def process_delayed_events() do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    events =
      WebhookEvent
      |> where([e], not is_nil(e.deliver_at) and e.deliver_at <= ^now and e.status == "active")
      |> join(:left, [e], d in Delivery, on: d.event_id == e.id)
      |> group_by([e, d], e.id)
      |> having([e, d], count(d.id) == 0)
      |> select([e, d], e)
      |> Repo.all()

    Enum.each(events, fn event ->
      create_deliveries_for_event(event)
      broadcast(event.project_id, {:delayed_event_delivered, event})
    end)

    {:ok, length(events)}
  end

  # ---------- Helpers ----------

  defp maybe_filter_active(query, _field, true), do: query

  defp maybe_filter_active(query, field, false) do
    where(query, [x], field(x, ^field) == "active")
  end

  # ---------- Cache Invalidation ----------

  defp invalidate_api_key_cache() do
    Cachex.keys(@cache)
    |> then(fn
      {:ok, keys} -> keys
      _ -> []
    end)
    |> Enum.filter(fn
      {:api_key, _} -> true
      _ -> false
    end)
    |> Enum.each(&Cachex.del(@cache, &1))
  end

  # ---------- Cursor Pagination ----------

  @default_page_size 50
  @max_page_size 200

  @doc """
  Paginate events with cursor-based pagination.
  Returns %{data: [...], has_next: bool, next_cursor: string | nil}
  Cursor is the ID of the last item in the current page.
  """
  def paginate_events(project_id, opts \\ []) do
    limit = parse_limit(opts)
    cursor = Keyword.get(opts, :cursor)
    topic = Keyword.get(opts, :topic)

    query =
      WebhookEvent
      |> where([e], e.project_id == ^project_id and e.status == "active")
      |> maybe_filter_topic(topic)
      |> order_by([e], desc: e.occurred_at, desc: e.id)

    query = apply_cursor(query, cursor, :occurred_at)

    items = query |> limit(^(limit + 1)) |> Repo.all()
    build_page(items, limit)
  end

  @doc "Paginate deliveries with cursor-based pagination."
  def paginate_deliveries(opts \\ []) do
    limit = parse_limit(opts)
    cursor = Keyword.get(opts, :cursor)
    project_id = Keyword.get(opts, :project_id)
    status = Keyword.get(opts, :status)
    webhook_id = Keyword.get(opts, :webhook_id)

    query =
      Delivery
      |> maybe_where(:status, status)
      |> maybe_where(:webhook_id, webhook_id)
      |> order_by([d], desc: d.inserted_at, desc: d.id)

    query =
      if project_id do
        event_ids = from(e in WebhookEvent, where: e.project_id == ^project_id, select: e.id)
        where(query, [d], d.event_id in subquery(event_ids))
      else
        query
      end

    query = apply_cursor(query, cursor, :inserted_at)

    items = query |> limit(^(limit + 1)) |> preload([:event, :webhook]) |> Repo.all()
    build_page(items, limit)
  end

  defp apply_cursor(query, nil, _field), do: query

  defp apply_cursor(query, cursor, field) do
    case Repo.get(
           query
           |> exclude(:order_by)
           |> exclude(:limit)
           |> limit(1)
           |> where([x], x.id == ^cursor),
           cursor
         ) do
      nil ->
        query

      record ->
        cursor_val = Map.get(record, field)

        where(
          query,
          [x],
          field(x, ^field) < ^cursor_val or (field(x, ^field) == ^cursor_val and x.id < ^cursor)
        )
    end
  end

  defp parse_limit(opts) do
    limit = Keyword.get(opts, :limit, @default_page_size)
    min(max(limit, 1), @max_page_size)
  end

  defp build_page(items, limit) do
    has_next = length(items) > limit
    data = Enum.take(items, limit)
    next_cursor = if has_next and data != [], do: List.last(data).id, else: nil

    %{data: data, has_next: has_next, next_cursor: next_cursor}
  end

  # ---------- PubSub ----------

  @pubsub StreamflixCore.PubSub

  @doc "Subscribe to real-time updates for a project"
  def subscribe(project_id) do
    Phoenix.PubSub.subscribe(@pubsub, "project:#{project_id}")
  end

  defp broadcast(project_id, message) do
    Phoenix.PubSub.broadcast(@pubsub, "project:#{project_id}", message)
  end

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
end
