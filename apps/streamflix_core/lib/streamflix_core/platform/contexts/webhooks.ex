defmodule StreamflixCore.Platform.Webhooks do
  @moduledoc """
  Webhook management: CRUD, matching, health, templates, simulation.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{Webhook, Delivery}

  @cache :platform_cache
  @webhooks_ttl :timer.seconds(300)

  # ---------- Templates ----------

  @webhook_templates [
    %{
      id: "slack",
      name: "Slack",
      description: "Send to a Slack channel via Incoming Webhook",
      body_config: %{
        "body_mode" => "custom",
        "template" => %{
          "text" => "New event: {{topic}}",
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
      description: "Send to a Discord channel via Webhook URL",
      body_config: %{
        "body_mode" => "custom",
        "template" => %{
          "content" => "Event: {{topic}}",
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
      description: "Send message via Telegram Bot API",
      body_config: %{
        "body_mode" => "custom",
        "template" => %{
          "chat_id" => "{{CHAT_ID}}",
          "text" => "Event {{topic}}: {{payload}}"
        }
      },
      headers: %{"content-type" => "application/json"},
      url_placeholder: "https://api.telegram.org/botTOKEN/sendMessage"
    },
    %{
      id: "generic",
      name: "Generic JSON",
      description: "Full payload as JSON",
      body_config: %{"body_mode" => "full"},
      headers: %{"content-type" => "application/json"},
      url_placeholder: "https://your-endpoint.com/webhook"
    },
    %{
      id: "custom",
      name: "Custom",
      description: "Configure manually",
      body_config: nil,
      headers: %{},
      url_placeholder: "https://your-endpoint.com/webhook"
    }
  ]

  def webhook_templates, do: @webhook_templates

  # ---------- CRUD ----------

  def create_webhook(project_id, attrs) do
    attrs = Map.merge(attrs, %{"project_id" => project_id})

    case %Webhook{}
         |> Webhook.changeset(attrs)
         |> Repo.insert() do
      {:ok, webhook} ->
        Cachex.del(@cache, {:active_webhooks, project_id})
        invalidate_webhook_health_cache(project_id)
        {:ok, webhook}

      error ->
        error
    end
  end

  def list_webhooks(project_id, opts \\ []) do
    include_inactive = Keyword.get(opts, :include_inactive, false)

    Webhook
    |> where([w], w.project_id == ^project_id)
    |> maybe_filter_active(include_inactive)
    |> order_by([w], desc: w.inserted_at)
    |> Repo.all()
  end

  def get_webhook(id), do: Repo.get(Webhook, id)
  def get_webhook!(id), do: Repo.get!(Webhook, id)

  def update_webhook(%Webhook{} = webhook, attrs) do
    # Reset circuit breaker when URL changes so deliveries aren't blocked
    attrs =
      if is_map(attrs) and url_changed?(attrs, webhook) do
        attrs
        |> Map.put(:circuit_state, "closed")
        |> Map.put(:consecutive_failures, 0)
        |> Map.put(:circuit_opened_at, nil)
      else
        attrs
      end

    case webhook
         |> Webhook.changeset(attrs)
         |> Repo.update() do
      {:ok, updated} ->
        Cachex.del(@cache, {:active_webhooks, webhook.project_id})
        invalidate_webhook_health_cache(webhook.project_id)
        {:ok, updated}

      error ->
        error
    end
  end

  defp url_changed?(%{url: new_url}, %Webhook{url: old_url}) when new_url != old_url, do: true
  defp url_changed?(%{"url" => new_url}, %Webhook{url: old_url}) when new_url != old_url, do: true
  defp url_changed?(_, _), do: false

  def set_webhook_inactive(%Webhook{} = webhook) do
    update_webhook(webhook, %{status: "inactive"})
  end

  def list_active_webhooks_for_project(project_id) do
    cache_key = {:active_webhooks, project_id}

    case Cachex.fetch(@cache, cache_key, fn _key ->
           result =
             Webhook
             |> where([w], w.project_id == ^project_id and w.status == "active")
             |> Repo.all()

           {:commit, result, ttl: @webhooks_ttl}
         end) do
      {:ok, webhooks} -> webhooks
      {:commit, webhooks} -> webhooks
    end
  end

  # ---------- Matching ----------

  def webhook_matches_event?(webhook, event) do
    topics_ok = topic_matches?(webhook.topics || [], event.topic)
    filters_ok = filters_match?(webhook.filters || [], event.topic, event.payload)
    topics_ok and filters_ok
  end

  def topic_matches?([], _event_topic), do: true
  def topic_matches?(_topics, nil), do: false

  def topic_matches?(topics, event_topic) when is_list(topics) do
    event_segments = String.split(event_topic, ".")

    Enum.any?(topics, fn pattern ->
      pattern_segments = String.split(pattern, ".")
      segments_match?(pattern_segments, event_segments)
    end)
  end

  defp segments_match?([], []), do: true
  defp segments_match?([], _remaining), do: false
  defp segments_match?(["#"], [_ | _]), do: true
  defp segments_match?(["#"], []), do: false
  defp segments_match?(["#" | rest], event_segments), do: hash_match?(rest, event_segments)
  defp segments_match?(_pattern, []), do: false

  defp segments_match?(["*" | p_rest], [_e | e_rest]),
    do: segments_match?(p_rest, e_rest)

  defp segments_match?([p | p_rest], [e | e_rest]) when p == e,
    do: segments_match?(p_rest, e_rest)

  defp segments_match?(_pattern, _event), do: false

  # `#` matches one or more segments, so try dropping 1..N segments from event
  # `#` consumed one or more segments; check if remaining pattern matches remaining event
  defp hash_match?([], event_segments), do: event_segments != []
  defp hash_match?(_rest, []), do: false

  defp hash_match?(rest, event_segments) do
    # Try consuming 1..N segments with `#`, then match rest of pattern
    Enum.any?(1..length(event_segments), fn drop ->
      segments_match?(rest, Enum.drop(event_segments, drop))
    end)
  end

  def filters_match?([], _topic, _payload), do: true

  def filters_match?(filters, topic, payload) when is_list(filters) do
    combined = Map.put(payload || %{}, "topic", topic)
    Enum.all?(filters, fn f -> filter_condition_holds?(f, combined) end)
  end

  def filters_match?(_, _, _), do: true

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
    end
  end

  defp compare(_, _, _), do: false

  # ---------- Health ----------

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

  @doc "Calculate health for all webhooks of a project in a single query"
  def webhooks_health(project_id) do
    case Cachex.fetch(@cache, {:webhook_health, project_id}, fn _ ->
           health = do_calculate_webhooks_health_batch(project_id)
           {:commit, health, ttl: :timer.seconds(60)}
         end) do
      {:ok, health} -> health
      {:commit, health} -> health
      _ -> %{}
    end
  end

  defp do_calculate_webhooks_health_batch(project_id) do
    since = DateTime.utc_now() |> DateTime.add(-24, :hour) |> DateTime.truncate(:microsecond)
    webhooks = list_webhooks(project_id)
    webhook_ids = Enum.map(webhooks, & &1.id)

    # Single query: aggregate all webhook health stats at once
    stats_map =
      if webhook_ids == [] do
        %{}
      else
        from(d in Delivery,
          where: d.webhook_id in ^webhook_ids and d.inserted_at >= ^since,
          group_by: d.webhook_id,
          select:
            {d.webhook_id,
             %{
               total: count(d.id),
               success: count(fragment("CASE WHEN ? = 'success' THEN 1 END", d.status)),
               failed: count(fragment("CASE WHEN ? = 'failed' THEN 1 END", d.status)),
               avg_latency:
                 fragment("AVG(EXTRACT(EPOCH FROM ? - ?))", d.updated_at, d.inserted_at)
             }}
        )
        |> Repo.all()
        |> Map.new()
      end

    # Build health map for all webhooks (including those with no deliveries)
    Map.new(webhooks, fn w ->
      stats = Map.get(stats_map, w.id, %{total: 0, success: 0, failed: 0, avg_latency: nil})

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

      {w.id,
       %{
         score: score,
         success_rate: success_rate,
         total: stats.total,
         success: stats.success,
         failed: stats.failed,
         avg_latency: to_float_or_nil(stats.avg_latency)
       }}
    end)
  end

  def invalidate_webhook_health_cache(project_id) do
    Cachex.del(@cache, {:webhook_health, project_id})
  end

  defp to_float_or_nil(nil), do: nil
  defp to_float_or_nil(%Decimal{} = d), do: d |> Decimal.to_float() |> Float.round(2)
  defp to_float_or_nil(f) when is_float(f), do: Float.round(f, 2)
  defp to_float_or_nil(i) when is_integer(i), do: i * 1.0

  # ---------- Simulator ----------

  @doc "Simulate an event: show which webhooks would match without sending"
  def simulate_event(project_id, body) when is_map(body) do
    {topic, payload} = StreamflixCore.Platform.Events.extract_topic_and_payload(body)
    webhooks = list_active_webhooks_for_project(project_id)

    fake_event = %{
      topic: topic,
      payload: payload,
      id: "simulated",
      occurred_at: DateTime.utc_now()
    }

    matching = Enum.filter(webhooks, &webhook_matches_event?(&1, fake_event))

    Enum.map(matching, fn webhook ->
      body_to_send = StreamflixCore.Platform.Deliveries.build_webhook_body(webhook, fake_event)
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
        matched_by_topics: topic_matches?(webhook.topics || [], topic),
        matched_by_filters: filters_match?(webhook.filters || [], topic, payload)
      }
    end)
  end

  def simulate_event(_project_id, _), do: {:error, :invalid_payload}

  # ---------- Test Webhook ----------

  @doc """
  Send a test ping to a webhook URL to verify connectivity.
  Returns {:ok, %{status: status, latency_ms: ms}} or {:error, reason}.
  """
  def test_webhook(webhook_id) do
    case get_webhook(webhook_id) do
      nil ->
        {:error, :not_found}

      webhook ->
        test_payload = %{
          "type" => "webhook.test",
          "message" => "This is a test ping from Streamflix",
          "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
        }

        body_json = Jason.encode!(test_payload)

        headers = [{"content-type", "application/json"}]

        headers =
          if webhook.secret_encrypted && webhook.secret_encrypted != "" do
            sig =
              :crypto.mac(:hmac, :sha256, webhook.secret_encrypted, body_json)
              |> Base.encode64(padding: false)

            [{"x-signature", "sha256=#{sig}"} | headers]
          else
            headers
          end

        start_time = System.monotonic_time(:millisecond)

        case Req.post(webhook.url,
               json: test_payload,
               headers: headers,
               receive_timeout: 10_000,
               connect_options: [timeout: 5_000]
             ) do
          {:ok, %{status: status}} ->
            latency_ms = System.monotonic_time(:millisecond) - start_time
            {:ok, %{status: status, latency_ms: latency_ms, webhook_id: webhook.id}}

          {:error, reason} ->
            {:error, %{reason: inspect(reason), webhook_id: webhook.id}}
        end
    end
  end

  # ---------- Helpers ----------

  defp maybe_filter_active(query, true), do: query
  defp maybe_filter_active(query, false), do: where(query, [x], x.status == "active")
end
