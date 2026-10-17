defmodule StreamflixCore.Platform.Replays do
  @moduledoc """
  Event replay management: create, list, cancel.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{Replay, Webhook, WebhookEvent}

  @doc """
  Creates a replay and enqueues its worker.

  Returns `{:error, {:invalid_filter, field}}` when a date cannot be parsed, the
  range is inverted, or `webhook_id` does not belong to the project — instead of
  silently dropping the filter and replaying every event.
  """
  def create_replay(project_id, user_id, filters) do
    with {:ok, from_date} <- parse_filter(filters, "from_date"),
         {:ok, to_date} <- parse_filter(filters, "to_date"),
         :ok <- validate_range(from_date, to_date),
         :ok <- validate_webhook(project_id, filters["webhook_id"]) do
      total = count_events_for_replay(project_id, filters["topic"], from_date, to_date)

      attrs = %{
        project_id: project_id,
        created_by: user_id,
        status: "pending",
        filters: normalize_filters(filters),
        total_events: total
      }

      with {:ok, replay} <- %Replay{} |> Replay.changeset(attrs) |> Repo.insert() do
        case Oban.insert(StreamflixCore.Platform.ObanReplayWorker.new(%{replay_id: replay.id})) do
          {:ok, _job} ->
            {:ok, replay}

          {:error, reason} ->
            replay |> Replay.changeset(%{status: "failed"}) |> Repo.update()
            {:error, reason}
        end
      end
    end
  end

  defp parse_filter(filters, key) do
    case filters[key] do
      blank when blank in [nil, ""] ->
        {:ok, nil}

      value ->
        case parse_replay_datetime(value) do
          nil -> {:error, {:invalid_filter, key}}
          dt -> {:ok, dt}
        end
    end
  end

  defp validate_range(%DateTime{} = from, %DateTime{} = to) do
    if DateTime.compare(from, to) == :gt, do: {:error, {:invalid_filter, "to_date"}}, else: :ok
  end

  defp validate_range(_from, _to), do: :ok

  defp validate_webhook(_project_id, blank) when blank in [nil, ""], do: :ok

  defp validate_webhook(project_id, webhook_id) do
    case Repo.get_uuid(Webhook, webhook_id) do
      %Webhook{project_id: ^project_id} -> :ok
      _ -> {:error, {:invalid_filter, "webhook_id"}}
    end
  end

  defp normalize_filters(filters) do
    Map.new(filters, fn {k, v} -> {k, if(v == "", do: nil, else: v)} end)
  end

  def list_replays(project_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    Replay
    |> where([r], r.project_id == ^project_id)
    |> order_by([r], desc: r.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_replay(id), do: Repo.get_uuid(Replay, id)

  def cancel_replay(id) do
    case Repo.get_uuid(Replay, id) do
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
end
