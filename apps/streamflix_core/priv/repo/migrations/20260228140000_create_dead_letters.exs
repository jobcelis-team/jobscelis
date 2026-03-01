defmodule StreamflixCore.Repo.Migrations.CreateDeadLetters do
  use Ecto.Migration

  def change do
    create table(:dead_letters, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false
      add :delivery_id, references(:deliveries, type: :binary_id, on_delete: :nilify_all)
      add :event_id, references(:webhook_events, type: :binary_id, on_delete: :nilify_all)
      add :webhook_id, references(:webhooks, type: :binary_id, on_delete: :nilify_all)
      add :original_payload, :map, null: false, default: %{}
      add :last_error, :text
      add :last_response_status, :integer
      add :attempts_exhausted, :integer, default: 5
      add :resolved, :boolean, default: false
      add :resolved_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:dead_letters, [:project_id, :resolved, :inserted_at],
      name: :idx_dead_letters_project
    )
  end
end
