defmodule StreamflixCore.Settings do
  @moduledoc """
  Settings management for platform configuration.
  """

  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.Setting


  # ============================================
  # GETTERS
  # ============================================

  @doc """
  Gets a setting value by key.
  """
  def get(key, default \\ nil) do
    case Repo.get_by(Setting, key: key) do
      nil -> default
      setting -> Setting.get_typed_value(setting)
    end
  end

  @doc """
  Gets all settings by category.
  """
  def get_by_category(category) do
    Setting
    |> where([s], s.category == ^category)
    |> Repo.all()
    |> Enum.map(fn s -> {s.key, Setting.get_typed_value(s)} end)
    |> Map.new()
  end

  @doc """
  Gets all settings.
  """
  def all do
    Setting
    |> Repo.all()
    |> Enum.map(fn s -> {s.key, Setting.get_typed_value(s)} end)
    |> Map.new()
  end

  # ============================================
  # SETTERS
  # ============================================

  @doc """
  Sets a setting value.
  """
  def set(key, value, opts \\ []) do
    value_type = Keyword.get(opts, :value_type, infer_type(value))
    category = Keyword.get(opts, :category, "general")
    description = Keyword.get(opts, :description)

    value_str = to_string_value(value, value_type)

    case Repo.get_by(Setting, key: key) do
      nil ->
        attrs = %{
          key: key,
          value: value_str,
          value_type: value_type,
          category: category,
          description: description
        }
        %Setting{}
        |> Setting.changeset(attrs)
        |> Repo.insert()

      existing ->
        attrs = %{
          value: value_str,
          value_type: value_type,
          category: category,
          description: description
        }
        existing
        |> Setting.changeset(attrs)
        |> Repo.update()
    end
  end

  # ============================================
  # PRICING HELPERS
  # ============================================

  def get_plan_price(plan) do
    get("pricing.#{plan}", default_price(plan))
  end

  def set_plan_price(plan, price) do
    set("pricing.#{plan}", price, category: "pricing", value_type: "float")
  end

  defp default_price("basic"), do: 8.99
  defp default_price("standard"), do: 13.99
  defp default_price("premium"), do: 17.99
  defp default_price(_), do: 0.0

  # ============================================
  # PLATFORM HELPERS
  # ============================================

  def get_platform_name, do: get("platform.name", "StreamFlix")
  def get_support_email, do: get("platform.support_email", "soporte@streamflix.com")
  def get_azure_account, do: get("platform.azure_account", "streamflix")
  def get_cdn_endpoint, do: get("platform.cdn_endpoint", "https://streamflix.blob.core.windows.net")

  # ============================================
  # HELPERS
  # ============================================

  defp infer_type(value) when is_integer(value), do: "integer"
  defp infer_type(value) when is_float(value), do: "float"
  defp infer_type(value) when is_boolean(value), do: "boolean"
  defp infer_type(value) when is_map(value) or is_list(value), do: "json"
  defp infer_type(_), do: "string"

  defp to_string_value(value, "json"), do: Jason.encode!(value)
  defp to_string_value(value, _), do: to_string(value)
end
