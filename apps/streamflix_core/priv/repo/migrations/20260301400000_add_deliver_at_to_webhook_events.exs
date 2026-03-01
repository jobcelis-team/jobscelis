defmodule StreamflixCore.Repo.Migrations.AddDeliverAtToWebhookEvents do
  use Ecto.Migration

  def change do
    alter table(:webhook_events) do
      add :deliver_at, :utc_datetime_usec
    end

    create index(:webhook_events, [:deliver_at],
      where: "deliver_at IS NOT NULL AND status = 'active'",
      name: :webhook_events_deliver_at_pending_idx
    )
  end
end
