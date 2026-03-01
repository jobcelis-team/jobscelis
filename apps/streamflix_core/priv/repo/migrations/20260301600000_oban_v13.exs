defmodule StreamflixCore.Repo.Migrations.ObanV13 do
  use Ecto.Migration

  def up, do: Oban.Migration.up(version: 13)
  def down, do: Oban.Migration.down(version: 13)
end
