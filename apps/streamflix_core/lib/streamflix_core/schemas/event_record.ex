defmodule StreamflixCore.Schemas.EventRecord do
  @moduledoc """
  Ecto schema for persisting domain events.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:event_id, :binary_id, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec, updated_at: false]

  schema "events" do
    field :event_type, :string
    field :aggregate_type, :string
    field :aggregate_id, :binary_id
    field :version, :integer, default: 1
    field :data, :map
    field :metadata, :map, default: %{}
    field :causation_id, :binary_id
    field :correlation_id, :binary_id

    timestamps()
  end

  @required_fields [:event_id, :event_type, :aggregate_type, :aggregate_id, :data]
  @optional_fields [:version, :metadata, :causation_id, :correlation_id]

  def changeset(record, attrs) do
    record
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:event_id, name: :events_pkey)
    |> unique_constraint([:aggregate_id, :version])
  end

  # ============================================
  # CONVERSION FUNCTIONS
  # ============================================

  @doc """
  Converts a domain event to a database record.
  """
  def from_domain_event(event) do
    event_module = event.__struct__
    event_type = event_type_from_module(event_module)
    {aggregate_type, aggregate_id} = extract_aggregate_info(event)

    %__MODULE__{
      event_id: Map.get(event, :event_id) || UUID.uuid4(),
      event_type: event_type,
      aggregate_type: aggregate_type,
      aggregate_id: aggregate_id,
      version: Map.get(event, :version, 1),
      data: event_to_map(event),
      metadata: %{
        node: to_string(Node.self()),
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    }
  end

  @doc """
  Converts a database record back to a domain event.
  """
  def to_domain_event(%__MODULE__{} = record) do
    module = module_from_event_type(record.event_type)

    if module && Code.ensure_loaded?(module) do
      data = record.data
      |> atomize_keys()
      |> Map.put(:event_id, record.event_id)

      struct(module, data)
    else
      nil
    end
  end

  # ============================================
  # QUERY HELPERS
  # ============================================

  def by_aggregate(query \\ __MODULE__, aggregate_type, aggregate_id) do
    from e in query,
      where: e.aggregate_type == ^to_string(aggregate_type),
      where: e.aggregate_id == ^aggregate_id
  end

  def by_type(query \\ __MODULE__, event_type) do
    from e in query,
      where: e.event_type == ^to_string(event_type)
  end

  def ordered_by_timestamp(query \\ __MODULE__) do
    from e in query, order_by: [asc: e.inserted_at]
  end

  def since(query \\ __MODULE__, datetime) do
    from e in query,
      where: e.inserted_at >= ^datetime
  end

  # ============================================
  # PRIVATE FUNCTIONS
  # ============================================

  defp event_type_from_module(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  defp module_from_event_type(event_type) do
    module_name = event_type
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join("")

    Module.concat([StreamflixCore.Events, module_name])
  rescue
    _ -> nil
  end

  defp extract_aggregate_info(event) do
    cond do
      Map.has_key?(event, :user_id) ->
        {"user", event.user_id}

      Map.has_key?(event, :profile_id) ->
        {"profile", event.profile_id}

      Map.has_key?(event, :content_id) ->
        {"content", event.content_id}

      Map.has_key?(event, :subscription_id) ->
        {"subscription", event.subscription_id}

      Map.has_key?(event, :video_id) ->
        {"video", event.video_id}

      Map.has_key?(event, :session_id) ->
        {"playback_session", event.session_id}

      true ->
        {"unknown", UUID.uuid4()}
    end
  end

  defp event_to_map(event) do
    event
    |> Map.from_struct()
    |> Map.drop([:__struct__])
    |> Enum.map(fn {k, v} -> {to_string(k), serialize_value(v)} end)
    |> Map.new()
  end

  defp serialize_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp serialize_value(%Date{} = d), do: Date.to_iso8601(d)
  defp serialize_value(value), do: value

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) ->
        {String.to_existing_atom(key), atomize_keys(value)}
      {key, value} ->
        {key, atomize_keys(value)}
    end)
  rescue
    ArgumentError -> map
  end
  defp atomize_keys(value), do: value
end
