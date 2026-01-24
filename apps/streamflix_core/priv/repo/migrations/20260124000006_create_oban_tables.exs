defmodule StreamflixCore.Repo.Migrations.CreateObanTables do
  use Ecto.Migration

  def up do
    Oban.Migrations.up(version: 12)
  end

  def down do
    Oban.Migrations.down(version: 1)
  end
end
