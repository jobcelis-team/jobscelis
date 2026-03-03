defmodule StreamflixCore.Schemas.WebhookEvent do
  @moduledoc """
  WebhookEvent schema: user-emitted event (topic + payload).
  Stored in webhook_events table to avoid conflict with event_sourcing events.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "webhook_events" do
    field(:topic, :string)
    field(:payload, :map, default: %{})
    field(:status, :string, default: "active")
    field(:occurred_at, :utc_datetime_usec)
    field(:deliver_at, :utc_datetime_usec)
    field(:payload_hash, :string)
    field(:idempotency_key, :string)

    belongs_to(:project, StreamflixCore.Schemas.Project)
    has_many(:deliveries, StreamflixCore.Schemas.Delivery, foreign_key: :event_id)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :project_id,
      :topic,
      :payload,
      :status,
      :occurred_at,
      :deliver_at,
      :payload_hash,
      :idempotency_key
    ])
    |> validate_required([:project_id, :payload, :occurred_at])
    |> validate_inclusion(:status, ~w(active inactive))
    |> foreign_key_constraint(:project_id)
    |> unique_constraint([:project_id, :idempotency_key],
      name: :webhook_events_project_idempotency_key_index
    )
  end
end
