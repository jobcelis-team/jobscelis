defmodule StreamflixCore.Schemas.NotificationChannel do
  @moduledoc """
  External notification channel configuration per project.
  Supports email, Slack, Discord, and meta-webhook channels.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_event_types ~w(
    webhook_failing circuit_open circuit_closed
    dlq_entry job_failed replay_completed
    security_anomaly system_health
  )

  schema "notification_channels" do
    belongs_to(:project, StreamflixCore.Schemas.Project)

    # Email
    field(:email_enabled, :boolean, default: false)
    field(:email_address, :string)

    # Slack
    field(:slack_enabled, :boolean, default: false)
    field(:slack_webhook_url, :string)

    # Discord
    field(:discord_enabled, :boolean, default: false)
    field(:discord_webhook_url, :string)

    # Meta-webhook
    field(:meta_webhook_enabled, :boolean, default: false)
    field(:meta_webhook_url, :string)
    field(:meta_webhook_secret, :string)

    # Event type filter (nil = all events)
    field(:event_types, {:array, :string})

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields [:project_id]
  @optional_fields [
    :email_enabled,
    :email_address,
    :slack_enabled,
    :slack_webhook_url,
    :discord_enabled,
    :discord_webhook_url,
    :meta_webhook_enabled,
    :meta_webhook_url,
    :meta_webhook_secret,
    :event_types
  ]

  def changeset(channel, attrs) do
    channel
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:project_id)
    |> validate_email_config()
    |> validate_slack_config()
    |> validate_discord_config()
    |> validate_meta_webhook_config()
    |> validate_event_types()
  end

  defp validate_email_config(changeset) do
    if get_field(changeset, :email_enabled) do
      validate_required(changeset, [:email_address])
      |> validate_format(:email_address, ~r/@/)
    else
      changeset
    end
  end

  defp validate_slack_config(changeset) do
    if get_field(changeset, :slack_enabled) do
      validate_required(changeset, [:slack_webhook_url])
      |> validate_format(:slack_webhook_url, ~r{^https://hooks\.slack\.com/})
    else
      changeset
    end
  end

  defp validate_discord_config(changeset) do
    if get_field(changeset, :discord_enabled) do
      validate_required(changeset, [:discord_webhook_url])
      |> validate_format(:discord_webhook_url, ~r{^https://discord(app)?\.com/api/webhooks/})
    else
      changeset
    end
  end

  defp validate_meta_webhook_config(changeset) do
    if get_field(changeset, :meta_webhook_enabled) do
      validate_required(changeset, [:meta_webhook_url])
      |> validate_format(:meta_webhook_url, ~r{^https?://})
    else
      changeset
    end
  end

  defp validate_event_types(changeset) do
    case get_field(changeset, :event_types) do
      nil ->
        changeset

      types ->
        if Enum.all?(types, &(&1 in @valid_event_types)) do
          changeset
        else
          add_error(changeset, :event_types, "contains invalid event types")
        end
    end
  end

  def valid_event_types, do: @valid_event_types
end
