defmodule StreamflixCore.Repo.Migrations.CreateNotificationChannels do
  use Ecto.Migration

  def change do
    # Disable Supabase RLS trigger before creating table
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

    create table(:notification_channels, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false

      # Channel: email
      add :email_enabled, :boolean, default: false, null: false
      add :email_address, :string

      # Channel: Slack incoming webhook
      add :slack_enabled, :boolean, default: false, null: false
      add :slack_webhook_url, :string

      # Channel: Discord incoming webhook
      add :discord_enabled, :boolean, default: false, null: false
      add :discord_webhook_url, :string

      # Channel: meta-webhook (webhook about your webhooks)
      add :meta_webhook_enabled, :boolean, default: false, null: false
      add :meta_webhook_url, :string
      add :meta_webhook_secret, :string

      # Which event types trigger external alerts (nil = all)
      add :event_types, {:array, :string}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:notification_channels, [:project_id])

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
