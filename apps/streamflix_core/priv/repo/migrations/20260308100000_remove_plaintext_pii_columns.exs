defmodule StreamflixCore.Repo.Migrations.RemovePlaintextPiiColumns do
  @moduledoc """
  Removes plaintext PII columns after verifying encrypted columns are populated.
  Run `mix encrypt_pii` BEFORE this migration.

  WARNING: This migration is irreversible. Make sure all data is encrypted first.
  """
  use Ecto.Migration

  def up do
    # Users: remove plaintext email and name (keep email_encrypted, email_hash, name_encrypted)
    alter table(:users) do
      remove :email
      remove :name
    end

    # Rename encrypted columns to original names
    rename table(:users), :email_encrypted, to: :email
    rename table(:users), :name_encrypted, to: :name

    # Audit logs: remove plaintext IP and user agent
    alter table(:audit_logs) do
      remove :ip_address
      remove :user_agent
    end

    rename table(:audit_logs), :ip_address_encrypted, to: :ip_address
    rename table(:audit_logs), :user_agent_encrypted, to: :user_agent

    # Consents: remove plaintext IP
    alter table(:consents) do
      remove :ip_address
    end

    rename table(:consents), :ip_address_encrypted, to: :ip_address

    # Sandbox requests: remove plaintext IP
    alter table(:sandbox_requests) do
      remove :ip
    end

    rename table(:sandbox_requests), :ip_encrypted, to: :ip
  end

  def down do
    # Reverse: add back plaintext columns, rename encrypted back
    rename table(:users), :email, to: :email_encrypted
    rename table(:users), :name, to: :name_encrypted

    alter table(:users) do
      add :email, :string
      add :name, :string
    end

    rename table(:audit_logs), :ip_address, to: :ip_address_encrypted
    rename table(:audit_logs), :user_agent, to: :user_agent_encrypted

    alter table(:audit_logs) do
      add :ip_address, :string
      add :user_agent, :string
    end

    rename table(:consents), :ip_address, to: :ip_address_encrypted

    alter table(:consents) do
      add :ip_address, :string
    end

    rename table(:sandbox_requests), :ip, to: :ip_encrypted

    alter table(:sandbox_requests) do
      add :ip, :string
    end
  end
end
