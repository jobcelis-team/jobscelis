defmodule StreamflixCore.Repo.Migrations.AddIntegrityFieldsToWebhookEvents do
  use Ecto.Migration

  def change do
    alter table(:webhook_events) do
      add :payload_hash, :string
      add :idempotency_key, :string
    end

    create unique_index(:webhook_events, [:project_id, :idempotency_key],
      where: "idempotency_key IS NOT NULL",
      name: :webhook_events_project_idempotency_key_index
    )
  end
end
