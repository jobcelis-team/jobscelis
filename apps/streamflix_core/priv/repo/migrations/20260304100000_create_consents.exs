defmodule StreamflixCore.Repo.Migrations.CreateConsents do
  use Ecto.Migration

  def change do
    create table(:consents, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :purpose, :string, null: false
      add :granted_at, :utc_datetime_usec, null: false
      add :revoked_at, :utc_datetime_usec
      add :ip_address, :string
      add :version, :string, default: "1.0"

      timestamps(type: :utc_datetime_usec)
    end

    create index(:consents, [:user_id])
    create index(:consents, [:user_id, :purpose])
  end
end
