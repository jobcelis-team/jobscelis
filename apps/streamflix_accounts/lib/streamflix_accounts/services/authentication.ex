defmodule StreamflixAccounts.Services.Authentication do
  @moduledoc """
  Authentication service using Guardian for JWT tokens.
  """

  alias StreamflixAccounts.Schemas.User
  alias StreamflixCore.Repo

  @doc """
  Authenticates a user with email and password.
  """
  def authenticate(email, password) do
    user = Repo.get_by(User, email: String.downcase(email))

    case user do
      nil ->
        # Prevent timing attacks
        Pbkdf2.no_user_verify()
        {:error, :invalid_credentials}

      user ->
        # Check if user is active
        if user.status != "active" do
          Pbkdf2.no_user_verify()
          {:error, :account_inactive}
        else
          if Pbkdf2.verify_pass(password, user.password_hash) do
            maybe_rehash(user, password)
            {:ok, user}
          else
            {:error, :invalid_credentials}
          end
        end
    end
  end

  # Re-hash with current config if the stored hash used fewer rounds.
  # Wrapped in try/rescue so a rehash failure never blocks login.
  defp maybe_rehash(user, password) do
    try do
      configured_rounds = Application.get_env(:pbkdf2_elixir, :rounds, 210_000)

      if needs_rehash?(user.password_hash, configured_rounds) do
        new_hash = Pbkdf2.hash_pwd_salt(password)

        user
        |> Ecto.Changeset.change(password_hash: new_hash)
        |> Repo.update()
      end
    rescue
      _ -> :ok
    end
  end

  # PBKDF2 hash format: $pbkdf2-sha512$ROUNDS$SALT$HASH
  defp needs_rehash?(hash, target_rounds) do
    case Regex.run(~r/\$pbkdf2-sha512\$(\d+)\$/, hash) do
      [_, rounds_str] -> String.to_integer(rounds_str) < target_rounds
      _ -> false
    end
  end

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
        case StreamflixAccounts.Guardian.resource_from_claims(claims) do
          {:ok, user} -> {:ok, user, claims}
          error -> error
        end

      error ->
        error
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
