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
    |> validate_topics()
    |> foreign_key_constraint(:project_id)
  end

  @max_topics 50
  @max_topic_length 100
  @topic_format ~r/\A[A-Za-z0-9._*#:\-]+\z/

  @doc false
  def max_topics, do: @max_topics

  # Topics are shown in the dashboard and the embeddable portal: only plain
  # topic patterns are accepted so no markup can ever be stored.
  defp validate_topics(changeset) do
    validate_change(changeset, :topics, fn :topics, topics ->
      cond do
        length(topics) > @max_topics ->
          [topics: "cannot have more than #{@max_topics} topics"]

        not Enum.all?(topics, &valid_topic?/1) ->
          [
            topics:
              "each topic must be at most #{@max_topic_length} characters of letters, digits and . _ * # : -"
          ]

        true ->
          []
      end
    end)
  end

  defp valid_topic?(topic) when is_binary(topic),
    do: String.length(topic) <= @max_topic_length and topic =~ @topic_format

  defp valid_topic?(_), do: false

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
