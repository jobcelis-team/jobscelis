defmodule StreamflixCore.Repo.Migrations.AddPayloadOverrideToDeliveries do
  use Ecto.Migration

  # Payload produced by a pipeline (filter/transform) for this delivery.
  # NULL means the event payload is delivered as-is.
  def change do
    alter table(:deliveries) do
      add :payload_override, :map
    end
  end
end
