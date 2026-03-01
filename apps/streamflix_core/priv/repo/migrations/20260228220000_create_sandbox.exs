defmodule StreamflixCore.Repo.Migrations.CreateSandbox do
  use Ecto.Migration

  def change do
    create table(:sandbox_endpoints, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, references(:projects, type: :binary_id, on_delete: :delete_all), null: false
      add :slug, :string, null: false
      add :name, :string
      add :expires_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:sandbox_endpoints, [:slug])
    create index(:sandbox_endpoints, [:project_id, :expires_at])

    create table(:sandbox_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :endpoint_id, references(:sandbox_endpoints, type: :binary_id, on_delete: :delete_all), null: false
      add :method, :string, null: false
      add :path, :text
      add :headers, :map, default: %{}
      add :body, :text
      add :query_params, :map, default: %{}
      add :ip, :string

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:sandbox_requests, [:endpoint_id, :inserted_at])
  end
end
