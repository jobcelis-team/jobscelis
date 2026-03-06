defmodule StreamflixCore.Repo.Migrations.AddRateLimitFieldsToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :rate_limit_events_per_minute, :integer, default: 1000, null: false
      add :rate_limit_api_calls_per_minute, :integer, default: 500, null: false
    end
  end
end
