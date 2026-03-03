defmodule StreamflixCore.Repo.Migrations.AddCircuitBreakerToWebhooks do
  use Ecto.Migration

  def change do
    alter table(:webhooks) do
      add :circuit_state, :string, default: "closed"
      add :circuit_opened_at, :utc_datetime_usec
      add :consecutive_failures, :integer, default: 0
    end
  end
end
