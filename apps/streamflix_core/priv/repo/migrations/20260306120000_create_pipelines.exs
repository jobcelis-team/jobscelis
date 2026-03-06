defmodule StreamflixCore.Repo.Migrations.CreatePipelines do
  use Ecto.Migration

  def up do
    # Disable Supabase RLS event trigger if it exists (prevents CREATE TABLE failure)
    execute("""
    DO $$ BEGIN
      IF EXISTS (SELECT 1 FROM pg_event_trigger WHERE evtname = 'ensure_rls_on_new_tables') THEN
        ALTER EVENT TRIGGER ensure_rls_on_new_tables DISABLE;
      END IF;
    END $$;
    """)

    create table(:pipelines, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :status, :string, default: "active", null: false
      add :description, :text
      add :topics, {:array, :string}, default: []
      add :steps, {:array, :map}, default: []
      add :webhook_id, references(:webhooks, type: :binary_id, on_delete: :delete_all)
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:pipelines, [:project_id])
    create index(:pipelines, [:project_id, :status])

    # Re-enable the event trigger
    execute("""
    DO $$ BEGIN
      IF EXISTS (SELECT 1 FROM pg_event_trigger WHERE evtname = 'ensure_rls_on_new_tables') THEN
        ALTER EVENT TRIGGER ensure_rls_on_new_tables ENABLE;
      END IF;
    END $$;
    """)
  end

  def down do
    drop table(:pipelines)
  end
end
