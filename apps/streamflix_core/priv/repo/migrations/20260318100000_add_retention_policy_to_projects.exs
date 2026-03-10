defmodule StreamflixCore.Repo.Migrations.AddRetentionPolicyToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :retention_policy, :map, default: %{}
    end
  end
end
