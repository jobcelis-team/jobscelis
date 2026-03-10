defmodule StreamflixWebWeb.Api.V1.NotificationChannelsController do
  @moduledoc """
  API controller for managing external notification channels per project.
  Supports email, Slack, Discord, and meta-webhook channels.
  """
  use StreamflixWebWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias StreamflixCore.NotificationChannels
  alias StreamflixWebWeb.Schemas

  action_fallback StreamflixWebWeb.FallbackController

  tags(["Notification Channels"])
  security([%{"api_key" => []}])

  operation(:show,
    summary: "Get notification channel configuration",
    responses: [
      ok: {"Notification channel", "application/json", Schemas.NotificationChannelResponse},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse}
    ]
  )

  def show(conn, _params) do
    project = conn.assigns.current_project

    case NotificationChannels.get_by_project(project.id) do
      nil ->
        json(conn, %{data: nil})

      channel ->
        json(conn, %{data: channel_json(channel)})
    end
  end

  operation(:upsert,
    summary: "Create or update notification channel configuration",
    request_body:
      {"Channel configuration", "application/json", Schemas.NotificationChannelCreate},
    responses: [
      ok: {"Notification channel", "application/json", Schemas.NotificationChannelResponse},
      unprocessable_entity: {"Validation errors", "application/json", Schemas.ErrorResponse}
    ]
  )

  def upsert(conn, params) do
    project = conn.assigns.current_project

    attrs = %{
      email_enabled: params["email_enabled"] || false,
      email_address: params["email_address"],
      slack_enabled: params["slack_enabled"] || false,
      slack_webhook_url: params["slack_webhook_url"],
      discord_enabled: params["discord_enabled"] || false,
      discord_webhook_url: params["discord_webhook_url"],
      meta_webhook_enabled: params["meta_webhook_enabled"] || false,
      meta_webhook_url: params["meta_webhook_url"],
      meta_webhook_secret: params["meta_webhook_secret"],
      event_types: params["event_types"]
    }

    case NotificationChannels.upsert(project.id, attrs) do
      {:ok, channel} ->
        json(conn, %{data: channel_json(channel)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: format_errors(changeset)})
    end
  end

  operation(:delete,
    summary: "Delete notification channel configuration",
    responses: [
      no_content: {"Deleted", "application/json", nil},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse}
    ]
  )

  def delete(conn, _params) do
    project = conn.assigns.current_project

    case NotificationChannels.get_by_project(project.id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "No notification channel configured"})

      channel ->
        {:ok, _} = NotificationChannels.delete(channel)
        send_resp(conn, :no_content, "")
    end
  end

  operation(:test,
    summary: "Send a test notification to all enabled channels",
    responses: [
      ok: {"Test results", "application/json", Schemas.NotificationTestResponse},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse}
    ]
  )

  def test(conn, _params) do
    project = conn.assigns.current_project

    case NotificationChannels.get_by_project(project.id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "No notification channel configured"})

      channel ->
        payload = %{
          "message" => "This is a test notification from Jobcelis.",
          "test" => true
        }

        NotificationChannels.dispatch(project.id, "webhook_failing", payload)
        json(conn, %{status: "sent", channels: enabled_channels(channel)})
    end
  end

  # --- Helpers ---

  defp channel_json(ch) do
    %{
      id: ch.id,
      project_id: ch.project_id,
      email_enabled: ch.email_enabled,
      email_address: ch.email_address,
      slack_enabled: ch.slack_enabled,
      slack_webhook_url: mask_url(ch.slack_webhook_url),
      discord_enabled: ch.discord_enabled,
      discord_webhook_url: mask_url(ch.discord_webhook_url),
      meta_webhook_enabled: ch.meta_webhook_enabled,
      meta_webhook_url: ch.meta_webhook_url,
      meta_webhook_secret: if(ch.meta_webhook_secret, do: "••••••", else: nil),
      event_types: ch.event_types,
      inserted_at: ch.inserted_at,
      updated_at: ch.updated_at
    }
  end

  defp mask_url(nil), do: nil

  defp mask_url(url) do
    uri = URI.parse(url)
    "#{uri.scheme}://#{uri.host}/••••••"
  end

  defp enabled_channels(ch) do
    channels = []
    channels = if ch.email_enabled, do: ["email" | channels], else: channels
    channels = if ch.slack_enabled, do: ["slack" | channels], else: channels
    channels = if ch.discord_enabled, do: ["discord" | channels], else: channels
    if ch.meta_webhook_enabled, do: ["meta_webhook" | channels], else: channels
  end

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join(", ", fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
  end
end
