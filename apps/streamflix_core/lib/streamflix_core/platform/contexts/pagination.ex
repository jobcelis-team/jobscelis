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

    with {:ok, query} <- apply_cursor(query, cursor, :occurred_at) do
      items = query |> limit(^(limit + 1)) |> Repo.all()
      build_page(items, limit)
    else
      :invalid -> empty_page()
    end
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
      |> order_by([d], desc: d.inserted_at, desc: d.id)

    query =
      if project_id do
        event_ids = from(e in WebhookEvent, where: e.project_id == ^project_id, select: e.id)
        where(query, [d], d.event_id in subquery(event_ids))
      else
        query
      end

    # Malformed ids (cursor / webhook filter) give an empty page, not a 500
    with {:ok, query} <- maybe_where_uuid(query, :webhook_id, webhook_id),
         {:ok, query} <- apply_cursor(query, cursor, :inserted_at) do
      items = query |> limit(^(limit + 1)) |> preload([:event, :webhook]) |> Repo.all()
      build_page(items, limit)
    else
      :invalid -> empty_page()
    end
  end

  defp empty_page, do: %{data: [], has_next: false, next_cursor: nil}

  defp maybe_where_uuid(query, _field, blank) when blank in [nil, ""], do: {:ok, query}

  defp maybe_where_uuid(query, field, value) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} -> {:ok, where(query, [d], field(d, ^field) == ^uuid)}
      :error -> :invalid
    end
  end

  defp apply_cursor(query, blank, _field) when blank in [nil, ""], do: {:ok, query}

  defp apply_cursor(query, cursor, field) do
    case Ecto.UUID.cast(cursor) do
      {:ok, cursor} -> {:ok, apply_valid_cursor(query, cursor, field)}
      :error -> :invalid
    end
  end

  defp apply_valid_cursor(query, cursor, field) do
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
    case Keyword.get(opts, :limit, @default_page_size) do
      limit when is_integer(limit) -> min(max(limit, 1), @max_page_size)
      _ -> @default_page_size
    end
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
