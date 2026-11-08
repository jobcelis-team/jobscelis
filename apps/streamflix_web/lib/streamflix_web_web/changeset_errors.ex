defmodule StreamflixWebWeb.ChangesetErrors do
  @moduledoc false

  @doc """
  Fills in a changeset error's placeholders ("should be at most %{count}
  character(s)") for API responses. Use with `Ecto.Changeset.traverse_errors/2`.
  """
  def interpolate({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string_safe(value) end)
    end)
  end

  defp to_string_safe(value) when is_binary(value) or is_number(value) or is_atom(value),
    do: to_string(value)

  defp to_string_safe(value), do: inspect(value)
end
