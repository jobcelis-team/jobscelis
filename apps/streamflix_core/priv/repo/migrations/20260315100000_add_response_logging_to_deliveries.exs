defmodule StreamflixCore.Repo.Migrations.AddResponseLoggingToDeliveries do
  use Ecto.Migration

  def change do
    alter table(:deliveries) do
      add :response_headers, :map
      add :response_latency_ms, :integer
    end
  end
end
