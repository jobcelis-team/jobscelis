defmodule StreamflixCore.Types.WebhookFilters do
  @moduledoc """
  Ecto type for webhook filters: a list of filter maps. Stored as JSONB in Postgres.
  Allows default: [] in the schema (Ecto's :map does not allow list default).
  """
  use Ecto.Type

  def type, do: :map

  def cast(list) when is_list(list), do: {:ok, list}
  def cast(_), do: :error

  def load(list) when is_list(list), do: {:ok, list}
  def load(map) when is_map(map), do: {:ok, []}
  def load(nil), do: {:ok, []}

  def dump(list) when is_list(list), do: {:ok, list}
  def dump(_), do: {:ok, []}
end
