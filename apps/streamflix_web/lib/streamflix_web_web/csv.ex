defmodule StreamflixWebWeb.CSV do
  @moduledoc """
  CSV cell encoding shared by the browser and API exporters.

  Besides RFC 4180 quoting, values that a spreadsheet would evaluate as a
  formula (starting with `=`, `+`, `-`, `@`, tab or carriage return) are
  prefixed with a single quote so exported data cannot run formulas
  (CSV/formula injection).
  """

  @formula_triggers ["=", "+", "-", "@", "\t", "\r"]

  @doc "Encodes one value as a safe CSV cell."
  def escape(nil), do: ""

  def escape(value) do
    value
    |> to_string()
    |> neutralize_formula()
    |> quote_if_needed()
  end

  @doc "Prefixes a value that would be interpreted as a formula with a single quote."
  def neutralize_formula(value) when is_binary(value) do
    if String.starts_with?(value, @formula_triggers), do: "'" <> value, else: value
  end

  defp quote_if_needed(value) do
    if String.contains?(value, [",", "\"", "\n", "\r"]) do
      "\"" <> String.replace(value, "\"", "\"\"") <> "\""
    else
      value
    end
  end
end
