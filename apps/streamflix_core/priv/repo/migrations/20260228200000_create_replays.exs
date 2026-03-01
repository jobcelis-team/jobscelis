defmodule StreamflixCore.Repo.Migrations.CreateReplays do
  use Ecto.Migration

  def change do
    create table(:replays, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, default: "pending", null: false
      add :filters, :map, default: %{}
      add :total_events, :integer, default: 0
      add :processed_events, :integer, default: 0
      add :created_by, :binary_id
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:replays, [:project_id, :status, :inserted_at])
  end
end
