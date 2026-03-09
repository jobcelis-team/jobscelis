defmodule StreamflixCore.Schemas.Delivery do
  @moduledoc """
  Delivery schema: one attempt to POST to a webhook URL.
  Status: pending, success, failed.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "deliveries" do
    field(:status, :string, default: "pending")
    field(:attempt_number, :integer, default: 0)
    field(:response_status, :integer)
    field(:response_body, :string)
    field(:response_headers, :map)
    field(:response_latency_ms, :integer)
    field(:next_retry_at, :utc_datetime_usec)
    field(:request_headers, :map)
    field(:request_body, :string)
    field(:destination_ip, :string)

    belongs_to(:event, StreamflixCore.Schemas.WebhookEvent)
    belongs_to(:webhook, StreamflixCore.Schemas.Webhook)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(delivery, attrs) do
    delivery
    |> cast(attrs, [
      :event_id,
      :webhook_id,
      :status,
      :attempt_number,
      :response_status,
      :response_body,
      :response_headers,
      :response_latency_ms,
      :next_retry_at,
      :request_headers,
      :request_body,
      :destination_ip
    ])
    |> validate_required([:event_id, :webhook_id])
    |> validate_inclusion(:status, ~w(pending success failed circuit_open))
    |> foreign_key_constraint(:event_id)
    |> foreign_key_constraint(:webhook_id)
  end
end
