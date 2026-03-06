defmodule StreamflixCore.Repo.Migrations.Sprint5ObservabilityIndexes do
  use Ecto.Migration

  @moduledoc """
  Sprint 5 (#33): Database indexes audit.
  Adds missing composite indexes for hot query paths:
  - deliveries by event_id + status (event detail modal timeline)
  - deliveries by inserted_at descending (recent deliveries queries)
  - dead_letters by project_id + resolved (bulk DLQ operations)
  - webhook_events by project_id + occurred_at (dashboard listing)
  - notifications by user_id + inserted_at (notification listing)
  """

  def change do
    # Delivery timeline: filter by event_id and status
    create_if_not_exists index(:deliveries, [:event_id, :status],
                           name: :deliveries_event_id_status_idx)

    # Recent deliveries for a webhook, ordered by date
    create_if_not_exists index(:deliveries, [:webhook_id, :status, :inserted_at],
                           name: :deliveries_webhook_status_inserted_idx)

    # Bulk DLQ: filter by project + resolved flag
    create_if_not_exists index(:dead_letters, [:project_id, :resolved],
                           name: :dead_letters_project_resolved_idx)

    # Events listing: project + occurred_at descending (most common dashboard query)
    execute(
      "CREATE INDEX IF NOT EXISTS webhook_events_project_occurred_desc_idx ON webhook_events (project_id, occurred_at DESC)",
      "DROP INDEX IF EXISTS webhook_events_project_occurred_desc_idx"
    )

    # Notifications: user_id + inserted_at descending
    execute(
      "CREATE INDEX IF NOT EXISTS notifications_user_inserted_desc_idx ON notifications (user_id, inserted_at DESC)",
      "DROP INDEX IF EXISTS notifications_user_inserted_desc_idx"
    )

    # Consents: unique per user+purpose (for idempotent grant_consent)
    create_if_not_exists unique_index(:consents, [:user_id, :purpose, :revoked_at],
                                      name: :consents_user_purpose_active_idx,
                                      where: "revoked_at IS NULL")
  end
end
