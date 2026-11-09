defmodule StreamflixCore.Schemas.AuditLog do
  @moduledoc """
  Immutable audit log entry. Records every significant action in the platform.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "audit_logs" do
    field(:user_id, :binary_id)
    field(:project_id, :binary_id)
    field(:action, :string)
    field(:resource_type, :string)
    field(:resource_id, :binary_id)
    field(:metadata, :map, default: %{})
    field(:ip_address, StreamflixCore.Encrypted.Binary)
    # Blind index of ip_address: equal IPs give equal hashes (breach detection)
    field(:ip_hash, StreamflixCore.Hashed.HMAC)
    field(:user_agent, StreamflixCore.Encrypted.Binary)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [
      :user_id,
      :project_id,
      :action,
      :resource_type,
      :resource_id,
      :metadata,
      :ip_address,
      :user_agent
    ])
    |> validate_required([:action])
    |> put_ip_hash()
  end

  defp put_ip_hash(changeset) do
    case get_change(changeset, :ip_address) do
      ip when is_binary(ip) and ip != "" -> put_change(changeset, :ip_hash, String.trim(ip))
      _ -> changeset
    end
  end
end
