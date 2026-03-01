defmodule StreamflixAccounts.Schemas.UserToken do
  use Ecto.Schema
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @reset_password_validity_in_minutes 60
  @confirm_email_validity_in_days 7
  @rate_limit_minutes 5

  schema "user_tokens" do
    field(:token, :binary)
    field(:context, :string)
    field(:sent_to, :string)

    belongs_to(:user, StreamflixAccounts.Schemas.User)

    timestamps(updated_at: false)
  end

  @doc """
  Generates a token for password reset.
  Returns {raw_token, hashed_token_struct}.
  """
  def build_reset_token(user) do
    build_hashed_token(user, "reset_password", user.email)
  end

  @doc """
  Generates a token for email confirmation.
  """
  def build_email_token(user) do
    build_hashed_token(user, "confirm_email", user.email)
  end

  defp build_hashed_token(user, context, sent_to) do
    token = :crypto.strong_rand_bytes(32)
    hashed_token = :crypto.hash(:sha256, token)

    {Base.url_encode64(token, padding: false),
     %__MODULE__{
       token: hashed_token,
       context: context,
       sent_to: sent_to,
       user_id: user.id
     }}
  end

  @doc """
  Query to find valid reset password token.
  """
  def verify_reset_token_query(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(:sha256, decoded_token)

        query =
          from(t in __MODULE__,
            where:
              t.token == ^hashed_token and
                t.context == "reset_password" and
                t.inserted_at > ago(^@reset_password_validity_in_minutes, "minute")
          )

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Query to find valid email confirmation token.
  """
  def verify_email_token_query(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(:sha256, decoded_token)

        query =
          from(t in __MODULE__,
            where:
              t.token == ^hashed_token and
                t.context == "confirm_email" and
                t.inserted_at > ago(^@confirm_email_validity_in_days, "day")
          )

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc """
  Checks if a token was created for this user+context within the rate limit window.
  Returns a query that matches recent tokens (< 5 minutes old).
  """
  def recent_token_query(user_id, context) do
    from(t in __MODULE__,
      where:
        t.user_id == ^user_id and
          t.context == ^context and
          t.inserted_at > ago(^@rate_limit_minutes, "minute"),
      limit: 1
    )
  end

  @doc """
  Query to delete all tokens for a user by context.
  """
  def by_user_and_contexts_query(user, contexts) do
    from(t in __MODULE__,
      where: t.user_id == ^user.id and t.context in ^contexts
    )
  end
end
