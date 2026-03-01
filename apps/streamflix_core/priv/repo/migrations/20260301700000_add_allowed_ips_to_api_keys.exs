defmodule StreamflixCore.Repo.Migrations.AddAllowedIpsToApiKeys do
  use Ecto.Migration

  def change do
    alter table(:api_keys) do
      add :allowed_ips, {:array, :string}, default: [], null: false
    end
  end
end
