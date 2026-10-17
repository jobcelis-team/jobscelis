defmodule StreamflixCore.Repo.Migrations.AddDispatchedAtToWebhookEvents do
  use Ecto.Migration

  # Marks when a delayed event was processed by the delayed-events worker, so
  # events that matched no webhook are not re-scanned on every run.
  def change do
    alter table(:webhook_events) do
      add :dispatched_at, :utc_datetime_usec
    end

    create index(:webhook_events, [:deliver_at],
             where: "dispatched_at IS NULL AND deliver_at IS NOT NULL",
             name: :webhook_events_pending_delayed_index
           )
  end
end
