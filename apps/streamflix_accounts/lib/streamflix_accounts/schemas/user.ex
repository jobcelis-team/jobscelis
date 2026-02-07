defmodule StreamflixAccounts.Schemas.User do
  @moduledoc """
  User schema for StreamFlix accounts.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :name, :string
    field :status, :string, default: "active"
    field :role, :string, default: "user"
    field :email_verified_at, :utc_datetime
    field :last_login_at, :utc_datetime

    timestamps()
  end

  @required_fields [:email]
  @optional_fields [:name, :status, :role, :email_verified_at, :last_login_at]

  def changeset(user, attrs) do
    user
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_email()
    |> validate_inclusion(:role, ["user", "admin", "moderator", "superadmin"])
    |> unique_constraint(:email)
  end

  def registration_changeset(user, attrs) do
    user
    |> changeset(attrs)
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_password()
    |> hash_password()
  end

  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_password()
    |> hash_password()
  end

  # ============================================
  # VALIDATIONS
  # ============================================

  defp validate_email(changeset) do
    changeset
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> validate_length(:email, max: 160)
    |> update_change(:email, &String.downcase/1)
  end

  defp validate_password(changeset) do
    changeset
    |> validate_length(:password, min: 8, max: 72)
    |> validate_format(:password, ~r/[a-z]/, message: "must have at least one lowercase letter")
    |> validate_format(:password, ~r/[A-Z]/, message: "must have at least one uppercase letter")
    |> validate_format(:password, ~r/[0-9]/, message: "must have at least one digit")
  end

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset
      password ->
        # Using Pbkdf2 instead of Bcrypt (pure Elixir, no C compiler needed on Windows)
        put_change(changeset, :password_hash, Pbkdf2.hash_pwd_salt(password))
    end
  end

  # ============================================
  # QUERIES
  # ============================================

  def active(query \\ __MODULE__) do
    from u in query, where: u.status == "active"
  end

  def by_email(query \\ __MODULE__, email) do
    from u in query, where: u.email == ^String.downcase(email)
  end

  def admin(query \\ __MODULE__) do
    from u in query, where: u.role == "admin"
  end

  def is_admin?(%__MODULE__{} = user) do
    user.role == "admin"
  end
end
