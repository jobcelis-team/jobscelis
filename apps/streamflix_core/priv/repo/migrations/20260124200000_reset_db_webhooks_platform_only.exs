defmodule StreamflixCore.Repo.Migrations.ResetDbWebhooksPlatformOnly do
  @moduledoc """
  Limpia toda la BD y deja solo el esquema del producto Webhooks + Events:
  users, projects, api_keys, webhooks, webhook_events, deliveries, jobs, job_runs, oban_jobs.
  """
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS citext"
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""

    # Drop all tables in public (except schema_migrations). CASCADE to remove FKs.
    execute """
    DO $$
    DECLARE
      r RECORD;
    BEGIN
      FOR r IN (
        SELECT tablename FROM pg_tables
        WHERE schemaname = 'public'
        AND tablename NOT IN ('schema_migrations')
      ) LOOP
        EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(r.tablename) || ' CASCADE';
      END LOOP;
    END $$;
    """

    # ----- USERS (solo lo necesario para auth + role + status) -----
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :email, :citext, null: false
      add :password_hash, :string, null: false
      add :name, :string, null: false, default: ""
      add :status, :string, null: false, default: "active"
      add :role, :string, null: false, default: "user"
      add :email_verified_at, :utc_datetime_usec
      add :last_login_at, :utc_datetime_usec
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end
    create unique_index(:users, [:email])
    create index(:users, [:status])
    create index(:users, [:role])

    # ----- PROJECTS -----
    create table(:projects, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :name, :string, null: false, default: "My Project"
      add :status, :string, null: false, default: "active"
      add :settings, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end
    create index(:projects, [:user_id])
    create index(:projects, [:status])

    # ----- API KEYS -----
    create table(:api_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false
      add :prefix, :string, null: false
      add :key_hash, :string, null: false
      add :name, :string, default: "Default"
      add :status, :string, null: false, default: "active"

      timestamps(type: :utc_datetime_usec)
    end
    create index(:api_keys, [:project_id])
    create index(:api_keys, [:prefix])
    create index(:api_keys, [:status])

    # ----- WEBHOOKS -----
    create table(:webhooks, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false
      add :url, :string, null: false
      add :secret_encrypted, :string
      add :status, :string, null: false, default: "active"
      add :topics, {:array, :string}, default: []
      add :filters, :map, default: fragment("'[]'::jsonb")
      add :body_config, :map, default: %{}
      add :headers, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end
    create index(:webhooks, [:project_id])
    create index(:webhooks, [:status])

    # ----- WEBHOOK_EVENTS -----
    create table(:webhook_events, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false
      add :topic, :string
      add :payload, :map, null: false, default: %{}
      add :status, :string, null: false, default: "active"
      add :occurred_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end
    create index(:webhook_events, [:project_id])
    create index(:webhook_events, [:topic])
    create index(:webhook_events, [:status])
    create index(:webhook_events, [:occurred_at])

    # ----- DELIVERIES -----
    create table(:deliveries, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :event_id, references(:webhook_events, type: :binary_id, on_delete: :delete_all), null: false
      add :webhook_id, references(:webhooks, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "pending"
      add :attempt_number, :integer, null: false, default: 0
      add :response_status, :integer
      add :response_body, :text
      add :next_retry_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end
    create index(:deliveries, [:event_id])
    create index(:deliveries, [:webhook_id])
    create index(:deliveries, [:status])
    create index(:deliveries, [:next_retry_at])

    # ----- JOBS -----
    create table(:jobs, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :schedule_type, :string, null: false
      add :schedule_config, :map, null: false, default: %{}
      add :action_type, :string, null: false
      add :action_config, :map, null: false, default: %{}
      add :status, :string, null: false, default: "active"

      timestamps(type: :utc_datetime_usec)
    end
    create index(:jobs, [:project_id])
    create index(:jobs, [:status])

    # ----- JOB_RUNS -----
    create table(:job_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :job_id, references(:jobs, type: :binary_id, on_delete: :delete_all), null: false
      add :executed_at, :utc_datetime_usec, null: false
      add :status, :string, null: false
      add :result, :map

      timestamps(type: :utc_datetime_usec)
    end
    create index(:job_runs, [:job_id])
    create index(:job_runs, [:executed_at])

    # ----- OBAN -----
    Oban.Migration.up(version: 12)
  end

  def down do
    Oban.Migration.down(version: 1)
    drop table(:job_runs)
    drop table(:jobs)
    drop table(:deliveries)
    drop table(:webhook_events)
    drop table(:webhooks)
    drop table(:api_keys)
    drop table(:projects)
    drop table(:users)
  end
end
