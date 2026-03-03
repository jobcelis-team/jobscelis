defmodule StreamflixCore.Repo.Migrations.CreateUserSessions do
  use Ecto.Migration

  def change do
    create table(:user_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id, null: false
      add :token_jti, :string, null: false
      add :ip_address, :string
      add :user_agent, :string
      add :device_info, :string
      add :last_activity_at, :utc_datetime_usec
      add :revoked_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:user_sessions, [:token_jti])
    create index(:user_sessions, [:user_id])
  end
end
