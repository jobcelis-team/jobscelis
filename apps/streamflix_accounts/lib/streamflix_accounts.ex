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

        # Save initial password hash to history
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
  Actualiza el email del usuario. Requiere la contraseña actual para autorizar.
  El nuevo email debe ser único en el sistema y distinto al actual.
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
                user |> User.email_changeset(%{email: new_email}) |> Repo.update()

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
  Cambia la contraseña del usuario. Requiere la contraseña actual para autorizar.
  """
  def update_password(%User{} = user, current_password, new_password)
      when is_binary(current_password) and is_binary(new_password) do
    case Authentication.authenticate(user.email, current_password) do
      {:ok, _} ->
        # Check against last 5 passwords in history
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
              {:ok, updated_user}

            error ->
              error
          end
        end

      {:error, _} ->
        {:error, :wrong_password}
    end
  end

  def update_password(_, _, _), do: {:error, :invalid}

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

  def get_user(id), do: Repo.get(User, id)
  def get_user!(id), do: Repo.get!(User, id)
  def get_user_by_email(email) do
    Repo.get_by(User, email_hash: String.downcase(email))
  end

  def update_user(%User{} = user, attrs) do
    user |> User.changeset(attrs) |> Repo.update()
  end

  def authenticate(email, password, opts \\ []), do: Authentication.authenticate(email, password, opts)
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

  @doc "Verify a 6-digit TOTP code for login."
  def verify_mfa_code(%User{} = user, code) do
    MFA.verify_code(user.mfa_secret, code)
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
        # Check against last 5 passwords in history
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
        session
        |> Ecto.Changeset.change(revoked_at: DateTime.utc_now())
        |> Repo.update()
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

    {count, _} = Repo.update_all(query, set: [revoked_at: DateTime.utc_now()])
    {:ok, count}
  end

  def revoke_session_by_jti(user_id, jti) when is_binary(jti) do
    case UserSession |> UserSession.for_user(user_id) |> UserSession.by_jti(jti) |> Repo.one() do
      nil -> :ok
      session -> session |> Ecto.Changeset.change(revoked_at: DateTime.utc_now()) |> Repo.update()
    end
  end

  def revoke_session_by_jti(_user_id, _jti), do: :ok

  def session_revoked?(nil), do: false

  def session_revoked?(jti) do
    case UserSession |> UserSession.by_jti(jti) |> Repo.one() do
      nil -> false
      session -> not is_nil(session.revoked_at)
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

  def deactivate_user(user_id) do
    case get_user(user_id) do
      nil -> {:error, :not_found}
      user -> user |> User.changeset(%{status: "inactive"}) |> Repo.update()
    end
  end

  def activate_user(user_id) do
    case get_user(user_id) do
      nil -> {:error, :not_found}
      user -> user |> User.changeset(%{status: "active"}) |> Repo.update()
    end
  end
end
