defmodule StreamflixCore.Schemas.Project do
  @moduledoc """
  Project schema: workspace for a user. Holds webhooks, events, jobs.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "projects" do
    field(:name, :string)
    field(:status, :string, default: "active")
    field(:settings, :map, default: %{})
    field(:user_id, :binary_id)
    field(:is_default, :boolean, default: false)
    field(:rate_limit_events_per_minute, :integer, default: 1000)
    field(:rate_limit_api_calls_per_minute, :integer, default: 500)
    field(:retention_days, :integer)
    field(:retention_policy, :map, default: %{})

    has_many(:api_keys, StreamflixCore.Schemas.ApiKey)
    has_many(:webhooks, StreamflixCore.Schemas.Webhook)
    has_many(:webhook_events, StreamflixCore.Schemas.WebhookEvent)
    has_many(:jobs, StreamflixCore.Schemas.Job)
    has_many(:members, StreamflixCore.Schemas.ProjectMember)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(project, attrs) do
    project
    |> cast(attrs, [
      :user_id,
      :name,
      :status,
      :settings,
      :is_default,
      :rate_limit_events_per_minute,
      :rate_limit_api_calls_per_minute,
      :retention_days,
      :retention_policy
    ])
    |> validate_required([:name])
    |> validate_inclusion(:status, ~w(active inactive))
    |> validate_number(:retention_days, greater_than_or_equal_to: 1)
    |> foreign_key_constraint(:user_id)
  end
end
