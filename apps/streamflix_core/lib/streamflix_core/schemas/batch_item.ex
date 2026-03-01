defmodule StreamflixCore.Schemas.BatchItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "batch_items" do
    belongs_to(:webhook, StreamflixCore.Schemas.Webhook)
    belongs_to(:event, StreamflixCore.Schemas.WebhookEvent)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(batch_item, attrs) do
    batch_item
    |> cast(attrs, [:webhook_id, :event_id])
    |> validate_required([:webhook_id, :event_id])
    |> foreign_key_constraint(:webhook_id)
    |> foreign_key_constraint(:event_id)
  end
end
