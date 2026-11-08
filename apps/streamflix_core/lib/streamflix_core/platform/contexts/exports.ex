defmodule StreamflixCore.Platform.Exports do
  @moduledoc """
  Memory-bounded data for exports: rows are read in keyset-paginated pages of
  `@page_size`, selecting only the exported columns (no preloads), so a large
  export never holds all rows (or related payloads) in memory at once. No
  transaction is held open while the client downloads.
  """
  import Ecto.Query

  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{Delivery, WebhookEvent}

  @page_size 500
  @max_rows 10_000

  @doc "Maximum rows in one export."
  def max_rows, do: @max_rows

  @doc """
  Reduces over export pages of `kind` (`:events` or `:deliveries`) for a project,
  newest first, up to `max_rows/0` rows. `fun.(rows, acc)` returns
  `{:cont, acc}` or `{:halt, acc}`. Returns the final `acc`.

  Options: `:topic` (events only), `:page_size`.
  """
  def reduce_pages(kind, project_id, opts, acc, fun) do
    page_size = min(Keyword.get(opts, :page_size, @page_size), @max_rows)
    do_reduce(kind, project_id, opts, nil, 0, page_size, acc, fun)
  end

  defp do_reduce(kind, project_id, opts, cursor, fetched, page_size, acc, fun) do
    limit = min(page_size, @max_rows - fetched)

    rows = if limit > 0, do: page(kind, project_id, opts, cursor, limit), else: []

    case rows do
      [] ->
        acc

      rows ->
        case fun.(rows, acc) do
          {:halt, acc} ->
            acc

          {:cont, acc} when length(rows) < limit ->
            acc

          {:cont, acc} ->
            last = List.last(rows)

            do_reduce(
              kind,
              project_id,
              opts,
              {last.cursor_at, last.id},
              fetched + length(rows),
              page_size,
              acc,
              fun
            )
        end
    end
  end

  defp page(:events, project_id, opts, cursor, limit) do
    from(e in WebhookEvent,
      where: e.project_id == ^project_id and e.status == "active",
      order_by: [desc: e.occurred_at, desc: e.id],
      limit: ^limit,
      select: %{
        id: e.id,
        topic: e.topic,
        status: e.status,
        occurred_at: e.occurred_at,
        payload: e.payload,
        payload_hash: e.payload_hash,
        cursor_at: e.occurred_at
      }
    )
    |> maybe_topic(Keyword.get(opts, :topic))
    |> after_cursor(cursor, :occurred_at)
    |> Repo.all()
  end

  defp page(:deliveries, project_id, _opts, cursor, limit) do
    from(d in Delivery,
      join: e in WebhookEvent,
      on: e.id == d.event_id,
      where: e.project_id == ^project_id,
      order_by: [desc: d.inserted_at, desc: d.id],
      limit: ^limit,
      select: %{
        id: d.id,
        event_id: d.event_id,
        webhook_id: d.webhook_id,
        status: d.status,
        attempt_number: d.attempt_number,
        response_status: d.response_status,
        inserted_at: d.inserted_at,
        cursor_at: d.inserted_at
      }
    )
    |> after_cursor(cursor, :inserted_at)
    |> Repo.all()
  end

  defp maybe_topic(query, topic) when is_binary(topic) and topic != "",
    do: where(query, [e], e.topic == ^topic)

  defp maybe_topic(query, _), do: query

  defp after_cursor(query, nil, _field), do: query

  defp after_cursor(query, {at, id}, field) do
    where(
      query,
      [r],
      field(r, ^field) < ^at or (field(r, ^field) == ^at and r.id < ^id)
    )
  end
end
