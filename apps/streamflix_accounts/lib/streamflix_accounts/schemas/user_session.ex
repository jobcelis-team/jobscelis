defmodule StreamflixAccounts.Schemas.UserSession do
  @moduledoc """
  Tracks active JWT sessions per user. Enables listing and revoking sessions.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_sessions" do
    field(:user_id, :binary_id)
    field(:token_jti, :string)
    field(:ip_address, :string)
    field(:user_agent, :string)
    field(:device_info, :string)
    field(:last_activity_at, :utc_datetime_usec)
    field(:revoked_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @required_fields [:user_id, :token_jti]
  @optional_fields [:ip_address, :user_agent, :device_info, :last_activity_at, :revoked_at]

  def changeset(session, attrs) do
    session
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:token_jti)
  end

  # Query helpers

  def active(query \\ __MODULE__) do
    from(s in query, where: is_nil(s.revoked_at))
  end

  def for_user(query \\ __MODULE__, user_id) do
    from(s in query, where: s.user_id == ^user_id)
  end

  def by_jti(query \\ __MODULE__, jti) do
    from(s in query, where: s.token_jti == ^jti)
  end
end
