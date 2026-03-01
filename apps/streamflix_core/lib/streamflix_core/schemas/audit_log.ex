defmodule StreamflixCore.Schemas.AuditLog do
  @moduledoc """
  Immutable audit log entry. Records every significant action in the platform.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "audit_logs" do
    field :user_id, :binary_id
    field :project_id, :binary_id
    field :action, :string
    field :resource_type, :string
    field :resource_id, :binary_id
    field :metadata, :map, default: %{}
    field :ip_address, :string
    field :user_agent, :string

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [:user_id, :project_id, :action, :resource_type, :resource_id, :metadata, :ip_address, :user_agent])
    |> validate_required([:action])
  end
end
