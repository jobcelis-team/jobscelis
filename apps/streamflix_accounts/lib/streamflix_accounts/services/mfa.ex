defmodule StreamflixAccounts.Services.MFA do
  @moduledoc """
  MFA/TOTP service — secret generation, code verification, backup codes.
  Uses nimble_totp for TOTP operations.
  """

  import Ecto.Query

  alias StreamflixAccounts.Schemas.User
  alias StreamflixCore.Repo
  alias StreamflixCore.Audit

  @issuer "Jobcelis"
  @backup_code_count 10
  @backup_code_length 8

  # ── Secret & URI ──────────────────────────────────────────────────

  @doc "Generate a new random TOTP secret (raw 20-byte binary)."
  def generate_secret do
    NimbleTOTP.secret()
  end

  @doc "Build the otpauth:// URI for QR code generation."
  def generate_otpauth_uri(secret, email) do
    NimbleTOTP.otpauth_uri("#{@issuer}:#{email}", secret, issuer: @issuer)
  end

  # ── Code verification ─────────────────────────────────────────────

  @doc "Verify a 6-digit TOTP code against a secret. Allows 1 period of clock drift."
  def verify_code(secret, code) when is_binary(secret) and is_binary(code) do
    # since: allows 1 period (30s) of drift
    NimbleTOTP.valid?(secret, code, since: System.system_time(:second) - 30)
  end

  def verify_code(_, _), do: false

  @period 30

  @doc """
  Verify a login TOTP code and consume its time step, so the same code (or an
  older one) cannot be replayed within its validity window. The consume step is
  a conditional update, which also makes two concurrent uses of one code fail.
  """
  def verify_and_consume_code(%User{mfa_secret: secret} = user, code)
      when is_binary(secret) and is_binary(code) do
    now = System.system_time(:second)

    # Current step first, then one step of clock drift
    case Enum.find([now, now - @period], &NimbleTOTP.valid?(secret, code, time: &1)) do
      nil -> false
      matched -> consume_step(user, DateTime.from_unix!(matched - rem(matched, @period)))
    end
  end

  def verify_and_consume_code(_, _), do: false

  defp consume_step(user, step_start) do
    {count, _} =
      from(u in User,
        where: u.id == ^user.id,
        where: is_nil(u.mfa_last_used_at) or u.mfa_last_used_at < ^step_start
      )
      |> Repo.update_all(set: [mfa_last_used_at: step_start])

    count == 1
  end

  # ── Backup codes ──────────────────────────────────────────────────

  @doc "Generate a list of random alphanumeric backup codes."
  def generate_backup_codes do
    Enum.map(1..@backup_code_count, fn _ ->
      :crypto.strong_rand_bytes(@backup_code_length)
      |> Base.encode32(case: :lower, padding: false)
      |> binary_part(0, @backup_code_length)
    end)
  end

  @doc "SHA-256 hash each backup code for safe DB storage."
  def hash_backup_codes(codes) when is_list(codes) do
    Enum.map(codes, &hash_code/1)
  end

  defp hash_code(code) do
    :crypto.hash(:sha256, String.downcase(String.trim(code))) |> Base.encode16(case: :lower)
  end

  @doc """
  Verify a backup code against the user's stored hashed codes.
  If valid, consume the code (remove it from the list) and return {:ok, updated_user}.
  """
  def verify_backup_code(%User{} = user, code) when is_binary(code) do
    hashed = hash_code(code)

    # Removed atomically (array_remove guarded by the code still being present):
    # two concurrent logins with the same backup code cannot both succeed.
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    {count, rows} =
      from(u in User,
        where: u.id == ^user.id and fragment("? = ANY(?)", ^hashed, u.mfa_backup_codes),
        select: u.mfa_backup_codes,
        update: [
          set: [
            mfa_backup_codes: fragment("array_remove(?, ?)", u.mfa_backup_codes, ^hashed),
            updated_at: ^now
          ]
        ]
      )
      |> Repo.update_all([])

    case {count, rows} do
      {1, [remaining]} ->
        Audit.record("user.mfa_backup_used",
          user_id: user.id,
          resource_type: "user",
          resource_id: user.id,
          metadata: %{remaining_codes: length(remaining)}
        )

        {:ok, %{user | mfa_backup_codes: remaining}}

      _ ->
        {:error, :invalid_code}
    end
  end

  # ── Enable / Disable MFA ──────────────────────────────────────────

  @doc """
  Enable MFA for a user. Requires the secret being set up and a valid TOTP code
  to confirm the user has properly configured their authenticator app.
  Returns {:ok, user, backup_codes} on success.
  """
  def enable_mfa(%User{} = user, secret, code) when is_binary(secret) and is_binary(code) do
    if verify_code(secret, code) do
      backup_codes = generate_backup_codes()
      hashed_codes = hash_backup_codes(backup_codes)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      changeset =
        User.mfa_changeset(user, %{
          mfa_enabled: true,
          mfa_secret: secret,
          mfa_backup_codes: hashed_codes,
          mfa_enabled_at: now
        })

      case Repo.update(changeset) do
        {:ok, updated_user} ->
          Audit.record("user.mfa_enabled",
            user_id: user.id,
            resource_type: "user",
            resource_id: user.id
          )

          {:ok, updated_user, backup_codes}

        error ->
          error
      end
    else
      {:error, :invalid_code}
    end
  end

  @doc """
  Disable MFA for a user. Requires current password for security.
  """
  def disable_mfa(%User{} = user, password) when is_binary(password) do
    case StreamflixAccounts.Services.Authentication.authenticate(user.email, password) do
      {:ok, _} ->
        changeset =
          User.mfa_changeset(user, %{
            mfa_enabled: false,
            mfa_secret: nil,
            mfa_backup_codes: [],
            mfa_enabled_at: nil
          })

        case Repo.update(changeset) do
          {:ok, updated_user} ->
            Audit.record("user.mfa_disabled",
              user_id: user.id,
              resource_type: "user",
              resource_id: user.id
            )

            {:ok, updated_user}

          error ->
            error
        end

      {:error, _} ->
        {:error, :wrong_password}
    end
  end

  @doc "Regenerate backup codes for a user who already has MFA enabled."
  def regenerate_backup_codes(%User{mfa_enabled: true} = user) do
    backup_codes = generate_backup_codes()
    hashed_codes = hash_backup_codes(backup_codes)

    case user |> User.mfa_changeset(%{mfa_backup_codes: hashed_codes}) |> Repo.update() do
      {:ok, updated_user} ->
        {:ok, updated_user, backup_codes}

      error ->
        error
    end
  end

  def regenerate_backup_codes(_), do: {:error, :mfa_not_enabled}
end
