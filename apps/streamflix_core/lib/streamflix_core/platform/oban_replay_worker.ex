defmodule StreamflixCore.Platform.ObanReplayWorker do
  @moduledoc """
  Oban worker that processes an event replay: re-creates deliveries for matching events.
  Runs in the 'replay' queue to avoid affecting normal delivery throughput.
  """
  use Oban.Worker, queue: :replay, max_attempts: 1

  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{Replay, WebhookEvent, Delivery}
  alias StreamflixCore.Platform

  import Ecto.Query
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

  @batch_size 500

  defp run_replay(replay) do
    run_replay!(replay)
  rescue
    e ->
      Logger.error("Replay crashed",
        worker: "ReplayWorker",
        replay_id: replay.id,
        error: Exception.message(e)
      )

      finish(replay, "failed", nil)
      broadcast_progress(replay.project_id, replay.id, "failed", 0, replay.total_events)
      {:error, Exception.message(e)}
  end

  defp run_replay!(replay) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    replay =
      replay
      |> Replay.changeset(%{status: "running", started_at: now})
      |> Repo.update!()

    filters = replay.filters || %{}
    topic = filters["topic"]
    from_date = parse_datetime(filters["from_date"])
    to_date = parse_datetime(filters["to_date"])

    total = count_events(replay.project_id, topic, from_date, to_date)

    replay =
      replay
      |> Replay.changeset(%{total_events: total})
      |> Repo.update!()

    broadcast_progress(replay.project_id, replay.id, "running", 0, total)

    webhooks = target_webhooks(replay.project_id, filters["webhook_id"])
    query = events_query(replay.project_id, topic, from_date, to_date)

    {processed, status} = process_batches(replay, query, webhooks, total, nil, 0)

    finish(replay, status, processed)
    broadcast_progress(replay.project_id, replay.id, status, processed, total)

    if status == "completed" do
      project = Repo.get(StreamflixCore.Schemas.Project, replay.project_id)

      if project && project.user_id do
        StreamflixCore.Notifications.notify_replay_completed(
          project.user_id,
          project.id,
          processed
        )
      end
    end

    Logger.info("Replay finished",
      worker: "ReplayWorker",
      replay_id: replay.id,
      project_id: replay.project_id,
      status: status,
      processed_events: processed,
      total_events: total
    )

    :ok
  end

  # Keyset pagination over (occurred_at, id) so large projects never load every
  # event into memory at once. Cancellation is checked once per batch.
  defp process_batches(replay, query, webhooks, total, cursor, count) do
    if cancelled?(replay.id) do
      {count, "cancelled"}
    else
      batch = query |> after_cursor(cursor) |> limit(@batch_size) |> Repo.all()

      case batch do
        [] ->
          {count, "completed"}

        events ->
          Enum.each(events, &replay_event(&1, webhooks))
          new_count = count + length(events)

          replay
          |> Replay.changeset(%{processed_events: new_count})
          |> Repo.update!()

          broadcast_progress(replay.project_id, replay.id, "running", new_count, total)

          last = List.last(events)
          process_batches(replay, query, webhooks, total, {last.occurred_at, last.id}, new_count)
      end
    end
  end

  defp replay_event(event, webhooks) do
    webhooks
    |> Enum.filter(&Platform.webhook_matches_event?(&1, event))
    |> Enum.each(fn w ->
      delivery =
        %Delivery{}
        |> Delivery.changeset(%{
          event_id: event.id,
          webhook_id: w.id,
          status: "pending",
          attempt_number: 0
        })
        |> Repo.insert!()

      {:ok, _job} =
        Oban.insert(StreamflixCore.Platform.ObanDeliveryWorker.new(%{delivery_id: delivery.id}))
    end)
  end

  defp cancelled?(replay_id) do
    Repo.one(from(r in Replay, where: r.id == ^replay_id, select: r.status)) == "cancelled"
  end

  # Never overwrite a cancellation that happened while the last batch was running.
  defp finish(replay, status, processed) do
    completed_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    status = if cancelled?(replay.id), do: "cancelled", else: status

    changes =
      [status: status, completed_at: completed_at, updated_at: completed_at] ++
        if(processed, do: [processed_events: processed], else: [])

    Repo.update_all(from(r in Replay, where: r.id == ^replay.id), set: changes)
  end

  defp target_webhooks(project_id, webhook_id) when webhook_id in [nil, ""] do
    Platform.list_active_webhooks_for_project(project_id)
  end

  defp target_webhooks(project_id, webhook_id) do
    case Platform.get_webhook(webhook_id) do
      %{project_id: ^project_id, status: "active"} = w -> [w]
      _ -> []
    end
  end

  defp events_query(project_id, topic, from_date, to_date) do
    query =
      WebhookEvent
      |> where([e], e.project_id == ^project_id and e.status == "active")
      |> order_by([e], asc: e.occurred_at, asc: e.id)

    query = if topic && topic != "", do: where(query, [e], e.topic == ^topic), else: query
    query = if from_date, do: where(query, [e], e.occurred_at >= ^from_date), else: query
    if to_date, do: where(query, [e], e.occurred_at <= ^to_date), else: query
  end

  defp after_cursor(query, nil), do: query

  defp after_cursor(query, {occurred_at, id}) do
    where(
      query,
      [e],
      e.occurred_at > ^occurred_at or (e.occurred_at == ^occurred_at and e.id > ^id)
    )
  end

  defp count_events(project_id, topic, from_date, to_date) do
    project_id
    |> events_query(topic, from_date, to_date)
    |> exclude(:order_by)
    |> select([e], count(e.id))
    |> Repo.one()
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
