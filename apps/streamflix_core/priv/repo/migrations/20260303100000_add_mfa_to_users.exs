defmodule StreamflixCore.Repo.Migrations.AddMfaToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :mfa_enabled, :boolean, default: false, null: false
      add :mfa_secret, :binary
      add :mfa_backup_codes, {:array, :string}, default: []
      add :mfa_enabled_at, :utc_datetime
    end
  end
end
