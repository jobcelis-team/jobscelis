defmodule StreamflixCore.Cache do
  @moduledoc """
  Multi-level distributed cache using Nebulex.

  Provides:
  - L1: Local in-memory cache (fastest)
  - L2: Distributed cache across nodes

  ## Usage

      # Set a value
      Cache.put(:my_key, "value", ttl: :timer.hours(1))

      # Get a value
      Cache.get(:my_key)

      # Get or compute
      Cache.get_or_put(:expensive_key, fn -> compute_expensive_value() end)

  """

  use Nebulex.Cache,
    otp_app: :streamflix_core,
    adapter: Nebulex.Adapters.Local

  # ============================================
  # HIGH-LEVEL API
  # ============================================

  @doc """
  Gets a value from cache or computes it if not present.
  """
  def get_or_put(key, fun, opts \\ []) when is_function(fun, 0) do
    case get(key) do
      nil ->
        value = fun.()
        put(key, value, opts)
        value
      value ->
        value
    end
  end

  @doc """
  Gets a value, with a fallback if not present.
  """
  def get_with_fallback(key, fallback) do
    case get(key) do
      nil -> fallback
      value -> value
    end
  end

  @doc """
  Invalidates all keys matching a pattern.
  """
  def invalidate_pattern(pattern) do
    stream()
    |> Stream.filter(fn {key, _} -> key_matches_pattern?(key, pattern) end)
    |> Enum.each(fn {key, _} -> delete(key) end)
  end

  @doc """
  Returns cache statistics.
  """
  def stats do
    %{
      size: count_all(),
      memory: :erlang.memory(:total)
    }
  end

  # ============================================
  # DOMAIN-SPECIFIC HELPERS
  # ============================================

  @doc """
  Caches content metadata.
  """
  def cache_content(content_id, content, ttl \\ :timer.hours(1)) do
    put({:content, content_id}, content, ttl: ttl)
  end

  @doc """
  Gets cached content metadata.
  """
  def get_content(content_id) do
    get({:content, content_id})
  end

  @doc """
  Caches user session data.
  """
  def cache_session(session_id, session_data, ttl \\ :timer.hours(24)) do
    put({:session, session_id}, session_data, ttl: ttl)
  end

  @doc """
  Gets cached session data.
  """
  def get_session(session_id) do
    get({:session, session_id})
  end

  @doc """
  Caches recommendations for a profile.
  """
  def cache_recommendations(profile_id, recommendations, ttl \\ :timer.hours(6)) do
    put({:recommendations, profile_id}, recommendations, ttl: ttl)
  end

  @doc """
  Gets cached recommendations.
  """
  def get_recommendations(profile_id) do
    get({:recommendations, profile_id})
  end

  @doc """
  Invalidates all cache for a specific user.
  """
  def invalidate_user(user_id) do
    invalidate_pattern({:user, user_id, :_})
    invalidate_pattern({:profile, :_, user_id})
  end

  @doc """
  Invalidates content cache.
  """
  def invalidate_content(content_id) do
    delete({:content, content_id})
    invalidate_pattern({:genre, :_, :_})
  end

  # ============================================
  # PRIVATE FUNCTIONS
  # ============================================

  defp key_matches_pattern?(key, pattern) when is_tuple(key) and is_tuple(pattern) do
    key_list = Tuple.to_list(key)
    pattern_list = Tuple.to_list(pattern)

    if length(key_list) == length(pattern_list) do
      Enum.zip(key_list, pattern_list)
      |> Enum.all?(fn
        {_, :_} -> true
        {a, b} -> a == b
      end)
    else
      false
    end
  end

  defp key_matches_pattern?(_, _), do: false
end
