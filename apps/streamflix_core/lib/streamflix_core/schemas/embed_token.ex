defmodule StreamflixCore.Schemas.EmbedToken do
  @moduledoc """
  Embed token schema: short-lived tokens for the embeddable portal.
  Allows end-users to manage webhooks and view deliveries within
  a customer's application via an embedded widget.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_scopes ~w(webhooks:read webhooks:write deliveries:read deliveries:retry)

  schema "embed_tokens" do
    field(:prefix, :string)
    field(:token_hash, :string)
    field(:name, :string, default: "Default")
    field(:status, :string, default: "active")
    field(:scopes, {:array, :string}, default: @valid_scopes)
    field(:allowed_origins, {:array, :string}, default: [])
    field(:metadata, :map, default: %{})
    field(:expires_at, :utc_datetime_usec)

    belongs_to(:project, StreamflixCore.Schemas.Project)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(token, attrs) do
    token
    |> cast(attrs, [
      :project_id,
      :prefix,
      :token_hash,
      :name,
      :status,
      :scopes,
      :allowed_origins,
      :metadata,
      :expires_at
    ])
    |> validate_required([:project_id, :prefix, :token_hash])
    |> validate_inclusion(:status, ~w(active inactive))
    |> validate_scopes()
    |> foreign_key_constraint(:project_id)
    |> unique_constraint(:token_hash)
  end

  defp validate_scopes(changeset) do
    case get_change(changeset, :scopes) do
      nil ->
        changeset

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
