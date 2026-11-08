defmodule StreamflixCore.Repo.Migrations.WebhookUrlText do
  use Ecto.Migration

  # varchar(255) rejected longer webhook URLs with a database error; the
  # changeset now caps them at 2048. varchar -> text needs no table rewrite.
  def change do
    alter table(:webhooks) do
      modify(:url, :text, from: :string)
    end
  end
end
