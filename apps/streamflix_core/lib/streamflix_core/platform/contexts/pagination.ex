defmodule StreamflixCore.Platform.Pagination do
  @moduledoc """
  Cursor-based pagination for events and deliveries.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{WebhookEvent, Delivery}

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

  defp maybe_filter_topic(query, nil), do: query
  defp maybe_filter_topic(query, topic), do: where(query, [e], e.topic == ^topic)

  defp maybe_where(query, _field, nil), do: query
  defp maybe_where(query, field, value), do: where(query, [d], field(d, ^field) == ^value)
end
