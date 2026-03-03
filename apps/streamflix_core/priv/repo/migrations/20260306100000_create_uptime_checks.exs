defmodule StreamflixCore.Repo.Migrations.CreateUptimeChecks do
  use Ecto.Migration

  def change do
    create table(:uptime_checks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, null: false
      add :checks, :map, default: %{}
      add :response_time_ms, :integer
      add :metadata, :map, default: %{}

      timestamps(updated_at: false)
    end

    create index(:uptime_checks, [:inserted_at])
  end
end
