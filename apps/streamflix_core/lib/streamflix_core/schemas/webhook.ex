defmodule StreamflixCore.Schemas.Webhook do
  @moduledoc """
  Webhook schema: destination URL + filters + body_config.
  Only active webhooks receive deliveries.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "webhooks" do
    field :url, :string
    field :secret_encrypted, StreamflixCore.Encrypted.Binary
    field :status, :string, default: "active"
    field :topics, {:array, :string}, default: []
    field :filters, StreamflixCore.Types.WebhookFilters, default: []
    field :body_config, :map, default: %{}
    field :headers, :map, default: %{}
    field :retry_config, :map, default: %{}
    field :batch_config, :map

    belongs_to :project, StreamflixCore.Schemas.Project
    has_many :deliveries, StreamflixCore.Schemas.Delivery

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(webhook, attrs) do
    webhook
    |> cast(attrs, [:project_id, :url, :secret_encrypted, :status, :topics, :filters, :body_config, :headers, :retry_config, :batch_config])
    |> validate_required([:project_id, :url])
    |> validate_inclusion(:status, ~w(active inactive))
    |> validate_format(:url, ~r|^https?://|, message: "must be http or https")
    |> foreign_key_constraint(:project_id)
  end
end
