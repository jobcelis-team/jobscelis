defmodule StreamflixCore.Platform.Transformer do
  @moduledoc """
  Payload transformation engine for event pipelines.
  Supports JSONPath-style field extraction and Liquid-like templates.
  """

  @doc """
  Apply a transformation step to a payload.

  Supported transform operations:
  - "pick"    — Keep only specified fields
  - "remove"  — Remove specified fields
  - "rename"  — Rename fields (map of old_name => new_name)
  - "set"     — Set static values
  - "template" — Apply a Liquid-like template (simple variable substitution)
  - "flatten" — Flatten nested objects with dot notation keys
  """
  def apply_transform(%{"operation" => operation} = step, payload) do
    case operation do
      "pick" -> pick_fields(payload, Map.get(step, "fields", []))
      "remove" -> remove_fields(payload, Map.get(step, "fields", []))
      "rename" -> rename_fields(payload, Map.get(step, "mapping", %{}))
      "set" -> set_fields(payload, Map.get(step, "values", %{}))
      "template" -> apply_template(payload, Map.get(step, "template", %{}))
      "flatten" -> flatten_payload(payload)
      _ -> {:ok, payload}
    end
  end

  def apply_transform(_step, payload), do: {:ok, payload}

  @doc "Keep only the specified fields from the payload."
  def pick_fields(payload, fields) when is_list(fields) do
    result =
      Enum.reduce(fields, %{}, fn field, acc ->
        value = get_nested(payload, field)
        if value != nil, do: put_nested(acc, field, value), else: acc
      end)

    {:ok, result}
  end

  @doc "Remove specified fields from the payload."
  def remove_fields(payload, fields) when is_list(fields) do
    result =
      Enum.reduce(fields, payload, fn field, acc ->
        drop_nested(acc, field)
      end)

    {:ok, result}
  end

  @doc "Rename fields in the payload."
  def rename_fields(payload, mapping) when is_map(mapping) do
    result =
      Enum.reduce(mapping, payload, fn {old_key, new_key}, acc ->
        value = get_nested(acc, old_key)

        if value != nil do
          acc
          |> drop_nested(old_key)
          |> put_nested(new_key, value)
        else
          acc
        end
      end)

    {:ok, result}
  end

  @doc "Set static values in the payload."
  def set_fields(payload, values) when is_map(values) do
    {:ok, Map.merge(stringify_keys(payload), stringify_keys(values))}
  end

  @doc """
  Apply a Liquid-like template. The template is a map where values can contain
  `{{ field.path }}` placeholders that get replaced with actual payload values.

  Example:
    template: %{"id" => "{{ order_id }}", "email" => "{{ customer.email }}"}
    payload:  %{"order_id" => "123", "customer" => %{"email" => "j@x.com"}}
    result:   %{"id" => "123", "email" => "j@x.com"}
  """
  def apply_template(payload, template) when is_map(template) do
    result =
      Enum.reduce(template, %{}, fn {key, value}, acc ->
        resolved = resolve_template_value(value, payload)
        Map.put(acc, key, resolved)
      end)

    {:ok, result}
  end

  @doc "Flatten a nested map into dot-notation keys."
  def flatten_payload(payload) when is_map(payload) do
    {:ok, do_flatten(payload, "")}
  end

  # ── Private helpers ──

  defp resolve_template_value(value, payload) when is_binary(value) do
    Regex.replace(~r/\{\{\s*([^}]+?)\s*\}\}/, value, fn _, path ->
      case get_nested(payload, String.trim(path)) do
        nil -> ""
        val when is_binary(val) -> val
        val -> inspect(val)
      end
    end)
  end

  defp resolve_template_value(value, payload) when is_map(value) do
    Enum.reduce(value, %{}, fn {k, v}, acc ->
      Map.put(acc, k, resolve_template_value(v, payload))
    end)
  end

  defp resolve_template_value(value, _payload), do: value

  defp get_nested(map, path) when is_binary(path) do
    keys = String.split(path, ".")
    get_in_map(map, keys)
  end

  defp get_in_map(value, []), do: value

  defp get_in_map(%{} = map, [key | rest]) do
    value = Map.get(map, key) || Map.get(map, String.to_existing_atom(key))
    get_in_map(value, rest)
  rescue
    ArgumentError -> nil
  end

  defp get_in_map(_, _), do: nil

  defp put_nested(map, path, value) when is_binary(path) do
    keys = String.split(path, ".")
    do_put_nested(map, keys, value)
  end

  defp do_put_nested(_map, [key], value), do: Map.put(%{}, key, value)

  defp do_put_nested(map, [key | rest], value) do
    existing = Map.get(map, key, %{})
    Map.put(map, key, do_put_nested(existing, rest, value))
  end

  defp drop_nested(map, path) when is_binary(path) do
    case String.split(path, ".") do
      [key] ->
        Map.delete(stringify_keys(map), key)

      [key | rest] ->
        case Map.get(stringify_keys(map), key) do
          %{} = nested ->
            Map.put(stringify_keys(map), key, drop_nested(nested, Enum.join(rest, ".")))

          _ ->
            stringify_keys(map)
        end
    end
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp do_flatten(map, prefix) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      full_key = if prefix == "", do: to_string(key), else: "#{prefix}.#{key}"

      case value do
        %{} = nested -> Map.merge(acc, do_flatten(nested, full_key))
        _ -> Map.put(acc, full_key, value)
      end
    end)
  end
end
