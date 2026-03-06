defmodule StreamflixCore.Platform.Analytics do
  @moduledoc """
  Analytics queries: events per day, deliveries per day, top topics, delivery stats.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{WebhookEvent, Delivery, Webhook}

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
end
