defmodule StreamflixCore.SafeJson do
  @moduledoc """
  JSON decoding with a nesting limit for untrusted input.

  Size limits alone do not bound nesting: 256 KB of `[[[[...` is over 100k
  levels, which PostgreSQL rejects when storing it as jsonb ("stack depth
  limit exceeded"), turning a bad request into a 500. Real payloads never come
  close to the limit.
  """

  @max_depth 64

  def max_depth, do: @max_depth

  @doc "Like `Jason.decode/1`, but `{:error, :too_deep}` past the nesting limit."
  def decode(binary) do
    with {:ok, term} <- Jason.decode(binary) do
      if within_depth?(term), do: {:ok, term}, else: {:error, :too_deep}
    end
  end

  @doc "Decoder for `Plug.Parsers` (raises, which Plug turns into a 400)."
  def decode!(binary) do
    term = Jason.decode!(binary)

    if within_depth?(term) do
      term
    else
      raise ArgumentError, "JSON nesting exceeds #{@max_depth} levels"
    end
  end

  @doc "True when no map/list is nested more than `max` levels deep."
  def within_depth?(term, max \\ @max_depth)

  def within_depth?(map, depth) when is_map(map) and not is_struct(map),
    do: depth > 0 and Enum.all?(map, fn {_k, v} -> within_depth?(v, depth - 1) end)

  def within_depth?(list, depth) when is_list(list),
    do: depth > 0 and Enum.all?(list, &within_depth?(&1, depth - 1))

  def within_depth?(_scalar, _depth), do: true
end
