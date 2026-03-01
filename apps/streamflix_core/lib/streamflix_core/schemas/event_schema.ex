defmodule StreamflixCore.Schemas.EventSchema do
  @moduledoc """
  EventSchema: JSON Schema definition for validating event payloads per topic.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "event_schemas" do
    field(:topic, :string)
    field(:schema, :map)
    field(:version, :integer, default: 1)
    field(:status, :string, default: "active")

    belongs_to(:project, StreamflixCore.Schemas.Project)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(event_schema, attrs) do
    event_schema
    |> cast(attrs, [:project_id, :topic, :schema, :version, :status])
    |> validate_required([:project_id, :topic, :schema])
    |> validate_inclusion(:status, ~w(active inactive))
    |> unique_constraint([:project_id, :topic, :version])
    |> foreign_key_constraint(:project_id)
  end
end
