defmodule StreamflixAccounts.Schemas.PasswordHistory do
  @moduledoc """
  Stores historical password hashes for a user.
  Used to prevent password reuse (last N passwords).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "password_history" do
    field(:user_id, :binary_id)
    field(:password_hash, :string)

    timestamps(updated_at: false)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:user_id, :password_hash])
    |> validate_required([:user_id, :password_hash])
  end
end
