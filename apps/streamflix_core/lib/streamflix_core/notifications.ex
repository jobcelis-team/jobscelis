defmodule StreamflixCore.Notifications do
  @moduledoc """
  Context for internal notifications. Creates, lists, marks as read.
  Broadcasts via PubSub for real-time bell updates.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.Notification

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

  # --- Notification triggers (called from workers/platform) ---

  def notify_webhook_failing(user_id, project_id, webhook_url) do
    create(%{
      user_id: user_id,
      project_id: project_id,
      type: "webhook_failing",
      title: "Webhook fallando",
      message: "#{webhook_url} tiene múltiples fallos consecutivos",
      metadata: %{"webhook_url" => webhook_url}
    })
  end

  def notify_job_failed(user_id, project_id, job_name) do
    create(%{
      user_id: user_id,
      project_id: project_id,
      type: "job_failed",
      title: "Job fallido",
      message: "El job programado \"#{job_name}\" falló al ejecutarse",
      metadata: %{"job_name" => job_name}
    })
  end

  def notify_dlq_entry(user_id, project_id, webhook_url) do
    create(%{
      user_id: user_id,
      project_id: project_id,
      type: "dlq_entry",
      title: "Entrega movida a DLQ",
      message: "Una entrega a #{webhook_url} agotó todos los reintentos",
      metadata: %{"webhook_url" => webhook_url}
    })
  end

  def notify_replay_completed(user_id, project_id, event_count) do
    create(%{
      user_id: user_id,
      project_id: project_id,
      type: "replay_completed",
      title: "Replay completado",
      message: "Se re-enviaron #{event_count} eventos exitosamente",
      metadata: %{"event_count" => event_count}
    })
  end

  # --- PubSub ---

  def subscribe(user_id) do
    Phoenix.PubSub.subscribe(@pubsub, "notifications:#{user_id}")
  end

  defp broadcast(user_id, message) do
    Phoenix.PubSub.broadcast(@pubsub, "notifications:#{user_id}", message)
  end

  defp maybe_unread_only(query, true), do: where(query, [n], n.read == false)
  defp maybe_unread_only(query, _), do: query
end
