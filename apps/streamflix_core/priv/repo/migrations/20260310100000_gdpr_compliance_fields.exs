defmodule StreamflixCore.Repo.Migrations.GdprComplianceFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :processing_consent, :boolean, default: true, null: false
      add :restricted_at, :utc_datetime_usec
      add :restriction_reason, :string
    end
  end
end
