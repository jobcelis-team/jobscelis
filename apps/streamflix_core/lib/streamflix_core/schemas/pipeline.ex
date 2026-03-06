defmodule StreamflixCore.Schemas.Pipeline do
  @moduledoc """
  Event pipeline schema. Defines a processing chain:
  filter → transform → delay → deliver to webhook.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_statuses ~w(active inactive)

  schema "pipelines" do
    field(:name, :string)
    field(:status, :string, default: "active")
    field(:description, :string)

    # Which events trigger this pipeline
    field(:topics, {:array, :string}, default: [])

    # Steps executed in order
    field(:steps, {:array, :map}, default: [])

    # Target webhook (final delivery destination)
    field(:webhook_id, :binary_id)

    belongs_to(:project, StreamflixCore.Schemas.Project)

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(project_id name webhook_id)a
  @optional_fields ~w(status description topics steps)a

  def changeset(pipeline, attrs) do
    pipeline
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_steps()
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:webhook_id)
  end

  defp validate_steps(changeset) do
    case get_change(changeset, :steps) do
      nil ->
        changeset

      steps ->
        valid_types = ~w(filter transform delay)

        if Enum.all?(steps, fn step ->
             is_map(step) and Map.get(step, "type") in valid_types
           end) do
          changeset
        else
          add_error(
            changeset,
            :steps,
            "each step must have a valid type: filter, transform, delay"
          )
        end
    end
  end
end
