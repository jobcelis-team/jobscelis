defmodule StreamflixCore.Platform do
  @moduledoc """
  Context for the Webhooks + Events platform: projects, API keys, events, webhooks, deliveries, jobs.
  All "delete" operations set status to inactive (soft delete).
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{Project, ApiKey, Webhook, WebhookEvent, Delivery, Job, JobRun}

  # ---------- Projects ----------

  def create_project(attrs) do
    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert()
  end

  def get_project(id), do: Repo.get(Project, id)
  def get_project!(id), do: Repo.get!(Project, id)

  def get_project_by_user_id(user_id) do
    Repo.get_by(Project, user_id: user_id, status: "active")
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

    case %ApiKey{}
         |> ApiKey.changeset(Map.merge(attrs, %{
           project_id: project_id,
           prefix: prefix,
           key_hash: key_hash,
           name: attrs["name"] || attrs[:name] || "Default"
         }))
         |> Repo.insert() do
      {:ok, api_key} -> {:ok, api_key, raw_key}
      err -> err
    end
  end

  def verify_api_key(_prefix, raw_key) when is_binary(raw_key) do
    key_hash = hash_api_key(raw_key)
    ApiKey
    |> where([k], k.key_hash == ^key_hash and k.status == "active")
    |> join(:inner, [k], p in Project, on: p.id == k.project_id and p.status == "active")
    |> preload([k, p], [project: p])
    |> Repo.one()
  end

  def get_api_key_for_project(project_id) do
    ApiKey
    |> where([k], k.project_id == ^project_id and k.status == "active")
    |> order_by([k], desc: k.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def regenerate_api_key(project_id) do
    # Deactivate existing keys for this project
    ApiKey
    |> where([k], k.project_id == ^project_id)
    |> Repo.update_all(set: [status: "inactive", updated_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)])

    create_api_key(project_id, %{name: "Default"})
  end

  def set_api_key_inactive(%ApiKey{} = key) do
    key
    |> ApiKey.changeset(%{status: "inactive"})
    |> Repo.update()
  end

  defp generate_raw_api_key do
    @prefix <> Base.url_encode64(:crypto.strong_rand_bytes(@key_byte_length), padding: false)
  end

  defp hash_api_key(raw) do
    :crypto.hash(:sha256, raw) |> Base.encode64(padding: false)
  end

  # ---------- Webhooks ----------

  def create_webhook(project_id, attrs) do
    attrs = Map.merge(attrs, %{"project_id" => project_id})
    %Webhook{}
    |> Webhook.changeset(attrs)
    |> Repo.insert()
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
    webhook
    |> Webhook.changeset(attrs)
    |> Repo.update()
  end

  def set_webhook_inactive(%Webhook{} = webhook) do
    update_webhook(webhook, %{status: "inactive"})
  end

  def list_active_webhooks_for_project(project_id) do
    Webhook
    |> where([w], w.project_id == ^project_id and w.status == "active")
    |> Repo.all()
  end

  # ---------- Events (webhook_events) ----------

  def create_event(project_id, body) when is_map(body) do
    {topic, payload} = extract_topic_and_payload(body)
    occurred_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    attrs = %{
      project_id: project_id,
      topic: topic,
      payload: payload,
      status: "active",
      occurred_at: occurred_at
    }

    with {:ok, event} <- insert_event(attrs),
         :ok <- create_deliveries_for_event(event) do
      {:ok, event}
    end
  end

  def create_event(_project_id, _), do: {:error, :invalid_payload}

  defp extract_topic_and_payload(body) do
    case Map.get(body, "topic") || Map.get(body, :topic) do
      nil -> {nil, body}
      t when is_binary(t) -> {t, Map.delete(Map.new(body, fn {k, v} -> {to_string(k), v} end), "topic")}
      _ -> {nil, body}
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
      case %Delivery{}
           |> Delivery.changeset(%{
             event_id: event.id,
             webhook_id: w.id,
             status: "pending",
             attempt_number: 0
           })
           |> Repo.insert() do
        {:ok, delivery} ->
          Oban.insert(StreamflixCore.Platform.ObanDeliveryWorker.new(%{delivery_id: delivery.id}))
        _ ->
          :ok
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
      _ -> true
    end
  end
  defp filter_condition_holds?(_, _), do: true

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
  defp maybe_where_event_in_subquery(query, event_ids_query), do: where(query, [d], d.event_id in subquery(event_ids_query))

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

  def build_webhook_body(webhook, event) do
    config = webhook.body_config || %{}
    mode = config["body_mode"] || "full"
    payload = event.payload || %{}

    base = case mode do
      "pick" ->
        keys = config["body_pick"] || []
        Enum.reduce(keys, %{}, fn k, acc -> Map.put(acc, k, payload[k]) end)
      _ ->
        payload
    end

    rename = config["body_rename"] || %{}
    base = Enum.reduce(rename, base, fn {from_k, to_k}, acc ->
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

  def list_jobs_to_run_now do
    # Simple: daily at hour:minute. TODO: weekly, monthly, cron
    now = DateTime.utc_now()
    today_sec = now.hour * 3600 + now.minute * 60 + now.second

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
        _ ->
          false
      end
    end)
  end

  def list_job_runs(job_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    JobRun
    |> where([r], r.job_id == ^job_id)
    |> order_by([r], desc: r.executed_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def create_job_run(job_id, status, result \\ nil) do
    %JobRun{}
    |> JobRun.changeset(%{
      job_id: job_id,
      executed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
      status: status,
      result: result
    })
    |> Repo.insert()
  end

  # ---------- Helpers ----------

  defp maybe_filter_active(query, _field, true), do: query
  defp maybe_filter_active(query, field, false) do
    where(query, [x], field(x, ^field) == "active")
  end
end
