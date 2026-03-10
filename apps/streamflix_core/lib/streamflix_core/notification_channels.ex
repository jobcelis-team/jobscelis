defmodule StreamflixCore.NotificationChannels do
  @moduledoc """
  Context for managing external notification channels per project.
  Handles CRUD operations and dispatching alerts to configured channels.
  """
  require Logger

  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.NotificationChannel

  # --- CRUD ---

  def get_by_project(project_id) do
    Repo.get_by(NotificationChannel, project_id: project_id)
  end

  def create(attrs) do
    %NotificationChannel{}
    |> NotificationChannel.changeset(attrs)
    |> Repo.insert()
  end

  def update(%NotificationChannel{} = channel, attrs) do
    channel
    |> NotificationChannel.changeset(attrs)
    |> Repo.update()
  end

  def delete(%NotificationChannel{} = channel) do
    Repo.delete(channel)
  end

  def upsert(project_id, attrs) do
    case get_by_project(project_id) do
      nil -> create(Map.put(attrs, :project_id, project_id))
      channel -> update(channel, attrs)
    end
  end

  # --- Dispatch ---

  @doc """
  Dispatches an external notification for the given project and event type.
  Called after an in-app notification is created. Enqueues an Oban job
  so delivery happens asynchronously.
  """
  def dispatch(project_id, event_type, payload) when is_binary(project_id) do
    case get_by_project(project_id) do
      nil ->
        :ok

      channel ->
        if should_notify?(channel, event_type) do
          enqueue_delivery(channel, event_type, payload)
        else
          :ok
        end
    end
  end

  def dispatch(_, _, _), do: :ok

  defp should_notify?(%NotificationChannel{} = ch, event_type) do
    has_any_channel?(ch) and event_type_enabled?(ch, event_type)
  end

  defp has_any_channel?(ch) do
    ch.email_enabled or ch.slack_enabled or ch.discord_enabled or ch.meta_webhook_enabled
  end

  defp event_type_enabled?(%{event_types: nil}, _type), do: true
  defp event_type_enabled?(%{event_types: []}, _type), do: true
  defp event_type_enabled?(%{event_types: types}, type), do: type in types

  defp enqueue_delivery(channel, event_type, payload) do
    %{
      channel_id: channel.id,
      event_type: event_type,
      payload: payload
    }
    |> StreamflixCore.Platform.ExternalNotificationWorker.new()
    |> Oban.insert()
  end
end
