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
    field(:email, StreamflixCore.Encrypted.Binary)
    field(:password, :string, virtual: true)
    field(:password_hash, :string)
    field(:name, StreamflixCore.Encrypted.Binary)
    field(:email_hash, StreamflixCore.Hashed.HMAC)
    field(:status, :string, default: "active")
    field(:role, :string, default: "user")
    field(:email_verified_at, :utc_datetime)
    field(:last_login_at, :utc_datetime)
    field(:failed_login_attempts, :integer, default: 0)
    field(:locked_at, :utc_datetime_usec)

    # GDPR
    field(:processing_consent, :boolean, default: true)
    field(:restricted_at, :utc_datetime_usec)
    field(:restriction_reason, :string)

    # Preferences
    field(:last_project_id, :binary_id)

    # MFA / TOTP
    field(:mfa_enabled, :boolean, default: false)
    field(:mfa_secret, StreamflixCore.Encrypted.Binary)
    field(:mfa_backup_codes, {:array, :string}, default: [])
    field(:mfa_enabled_at, :utc_datetime)

    timestamps()
  end

  @required_fields [:email]
  @optional_fields [
    :name,
    :status,
    :role,
    :email_verified_at,
    :last_login_at,
    :failed_login_attempts,
    :locked_at,
    :processing_consent,
    :restricted_at,
    :restriction_reason,
    :last_project_id
  ]

  @max_failed_attempts 5
  @lockout_duration_minutes 15

  def max_failed_attempts, do: @max_failed_attempts
  def lockout_duration_minutes, do: @lockout_duration_minutes

  def locked?(%__MODULE__{locked_at: nil}), do: false

  def locked?(%__MODULE__{locked_at: locked_at}) do
    cutoff = DateTime.add(DateTime.utc_now(), -@lockout_duration_minutes * 60, :second)
    DateTime.compare(locked_at, cutoff) == :gt
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_email()
    |> validate_inclusion(:role, ["user", "admin", "moderator", "superadmin"])
    |> validate_inclusion(:status, ["active", "inactive", "restricted"])
    |> unique_constraint(:email_hash, message: "already registered")
    |> put_encrypted_email()
  end

  @doc "Changeset for GDPR-specific operations (restriction, objection)."
  def gdpr_changeset(user, attrs) do
    user
    |> cast(attrs, [:status, :processing_consent, :restricted_at, :restriction_reason])
    |> validate_inclusion(:status, ["active", "inactive", "restricted"])
  end

  @doc """
  Changeset for email-only updates. Does not touch password or role.
  Uniqueness is enforced at the DB level; the context checks beforehand
  that the email is not the same or already taken by another user.
  """
  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_required([:email])
    |> validate_email()
    |> unique_constraint(:email_hash, message: "already registered")
    |> put_encrypted_email()
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

  @doc """
  Changeset for enabling/disabling MFA. Kept separate from changeset/2 to prevent accidental updates.
  """
  def mfa_changeset(user, attrs) do
    user
    |> cast(attrs, [:mfa_enabled, :mfa_secret, :mfa_backup_codes, :mfa_enabled_at])
  end

  # ============================================
  # GDPR HELPERS
  # ============================================

  def restricted?(%__MODULE__{status: "restricted"}), do: true
  def restricted?(%__MODULE__{}), do: false

  def processing_allowed?(%__MODULE__{status: "restricted"}), do: false
  def processing_allowed?(%__MODULE__{processing_consent: false}), do: false
  def processing_allowed?(%__MODULE__{}), do: true

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
    |> validate_not_common_password()
  end

  defp validate_not_common_password(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset

      password ->
        if StreamflixAccounts.PasswordPolicy.common_password?(password) do
          add_error(changeset, :password, "is too common and easily guessed")
        else
          changeset
        end
    end
  end

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset

      password ->
        put_change(changeset, :password_hash, Argon2.hash_pwd_salt(password))
    end
  end

  defp put_encrypted_email(changeset) do
    case get_change(changeset, :email) do
      nil ->
        changeset

      email ->
        put_change(changeset, :email_hash, String.downcase(email))
    end
  end

  # ============================================
  # QUERIES
  # ============================================

  def active(query \\ __MODULE__) do
    from(u in query, where: u.status == "active")
  end

  def by_email(query \\ __MODULE__, email) do
    from(u in query, where: u.email_hash == ^String.downcase(email))
  end

  def admin(query \\ __MODULE__) do
    from(u in query, where: u.role == "admin")
  end

  def superadmin(query \\ __MODULE__) do
    from(u in query, where: u.role == "superadmin")
  end

  def admin?(%__MODULE__{} = user) do
    user.role in ["admin", "superadmin"]
  end

  def superadmin?(%__MODULE__{} = user) do
    user.role == "superadmin"
  end
end
