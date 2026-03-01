defmodule StreamflixCore.Repo.Migrations.CreateBatchItems do
  use Ecto.Migration

  def change do
    create table(:batch_items, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :webhook_id, references(:webhooks, type: :binary_id, on_delete: :delete_all), null: false
      add :event_id, references(:webhook_events, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:batch_items, [:webhook_id, :inserted_at])

    alter table(:webhooks) do
      add :batch_config, :map
    end
  end
end
