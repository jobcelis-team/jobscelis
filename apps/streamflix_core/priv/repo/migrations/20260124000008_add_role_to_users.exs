defmodule StreamflixCore.Repo.Migrations.AddRoleToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add_if_not_exists :role, :string, default: "user"
    end

    create_if_not_exists index(:users, [:role])
  end
end
