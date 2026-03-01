defmodule StreamflixCore.Repo.Migrations.AddScopesToApiKeys do
  use Ecto.Migration

  def change do
    alter table(:api_keys) do
      add :scopes, {:array, :string}, null: false, default: fragment("'{\"*\"}'")
    end
  end
end
