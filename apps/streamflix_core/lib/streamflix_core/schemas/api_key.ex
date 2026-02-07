defmodule StreamflixCore.Schemas.ApiKey do
  @moduledoc """
  API Key schema: used for Bearer token auth on all API requests.
  Stored hash only; prefix for display. Status active/inactive.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "api_keys" do
    field :prefix, :string
    field :key_hash, :string
    field :name, :string, default: "Default"
    field :status, :string, default: "active"

    belongs_to :project, StreamflixCore.Schemas.Project

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:project_id, :prefix, :key_hash, :name, :status])
    |> validate_required([:project_id, :prefix, :key_hash])
    |> validate_inclusion(:status, ~w(active inactive))
    |> foreign_key_constraint(:project_id)
  end
end
