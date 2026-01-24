defmodule StreamflixCore.Schemas.Setting do
  @moduledoc """
  Settings schema for platform configuration.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "settings" do
    field :key, :string
    field :value, :string
    field :value_type, :string, default: "string"
    field :category, :string, default: "general"
    field :description, :string

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields [:key]
  @optional_fields [:value, :value_type, :category, :description]

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:value_type, ["string", "integer", "float", "boolean", "json"])
    |> unique_constraint(:key)
  end

  # Helper to get typed value
  def get_typed_value(%__MODULE__{value: nil}), do: nil
  def get_typed_value(%__MODULE__{value: value, value_type: "integer"}), do: String.to_integer(value)
  def get_typed_value(%__MODULE__{value: value, value_type: "float"}), do: String.to_float(value)
  def get_typed_value(%__MODULE__{value: value, value_type: "boolean"}), do: value == "true"
  def get_typed_value(%__MODULE__{value: value, value_type: "json"}), do: Jason.decode!(value)
  def get_typed_value(%__MODULE__{value: value}), do: value
end
