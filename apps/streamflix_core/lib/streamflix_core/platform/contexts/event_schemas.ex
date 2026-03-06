defmodule StreamflixCore.Platform.EventSchemas do
  @moduledoc """
  Event schema management: CRUD, JSON Schema validation.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.EventSchema

  def create_event_schema(project_id, attrs) do
    attrs = Map.merge(attrs, %{"project_id" => project_id})

    %EventSchema{}
    |> EventSchema.changeset(attrs)
    |> Repo.insert()
  end

  def list_event_schemas(project_id, opts \\ []) do
    include_inactive = Keyword.get(opts, :include_inactive, false)

    EventSchema
    |> where([s], s.project_id == ^project_id)
    |> maybe_filter_active(include_inactive)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  def get_event_schema(id), do: Repo.get(EventSchema, id)

  def update_event_schema(%EventSchema{} = schema, attrs) do
    schema
    |> EventSchema.changeset(attrs)
    |> Repo.update()
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
        schema_record =
          EventSchema
          |> where([s], s.project_id == ^project_id and s.topic == ^t and s.status == "active")
          |> order_by([s], desc: s.version)
          |> limit(1)
          |> Repo.one()

        case schema_record do
          nil ->
            :ok

          %{schema: json_schema} ->
            resolved = ExJsonSchema.Schema.resolve(json_schema)

            case ExJsonSchema.Validator.validate(resolved, payload) do
              :ok -> :ok
              {:error, errors} -> {:error, {:schema_validation, errors}}
            end
        end
    end
  end

  def dry_validate_event_payload(project_id, topic, payload) do
    validate_event_payload(project_id, topic, payload)
  end

  defp maybe_filter_active(query, true), do: query
  defp maybe_filter_active(query, false), do: where(query, [x], x.status == "active")
end
