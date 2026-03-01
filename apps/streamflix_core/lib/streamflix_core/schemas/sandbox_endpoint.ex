defmodule StreamflixCore.Schemas.SandboxEndpoint do
  @moduledoc """
  A temporary sandbox URL endpoint for testing webhooks (like RequestBin).
  Auto-expires after 24 hours.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sandbox_endpoints" do
    field(:slug, :string)
    field(:name, :string)
    field(:expires_at, :utc_datetime_usec)

    belongs_to(:project, StreamflixCore.Schemas.Project)
    has_many(:requests, StreamflixCore.Schemas.SandboxRequest, foreign_key: :endpoint_id)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(endpoint, attrs) do
    endpoint
    |> cast(attrs, [:project_id, :slug, :name, :expires_at])
    |> validate_required([:project_id, :slug, :expires_at])
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:project_id)
  end
end
