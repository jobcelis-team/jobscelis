defmodule StreamflixCore.Repo.Migrations.AddRateLimitToWebhooks do
  use Ecto.Migration

  def change do
    alter table(:webhooks) do
      add :rate_limit, :map, default: %{}
    end
  end
end
