defmodule StreamflixCore.Repo.Migrations.CreateEventSchemas do
  use Ecto.Migration

  def change do
    create table(:event_schemas, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false
      add :topic, :string, size: 255, null: false
      add :schema, :map, null: false
      add :version, :integer, default: 1
      add :status, :string, size: 20, default: "active"

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:event_schemas, [:project_id, :topic, :version])
  end
end
