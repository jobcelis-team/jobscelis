defmodule StreamflixCore.Repo.Migrations.AddIpHashToAuditLogs do
  use Ecto.Migration

  # ip_address is encrypted with a random IV, so equal IPs never compare equal.
  # ip_hash is a keyed HMAC (blind index) that lets breach detection group
  # failed logins by IP without storing the address in clear. Old rows keep a
  # NULL hash: detection only looks at the last few minutes.
  def change do
    alter table(:audit_logs) do
      add(:ip_hash, :binary)
    end
  end
end
