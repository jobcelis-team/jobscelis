defmodule StreamflixAccounts.Guardian do
  @moduledoc """
  Guardian implementation for JWT authentication.
  """

  use Guardian, otp_app: :streamflix_accounts

  alias StreamflixAccounts.Schemas.User
  alias StreamflixCore.Repo

  @doc """
  Generates the subject for a token from the user.
  """
  def subject_for_token(%User{id: id}, _claims) do
    {:ok, to_string(id)}
  end

  def subject_for_token(_, _) do
    {:error, :invalid_resource}
  end

  @doc """
  Retrieves the user from token claims.
  """
  def resource_from_claims(%{"sub" => id}) do
    case Cachex.fetch(:platform_cache, {:user, id}, fn _key ->
           case Repo.get(User, id) do
             nil -> {:ignore, nil}
             user -> {:commit, user, ttl: :timer.seconds(120)}
           end
         end) do
      {:ok, user} -> {:ok, user}
      {:commit, user} -> {:ok, user}
      {:ignore, _} -> {:error, :resource_not_found}
    end
  end

  def resource_from_claims(_claims) do
    {:error, :invalid_claims}
  end

  @doc """
  Called after a token is successfully verified.
  Can be used to add additional claims validation.
  """
  def verify_claims(claims, _opts) do
    {:ok, claims}
  end

  @doc """
  Called when building claims for a new token.
  """
  def build_claims(claims, _resource, _opts) do
    {:ok, claims}
  end
end
