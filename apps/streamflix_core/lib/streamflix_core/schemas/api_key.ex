defmodule StreamflixCore.Schemas.ApiKey do
  @moduledoc """
  API Key schema: used for Bearer token auth on all API requests.
  Stored hash only; prefix for display. Status active/inactive.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_scopes ~w(* events:read events:write webhooks:read webhooks:write jobs:read jobs:write deliveries:read deliveries:retry)

  schema "api_keys" do
    field :prefix, :string
    field :key_hash, :string
    field :name, :string, default: "Default"
    field :status, :string, default: "active"
    field :scopes, {:array, :string}, default: ["*"]
    field :allowed_ips, {:array, :string}, default: []

    belongs_to :project, StreamflixCore.Schemas.Project

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:project_id, :prefix, :key_hash, :name, :status, :scopes, :allowed_ips])
    |> validate_required([:project_id, :prefix, :key_hash])
    |> validate_inclusion(:status, ~w(active inactive))
    |> validate_scopes()
    |> foreign_key_constraint(:project_id)
  end

  defp validate_scopes(changeset) do
    case get_change(changeset, :scopes) do
      nil -> changeset
      scopes ->
        if Enum.all?(scopes, &(&1 in @valid_scopes)) do
          changeset
        else
          add_error(changeset, :scopes, "contains invalid scope(s)")
        end
    end
  end

  def valid_scopes, do: @valid_scopes
end
