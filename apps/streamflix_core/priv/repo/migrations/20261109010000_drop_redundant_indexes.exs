defmodule StreamflixCore.Repo.Migrations.DropRedundantIndexes do
  use Ecto.Migration

  # Every insert into deliveries and webhook_events updates every index on them.
  # These are dead (next_retry_at is always NULL and never queried), exact
  # duplicates, or covered by a composite index that starts with the same
  # column(s). `down` recreates them.
  def up do
    drop_if_exists(index(:deliveries, [:next_retry_at], name: :deliveries_next_retry_at_index))
    drop_if_exists(index(:deliveries, [:next_retry_at], name: :idx_deliveries_pending_retry))
    # covered by idx_deliveries_webhook_recent (webhook_id, inserted_at)
    drop_if_exists(index(:deliveries, [:webhook_id], name: :deliveries_webhook_id_index))
    # covered by deliveries_event_id_status_idx (event_id, status)
    drop_if_exists(index(:deliveries, [:event_id], name: :deliveries_event_id_index))
    # covered by idx_deliveries_status_inserted (status, inserted_at)
    drop_if_exists(index(:deliveries, [:status], name: :deliveries_status_index))
    # covered by webhook_events_project_occurred_desc_idx (project_id, occurred_at)
    drop_if_exists(index(:webhook_events, [:project_id], name: :webhook_events_project_id_index))
    # delayed events use webhook_events_pending_delayed_index
    drop_if_exists(index(:webhook_events, [:deliver_at], name: :idx_webhook_events_deliver_at))

    drop_if_exists(
      index(:webhook_events, [:deliver_at], name: :webhook_events_deliver_at_pending_idx)
    )

    # exact duplicate of audit_logs_action_inserted_at_index
    drop_if_exists(
      index(:audit_logs, [:action, :inserted_at], name: :idx_audit_logs_action_inserted)
    )
  end

  def down do
    create_if_not_exists(
      index(:deliveries, [:next_retry_at], name: :deliveries_next_retry_at_index)
    )

    create_if_not_exists(
      index(:deliveries, [:next_retry_at],
        name: :idx_deliveries_pending_retry,
        where: "status = 'pending' AND next_retry_at IS NOT NULL"
      )
    )

    create_if_not_exists(index(:deliveries, [:webhook_id], name: :deliveries_webhook_id_index))
    create_if_not_exists(index(:deliveries, [:event_id], name: :deliveries_event_id_index))
    create_if_not_exists(index(:deliveries, [:status], name: :deliveries_status_index))

    create_if_not_exists(
      index(:webhook_events, [:project_id], name: :webhook_events_project_id_index)
    )

    create_if_not_exists(
      index(:webhook_events, [:deliver_at],
        name: :idx_webhook_events_deliver_at,
        where: "deliver_at IS NOT NULL"
      )
    )

    create_if_not_exists(
      index(:webhook_events, [:deliver_at],
        name: :webhook_events_deliver_at_pending_idx,
        where: "deliver_at IS NOT NULL AND status = 'active'"
      )
    )

    create_if_not_exists(
      index(:audit_logs, [:action, :inserted_at], name: :idx_audit_logs_action_inserted)
    )
  end
end
