defmodule StreamflixCore.Platform.ApiKeys do
  @moduledoc """
  API key management: create, verify, regenerate.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{ApiKey, Project}

  @cache :platform_cache
  @api_key_ttl :timer.seconds(120)
  @prefix "wh_"
  @key_byte_length 32

  def create_api_key(project_id, attrs \\ %{}) do
    raw_key = generate_raw_api_key()
    prefix = String.slice(raw_key, 0, 12)
    key_hash = hash_api_key(raw_key)

    scopes = attrs["scopes"] || attrs[:scopes] || ["*"]
    allowed_ips = attrs["allowed_ips"] || attrs[:allowed_ips] || []

    case %ApiKey{}
         |> ApiKey.changeset(
           Map.merge(attrs, %{
             project_id: project_id,
             prefix: prefix,
             key_hash: key_hash,
             name: attrs["name"] || attrs[:name] || "Default",
             scopes: scopes,
             allowed_ips: allowed_ips
           })
         )
         |> Repo.insert() do
      {:ok, api_key} -> {:ok, api_key, raw_key}
      err -> err
    end
  end

  def verify_api_key(_prefix, raw_key) when is_binary(raw_key) do
    key_hash = hash_api_key(raw_key)
    cache_key = {:api_key, key_hash}

    case Cachex.fetch(@cache, cache_key, fn _key ->
           result =
             ApiKey
             |> where([k], k.key_hash == ^key_hash and k.status == "active")
             |> join(:inner, [k], p in Project, on: p.id == k.project_id and p.status == "active")
             |> preload([k, p], project: p)
             |> Repo.one()

           case result do
             nil -> {:ignore, nil}
             api_key -> {:commit, api_key, ttl: @api_key_ttl}
           end
         end) do
      {:ok, api_key} -> api_key
      {:commit, api_key} -> api_key
      {:ignore, _} -> nil
    end
  end

  def get_api_key_for_project(project_id) do
    ApiKey
    |> where([k], k.project_id == ^project_id and k.status == "active")
    |> order_by([k], desc: k.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def regenerate_api_key(project_id) do
    # Preserve scopes and allowed_ips from current active key
    current_key = get_api_key_for_project(project_id)
    scopes = if current_key, do: current_key.scopes || ["*"], else: ["*"]
    allowed_ips = if current_key, do: current_key.allowed_ips || [], else: []

    # Deactivate existing keys for this project
    ApiKey
    |> where([k], k.project_id == ^project_id)
    |> Repo.update_all(
      set: [status: "inactive", updated_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)]
    )

    invalidate_api_key_cache()
    create_api_key(project_id, %{name: "Default", scopes: scopes, allowed_ips: allowed_ips})
  end

  defp generate_raw_api_key() do
    @prefix <> Base.url_encode64(:crypto.strong_rand_bytes(@key_byte_length), padding: false)
  end

  defp hash_api_key(raw) do
    :crypto.hash(:sha256, raw) |> Base.encode64(padding: false)
  end

  defp invalidate_api_key_cache() do
    Cachex.clear(@cache)
  end
end
