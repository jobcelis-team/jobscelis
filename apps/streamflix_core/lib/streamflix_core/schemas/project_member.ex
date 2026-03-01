defmodule StreamflixCore.Schemas.ProjectMember do
  @moduledoc """
  ProjectMember: team collaboration — tracks user membership in projects with roles.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_roles ~w(owner editor viewer)
  @valid_statuses ~w(pending active removed)

  schema "project_members" do
    field :role, :string, default: "viewer"
    field :status, :string, default: "pending"
    field :user_id, :binary_id
    field :invited_by, :binary_id

    belongs_to :project, StreamflixCore.Schemas.Project

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [:project_id, :user_id, :role, :status, :invited_by])
    |> validate_required([:project_id, :user_id, :role, :status])
    |> validate_inclusion(:role, @valid_roles)
    |> validate_inclusion(:status, @valid_statuses)
    |> unique_constraint([:project_id, :user_id])
    |> foreign_key_constraint(:project_id)
  end
end
