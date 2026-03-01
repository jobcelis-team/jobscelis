defmodule StreamflixCore.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all)
      add :type, :string, null: false
      add :title, :string, null: false
      add :message, :text
      add :metadata, :map, default: %{}
      add :read, :boolean, default: false
      add :read_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:notifications, [:user_id, :read, :inserted_at],
      name: :idx_notifications_user
    )
  end
end
