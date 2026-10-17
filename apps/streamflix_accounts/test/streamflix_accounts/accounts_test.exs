defmodule StreamflixAccounts.AccountsTest do
  @moduledoc """
  Tests for StreamflixAccounts: registration, authentication, MFA, lockout, sessions.
  """
  use StreamflixAccounts.DataCase, async: false

  import Ecto.Query

  @valid_password "SecurePass123!"

  defp unique_email, do: "test#{System.unique_integer([:positive])}@example.com"

  defp register_user(attrs \\ %{}) do
    base = %{email: unique_email(), password: @valid_password, name: "Test User"}
    attrs = Map.merge(base, attrs)

    case StreamflixAccounts.register_user(attrs) do
      {:ok, user, _opts} -> user
      {:ok, user} -> user
    end
  end

  describe "register_user/1" do
    test "registers user with valid attrs" do
      email = unique_email()
      attrs = %{email: email, password: @valid_password, name: "New User"}

      assert {:ok, user, _} = StreamflixAccounts.register_user(attrs)
      assert user.id
      assert user.status == "active"
      assert user.role == "user"
    end

    test "returns error for duplicate email" do
      email = unique_email()
      attrs = %{email: email, password: @valid_password, name: "User1"}
      assert {:ok, _, _} = StreamflixAccounts.register_user(attrs)

      assert {:error, :email_already_registered} =
               StreamflixAccounts.register_user(%{
                 email: email,
                 password: @valid_password,
                 name: "User2"
               })
    end

    test "returns error for weak password — too short" do
      attrs = %{email: unique_email(), password: "Ab1!", name: "User"}
      assert {:error, %Ecto.Changeset{}} = StreamflixAccounts.register_user(attrs)
    end

    test "returns error for password missing uppercase" do
      attrs = %{email: unique_email(), password: "alllowercase1", name: "User"}
      assert {:error, %Ecto.Changeset{}} = StreamflixAccounts.register_user(attrs)
    end

    test "returns error for password missing digit" do
      attrs = %{email: unique_email(), password: "NoDigitsHere!", name: "User"}
      assert {:error, %Ecto.Changeset{}} = StreamflixAccounts.register_user(attrs)
    end
  end

  describe "authenticate/2" do
    test "authenticates with correct credentials" do
      user = register_user()
      assert {:ok, authed} = StreamflixAccounts.authenticate(user.email, @valid_password)
      assert authed.id == user.id
    end

    test "rejects incorrect password" do
      user = register_user()

      assert {:error, :invalid_credentials} =
               StreamflixAccounts.authenticate(user.email, "Wrong1234")
    end

    test "rejects non-existent email" do
      assert {:error, :invalid_credentials} =
               StreamflixAccounts.authenticate("nobody@example.com", @valid_password)
    end

    test "rejects inactive user" do
      user = register_user()
      {:ok, _} = StreamflixAccounts.update_user(user, %{status: "inactive"})

      assert {:error, :account_inactive} =
               StreamflixAccounts.authenticate(user.email, @valid_password)
    end

    test "increments failed_login_attempts on wrong password" do
      user = register_user()
      StreamflixAccounts.authenticate(user.email, "Wrong1234")

      updated = StreamflixAccounts.get_user(user.id)
      assert updated.failed_login_attempts == 1
    end

    test "locks account after 5 failed attempts" do
      user = register_user()

      for _ <- 1..5 do
        StreamflixAccounts.authenticate(user.email, "Wrong1234")
      end

      updated = StreamflixAccounts.get_user(user.id)
      assert updated.failed_login_attempts >= 5
      assert not is_nil(updated.locked_at)
    end

    test "rejects login when account is locked" do
      user = register_user()

      for _ <- 1..5 do
        StreamflixAccounts.authenticate(user.email, "Wrong1234")
      end

      assert {:error, :account_locked} =
               StreamflixAccounts.authenticate(user.email, @valid_password)
    end

    test "auto-unlocks after lockout expires" do
      user = register_user()

      # Lock the account
      for _ <- 1..5 do
        StreamflixAccounts.authenticate(user.email, "Wrong1234")
      end

      # Set locked_at to 16 minutes ago (lockout is 15 min)
      past = DateTime.add(DateTime.utc_now(), -16 * 60, :second)

      user
      |> Ecto.Changeset.change(locked_at: past)
      |> Repo.update!()

      assert {:ok, _} = StreamflixAccounts.authenticate(user.email, @valid_password)
    end
  end

  describe "MFA" do
    test "setup_mfa returns secret and URI" do
      user = register_user()
      assert {:ok, secret, uri} = StreamflixAccounts.setup_mfa(user)
      assert is_binary(secret)
      assert String.starts_with?(uri, "otpauth://")
    end

    test "enable_mfa with valid TOTP code succeeds" do
      user = register_user()
      {:ok, secret, _uri} = StreamflixAccounts.setup_mfa(user)
      valid_code = NimbleTOTP.verification_code(secret)

      assert {:ok, updated, backup_codes} =
               StreamflixAccounts.enable_mfa(user, secret, valid_code)

      assert updated.mfa_enabled == true
      assert length(backup_codes) == 10
    end

    test "enable_mfa with invalid code fails" do
      user = register_user()
      {:ok, secret, _uri} = StreamflixAccounts.setup_mfa(user)

      assert {:error, :invalid_code} = StreamflixAccounts.enable_mfa(user, secret, "000000")
    end

    test "verify_mfa_code with valid code returns true" do
      user = register_user()
      {:ok, secret, _uri} = StreamflixAccounts.setup_mfa(user)
      valid_code = NimbleTOTP.verification_code(secret)
      {:ok, updated, _} = StreamflixAccounts.enable_mfa(user, secret, valid_code)

      new_code = NimbleTOTP.verification_code(updated.mfa_secret)
      assert StreamflixAccounts.verify_mfa_code(updated, new_code) == true
    end

    test "verify_mfa_backup_code consumes the code" do
      user = register_user()
      {:ok, secret, _uri} = StreamflixAccounts.setup_mfa(user)
      valid_code = NimbleTOTP.verification_code(secret)
      {:ok, enabled_user, backup_codes} = StreamflixAccounts.enable_mfa(user, secret, valid_code)

      first_code = List.first(backup_codes)
      assert {:ok, updated} = StreamflixAccounts.verify_mfa_backup_code(enabled_user, first_code)
      assert length(updated.mfa_backup_codes) == length(enabled_user.mfa_backup_codes) - 1
    end
  end

  describe "login hardening" do
    defp mfa_user do
      user = register_user()
      {:ok, secret, _} = StreamflixAccounts.setup_mfa(user)

      {:ok, enabled, codes} =
        StreamflixAccounts.enable_mfa(user, secret, NimbleTOTP.verification_code(secret))

      {enabled, codes}
    end

    test "a TOTP code cannot be used twice" do
      {user, _} = mfa_user()
      code = NimbleTOTP.verification_code(user.mfa_secret)

      assert StreamflixAccounts.verify_mfa_code(user, code) == true
      assert StreamflixAccounts.verify_mfa_code(user, code) == false
    end

    test "too many wrong TOTP codes end the challenge" do
      {user, _} = mfa_user()
      results = for _ <- 1..5, do: StreamflixAccounts.verify_mfa_code(user, "000000")
      assert List.last(results) == :too_many_attempts

      code = NimbleTOTP.verification_code(user.mfa_secret)
      assert StreamflixAccounts.verify_mfa_code(user, code) == :too_many_attempts
      Cachex.del(:platform_cache, {:mfa_attempts, user.id})
    end

    test "a backup code works only once, even from a stale struct" do
      {user, [code | _]} = mfa_user()

      assert {:ok, _} = StreamflixAccounts.verify_mfa_backup_code(user, code)
      assert {:error, :invalid_code} = StreamflixAccounts.verify_mfa_backup_code(user, code)
    end

    test "an inactive account is only revealed to someone with the password" do
      user = register_user()
      {:ok, _} = StreamflixAccounts.update_user(user, %{status: "inactive"})

      assert {:error, :invalid_credentials} =
               StreamflixAccounts.authenticate(user.email, "Wrong1234")
    end

    test "failed attempts are counted atomically under concurrency" do
      user = register_user()

      1..4
      |> Task.async_stream(fn _ -> StreamflixAccounts.authenticate(user.email, "Wrong1234") end,
        max_concurrency: 4
      )
      |> Stream.run()

      assert StreamflixAccounts.get_user(user.id).failed_login_attempts == 4
    end

    test "changing the email requires verifying the new address" do
      user = register_user()

      user
      |> Ecto.Changeset.change(
        email_verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
      )
      |> Repo.update!()

      {:ok, _old_token} =
        StreamflixAccounts.generate_email_confirmation_token(StreamflixAccounts.get_user(user.id))

      assert {:ok, updated} =
               StreamflixAccounts.update_email(
                 StreamflixAccounts.get_user(user.id),
                 unique_email(),
                 @valid_password
               )

      assert is_nil(updated.email_verified_at)

      refute Repo.exists?(
               from(t in StreamflixAccounts.Schemas.UserToken, where: t.user_id == ^user.id)
             )
    end
  end

  describe "update_password/3" do
    test "updates with correct current password" do
      user = register_user()
      new_pass = "NewSecure456!"
      assert {:ok, _} = StreamflixAccounts.update_password(user, @valid_password, new_pass)

      assert {:ok, _} = StreamflixAccounts.authenticate(user.email, new_pass)
    end

    test "rejects wrong current password" do
      user = register_user()

      assert {:error, :wrong_password} =
               StreamflixAccounts.update_password(user, "WrongPass1", "NewSecure456!")
    end
  end

  describe "sessions" do
    test "create_session creates a session record" do
      user = register_user()
      jti = Ecto.UUID.generate()
      assert {:ok, session} = StreamflixAccounts.create_session(user.id, jti)
      assert session.user_id == user.id
      assert session.token_jti == jti
    end

    test "list_sessions returns active sessions" do
      user = register_user()
      jti1 = Ecto.UUID.generate()
      jti2 = Ecto.UUID.generate()
      {:ok, _} = StreamflixAccounts.create_session(user.id, jti1)
      {:ok, _} = StreamflixAccounts.create_session(user.id, jti2)

      sessions = StreamflixAccounts.list_sessions(user.id)
      assert length(sessions) == 2
    end

    test "revoke_session marks session as revoked" do
      user = register_user()
      jti = Ecto.UUID.generate()
      {:ok, session} = StreamflixAccounts.create_session(user.id, jti)

      assert {:ok, revoked} = StreamflixAccounts.revoke_session(session.id, user.id)
      assert not is_nil(revoked.revoked_at)
    end

    test "revoke_all_sessions revokes all except excluded JTI" do
      user = register_user()
      jti1 = Ecto.UUID.generate()
      jti2 = Ecto.UUID.generate()
      {:ok, _} = StreamflixAccounts.create_session(user.id, jti1)
      {:ok, _} = StreamflixAccounts.create_session(user.id, jti2)

      assert {:ok, 1} = StreamflixAccounts.revoke_all_sessions(user.id, except_jti: jti1)
      sessions = StreamflixAccounts.list_sessions(user.id)
      assert length(sessions) == 1
      assert hd(sessions).token_jti == jti1
    end
  end

  describe "update_user_timezone/2" do
    test "stores a valid IANA zone or UTC" do
      user = register_user()

      assert {:ok, %{timezone: "America/Guayaquil"}} =
               StreamflixAccounts.update_user_timezone(user, "America/Guayaquil")

      assert {:ok, %{timezone: "America/Argentina/Buenos_Aires"}} =
               StreamflixAccounts.update_user_timezone(user, "America/Argentina/Buenos_Aires")

      assert {:ok, %{timezone: "UTC"}} = StreamflixAccounts.update_user_timezone(user, "UTC")
    end

    test "blank resets to automatic (browser timezone)" do
      user = register_user()
      {:ok, user} = StreamflixAccounts.update_user_timezone(user, "UTC")
      assert {:ok, %{timezone: nil}} = StreamflixAccounts.update_user_timezone(user, "")
    end

    test "rejects values that are not zone names" do
      user = register_user()

      for bad <- [
            "<script>",
            "America/Guayaquil; DROP",
            "../etc/passwd",
            String.duplicate("A/b", 30)
          ] do
        assert {:error, _} = StreamflixAccounts.update_user_timezone(user, bad)
      end
    end
  end

  describe "cached session user" do
    test "user changes are visible to sessions immediately" do
      user = register_user()

      # Warm Guardian's per-user cache
      assert {:ok, %{timezone: nil}} =
               StreamflixAccounts.Guardian.resource_from_claims(%{"sub" => user.id})

      {:ok, _} = StreamflixAccounts.update_user_timezone(user, "Asia/Tokyo")
      {:ok, _} = StreamflixAccounts.update_name(user, "Renamed")

      assert {:ok, %{timezone: "Asia/Tokyo", name: "Renamed"}} =
               StreamflixAccounts.Guardian.resource_from_claims(%{"sub" => user.id})
    end

    test "the web-session user cache is invalidated too" do
      user = register_user()
      Cachex.put(:platform_cache, {:auth_user, user.id}, :stale)

      {:ok, _} = StreamflixAccounts.update_user_timezone(user, "Europe/Madrid")

      assert {:ok, nil} = Cachex.get(:platform_cache, {:auth_user, user.id})
    end

    test "the cached user expires after its own TTL, not the cache default" do
      user = register_user()
      {:ok, _} = StreamflixAccounts.Guardian.resource_from_claims(%{"sub" => user.id})

      assert {:ok, ttl} = Cachex.ttl(:platform_cache, {:user, user.id})
      assert is_integer(ttl) and ttl <= :timer.seconds(120)
    end
  end

  describe "token verification hardening" do
    defp session_token(user) do
      {:ok, token, claims} = StreamflixAccounts.generate_token(user)
      {:ok, _} = StreamflixAccounts.create_session(user.id, claims["jti"])
      {token, claims}
    end

    test "an access token with a session authenticates" do
      user = register_user()
      {token, _} = session_token(user)
      assert {:ok, %{id: id}, _} = StreamflixAccounts.verify_token(token)
      assert id == user.id
    end

    test "an MFA challenge token is not an access token" do
      user = register_user()

      {:ok, mfa_token, claims} =
        StreamflixAccounts.Guardian.encode_and_sign(user, %{"type" => "mfa_challenge"},
          ttl: {5, :minute}
        )

      assert {:error, :invalid_token_type} = StreamflixAccounts.verify_token(mfa_token)

      # Even with a session row for its jti it must not authenticate
      {:ok, _} = StreamflixAccounts.create_session(user.id, claims["jti"])
      assert {:error, :invalid_token_type} = StreamflixAccounts.verify_token(mfa_token)

      assert {:error, _} = StreamflixAccounts.Services.Authentication.refresh_token(mfa_token)
    end

    test "a token without a session row is rejected" do
      user = register_user()
      {:ok, token, _} = StreamflixAccounts.generate_token(user)
      assert {:error, :session_revoked} = StreamflixAccounts.verify_token(token)
    end

    test "refresh issues a tracked token and revokes the old one" do
      user = register_user()
      {old, _} = session_token(user)

      assert {:ok, new, new_claims} =
               StreamflixAccounts.Services.Authentication.refresh_token(old)

      assert {:ok, _, _} = StreamflixAccounts.verify_token(new)
      assert {:error, :session_revoked} = StreamflixAccounts.verify_token(old)

      assert Enum.any?(
               StreamflixAccounts.list_sessions(user.id),
               &(&1.token_jti == new_claims["jti"])
             )

      # A revoked token cannot be refreshed into a new one
      assert {:error, :session_revoked} =
               StreamflixAccounts.Services.Authentication.refresh_token(old)
    end

    test "a deactivated user can no longer authenticate" do
      user = register_user()
      {token, _} = session_token(user)
      {:ok, _} = StreamflixAccounts.deactivate_user(user.id)
      assert {:error, _} = StreamflixAccounts.verify_token(token)
    end
  end
end
