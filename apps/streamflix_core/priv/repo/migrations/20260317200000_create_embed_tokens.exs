defmodule StreamflixCore.Repo.Migrations.CreateEmbedTokens do
  use Ecto.Migration

  def change do
    # Disable Supabase RLS trigger before table creation
    execute(
      """
      DO $$ BEGIN
        IF EXISTS (SELECT 1 FROM pg_event_trigger WHERE evtname = 'ensure_rls_on_new_tables') THEN
          ALTER EVENT TRIGGER ensure_rls_on_new_tables DISABLE;
        END IF;
      END $$;
      """,
      """
      DO $$ BEGIN
        IF EXISTS (SELECT 1 FROM pg_event_trigger WHERE evtname = 'ensure_rls_on_new_tables') THEN
          ALTER EVENT TRIGGER ensure_rls_on_new_tables ENABLE;
        END IF;
      END $$;
      """
    )

    create table(:embed_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false
      add :prefix, :string, null: false
      add :token_hash, :string, null: false
      add :name, :string, default: "Default"
      add :status, :string, null: false, default: "active"
      add :scopes, {:array, :string}, null: false, default: ["webhooks:read", "webhooks:write", "deliveries:read", "deliveries:retry"]
      add :allowed_origins, {:array, :string}, default: []
      add :metadata, :map, default: %{}
      add :expires_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:embed_tokens, [:project_id])
    create unique_index(:embed_tokens, [:token_hash])
    create index(:embed_tokens, [:status])

    # Re-enable Supabase RLS trigger
    execute(
      """
      DO $$ BEGIN
        IF EXISTS (SELECT 1 FROM pg_event_trigger WHERE evtname = 'ensure_rls_on_new_tables') THEN
          ALTER EVENT TRIGGER ensure_rls_on_new_tables ENABLE;
        END IF;
      END $$;
      """,
      """
      DO $$ BEGIN
        IF EXISTS (SELECT 1 FROM pg_event_trigger WHERE evtname = 'ensure_rls_on_new_tables') THEN
          ALTER EVENT TRIGGER ensure_rls_on_new_tables DISABLE;
        END IF;
      END $$;
      """
    )
  end
end
