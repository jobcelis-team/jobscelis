defmodule StreamflixCore.Schemas.Consent do
  @moduledoc """
  GDPR consent record. Tracks when a user grants/revokes consent for each purpose.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_purposes ~w(terms privacy data_processing marketing)

  schema "consents" do
    field(:user_id, :binary_id)
    field(:purpose, :string)
    field(:granted_at, :utc_datetime_usec)
    field(:revoked_at, :utc_datetime_usec)
    field(:ip_address, StreamflixCore.Encrypted.Binary)
    field(:version, :string, default: "1.0")

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(consent, attrs) do
    consent
    |> cast(attrs, [:user_id, :purpose, :granted_at, :revoked_at, :ip_address, :version])
    |> validate_required([:user_id, :purpose, :granted_at])
    |> validate_inclusion(:purpose, @valid_purposes)
    |> foreign_key_constraint(:user_id)
  end

  def revoke_changeset(consent) do
    consent
    |> change(%{revoked_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)})
  end
end
