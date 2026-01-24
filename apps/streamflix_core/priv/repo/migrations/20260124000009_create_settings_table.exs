defmodule StreamflixCore.Repo.Migrations.CreateSettingsTable do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:settings, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :key, :string, null: false
      add :value, :text
      add :value_type, :string, default: "string"  # string, integer, float, boolean, json
      add :category, :string, default: "general"  # general, pricing, platform, cdn, etc.
      add :description, :text

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:settings, [:key])
    create_if_not_exists index(:settings, [:category])
  end
end
