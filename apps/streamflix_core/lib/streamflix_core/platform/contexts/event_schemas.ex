defmodule StreamflixCore.Platform.EventSchemas do
  @moduledoc """
  Event schema management: CRUD, JSON Schema validation.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.EventSchema

  @cache :platform_cache
  @resolved_ttl :timer.minutes(10)

  def create_event_schema(project_id, attrs) do
    attrs = Map.merge(attrs, %{"project_id" => project_id})

    StreamflixCore.Platform.Quotas.with_quota(:event_schemas, project_id, fn ->
      %EventSchema{}
      |> EventSchema.changeset(attrs)
      |> validate_schema_document()
      |> Repo.insert()
      |> invalidate_active_schema()
    end)
  end

  def list_event_schemas(project_id, opts \\ []) do
    include_inactive = Keyword.get(opts, :include_inactive, false)

    EventSchema
    |> where([s], s.project_id == ^project_id)
    |> maybe_filter_active(include_inactive)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  def get_event_schema(id), do: Repo.get_uuid(EventSchema, id)

  def update_event_schema(%EventSchema{} = schema, attrs) do
    # The topic may change: the old one's cached schema is cleared too
    Cachex.del(@cache, {:active_event_schema, schema.project_id, schema.topic})

    schema
    |> EventSchema.changeset(attrs)
    |> validate_schema_document()
    |> Repo.update()
    |> invalidate_active_schema()
  end

  @active_ttl :timer.seconds(60)

  defp invalidate_active_schema({:ok, %EventSchema{project_id: p, topic: t}} = result) do
    Cachex.del(@cache, {:active_event_schema, p, t})
    result
  end

  defp invalidate_active_schema(other), do: other

  # The active schema of a topic is read for every event, so it is cached
  # (nil as :none); create and update clear it.
  defp active_schema(project_id, topic) do
    loader = fn ->
      EventSchema
      |> where([s], s.project_id == ^project_id and s.topic == ^topic and s.status == "active")
      |> order_by([s], desc: s.version)
      |> limit(1)
      |> Repo.one()
    end

    case Cachex.fetch(@cache, {:active_event_schema, project_id, topic}, fn _ ->
           {:commit, loader.() || :none, expire: @active_ttl}
         end) do
      {status, :none} when status in [:ok, :commit] -> nil
      {status, record} when status in [:ok, :commit] -> record
      _ -> loader.()
    end
  end

  @doc "Max size of a schema document (JSON-encoded bytes)."
  def max_schema_bytes, do: Application.get_env(:streamflix_core, :max_event_schema_bytes, 64_000)

  @doc """
  Validates the `:schema` field of a changeset: size limit, only local `$ref`s
  (`#...`; remote references are never fetched) and the document must resolve
  as a JSON Schema. Rejected here so a stored schema can always be applied.
  """
  def validate_schema_document(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.validate_change(changeset, :schema, fn :schema, schema ->
      case check_schema_document(schema) do
        :ok -> []
        {:error, message} -> [schema: message]
      end
    end)
  end

  @doc "Returns :ok or {:error, message} for a JSON Schema document."
  def check_schema_document(schema) when is_map(schema) do
    max = max_schema_bytes()

    cond do
      byte_size(Jason.encode!(schema)) > max ->
        {:error, "is too large (maximum #{max} bytes)"}

      remote_ref?(schema) ->
        {:error, "must not use remote $ref (only local references starting with #)"}

      true ->
        case resolve_schema(schema) do
          {:ok, _} -> :ok
          {:error, message} -> {:error, "is not a valid JSON Schema: " <> message}
        end
    end
  rescue
    _ -> {:error, "is not a valid JSON Schema"}
  end

  def check_schema_document(_), do: {:error, "must be a JSON object"}

  defp remote_ref?(%{} = map) do
    Enum.any?(map, fn
      {"$ref", ref} -> not (is_binary(ref) and String.starts_with?(ref, "#"))
      {_k, v} -> remote_ref?(v)
    end)
  end

  defp remote_ref?(list) when is_list(list), do: Enum.any?(list, &remote_ref?/1)
  defp remote_ref?(_), do: false

  defp resolve_schema(schema) do
    {:ok, ExJsonSchema.Schema.resolve(schema)}
  rescue
    e -> {:error, Exception.message(e)}
  end

  def delete_event_schema(%EventSchema{} = schema) do
    update_event_schema(schema, %{status: "inactive"})
  end

  def validate_event_payload(project_id, topic, payload) do
    case topic do
      nil ->
        :ok

      "" ->
        :ok

      t ->
        case active_schema(project_id, t) do
          nil ->
            :ok

          record ->
            apply_schema(record, payload)
        end
    end
  end

  # Never raises: a schema that cannot be resolved or applied (e.g. stored before
  # schemas were validated on save) rejects the event as a validation failure
  # instead of crashing event creation with a 500.
  defp apply_schema(record, payload) do
    with {:ok, resolved} <- cached_resolved(record) do
      case ExJsonSchema.Validator.validate(resolved, payload) do
        :ok -> :ok
        {:error, errors} -> {:error, {:schema_validation, errors}}
      end
    end
  rescue
    _ -> schema_unusable()
  end

  defp cached_resolved(%{id: id, updated_at: updated_at, schema: schema}) do
    key = {:resolved_event_schema, id, updated_at}

    case Cachex.get(@cache, key) do
      {:ok, nil} -> resolve_and_cache(key, schema)
      {:ok, resolved} -> {:ok, resolved}
      _ -> resolve_and_cache(key, schema)
    end
  end

  defp resolve_and_cache(key, schema) do
    if is_map(schema) and not remote_ref?(schema) do
      case resolve_schema(schema) do
        {:ok, resolved} ->
          Cachex.put(@cache, key, resolved, expire: @resolved_ttl)
          {:ok, resolved}

        {:error, _} ->
          schema_unusable()
      end
    else
      schema_unusable()
    end
  end

  defp schema_unusable,
    do: {:error, {:schema_validation, [{"Event schema for this topic is invalid", "#"}]}}

  def dry_validate_event_payload(project_id, topic, payload) do
    validate_event_payload(project_id, topic, payload)
  end

  defp maybe_filter_active(query, true), do: query
  defp maybe_filter_active(query, false), do: where(query, [x], x.status == "active")
end
