defmodule StreamflixCore.Repo.Migrations.AddMissingPerformanceIndexes do
  use Ecto.Migration

  def change do
    # Speeds up purge, replay, and health queries on deliveries
    create_if_not_exists index(:deliveries, [:status, :inserted_at],
                           name: :idx_deliveries_status_inserted)

    # Speeds up password history checks (most recent first)
    create_if_not_exists index(:password_history, [:user_id, :inserted_at],
                           name: :idx_password_history_user_inserted)

    # Speeds up breach detection queries filtering by action + time range
    create_if_not_exists index(:audit_logs, [:action, :inserted_at],
                           name: :idx_audit_logs_action_inserted)

    # Speeds up delayed events query (partial index on non-null deliver_at)
    execute(
      "CREATE INDEX IF NOT EXISTS idx_webhook_events_deliver_at ON webhook_events(deliver_at) WHERE deliver_at IS NOT NULL",
      "DROP INDEX IF EXISTS idx_webhook_events_deliver_at"
    )
  end
end
