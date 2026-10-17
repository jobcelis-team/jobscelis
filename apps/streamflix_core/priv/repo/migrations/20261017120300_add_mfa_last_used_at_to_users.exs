defmodule StreamflixCore.Repo.Migrations.AddMfaLastUsedAtToUsers do
  use Ecto.Migration

  # Start of the TOTP time step last accepted for login: a code from that step
  # (or an earlier one) cannot be replayed.
  def change do
    alter table(:users) do
      add :mfa_last_used_at, :utc_datetime
    end
  end
end
