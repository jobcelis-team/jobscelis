defmodule StreamflixCore.Repo.Migrations.AddRetentionDaysToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :retention_days, :integer
    end
  end
end
