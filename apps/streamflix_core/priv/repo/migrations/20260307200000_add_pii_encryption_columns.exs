defmodule StreamflixCore.Repo.Migrations.AddPiiEncryptionColumns do
  use Ecto.Migration

  def change do
    # Users: encrypted email, HMAC hash for lookups, encrypted name
    alter table(:users) do
      add :email_encrypted, :binary
      add :email_hash, :binary
      add :name_encrypted, :binary
    end

    create unique_index(:users, [:email_hash])

    # Audit logs: encrypted IP and user agent
    alter table(:audit_logs) do
      add :ip_address_encrypted, :binary
      add :user_agent_encrypted, :binary
    end

    # Consents: encrypted IP
    alter table(:consents) do
      add :ip_address_encrypted, :binary
    end

    # Sandbox requests: encrypted IP
    alter table(:sandbox_requests) do
      add :ip_encrypted, :binary
    end
  end
end
