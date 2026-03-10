defmodule StreamflixCore.EmbedTokens do
  @moduledoc """
  Context for managing embed tokens used by the embeddable portal.
  Tokens are hashed (SHA-256) before storage; only the prefix is stored in clear.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.EmbedToken

  @prefix "emb_"

  @doc """
  Creates a new embed token. Returns `{:ok, raw_token, embed_token}`.
  The raw_token is returned only once and must be given to the end-user.
  """
  def create(project_id, attrs \\ %{}) do
    raw = generate_raw_token()
    hash = hash_token(raw)
    prefix = @prefix <> String.slice(raw, 0, 8)

    token_attrs =
      Map.merge(
        %{
          project_id: project_id,
          prefix: prefix,
          token_hash: hash
        },
        attrs
      )

    case %EmbedToken{} |> EmbedToken.changeset(token_attrs) |> Repo.insert() do
      {:ok, token} -> {:ok, @prefix <> raw, token}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Verifies a raw embed token. Returns the token record or nil.
  """
  def verify(raw_key) when is_binary(raw_key) do
    # Strip prefix if present
    raw =
      if String.starts_with?(raw_key, @prefix), do: String.slice(raw_key, 4..-1//1), else: raw_key

    hash = hash_token(raw)

    now = DateTime.utc_now()

    from(t in EmbedToken,
      where: t.token_hash == ^hash,
      where: t.status == "active",
      where: is_nil(t.expires_at) or t.expires_at > ^now,
      preload: [:project]
    )
    |> Repo.one()
  end

  def verify(_), do: nil

  @doc """
  Lists embed tokens for a project.
  """
  def list_by_project(project_id) do
    from(t in EmbedToken,
      where: t.project_id == ^project_id,
      where: t.status == "active",
      order_by: [desc: :inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Revokes (deactivates) an embed token.
  """
  def revoke(token_id) do
    case Repo.get(EmbedToken, token_id) do
      nil -> {:error, :not_found}
      token -> token |> EmbedToken.changeset(%{status: "inactive"}) |> Repo.update()
    end
  end

  @doc """
  Checks if a token has the given scope.
  """
  def has_scope?(%EmbedToken{scopes: scopes}, required) do
    required in scopes
  end

  defp generate_raw_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp hash_token(raw) do
    :crypto.hash(:sha256, raw) |> Base.encode64()
  end
end
