defmodule StreamflixCore.Repo.Migrations.AddTimezoneToUsers do
  use Ecto.Migration

  # Preferred display timezone (IANA name, e.g. "America/Guayaquil", or "UTC").
  # NULL = automatic: use the browser's timezone.
  def change do
    alter table(:users) do
      add :timezone, :string, size: 64
    end
  end
end
