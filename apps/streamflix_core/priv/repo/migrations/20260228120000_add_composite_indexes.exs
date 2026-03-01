defmodule StreamflixCore.Repo.Migrations.AddCompositeIndexes do
  @moduledoc """
  Adds composite and partial indexes for performance optimization.
  These indexes speed up the most common queries by 10-100x on large datasets.
  """
  use Ecto.Migration

  def up do
    # Deliveries: pending deliveries by webhook (used in health checks and retry logic)
    create index(:deliveries, [:webhook_id, :status],
      where: "status = 'pending'",
      name: :idx_deliveries_webhook_pending
    )

    # Deliveries: pending deliveries ready for retry
    create index(:deliveries, [:next_retry_at],
      where: "status = 'pending' AND next_retry_at IS NOT NULL",
      name: :idx_deliveries_pending_retry
    )

    # Deliveries: recent deliveries per webhook (dashboard queries)
    create index(:deliveries, [:webhook_id, :inserted_at],
      name: :idx_deliveries_webhook_recent
    )

    # Events: project + topic + date (list_events with topic filter, event replay)
    create index(:webhook_events, [:project_id, :topic, :occurred_at],
      name: :idx_events_project_topic_date
    )

    # Events: project + status + occurred_at (list_events default query)
    create index(:webhook_events, [:project_id, :status, :occurred_at],
      where: "status = 'active'",
      name: :idx_events_project_active
    )

    # Jobs: active jobs by schedule type (Scheduler query every 60s)
    create index(:jobs, [:status, :schedule_type],
      where: "status = 'active'",
      name: :idx_jobs_active_schedule
    )

    # API Keys: active key lookup by hash (verify_api_key on every API request)
    create index(:api_keys, [:key_hash],
      where: "status = 'active'",
      name: :idx_api_keys_active_hash
    )

    # Projects: user's active project (get_project_by_user_id)
    create index(:projects, [:user_id, :status],
      where: "status = 'active'",
      name: :idx_projects_user_active
    )

    # Webhooks: active webhooks per project (list_active_webhooks_for_project)
    create index(:webhooks, [:project_id, :status],
      where: "status = 'active'",
      name: :idx_webhooks_project_active
    )

    # Job runs: recent runs per job (list_job_runs)
    create index(:job_runs, [:job_id, :executed_at],
      name: :idx_job_runs_job_recent
    )

    # Upgrade Oban to V13 for improved indexes
    Oban.Migration.up(version: 13)
  end

  def down do
    Oban.Migration.down(version: 12)

    drop_if_exists index(:job_runs, [:job_id, :executed_at], name: :idx_job_runs_job_recent)
    drop_if_exists index(:webhooks, [:project_id, :status], name: :idx_webhooks_project_active)
    drop_if_exists index(:projects, [:user_id, :status], name: :idx_projects_user_active)
    drop_if_exists index(:api_keys, [:key_hash], name: :idx_api_keys_active_hash)
    drop_if_exists index(:jobs, [:status, :schedule_type], name: :idx_jobs_active_schedule)
    drop_if_exists index(:webhook_events, [:project_id, :status, :occurred_at], name: :idx_events_project_active)
    drop_if_exists index(:webhook_events, [:project_id, :topic, :occurred_at], name: :idx_events_project_topic_date)
    drop_if_exists index(:deliveries, [:webhook_id, :inserted_at], name: :idx_deliveries_webhook_recent)
    drop_if_exists index(:deliveries, [:next_retry_at], name: :idx_deliveries_pending_retry)
    drop_if_exists index(:deliveries, [:webhook_id, :status], name: :idx_deliveries_webhook_pending)
  end
end
