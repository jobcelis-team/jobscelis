defmodule StreamflixCore.Repo.Migrations.AddStatusToProfiles do
  use Ecto.Migration

  def change do
    alter table(:profiles) do
      add_if_not_exists :status, :string, default: "active"
    end

    create_if_not_exists index(:profiles, [:status])
  end
end
