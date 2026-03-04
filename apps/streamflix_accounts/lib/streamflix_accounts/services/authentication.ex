defmodule StreamflixAccounts.Services.Authentication do
  @moduledoc """
  Authentication service using Guardian for JWT tokens.
  """

  alias StreamflixAccounts.Schemas.User
  alias StreamflixCore.Repo
  alias StreamflixCore.Audit

  @doc """
  Authenticates a user with email and password.
  opts: [ip_address: string, user_agent: string, method: string]
  """
  def authenticate(email, password, opts \\ []) do
    user = Repo.get_by(User, email_hash: String.downcase(email))

    case user do
      nil ->
        # Prevent timing attacks
        Argon2.no_user_verify()
        {:error, :invalid_credentials}

      user ->
        # Check if user is active
        if user.status != "active" do
          Argon2.no_user_verify()
          {:error, :account_inactive}
        else
          # Check if account is locked
          if User.locked?(user) do
            audit_login(user, "user.login_failed", opts, %{reason: "account_locked"})
            {:error, :account_locked}
          else
            # Auto-unlock if lockout expired
            user = maybe_auto_unlock(user)

            if verify_password(password, user.password_hash) do
              reset_failed_attempts(user)

              # Fire-and-forget: rehash + audit don't block the login response
              Task.Supervisor.start_child(StreamflixCore.TaskSupervisor, fn ->
                maybe_rehash(user, password)
                audit_login(user, "user.login", opts)
              end)

              {:ok, user}
            else
              user = increment_failed_attempts(user)

              Task.Supervisor.start_child(StreamflixCore.TaskSupervisor, fn ->
                audit_login(user, "user.login_failed", opts, %{
                  attempts: user.failed_login_attempts
                })
              end)

              if user.failed_login_attempts >= User.max_failed_attempts() do
                lock_account(user, opts)
                {:error, :account_locked}
              else
                {:error, :invalid_credentials}
              end
            end
          end
        end
    end
  end

  defp maybe_auto_unlock(%User{locked_at: nil} = user), do: user

  defp maybe_auto_unlock(%User{} = user) do
    if User.locked?(user) do
      user
    else
      # Lock expired — reset
      {:ok, user} =
        user
        |> Ecto.Changeset.change(failed_login_attempts: 0, locked_at: nil)
        |> Repo.update()

      Audit.record("user.unlocked",
        user_id: user.id,
        resource_type: "user",
        resource_id: user.id,
        metadata: %{reason: "lockout_expired"}
      )

      user
    end
  end

  defp increment_failed_attempts(%User{} = user) do
    new_count = (user.failed_login_attempts || 0) + 1

    {:ok, user} =
      user
      |> Ecto.Changeset.change(failed_login_attempts: new_count)
      |> Repo.update()

    user
  end

  defp reset_failed_attempts(%User{failed_login_attempts: 0}), do: :ok

  defp reset_failed_attempts(%User{} = user) do
    user
    |> Ecto.Changeset.change(failed_login_attempts: 0, locked_at: nil)
    |> Repo.update()
  end

  defp lock_account(%User{} = user, opts) do
    {:ok, _user} =
      user
      |> Ecto.Changeset.change(locked_at: DateTime.utc_now())
      |> Repo.update()

    Audit.record("user.locked",
      user_id: user.id,
      resource_type: "user",
      resource_id: user.id,
      metadata: %{
        failed_attempts: user.failed_login_attempts,
        lockout_minutes: User.lockout_duration_minutes()
      },
      ip_address: opts[:ip_address],
      user_agent: opts[:user_agent]
    )
  end

  defp audit_login(user, action, opts, metadata \\ %{}) do
    Audit.record(action,
      user_id: user.id,
      resource_type: "user",
      resource_id: user.id,
      metadata: Map.merge(metadata, %{method: opts[:method] || "password"}),
      ip_address: opts[:ip_address],
      user_agent: opts[:user_agent]
    )
  end

  # Verify password against either Argon2id or legacy PBKDF2 hashes.
  defp verify_password(password, "$argon2id$" <> _ = hash), do: Argon2.verify_pass(password, hash)

  defp verify_password(password, "$pbkdf2-sha512$" <> _ = hash),
    do: Pbkdf2.verify_pass(password, hash)

  defp verify_password(_password, _hash), do: false

  # Re-hash to Argon2id if stored hash is legacy PBKDF2.
  # Wrapped in try/rescue so a rehash failure never blocks login.
  defp maybe_rehash(user, password) do
    try do
      if needs_rehash?(user.password_hash) do
        new_hash = Argon2.hash_pwd_salt(password)

        user
        |> Ecto.Changeset.change(password_hash: new_hash)
        |> Repo.update()
      end
    rescue
      _ -> :ok
    end
  end

  # Any PBKDF2 hash needs migration to Argon2id.
  defp needs_rehash?("$pbkdf2-sha512$" <> _), do: true
  defp needs_rehash?(_), do: false

  @doc """
  Generates a JWT token for a user.
  """
  def generate_token(user) do
    StreamflixAccounts.Guardian.encode_and_sign(user, %{}, ttl: {7, :day})
  end

  @doc """
  Verifies and decodes a token.
  """
  def verify_token(token) do
    case StreamflixAccounts.Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        jti = claims["jti"]
        user_id = claims["sub"]

        if StreamflixAccounts.session_revoked?(jti) do
          {:error, :session_revoked}
        else
          case cached_get_user(user_id) do
            {:ok, user} -> {:ok, user, claims}
            error -> error
          end
        end

      error ->
        error
    end
  end

  # Cache user struct for 60s to avoid DB hit on every request.
  # Invalidated naturally by TTL expiry — acceptable for auth context.
  defp cached_get_user(user_id) do
    case Cachex.fetch(:platform_cache, {:auth_user, user_id}, fn _ ->
           case StreamflixCore.Repo.get(StreamflixAccounts.Schemas.User, user_id) do
             nil -> {:ignore, nil}
             user -> {:commit, user, ttl: :timer.seconds(60)}
           end
         end) do
      {:ok, user} -> {:ok, user}
      {:commit, user} -> {:ok, user}
      _ -> {:error, :resource_not_found}
    end
  end

  @doc """
  Refreshes an existing token.
  """
  def refresh_token(token) do
    case StreamflixAccounts.Guardian.refresh(token) do
      {:ok, _old_stuff, {new_token, new_claims}} ->
        {:ok, new_token, new_claims}

      error ->
        error
    end
  end

  @doc """
  Revokes a token.
  """
  def revoke_token(token) do
    StreamflixAccounts.Guardian.revoke(token)
  end
end
