defmodule StreamflixCore.Repo.Migrations.AddPerformanceIndexes do
  use Ecto.Migration

  def change do
    # Covering index for access checks: user_can_access?/user_can_write?
    # Replaces sequential scan on (project_id, user_id) + status filter
    create_if_not_exists index(:project_members, [:project_id, :user_id, :status],
      name: :project_members_access_check_idx
    )

    # Covering index for team member listing with status filter
    create_if_not_exists index(:project_members, [:project_id, :status, :inserted_at],
      name: :project_members_listing_idx
    )

    # Covering index for audit log filtered queries (action + date range)
    create_if_not_exists index(:audit_logs, [:project_id, :action, :inserted_at],
      name: :audit_logs_project_action_idx
    )

    # Expression index for analytics DATE() aggregation on webhook_events
    execute(
      "CREATE INDEX IF NOT EXISTS webhook_events_inserted_date_idx ON webhook_events (date_trunc('day', inserted_at), project_id)",
      "DROP INDEX IF EXISTS webhook_events_inserted_date_idx"
    )

    # Expression index for analytics DATE() aggregation on deliveries
    execute(
      "CREATE INDEX IF NOT EXISTS deliveries_inserted_date_idx ON deliveries (date_trunc('day', inserted_at), webhook_id)",
      "DROP INDEX IF EXISTS deliveries_inserted_date_idx"
    )
  end
end
