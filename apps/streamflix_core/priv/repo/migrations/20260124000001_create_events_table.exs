defmodule StreamflixCore.Repo.Migrations.CreateEventsTable do
  use Ecto.Migration

  def change do
    # Extension for UUID generation
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", "DROP EXTENSION IF EXISTS \"uuid-ossp\""
    execute "CREATE EXTENSION IF NOT EXISTS \"citext\"", "DROP EXTENSION IF EXISTS \"citext\""
    execute "CREATE EXTENSION IF NOT EXISTS \"pgcrypto\"", "DROP EXTENSION IF EXISTS \"pgcrypto\""

    # ============================================
    # EVENTS TABLE (Event Sourcing)
    # ============================================
    create_if_not_exists table(:events, primary_key: false) do
      add :event_id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :event_type, :string, null: false
      add :aggregate_type, :string, null: false
      add :aggregate_id, :binary_id, null: false
      add :version, :integer, null: false, default: 1
      add :data, :map, null: false, default: %{}
      add :metadata, :map, default: %{}
      add :causation_id, :binary_id
      add :correlation_id, :binary_id

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create_if_not_exists index(:events, [:aggregate_type, :aggregate_id])
    create_if_not_exists index(:events, [:event_type])
    create_if_not_exists index(:events, [:inserted_at])
    create_if_not_exists unique_index(:events, [:aggregate_id, :version], name: :events_aggregate_version_index)
  end
end
