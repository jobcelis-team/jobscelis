defmodule StreamflixCore.Repo.Migrations.AddRetryConfigToWebhooks do
  use Ecto.Migration

  def change do
    alter table(:webhooks) do
      add :retry_config, :map, default: %{}
    end
  end
end
