defmodule StreamflixCore.Repo.Migrations.MultiProjectSupport do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :is_default, :boolean, null: false, default: false
    end

    create index(:projects, [:user_id, :is_default])
  end
end
