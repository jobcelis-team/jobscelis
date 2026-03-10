defmodule StreamflixCore.Platform.ExternalNotificationWorker do
  @moduledoc """
  Oban worker that delivers external notifications to configured channels:
  email, Slack, Discord, and meta-webhook.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.NotificationChannel

  @receive_timeout 10_000

  @impl true
  def perform(%Oban.Job{
        args: %{
          "channel_id" => channel_id,
          "event_type" => event_type,
          "payload" => payload
        }
      }) do
    case Repo.get(NotificationChannel, channel_id) do
      nil ->
        Logger.warning("Notification channel not found",
          worker: "ExternalNotificationWorker",
          channel_id: channel_id
        )

        :ok

      channel ->
        deliver_to_channels(channel, event_type, payload)
    end
  end

  defp deliver_to_channels(channel, event_type, payload) do
    results = []

    results =
      if channel.email_enabled and channel.email_address do
        [deliver_email(channel, event_type, payload) | results]
      else
        results
      end

    results =
      if channel.slack_enabled and channel.slack_webhook_url do
        [deliver_slack(channel.slack_webhook_url, event_type, payload) | results]
      else
        results
      end

    results =
      if channel.discord_enabled and channel.discord_webhook_url do
        [deliver_discord(channel.discord_webhook_url, event_type, payload) | results]
      else
        results
      end

    results =
      if channel.meta_webhook_enabled and channel.meta_webhook_url do
        [deliver_meta_webhook(channel, event_type, payload) | results]
      else
        results
      end

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if errors == [] do
      :ok
    else
      Logger.error("Some external notifications failed",
        worker: "ExternalNotificationWorker",
        channel_id: channel.id,
        errors: inspect(errors)
      )

      # Return error to trigger Oban retry
      {:error, "#{length(errors)} channel(s) failed"}
    end
  end

  # --- Email ---

  defp deliver_email(channel, event_type, payload) do
    project = Repo.get(StreamflixCore.Schemas.Project, channel.project_id)
    project_name = if project, do: project.name, else: "Unknown"

    subject = "Jobcelis Alert: #{format_event_type(event_type)} — #{project_name}"
    html = build_alert_email(event_type, payload, project_name)

    config = Application.get_env(:streamflix_web, StreamflixWebWeb.Mailer, [])
    api_key = config[:api_key]
    from_email = config[:from_email] || "noreply@jobcelis.com"
    from_name = config[:from_name] || "Jobcelis"

    if api_key do
      body =
        Jason.encode!(%{
          from: "#{from_name} <#{from_email}>",
          to: [channel.email_address],
          subject: subject,
          html: html
        })

      case Req.post("https://api.resend.com/emails",
             body: body,
             headers: [
               {"authorization", "Bearer #{api_key}"},
               {"content-type", "application/json"}
             ],
             receive_timeout: @receive_timeout,
             retry: false
           ) do
        {:ok, %{status: status}} when status in 200..299 ->
          Logger.info("Alert email sent",
            worker: "ExternalNotificationWorker",
            channel_id: channel.id,
            event_type: event_type
          )

          :ok

        {:ok, %{status: status, body: resp}} ->
          {:error, {:email, status, resp}}

        {:error, reason} ->
          {:error, {:email, reason}}
      end
    else
      Logger.info("No RESEND_API_KEY — skipping alert email",
        worker: "ExternalNotificationWorker"
      )

      :ok
    end
  end

  # --- Slack ---

  defp deliver_slack(webhook_url, event_type, payload) do
    title = format_event_type(event_type)
    message = Map.get(payload, "message", "")

    body =
      Jason.encode!(%{
        text: ":warning: *Jobcelis Alert: #{title}*\n#{message}",
        blocks: [
          %{
            type: "section",
            text: %{
              type: "mrkdwn",
              text: ":warning: *#{title}*\n#{message}"
            }
          },
          %{
            type: "context",
            elements: [
              %{type: "mrkdwn", text: "Event: `#{event_type}`"},
              %{
                type: "mrkdwn",
                text: "Time: #{DateTime.utc_now() |> DateTime.to_iso8601()}"
              }
            ]
          }
        ]
      })

    case Req.post(webhook_url,
           body: body,
           headers: [{"content-type", "application/json"}],
           receive_timeout: @receive_timeout,
           retry: false
         ) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, %{status: status, body: resp}} ->
        {:error, {:slack, status, resp}}

      {:error, reason} ->
        {:error, {:slack, reason}}
    end
  end

  # --- Discord ---

  defp deliver_discord(webhook_url, event_type, payload) do
    title = format_event_type(event_type)
    message = Map.get(payload, "message", "")

    body =
      Jason.encode!(%{
        embeds: [
          %{
            title: "⚠️ #{title}",
            description: message,
            color: 15_158_332,
            fields: [
              %{name: "Event", value: "`#{event_type}`", inline: true},
              %{
                name: "Time",
                value: DateTime.utc_now() |> DateTime.to_iso8601(),
                inline: true
              }
            ],
            footer: %{text: "Jobcelis Alerts"}
          }
        ]
      })

    case Req.post(webhook_url,
           body: body,
           headers: [{"content-type", "application/json"}],
           receive_timeout: @receive_timeout,
           retry: false
         ) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, %{status: status, body: resp}} ->
        {:error, {:discord, status, resp}}

      {:error, reason} ->
        {:error, {:discord, reason}}
    end
  end

  # --- Meta-webhook ---

  defp deliver_meta_webhook(channel, event_type, payload) do
    body =
      Jason.encode!(%{
        event_type: event_type,
        payload: payload,
        project_id: channel.project_id,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })

    headers = [{"content-type", "application/json"}]

    headers =
      if channel.meta_webhook_secret do
        sig =
          :crypto.mac(:hmac, :sha256, channel.meta_webhook_secret, body)
          |> Base.encode64(padding: false)

        [{"x-signature", "sha256=#{sig}"} | headers]
      else
        headers
      end

    case Req.post(channel.meta_webhook_url,
           body: body,
           headers: headers,
           receive_timeout: @receive_timeout,
           retry: false
         ) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, %{status: status, body: resp}} ->
        {:error, {:meta_webhook, status, resp}}

      {:error, reason} ->
        {:error, {:meta_webhook, reason}}
    end
  end

  # --- Formatting ---

  defp format_event_type(type) do
    type
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp build_alert_email(event_type, payload, project_name) do
    title = format_event_type(event_type)
    message = Map.get(payload, "message", "")
    year = Date.utc_today().year

    """
    <!DOCTYPE html>
    <html lang="en">
    <head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1.0" /></head>
    <body style="margin:0;padding:0;background-color:#f1f5f9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f1f5f9;padding:32px 16px;">
        <tr><td align="center">
          <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,0.08);">
            <tr><td style="padding:32px 40px 24px;border-bottom:3px solid #dc2626;">
              <h1 style="margin:0;font-size:24px;font-weight:700;color:#1e293b;">Jobcelis</h1>
              <p style="margin:4px 0 0;font-size:12px;color:#94a3b8;text-transform:uppercase;">Alert Notification</p>
            </td></tr>
            <tr><td style="padding:32px 40px 8px;">
              <h2 style="margin:0 0 16px;font-size:20px;font-weight:600;color:#dc2626;">#{title}</h2>
              <p style="margin:0 0 8px;font-size:14px;color:#64748b;">Project: <strong>#{project_name}</strong></p>
              <p style="margin:0 0 24px;font-size:15px;line-height:1.6;color:#475569;">#{message}</p>
              <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                <tr><td align="center" style="border-radius:8px;background-color:#4f46e5;">
                  <a href="https://jobcelis.com/platform" target="_blank" style="display:inline-block;padding:14px 36px;font-size:14px;font-weight:600;color:#ffffff;text-decoration:none;border-radius:8px;">View Dashboard</a>
                </td></tr>
              </table>
            </td></tr>
            <tr><td style="padding:16px 40px 32px;">
              <p style="margin:0;font-size:13px;color:#94a3b8;">Event type: #{event_type}</p>
            </td></tr>
            <tr><td style="padding:24px 40px 32px;background-color:#f8fafc;border-top:1px solid #e2e8f0;">
              <p style="margin:0;font-size:11px;color:#cbd5e1;">&copy; #{year} Jobcelis. All rights reserved.</p>
            </td></tr>
          </table>
        </td></tr>
      </table>
    </body>
    </html>
    """
  end
end
