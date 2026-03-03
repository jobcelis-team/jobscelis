defmodule StreamflixCore.Repo.Migrations.AddLoginLockoutToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :failed_login_attempts, :integer, default: 0, null: false
      add :locked_at, :utc_datetime_usec
    end
  end
end
