defmodule StreamflixCore.Repo.Migrations.CreateProjectMembers do
  use Ecto.Migration

  def change do
    create table(:project_members, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, :binary_id, null: false
      add :role, :string, size: 20, null: false, default: "viewer"
      add :invited_by, :binary_id
      add :status, :string, size: 20, null: false, default: "pending"

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:project_members, [:project_id, :user_id])
  end
end
