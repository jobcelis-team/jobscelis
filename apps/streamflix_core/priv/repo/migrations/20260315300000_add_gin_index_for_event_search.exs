defmodule StreamflixCore.Repo.Migrations.AddGinIndexForEventSearch do
  use Ecto.Migration

  def change do
    execute(
      "CREATE INDEX IF NOT EXISTS webhook_events_payload_gin ON webhook_events USING gin (payload jsonb_path_ops)",
      "DROP INDEX IF EXISTS webhook_events_payload_gin"
    )
  end
end
