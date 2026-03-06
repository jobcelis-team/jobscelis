defmodule StreamflixCore.Platform.Replays do
  @moduledoc """
  Event replay management: create, list, cancel.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{Replay, WebhookEvent}

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
end
