defmodule StreamflixCore.Repo.Migrations.CreatePasswordHistory do
  use Ecto.Migration

  def change do
    create table(:password_history, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id, null: false
      add :password_hash, :string, null: false

      timestamps(updated_at: false)
    end

    create index(:password_history, [:user_id])
  end
end
