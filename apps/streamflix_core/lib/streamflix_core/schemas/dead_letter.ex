defmodule StreamflixCore.Schemas.DeadLetter do
  @moduledoc """
  Dead Letter Queue entry. Created when a delivery exhausts all retry attempts.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "dead_letters" do
    field :original_payload, :map, default: %{}
    field :last_error, :string
    field :last_response_status, :integer
    field :attempts_exhausted, :integer, default: 5
    field :resolved, :boolean, default: false
    field :resolved_at, :utc_datetime_usec

    belongs_to :project, StreamflixCore.Schemas.Project
    belongs_to :delivery, StreamflixCore.Schemas.Delivery
    belongs_to :event, StreamflixCore.Schemas.WebhookEvent
    belongs_to :webhook, StreamflixCore.Schemas.Webhook

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(dead_letter, attrs) do
    dead_letter
    |> cast(attrs, [
      :project_id, :delivery_id, :event_id, :webhook_id,
      :original_payload, :last_error, :last_response_status,
      :attempts_exhausted, :resolved, :resolved_at
    ])
    |> validate_required([:project_id, :original_payload])
    |> foreign_key_constraint(:project_id)
  end
end
