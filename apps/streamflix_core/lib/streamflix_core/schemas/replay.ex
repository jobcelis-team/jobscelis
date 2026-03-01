defmodule StreamflixCore.Schemas.Replay do
  @moduledoc """
  Schema for event replay sessions. Tracks progress of re-sending events to webhooks.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "replays" do
    field :status, :string, default: "pending"
    field :filters, :map, default: %{}
    field :total_events, :integer, default: 0
    field :processed_events, :integer, default: 0
    field :created_by, :binary_id
    field :started_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec

    belongs_to :project, StreamflixCore.Schemas.Project

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(replay, attrs) do
    replay
    |> cast(attrs, [:project_id, :status, :filters, :total_events, :processed_events, :created_by, :started_at, :completed_at])
    |> validate_required([:project_id])
    |> validate_inclusion(:status, ["pending", "running", "completed", "failed", "cancelled"])
    |> foreign_key_constraint(:project_id)
  end
end
