defmodule StreamflixCore.Repo.Migrations.AddLastProjectIdToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :last_project_id, :binary_id
    end
  end
end
