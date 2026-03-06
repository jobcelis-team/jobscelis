defmodule StreamflixCore.Platform.ObanReplayWorker do
  @moduledoc """
  Oban worker that processes an event replay: re-creates deliveries for matching events.
  Runs in the 'replay' queue to avoid affecting normal delivery throughput.
  """
  use Oban.Worker, queue: :replay, max_attempts: 1

  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{Replay, WebhookEvent, Delivery}
  alias StreamflixCore.Platform

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"replay_id" => replay_id}}) do
    case Repo.get(Replay, replay_id) do
      nil ->
        Logger.warning("Replay not found", worker: "ReplayWorker", replay_id: replay_id)
        :ok

      %{status: "cancelled"} ->
        Logger.info("Replay was cancelled, skipping",
          worker: "ReplayWorker",
          replay_id: replay_id
        )

        :ok

      replay ->
        run_replay(replay)
    end
  end

  defp run_replay(replay) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    replay
    |> Replay.changeset(%{status: "running", started_at: now})
    |> Repo.update!()

    broadcast_progress(replay.project_id, replay.id, "running", 0, replay.total_events)

    filters = replay.filters || %{}
    topic = filters["topic"]
    from_date = parse_datetime(filters["from_date"])
    to_date = parse_datetime(filters["to_date"])
    webhook_id = filters["webhook_id"]

    events = query_events(replay.project_id, topic, from_date, to_date)
    total = length(events)

    replay =
      replay
      |> Replay.changeset(%{total_events: total})
      |> Repo.update!()

    webhooks =
      if webhook_id do
        case Platform.get_webhook(webhook_id) do
          nil -> []
          w -> if w.status == "active", do: [w], else: []
        end
      else
        Platform.list_active_webhooks_for_project(replay.project_id)
      end

    {processed, _} =
      Enum.reduce(events, {0, replay}, fn event, {count, rep} ->
        # Check if cancelled mid-replay
        fresh = Repo.get(Replay, rep.id)

        if fresh && fresh.status == "cancelled" do
          {count, rep}
        else
          matching = Enum.filter(webhooks, &Platform.webhook_matches_event?(&1, event))

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
                Oban.insert(
                  StreamflixCore.Platform.ObanDeliveryWorker.new(%{delivery_id: delivery.id})
                )

              _ ->
                :ok
            end
          end)

          new_count = count + 1

          # Update progress every 10 events or on the last one
          if rem(new_count, 10) == 0 or new_count == total do
            rep
            |> Replay.changeset(%{processed_events: new_count})
            |> Repo.update!()

            broadcast_progress(rep.project_id, rep.id, "running", new_count, total)
          end

          {new_count, rep}
        end
      end)

    # Final status
    final_status = if processed == total, do: "completed", else: "completed"
    completed_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    replay
    |> Replay.changeset(%{
      status: final_status,
      processed_events: processed,
      completed_at: completed_at
    })
    |> Repo.update!()

    broadcast_progress(replay.project_id, replay.id, final_status, processed, total)

    # Notify user
    project = Repo.get(StreamflixCore.Schemas.Project, replay.project_id)

    if project && project.user_id do
      StreamflixCore.Notifications.notify_replay_completed(
        project.user_id,
        project.id,
        processed
      )
    end

    Logger.info("Replay completed",
      worker: "ReplayWorker",
      replay_id: replay.id,
      project_id: replay.project_id,
      processed_events: processed,
      total_events: total
    )

    :ok
  end

  defp query_events(project_id, topic, from_date, to_date) do
    import Ecto.Query

    query =
      WebhookEvent
      |> where([e], e.project_id == ^project_id and e.status == "active")
      |> order_by([e], asc: e.occurred_at)

    query = if topic && topic != "", do: where(query, [e], e.topic == ^topic), else: query
    query = if from_date, do: where(query, [e], e.occurred_at >= ^from_date), else: query
    query = if to_date, do: where(query, [e], e.occurred_at <= ^to_date), else: query

    Repo.all(query)
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(""), do: nil

  defp parse_datetime(str) when is_binary(str) do
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

  defp parse_datetime(_), do: nil

  defp broadcast_progress(project_id, replay_id, status, processed, total) do
    Phoenix.PubSub.broadcast(
      StreamflixCore.PubSub,
      "project:#{project_id}",
      {:replay_progress, %{id: replay_id, status: status, processed: processed, total: total}}
    )
  end
end
