defmodule StreamflixCore.Repo.Migrations.EnsureObanTables do
  @moduledoc """
  Ensures Oban tables (oban_jobs, oban_peers, etc.) exist.
  Safe to run if the reset migration already created them.
  """
  use Ecto.Migration

  def up do
    Oban.Migration.up(version: 12)
  end

  def down do
    Oban.Migration.down(version: 1)
  end
end
