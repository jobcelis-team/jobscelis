defmodule StreamflixCore.Schemas.UptimeCheck do
  @moduledoc """
  Schema for uptime check records.
  Status: healthy, degraded, unhealthy.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "uptime_checks" do
    field :status, :string
    field :checks, :map, default: %{}
    field :response_time_ms, :integer
    field :metadata, :map, default: %{}

    timestamps(updated_at: false)
  end

  def changeset(check, attrs) do
    check
    |> cast(attrs, [:status, :checks, :response_time_ms, :metadata])
    |> validate_required([:status, :checks])
    |> validate_inclusion(:status, ~w(healthy degraded unhealthy))
  end
end
