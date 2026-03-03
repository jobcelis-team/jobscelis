defmodule StreamflixAccounts.Services.MFA do
  @moduledoc """
  MFA/TOTP service — secret generation, code verification, backup codes.
  Uses nimble_totp for TOTP operations.
  """

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

    if hashed in user.mfa_backup_codes do
      remaining = List.delete(user.mfa_backup_codes, hashed)

      case user |> User.mfa_changeset(%{mfa_backup_codes: remaining}) |> Repo.update() do
        {:ok, updated_user} ->
          Audit.record("user.mfa_backup_used",
            user_id: user.id,
            resource_type: "user",
            resource_id: user.id,
            metadata: %{remaining_codes: length(remaining)}
          )

          {:ok, updated_user}

        error ->
          error
      end
    else
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
