defmodule StreamflixCore.Notifications do
  @moduledoc """
  Context for internal notifications. Creates, lists, marks as read.
  Broadcasts via PubSub for real-time bell updates.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.Notification
  alias StreamflixCore.NotificationChannels

  @pubsub StreamflixCore.PubSub

  def create(attrs) do
    case %Notification{}
         |> Notification.changeset(attrs)
         |> Repo.insert() do
      {:ok, notif} ->
        broadcast(notif.user_id, {:new_notification, notif})
        {:ok, notif}

      error ->
        error
    end
  end

  def list_for_user(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    unread_only = Keyword.get(opts, :unread_only, false)

    Notification
    |> where([n], n.user_id == ^user_id)
    |> maybe_unread_only(unread_only)
    |> order_by([n], desc: n.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def unread_count(user_id) do
    Notification
    |> where([n], n.user_id == ^user_id and n.read == false)
    |> select([n], count(n.id))
    |> Repo.one()
  end

  def mark_as_read(id) do
    case Repo.get(Notification, id) do
      nil ->
        {:error, :not_found}

      notif ->
        notif
        |> Notification.changeset(%{
          read: true,
          read_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
        })
        |> Repo.update()
    end
  end

  def mark_all_read(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    {count, _} =
      Notification
      |> where([n], n.user_id == ^user_id and n.read == false)
      |> Repo.update_all(set: [read: true, read_at: now, updated_at: now])

    broadcast(user_id, :notifications_read)
    {:ok, count}
  end

  def mark_invite_read(user_id, member_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    Notification
    |> where(
      [n],
      n.user_id == ^user_id and n.type == "team_invite" and n.read == false and
        fragment("?->>'member_id' = ?", n.metadata, ^member_id)
    )
    |> Repo.update_all(set: [read: true, read_at: now, updated_at: now])

    :ok
  end

  # --- Notification triggers (called from workers/platform) ---

  def notify_webhook_failing(user_id, project_id, webhook_url) do
    result =
      create(%{
        user_id: user_id,
        project_id: project_id,
        type: "webhook_failing",
        title: "Webhook failing",
        message: "#{webhook_url} has multiple consecutive failures",
        metadata: %{"webhook_url" => webhook_url}
      })

    dispatch_external(project_id, "webhook_failing", %{
      "message" => "#{webhook_url} has multiple consecutive failures",
      "webhook_url" => webhook_url
    })

    result
  end

  def notify_job_failed(user_id, project_id, job_name) do
    result =
      create(%{
        user_id: user_id,
        project_id: project_id,
        type: "job_failed",
        title: "Job failed",
        message: "Scheduled job \"#{job_name}\" failed to execute",
        metadata: %{"job_name" => job_name}
      })

    dispatch_external(project_id, "job_failed", %{
      "message" => "Scheduled job \"#{job_name}\" failed to execute",
      "job_name" => job_name
    })

    result
  end

  def notify_dlq_entry(user_id, project_id, webhook_url) do
    result =
      create(%{
        user_id: user_id,
        project_id: project_id,
        type: "dlq_entry",
        title: "Delivery moved to DLQ",
        message: "A delivery to #{webhook_url} exhausted all retries",
        metadata: %{"webhook_url" => webhook_url}
      })

    dispatch_external(project_id, "dlq_entry", %{
      "message" => "A delivery to #{webhook_url} exhausted all retries",
      "webhook_url" => webhook_url
    })

    result
  end

  def notify_replay_completed(user_id, project_id, event_count) do
    result =
      create(%{
        user_id: user_id,
        project_id: project_id,
        type: "replay_completed",
        title: "Replay completed",
        message: "#{event_count} events were successfully re-delivered",
        metadata: %{"event_count" => event_count}
      })

    dispatch_external(project_id, "replay_completed", %{
      "message" => "#{event_count} events were successfully re-delivered",
      "event_count" => event_count
    })

    result
  end

  def notify_team_invite(user_id, project_id, role, member_id) do
    create(%{
      user_id: user_id,
      project_id: project_id,
      type: "team_invite",
      title: "Project invitation",
      message: "You have been invited to a project as #{role}.",
      metadata: %{"project_id" => project_id, "member_id" => member_id}
    })
  end

  # --- PubSub ---

  def subscribe(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, "notifications:#{user_id}")
  end

  defp broadcast(user_id, message) do
    Phoenix.PubSub.broadcast(@pubsub, "notifications:#{user_id}", message)
  end

  defp dispatch_external(project_id, event_type, payload) do
    NotificationChannels.dispatch(project_id, event_type, payload)
  end

  defp maybe_unread_only(query, true), do: where(query, [n], n.read == false)
  defp maybe_unread_only(query, _), do: query
end
