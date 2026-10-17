defmodule StreamflixAccounts do
  @moduledoc """
  StreamflixAccounts - User management and authentication for Webhooks + Events platform.
  - User registration and management
  - Authentication (JWT via Guardian)
  """

  alias StreamflixCore.Repo
  alias StreamflixCore.Platform
  alias StreamflixAccounts.Schemas.User
  alias StreamflixAccounts.Schemas.UserToken
  alias StreamflixAccounts.Services.Authentication
  alias StreamflixAccounts.Services.MFA
  alias StreamflixAccounts.Schemas.PasswordHistory
  alias StreamflixAccounts.Schemas.UserSession
  alias StreamflixAccounts.PasswordPolicy

  # ---------- USER ----------

  def register_user(attrs) do
    attrs = Map.put_new(attrs, :role, "user")
    email = attrs[:email] && String.downcase(attrs[:email])

    if email && get_user_by_email(email) do
      {:error, :email_already_registered}
    else
      do_register_user(attrs)
    end
  end

  defp do_register_user(attrs) do
    changeset = User.registration_changeset(%User{}, attrs)

    case Repo.insert(changeset) do
      {:ok, user} ->
        api_key_raw =
          case Platform.create_project(%{user_id: user.id, name: "My Project", is_default: true}) do
            {:ok, project} ->
              case Platform.create_api_key(project.id, %{name: "Default"}) do
                {:ok, _api_key, raw_key} -> raw_key
                _ -> nil
              end

            _ ->
              nil
          end

        StreamflixCore.GDPR.register_signup_consents(user.id)

        save_password_to_history(user.id, user.password_hash)

        if api_key_raw do
          {:ok, user, [api_key: api_key_raw]}
        else
          {:ok, user}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Updates the user's email. Requires the current password for authorization.
  The new email must be unique and different from the current one.
  """
  def update_email(%User{} = user, new_email, current_password)
      when is_binary(new_email) and is_binary(current_password) do
    case Authentication.authenticate(user.email, current_password) do
      {:ok, _} ->
        new_email = String.downcase(new_email)

        cond do
          new_email == user.email ->
            {:error, :same_email}

          true ->
            case get_user_by_email(new_email) do
              nil ->
                with {:ok, updated} <-
                       user |> User.email_changeset(%{email: new_email}) |> Repo.update() do
                  # Links mailed to the previous address must not confirm the new one
                  import Ecto.Query, only: [from: 2]

                  Repo.delete_all(
                    from(t in UserToken,
                      where:
                        t.user_id == ^user.id and t.context in ["confirm_email", "reset_password"]
                    )
                  )

                  {:ok, updated}
                end

              other when other.id == user.id ->
                {:error, :same_email}

              _other ->
                {:error, :email_taken}
            end
        end

      {:error, _} ->
        {:error, :wrong_password}
    end
  end

  def update_email(_, _, _), do: {:error, :invalid}

  @doc """
  Changes the user's password. Requires the current password for authorization.
  """
  # On success every other session is revoked (pass the current one as
  # `except_jti:` to keep it), so a stolen session dies with the old password.
  def update_password(user, current_password, new_password, opts \\ [])

  def update_password(%User{} = user, current_password, new_password, opts)
      when is_binary(current_password) and is_binary(new_password) do
    case Authentication.authenticate(user.email, current_password) do
      {:ok, _} ->
        history_hashes = get_password_history_hashes(user.id, 5)

        if PasswordPolicy.password_in_history?(new_password, history_hashes) do
          {:error, :password_recently_used}
        else
          old_hash = user.password_hash

          case user
               |> User.password_changeset(%{password: new_password})
               |> Repo.update() do
            {:ok, updated_user} ->
              save_password_to_history(user.id, old_hash)
              revoke_all_sessions(user.id, except_jti: opts[:except_jti])
              {:ok, updated_user}

            error ->
              error
          end
        end

      {:error, _} ->
        {:error, :wrong_password}
    end
  end

  def update_password(_, _, _, _), do: {:error, :invalid}

  def create_admin(attrs) do
    attrs =
      attrs
      |> Map.put(:role, "admin")
      |> Map.put_new(:name, "Administrator")

    register_user(attrs)
  end

  def promote_to_admin(user_id) do
    case get_user(user_id) do
      nil -> {:error, :not_found}
      user -> update_user(user, %{role: "admin"})
    end
  end

  def create_superadmin(attrs) do
    attrs =
      attrs
      |> Map.put(:role, "superadmin")
      |> Map.put_new(:name, "Super Administrator")

    register_user(attrs)
  end

  def promote_to_superadmin(user_id) do
    case get_user(user_id) do
      nil -> {:error, :not_found}
      user -> update_user(user, %{role: "superadmin"})
    end
  end

  def set_user_role(user_id, role) when role in ["user", "moderator", "admin", "superadmin"] do
    case get_user(user_id) do
      nil -> {:error, :not_found}
      user -> update_user(user, %{role: role})
    end
  end

  def get_user(id), do: Repo.get_uuid(User, id)

  @doc "Set the display timezone (IANA name or \"UTC\"); nil or \"\" = automatic (browser)."
  def update_user_timezone(%User{} = user, timezone) do
    user
    |> User.timezone_changeset(%{timezone: timezone})
    |> Repo.update()
  end

  @doc "Users for the given ids (missing ids are skipped)."
  def list_users_by_ids(ids) when is_list(ids) do
    import Ecto.Query, only: [from: 2]
    Repo.all(from(u in User, where: u.id in ^ids))
  end

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email) do
    Repo.get_by(User, email_hash: String.downcase(email))
  end

  def update_user(%User{} = user, attrs) do
    case user |> User.changeset(attrs) |> Repo.update() do
      {:ok, updated} ->
        # Re-seed the cache with the updated struct instead of deleting it.
        # This avoids a cache miss on the next verify_token call (e.g. after
        # the async last_login_at update races with the WS mount).
        Cachex.put(:platform_cache, {:auth_user, user.id}, updated, expire: :timer.seconds(60))
        {:ok, updated}

      error ->
        error
    end
  end

  def authenticate(email, password, opts \\ []),
    do: Authentication.authenticate(email, password, opts)

  def generate_token(user), do: Authentication.generate_token(user)
  def verify_token(token), do: Authentication.verify_token(token)

  # ---------- MFA / TOTP ----------

  @doc "Generate a new TOTP secret and otpauth URI for MFA setup."
  def setup_mfa(%User{} = user) do
    secret = MFA.generate_secret()
    uri = MFA.generate_otpauth_uri(secret, user.email)
    {:ok, secret, uri}
  end

  @doc "Enable MFA after user confirms with a valid TOTP code."
  def enable_mfa(%User{} = user, secret, code) do
    MFA.enable_mfa(user, secret, code)
  end

  @doc "Disable MFA (requires current password)."
  def disable_mfa(%User{} = user, password) do
    MFA.disable_mfa(user, password)
  end

  @max_mfa_attempts 5
  @mfa_attempts_window :timer.minutes(15)

  @doc """
  Verify a 6-digit TOTP code for login (each code can be used only once).

  Wrong codes are counted per user on the server; after #{@max_mfa_attempts} the
  user must start the login again. Returns `true`, `false` or `:too_many_attempts`.
  """
  def verify_mfa_code(%User{} = user, code) do
    key = {:mfa_attempts, user.id}

    cond do
      mfa_attempts(key) >= @max_mfa_attempts ->
        :too_many_attempts

      MFA.verify_and_consume_code(user, code) ->
        Cachex.del(:platform_cache, key)
        true

      true ->
        {:ok, count} = Cachex.incr(:platform_cache, key, 1)
        if count == 1, do: Cachex.expire(:platform_cache, key, @mfa_attempts_window)
        if count >= @max_mfa_attempts, do: :too_many_attempts, else: false
    end
  end

  defp mfa_attempts(key) do
    case Cachex.get(:platform_cache, key) do
      {:ok, n} when is_integer(n) -> n
      _ -> 0
    end
  end

  @doc "Verify a backup code (consumes it on success)."
  def verify_mfa_backup_code(%User{} = user, code) do
    MFA.verify_backup_code(user, code)
  end

  @doc "Regenerate backup codes for a user with MFA enabled."
  def regenerate_backup_codes(%User{} = user) do
    MFA.regenerate_backup_codes(user)
  end

  # ---------- PASSWORD RESET ----------

  @doc """
  Generates a password reset token for the user.
  Returns {:ok, raw_token} or {:error, reason}.
  """
  def generate_reset_password_token(email) do
    case get_user_by_email(email) do
      nil ->
        {:error, :user_not_found}

      user ->
        if Repo.exists?(UserToken.recent_token_query(user.id, "reset_password")) do
          {:error, :rate_limited}
        else
          {raw_token, token_struct} = UserToken.build_reset_token(user)

          case Repo.insert(token_struct) do
            {:ok, _} -> {:ok, raw_token, user}
            {:error, _} -> {:error, :token_creation_failed}
          end
        end
    end
  end

  @doc """
  Verifies a password reset token and returns the user.
  """
  def verify_reset_password_token(token) do
    case UserToken.verify_reset_token_query(token) do
      {:ok, query} ->
        case Repo.one(query) do
          nil -> {:error, :invalid_token}
          token_record -> {:ok, Repo.get(User, token_record.user_id)}
        end

      :error ->
        {:error, :invalid_token}
    end
  end

  @doc """
  Resets the user password using a valid reset token.
  Deletes all reset tokens for the user after success.
  """
  def reset_user_password(token, new_password) do
    case verify_reset_password_token(token) do
      {:ok, user} ->
        history_hashes = get_password_history_hashes(user.id, 5)

        if PasswordPolicy.password_in_history?(new_password, history_hashes) do
          {:error, :password_recently_used}
        else
          old_hash = user.password_hash

          result =
            user
            |> User.password_changeset(%{password: new_password})
            |> Repo.update()

          case result do
            {:ok, updated_user} ->
              save_password_to_history(user.id, old_hash)
              Repo.delete_all(UserToken.by_user_and_contexts_query(user, ["reset_password"]))
              # A reset usually follows a compromise: end every existing session
              revoke_all_sessions(user.id)
              {:ok, updated_user}

            {:error, changeset} ->
              {:error, changeset}
          end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---------- EMAIL VERIFICATION ----------

  @doc """
  Generates an email confirmation token for the user.
  """
  def generate_email_confirmation_token(user) do
    if Repo.exists?(UserToken.recent_token_query(user.id, "confirm_email")) do
      {:error, :rate_limited}
    else
      {raw_token, token_struct} = UserToken.build_email_token(user)

      case Repo.insert(token_struct) do
        {:ok, _} -> {:ok, raw_token}
        {:error, _} -> {:error, :token_creation_failed}
      end
    end
  end

  @doc """
  Confirms a user's email using the confirmation token.
  """
  def confirm_user_email(token) do
    case UserToken.verify_email_token_query(token) do
      {:ok, query} ->
        case Repo.one(query) do
          nil ->
            {:error, :invalid_token}

          token_record ->
            user = Repo.get(User, token_record.user_id)

            if user do
              now = DateTime.utc_now() |> DateTime.truncate(:second)

              result =
                user
                |> User.changeset(%{email_verified_at: now})
                |> Repo.update()

              case result do
                {:ok, updated_user} ->
                  Repo.delete_all(UserToken.by_user_and_contexts_query(user, ["confirm_email"]))
                  {:ok, updated_user}

                error ->
                  error
              end
            else
              {:error, :user_not_found}
            end
        end

      :error ->
        {:error, :invalid_token}
    end
  end

  # ---------- ACCOUNT DELETION ----------

  @doc """
  Deletes a user account and all associated data.
  Requires current password for confirmation.
  """
  def delete_user(%User{} = user, current_password) when is_binary(current_password) do
    case Authentication.authenticate(user.email, current_password) do
      {:ok, _} ->
        StreamflixCore.GDPR.erase_user(user)

      {:error, _} ->
        {:error, :wrong_password}
    end
  end

  def delete_user(_, _), do: {:error, :invalid}

  # ---------- NAME UPDATE ----------

  @doc """
  Updates the user's display name.
  """
  def update_name(%User{} = user, new_name) when is_binary(new_name) do
    user
    |> User.changeset(%{name: String.trim(new_name)})
    |> Repo.update()
  end

  def update_name(_, _), do: {:error, :invalid}

  # ---------- PASSWORD HISTORY (private) ----------

  defp save_password_to_history(user_id, password_hash) when is_binary(password_hash) do
    %PasswordHistory{}
    |> PasswordHistory.changeset(%{user_id: user_id, password_hash: password_hash})
    |> Repo.insert()
  end

  defp save_password_to_history(_user_id, _), do: :ok

  defp get_password_history_hashes(user_id, limit) do
    import Ecto.Query

    PasswordHistory
    |> where([ph], ph.user_id == ^user_id)
    |> order_by([ph], desc: ph.inserted_at)
    |> limit(^limit)
    |> select([ph], ph.password_hash)
    |> Repo.all()
  end

  # ---------- SESSIONS ----------

  def create_session(user_id, jti, opts \\ []) do
    %UserSession{}
    |> UserSession.changeset(%{
      user_id: user_id,
      token_jti: jti,
      ip_address: opts[:ip_address],
      user_agent: opts[:user_agent],
      device_info: parse_device_info(opts[:user_agent]),
      last_activity_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  @doc "Record activity for a session (used by the inactivity timeout)."
  def touch_session(jti) when is_binary(jti) do
    import Ecto.Query

    from(s in UserSession, where: s.token_jti == ^jti and is_nil(s.revoked_at))
    |> Repo.update_all(set: [last_activity_at: DateTime.utc_now()])

    :ok
  end

  def touch_session(_), do: :ok

  @doc "Last recorded activity (unix seconds) of a session, or nil."
  def session_last_activity(jti) when is_binary(jti) do
    import Ecto.Query

    from(s in UserSession, where: s.token_jti == ^jti, select: s.last_activity_at)
    |> Repo.one()
    |> case do
      %DateTime{} = dt -> DateTime.to_unix(dt)
      _ -> nil
    end
  end

  def session_last_activity(_), do: nil

  def list_sessions(user_id) do
    import Ecto.Query

    UserSession
    |> UserSession.for_user(user_id)
    |> UserSession.active()
    |> order_by([s], desc: s.last_activity_at)
    |> Repo.all()
  end

  def revoke_session(session_id, user_id) do
    import Ecto.Query

    case Repo.get_by(UserSession, id: session_id, user_id: user_id) do
      nil ->
        {:error, :not_found}

      session ->
        result =
          session
          |> Ecto.Changeset.change(revoked_at: DateTime.utc_now())
          |> Repo.update()

        mark_revoked([session.token_jti])
        result
    end
  end

  def revoke_all_sessions(user_id, opts \\ []) do
    import Ecto.Query
    except_jti = Keyword.get(opts, :except_jti)

    query =
      UserSession
      |> UserSession.for_user(user_id)
      |> UserSession.active()

    query =
      if except_jti do
        from(s in query, where: s.token_jti != ^except_jti)
      else
        query
      end

    {count, jtis} =
      query
      |> select([s], s.token_jti)
      |> Repo.update_all(set: [revoked_at: DateTime.utc_now()])

    mark_revoked(jtis)
    {:ok, count}
  end

  # Revocation must apply at once: session_revoked?/1 caches its answer, and
  # live (LiveView) connections of those sessions are dropped by the web app
  # through the configured `:on_sessions_revoked` {module, function} hook.
  defp mark_revoked(jtis) do
    jtis = Enum.filter(jtis || [], &is_binary/1)
    Enum.each(jtis, &Cachex.put(:platform_cache, {:session_revoked, &1}, true))

    case Application.get_env(:streamflix_accounts, :on_sessions_revoked) do
      {mod, fun} when jtis != [] -> apply(mod, fun, [jtis])
      _ -> :ok
    end
  end

  def revoke_session_by_jti(user_id, jti) when is_binary(jti) do
    result =
      case UserSession
           |> UserSession.for_user(user_id)
           |> UserSession.by_jti(jti)
           |> Repo.one() do
        nil ->
          :ok

        session ->
          session |> Ecto.Changeset.change(revoked_at: DateTime.utc_now()) |> Repo.update()
      end

    # Eagerly update cache (and drop live sockets) so revocation applies immediately
    mark_revoked([jti])
    result
  end

  def revoke_session_by_jti(_user_id, _jti), do: :ok

  # Every access token is issued together with a user_sessions row (web login,
  # signup, API login/register/MFA, refresh). A token without one (or without a
  # jti) was not issued as an access token — e.g. an MFA challenge — and is
  # treated as revoked.
  def session_revoked?(nil), do: true

  def session_revoked?(jti) do
    case Cachex.fetch(:platform_cache, {:session_revoked, jti}, fn _ ->
           revoked =
             case UserSession |> UserSession.by_jti(jti) |> Repo.one() do
               nil -> true
               session -> not is_nil(session.revoked_at)
             end

           {:commit, revoked, expire: :timer.seconds(120)}
         end) do
      {:ok, val} -> val
      {:commit, val} -> val
      _ -> false
    end
  end

  def parse_device_info(nil), do: "Desktop"

  def parse_device_info(ua) when is_binary(ua) do
    ua_lower = String.downcase(ua)

    cond do
      String.contains?(ua_lower, ["mobile", "iphone", "android"]) and
          not String.contains?(ua_lower, ["tablet", "ipad"]) ->
        "Mobile"

      String.contains?(ua_lower, ["tablet", "ipad"]) ->
        "Tablet"

      true ->
        "Desktop"
    end
  end

  # ---------- GDPR: Restriction (Art. 18) + Objection (Art. 21) ----------

  @doc "Restrict processing for a user (requires password confirmation)."
  def restrict_user(%User{} = user, current_password) when is_binary(current_password) do
    case Authentication.authenticate(user.email, current_password) do
      {:ok, _} ->
        StreamflixCore.GDPR.restrict_processing(user, "user_requested")

      {:error, _} ->
        {:error, :wrong_password}
    end
  end

  def restrict_user(_, _), do: {:error, :invalid}

  @doc "Lift processing restriction for a user."
  def lift_restriction(%User{} = user) do
    StreamflixCore.GDPR.lift_restriction(user)
  end

  @doc "Record user's objection to data processing (Art. 21)."
  def object_to_processing(%User{} = user) do
    StreamflixCore.GDPR.object_to_processing(user)
  end

  @doc "Restore user's processing consent after objection withdrawal."
  def restore_processing_consent(%User{} = user) do
    StreamflixCore.GDPR.restore_processing_consent(user)
  end

  # ---------- USER STATUS ----------

  def deactivate_user(user_id) do
    case get_user(user_id) do
      nil ->
        {:error, :not_found}

      user ->
        with {:ok, updated} <- user |> User.changeset(%{status: "inactive"}) |> Repo.update() do
          revoke_all_sessions(user.id)
          {:ok, updated}
        end
    end
  end

  def activate_user(user_id) do
    case get_user(user_id) do
      nil -> {:error, :not_found}
      user -> user |> User.changeset(%{status: "active"}) |> Repo.update()
    end
  end
end
