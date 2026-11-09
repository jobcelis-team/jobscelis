defmodule StreamflixWebWeb.FreshApiKey do
  @moduledoc """
  One-time hand-off of the API key created at sign-up to the dashboard.

  The raw key is kept briefly in Cachex instead of the session cookie, so it is
  not carried in every request for the life of the session. The dashboard's
  first render only peeks at it; the connected mount takes it, so it is shown
  once and a later visit no longer has it.
  """

  @cache :platform_cache
  @ttl :timer.minutes(10)

  def put(user_id, raw_key) when is_binary(raw_key) and raw_key != "" do
    Cachex.put(@cache, key(user_id), raw_key, expire: @ttl)
    :ok
  end

  def put(_user_id, _raw_key), do: :ok

  @doc "Reads the key; `take: true` also removes it."
  def get(user_id, take: true) do
    case Cachex.take(@cache, key(user_id)) do
      {:ok, raw_key} -> raw_key
      _ -> nil
    end
  end

  def get(user_id, take: false) do
    case Cachex.get(@cache, key(user_id)) do
      {:ok, raw_key} -> raw_key
      _ -> nil
    end
  end

  defp key(user_id), do: {:fresh_api_key, user_id}
end
