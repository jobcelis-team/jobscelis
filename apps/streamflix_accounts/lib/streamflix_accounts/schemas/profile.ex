defmodule StreamflixAccounts.Schemas.Profile do
  @moduledoc """
  Profile schema for StreamFlix.
  Each user can have multiple profiles (like Netflix).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "profiles" do
    field :name, :string
    field :avatar_url, :string
    field :is_kids, :boolean, default: false
    field :language, :string, default: "en"
    field :maturity_level, :string, default: "all"
    field :preferences, :map, default: %{}
    field :status, :string, default: "active"

    belongs_to :user, StreamflixAccounts.Schemas.User

    timestamps()
  end

  @required_fields [:name, :user_id]
  @optional_fields [:avatar_url, :is_kids, :language, :maturity_level, :preferences, :status]

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 50)
    |> validate_inclusion(:language, ["en", "es", "pt", "fr", "de", "it", "ja", "ko"])
    |> validate_inclusion(:maturity_level, ["all", "pg", "pg13", "r", "nc17"])
    |> validate_inclusion(:status, ["active", "inactive"])
    |> foreign_key_constraint(:user_id)
  end

  # ============================================
  # AVATARS
  # ============================================

  @avatars [
    "/images/avatars/avatar1.png",
    "/images/avatars/avatar2.png",
    "/images/avatars/avatar3.png",
    "/images/avatars/avatar4.png",
    "/images/avatars/avatar5.png",
    "/images/avatars/avatar6.png",
    "/images/avatars/avatar7.png",
    "/images/avatars/avatar8.png"
  ]

  def available_avatars, do: @avatars

  def random_avatar do
    Enum.random(@avatars)
  end
end
