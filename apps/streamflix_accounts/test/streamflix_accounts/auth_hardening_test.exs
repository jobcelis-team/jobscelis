defmodule StreamflixAccounts.AuthHardeningTest do
  @moduledoc """
  Restricted-account login, shared MFA attempt counter for backup codes and
  password validation ordering (no Argon2 work on invalid input).
  """
  use StreamflixAccounts.DataCase, async: false

  alias StreamflixAccounts.PasswordPolicy
  alias StreamflixAccounts.Schemas.User

  @valid_password "SecurePass123!"

  defp unique_email, do: "harden#{System.unique_integer([:positive])}@example.com"

  defp register_user do
    attrs = %{email: unique_email(), password: @valid_password, name: "Hardening"}

    case StreamflixAccounts.register_user(attrs) do
      {:ok, user, _opts} -> user
      {:ok, user} -> user
    end
  end

  describe "restricted accounts (GDPR Art. 18)" do
    test "can still log in and use their token" do
      user = register_user()
      {:ok, restricted} = StreamflixAccounts.restrict_user(user, @valid_password)
      assert restricted.status == "restricted"

      assert {:ok, logged_in} = StreamflixAccounts.authenticate(user.email, @valid_password)
      assert logged_in.id == user.id

      {:ok, token, claims} = StreamflixAccounts.generate_token(logged_in)
      {:ok, _session} = StreamflixAccounts.create_session(user.id, claims["jti"])
      Cachex.del(:platform_cache, {:auth_user, user.id})
      assert {:ok, %{status: "restricted"}, _claims} = StreamflixAccounts.verify_token(token)
    end

    test "inactive accounts are still rejected" do
      user = register_user()
      {:ok, _} = StreamflixAccounts.deactivate_user(user.id)

      assert {:error, :account_inactive} =
               StreamflixAccounts.authenticate(user.email, @valid_password)
    end
  end

  describe "MFA backup codes share the attempt counter" do
    setup do
      user = register_user()
      {:ok, secret, _} = StreamflixAccounts.setup_mfa(user)

      {:ok, enabled, codes} =
        StreamflixAccounts.enable_mfa(user, secret, NimbleTOTP.verification_code(secret))

      on_exit(fn -> Cachex.del(:platform_cache, {:mfa_attempts, user.id}) end)
      %{user: enabled, codes: codes}
    end

    test "wrong backup codes end the challenge", %{user: user, codes: [code | _]} do
      results = for _ <- 1..5, do: StreamflixAccounts.verify_mfa_backup_code(user, "wrong-code")
      assert Enum.take(results, 4) |> Enum.all?(&(&1 == {:error, :invalid_code}))
      assert List.last(results) == {:error, :too_many_attempts}

      # Even a valid backup code is refused once the limit is reached
      assert {:error, :too_many_attempts} = StreamflixAccounts.verify_mfa_backup_code(user, code)
      assert StreamflixAccounts.verify_mfa_code(user, "000000") == :too_many_attempts
    end

    test "TOTP and backup failures add up", %{user: user} do
      for _ <- 1..3, do: StreamflixAccounts.verify_mfa_code(user, "000000")
      assert {:error, :invalid_code} = StreamflixAccounts.verify_mfa_backup_code(user, "nope")

      assert {:error, :too_many_attempts} =
               StreamflixAccounts.verify_mfa_backup_code(user, "nope")
    end

    test "a non-string code counts as a failure instead of crashing", %{user: user} do
      assert {:error, :invalid_code} = StreamflixAccounts.verify_mfa_backup_code(user, %{})
    end
  end

  describe "password hashing only for valid changesets" do
    test "invalid password is not hashed" do
      cs = User.password_changeset(%User{}, %{password: String.duplicate("Aa1", 100)})
      refute cs.valid?
      refute Ecto.Changeset.get_change(cs, :password_hash)

      cs = User.registration_changeset(%User{}, %{email: unique_email(), password: "short"})
      refute cs.valid?
      refute Ecto.Changeset.get_change(cs, :password_hash)
    end

    test "valid password is hashed" do
      cs = User.password_changeset(%User{}, %{password: "Another1Pass"})
      assert cs.valid?
      assert is_binary(Ecto.Changeset.get_change(cs, :password_hash))
    end

    test "history check skips oversized passwords" do
      hash = Argon2.hash_pwd_salt(String.duplicate("A", 80))
      refute PasswordPolicy.password_in_history?(String.duplicate("A", 80), [hash])
    end
  end

  describe "password changes validate before Argon2" do
    test "update_password rejects an oversized password before checking anything" do
      user = register_user()
      long = "Aa1" <> String.duplicate("x", 100)

      # Wrong current password, but the policy error comes first
      assert {:error, %Ecto.Changeset{} = cs} =
               StreamflixAccounts.update_password(user, "WrongPass123", long)

      assert %{password: [_ | _]} = errors_on(cs)
      # No failed-login attempt recorded for the (never checked) current password
      assert StreamflixCore.Repo.get!(User, user.id).failed_login_attempts == 0
    end

    test "reset_user_password rejects an oversized password" do
      user = register_user()
      {:ok, token, _} = StreamflixAccounts.generate_reset_password_token(user.email)
      long = "Aa1" <> String.duplicate("x", 100)

      assert {:error, %Ecto.Changeset{}} = StreamflixAccounts.reset_user_password(token, long)
      # The token is still valid: nothing was consumed
      assert {:ok, _} = StreamflixAccounts.verify_reset_password_token(token)
    end

    test "reset_user_password still rejects a recently used password" do
      user = register_user()
      {:ok, token, _} = StreamflixAccounts.generate_reset_password_token(user.email)

      assert {:error, :password_recently_used} =
               StreamflixAccounts.reset_user_password(token, @valid_password)
    end
  end

  defp errors_on(changeset),
    do: Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
end
