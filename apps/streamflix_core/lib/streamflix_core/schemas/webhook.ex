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
    field(:url, :string)
    field(:secret_encrypted, StreamflixCore.Encrypted.Binary)
    field(:status, :string, default: "active")
    field(:topics, {:array, :string}, default: [])
    field(:filters, StreamflixCore.Types.WebhookFilters, default: [])
    field(:body_config, :map, default: %{})
    field(:headers, :map, default: %{})
    field(:retry_config, :map, default: %{})
    field(:batch_config, :map)
    field(:rate_limit, :map, default: %{})

    # Circuit breaker fields
    field(:circuit_state, :string, default: "closed")
    field(:circuit_opened_at, :utc_datetime_usec)
    field(:consecutive_failures, :integer, default: 0)

    belongs_to(:project, StreamflixCore.Schemas.Project)
    has_many(:deliveries, StreamflixCore.Schemas.Delivery)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(webhook, attrs) do
    webhook
    |> cast(attrs, [
      :project_id,
      :url,
      :secret_encrypted,
      :status,
      :topics,
      :filters,
      :body_config,
      :headers,
      :retry_config,
      :batch_config,
      :rate_limit,
      :circuit_state,
      :circuit_opened_at,
      :consecutive_failures
    ])
    |> validate_required([:project_id, :url])
    |> validate_inclusion(:status, ~w(active inactive))
    |> validate_format(:url, ~r|^https?://|, message: "must be http or https")
    |> StreamflixCore.Platform.UrlGuard.validate_changeset(:url)
    |> validate_headers()
    |> foreign_key_constraint(:project_id)
  end

  # Custom headers are sent with every delivery: string names/values only and
  # no CR/LF (header injection).
  defp validate_headers(changeset) do
    validate_change(changeset, :headers, fn :headers, headers ->
      valid? =
        is_map(headers) and
          Enum.all?(headers, fn {k, v} ->
            is_binary(k) and is_binary(v) and k =~ ~r/\A[A-Za-z0-9!#$%&'*+.^_`|~-]+\z/ and
              not String.contains?(v, ["\r", "\n"])
          end)

      if valid?, do: [], else: [headers: "must be a map of valid header names to string values"]
    end)
  end
end
