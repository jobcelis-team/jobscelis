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

  # URLs with signed query strings can be long; the column is text
  @max_url_length 2048

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
    |> validate_length(:url, max: @max_url_length)
    |> validate_format(:url, ~r|^https?://|, message: "must be http or https")
    |> validate_public_url()
    |> validate_headers()
    |> validate_topics()
    |> validate_rate_limit()
    |> validate_retry_config()
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

  # Only a well-formed URL is resolved and checked against private networks:
  # one error per problem, and no DNS lookup for input that is already invalid.
  defp validate_public_url(changeset) do
    if Keyword.has_key?(changeset.errors, :url),
      do: changeset,
      else: StreamflixCore.Platform.UrlGuard.validate_changeset(changeset, :url)
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

  @max_delay_seconds 86_400

  # Read by RateLimiter on every delivery. 0 throttled every delivery forever
  # (endless snoozes); a non-integer crashed the comparison.
  defp validate_rate_limit(changeset) do
    validate_change(changeset, :rate_limit, fn :rate_limit, config ->
      allowed = %{"max_per_second" => 1..10_000, "max_per_minute" => 1..600_000}

      if valid_int_config?(config, allowed),
        do: [],
        else: [
          rate_limit: "accepts max_per_second (1-10000) and max_per_minute (1-600000) as integers"
        ]
    end)
  end

  # Read by ObanDeliveryWorker.backoff/1: a string or float delay raised inside
  # Oban and left the job stuck until it was rescued.
  defp validate_retry_config(changeset) do
    validate_change(changeset, :retry_config, fn :retry_config, config ->
      allowed = %{
        "max_attempts" => 1..20,
        "base_delay_seconds" => 1..@max_delay_seconds,
        "base_delay" => 1..@max_delay_seconds,
        "max_delay_seconds" => 1..@max_delay_seconds,
        "max_delay" => 1..@max_delay_seconds
      }

      {special, ints} = Map.split(stringify(config), ["strategy", "jitter", "backoff_seconds"])

      valid? =
        is_map(config) and valid_int_config?(ints, allowed) and
          Map.get(special, "strategy", "exponential") in ~w(exponential linear fixed) and
          is_boolean(Map.get(special, "jitter", true)) and
          valid_backoff_list?(Map.get(special, "backoff_seconds"))

      if valid?,
        do: [],
        else: [
          retry_config:
            "accepts strategy (exponential, linear, fixed), jitter (boolean), integer " <>
              "max_attempts (1-20) and delays in seconds (1-86400), or backoff_seconds " <>
              "(up to 20 such delays)"
        ]
    end)
  end

  defp valid_backoff_list?(nil), do: true

  defp valid_backoff_list?(delays) when is_list(delays) and length(delays) <= 20,
    do: Enum.all?(delays, &(is_integer(&1) and &1 in 1..@max_delay_seconds))

  defp valid_backoff_list?(_), do: false

  defp valid_int_config?(config, allowed) when is_map(config) do
    Enum.all?(stringify(config), fn {key, value} ->
      case Map.fetch(allowed, key) do
        {:ok, range} -> is_integer(value) and value in range
        :error -> false
      end
    end)
  end

  defp valid_int_config?(_config, _allowed), do: false

  defp stringify(config) when is_map(config),
    do: Map.new(config, fn {k, v} -> {to_string(k), v} end)

  defp stringify(_config), do: %{}
end
