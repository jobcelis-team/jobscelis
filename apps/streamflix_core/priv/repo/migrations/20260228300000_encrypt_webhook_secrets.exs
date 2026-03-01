defmodule StreamflixCore.Repo.Migrations.EncryptWebhookSecrets do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE webhooks ALTER COLUMN secret_encrypted TYPE bytea USING secret_encrypted::bytea"
  end

  def down do
    execute "ALTER TABLE webhooks ALTER COLUMN secret_encrypted TYPE varchar USING encode(secret_encrypted, 'escape')"
  end
end
