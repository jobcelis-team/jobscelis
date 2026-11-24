defmodule StreamflixCore.Repo.Migrations.IndexForeignKeysOfDeadLetters do
  @moduledoc """
  Indexes the foreign keys of dead_letters and batch_items. Without them every
  delivery, event or webhook deleted (purges, project deletion) made Postgres
  scan these tables to apply ON DELETE, and create_dead_letter looked up
  delivery_id with a sequential scan.
  """
  use Ecto.Migration

  def change do
    create_if_not_exists index(:dead_letters, [:delivery_id])
    create_if_not_exists index(:dead_letters, [:event_id])
    create_if_not_exists index(:dead_letters, [:webhook_id])
    create_if_not_exists index(:batch_items, [:event_id])
  end
end
