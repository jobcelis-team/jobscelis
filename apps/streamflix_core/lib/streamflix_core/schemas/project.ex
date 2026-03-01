defmodule StreamflixCore.Schemas.Project do
  @moduledoc """
  Project schema: workspace for a user. Holds webhooks, events, jobs.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "projects" do
    field :name, :string
    field :status, :string, default: "active"
    field :settings, :map, default: %{}
    field :user_id, :binary_id
    field :is_default, :boolean, default: false

    has_many :api_keys, StreamflixCore.Schemas.ApiKey
    has_many :webhooks, StreamflixCore.Schemas.Webhook
    has_many :webhook_events, StreamflixCore.Schemas.WebhookEvent
    has_many :jobs, StreamflixCore.Schemas.Job
    has_many :members, StreamflixCore.Schemas.ProjectMember

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(project, attrs) do
    project
    |> cast(attrs, [:user_id, :name, :status, :settings, :is_default])
    |> validate_required([:name])
    |> validate_inclusion(:status, ~w(active inactive))
    |> foreign_key_constraint(:user_id)
  end
end
