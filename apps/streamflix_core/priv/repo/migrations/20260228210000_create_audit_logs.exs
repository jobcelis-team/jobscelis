defmodule StreamflixCore.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def change do
    create table(:audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id
      add :project_id, :binary_id
      add :action, :string, null: false
      add :resource_type, :string
      add :resource_id, :binary_id
      add :metadata, :map, default: %{}
      add :ip_address, :string
      add :user_agent, :text

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:audit_logs, [:project_id, :inserted_at])
    create index(:audit_logs, [:user_id, :inserted_at])
    create index(:audit_logs, [:action, :inserted_at])
  end
end
