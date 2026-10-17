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
        Argon2.no_user_verify()
        {:error, :invalid_credentials}

      user ->
        cond do
          User.locked?(user) ->
            Argon2.no_user_verify()
            audit_login(user, "user.login_failed", opts, %{reason: "account_locked"})
            {:error, :account_locked}

          not verify_password(password, user.password_hash) ->
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

          # Only someone who knows the password learns the account is inactive:
          # checking status first let anyone probe which emails are registered.
          user.status != "active" ->
            {:error, :account_inactive}

          true ->
            user = maybe_auto_unlock(user)
            reset_failed_attempts(user)

            # Fire-and-forget: audit doesn't block the login response
            Task.Supervisor.start_child(StreamflixCore.TaskSupervisor, fn ->
              audit_login(user, "user.login", opts)
            end)

            {:ok, user}
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

  # Atomic increment: parallel wrong-password requests read the same stale
  # count and could otherwise stay under the lockout threshold. An expired
  # lockout starts counting from zero again.
  defp increment_failed_attempts(%User{} = user) do
    import Ecto.Query

    base = if user.locked_at, do: 0, else: nil

    query =
      if base,
        do:
          from(u in User,
            where: u.id == ^user.id,
            update: [set: [failed_login_attempts: 1, locked_at: nil]]
          ),
        else: from(u in User, where: u.id == ^user.id, update: [inc: [failed_login_attempts: 1]])

    {_, [count]} = query |> select([u], u.failed_login_attempts) |> Repo.update_all([])
    %{user | failed_login_attempts: count, locked_at: nil}
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

  defp verify_password(password, hash), do: Argon2.verify_pass(password, hash)

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
    with {:ok, claims} <- StreamflixAccounts.Guardian.decode_and_verify(token),
         :ok <- ensure_access_token(claims),
         :ok <- ensure_not_revoked(claims["jti"]),
         {:ok, user} <- cached_get_user(claims["sub"]),
         :ok <- ensure_active(user) do
      {:ok, user, claims}
    end
  end

  # Access tokens carry no "type" claim; typed tokens (e.g. "mfa_challenge",
  # issued before the second factor) must never authenticate a request.
  defp ensure_access_token(%{"type" => type}) when not is_nil(type),
    do: {:error, :invalid_token_type}

  defp ensure_access_token(_claims), do: :ok

  defp ensure_not_revoked(jti) do
    if StreamflixAccounts.session_revoked?(jti), do: {:error, :session_revoked}, else: :ok
  end

  defp ensure_active(%{status: "inactive"}), do: {:error, :account_inactive}
  defp ensure_active(_user), do: :ok

  # Avoids a DB hit on every authenticated request; TTL handles staleness.
  defp cached_get_user(user_id) do
    case Cachex.fetch(:platform_cache, {:auth_user, user_id}, fn _ ->
           case StreamflixCore.Repo.get(StreamflixAccounts.Schemas.User, user_id) do
             nil -> {:ignore, nil}
             user -> {:commit, user, expire: :timer.seconds(60)}
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
  # Only a valid, non-revoked access token can be refreshed. The new token gets
  # its own session row (so it is listed and revocable) and the old one is revoked.
  def refresh_token(token, opts \\ []) do
    with {:ok, user, old_claims} <- verify_token(token),
         {:ok, new_token, new_claims} <- generate_token(user),
         {:ok, _session} <- StreamflixAccounts.create_session(user.id, new_claims["jti"], opts) do
      StreamflixAccounts.revoke_session_by_jti(user.id, old_claims["jti"])
      {:ok, new_token, new_claims}
    end
  end

  @doc """
  Revokes a token.
  """
  def revoke_token(token) do
    StreamflixAccounts.Guardian.revoke(token)
  end
end
