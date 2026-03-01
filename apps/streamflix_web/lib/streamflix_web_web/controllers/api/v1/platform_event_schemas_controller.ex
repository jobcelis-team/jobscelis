defmodule StreamflixWebWeb.Api.V1.PlatformEventSchemasController do
  use StreamflixWebWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias StreamflixCore.Platform

  plug StreamflixWebWeb.Plugs.RequireScope, "events:read" when action in [:index, :show]

  plug StreamflixWebWeb.Plugs.RequireScope,
       "events:write" when action in [:create, :update, :delete, :validate]

  tags(["Event Schemas"])
  security([%{"api_key" => []}])

  operation(:index,
    summary: "List event schemas",
    responses: [
      ok: {"Event schemas", "application/json", StreamflixWebWeb.Schemas.EventSchemaList}
    ]
  )

  def index(conn, _params) do
    project = conn.assigns.current_project
    schemas = Platform.list_event_schemas(project.id)
    json(conn, %{data: Enum.map(schemas, &schema_json/1)})
  end

  operation(:create,
    summary: "Create event schema",
    request_body:
      {"Schema params", "application/json", StreamflixWebWeb.Schemas.EventSchemaCreate},
    responses: [
      created:
        {"Schema created", "application/json", StreamflixWebWeb.Schemas.EventSchemaResponse}
    ]
  )

  def create(conn, params) do
    project = conn.assigns.current_project

    attrs = %{
      "topic" => params["topic"],
      "schema" => params["schema"],
      "version" => params["version"] || 1
    }

    case Platform.create_event_schema(project.id, attrs) do
      {:ok, schema} ->
        conn
        |> put_status(:created)
        |> json(%{data: schema_json(schema)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid schema params", details: format_errors(changeset)})
    end
  end

  operation(:show,
    summary: "Get event schema",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Event schema", "application/json", StreamflixWebWeb.Schemas.EventSchemaResponse}
    ]
  )

  def show(conn, %{"id" => id}) do
    project = conn.assigns.current_project

    case Platform.get_event_schema(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Schema not found"})

      schema ->
        if schema.project_id == project.id do
          json(conn, %{data: schema_json(schema)})
        else
          conn |> put_status(:not_found) |> json(%{error: "Schema not found"})
        end
    end
  end

  operation(:update,
    summary: "Update event schema",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body:
      {"Schema params", "application/json", StreamflixWebWeb.Schemas.EventSchemaCreate},
    responses: [
      ok: {"Schema updated", "application/json", StreamflixWebWeb.Schemas.EventSchemaResponse}
    ]
  )

  def update(conn, %{"id" => id} = params) do
    project = conn.assigns.current_project

    case Platform.get_event_schema(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Schema not found"})

      schema ->
        if schema.project_id != project.id do
          conn |> put_status(:not_found) |> json(%{error: "Schema not found"})
        else
          attrs = Map.take(params, ["topic", "schema", "version", "status"])

          case Platform.update_event_schema(schema, attrs) do
            {:ok, updated} ->
              json(conn, %{data: schema_json(updated)})

            {:error, changeset} ->
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{error: "Invalid params", details: format_errors(changeset)})
          end
        end
    end
  end

  operation(:delete,
    summary: "Delete event schema",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Schema deleted", "application/json", StreamflixWebWeb.Schemas.EventSchemaResponse}
    ]
  )

  def delete(conn, %{"id" => id}) do
    project = conn.assigns.current_project

    case Platform.get_event_schema(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Schema not found"})

      schema ->
        if schema.project_id != project.id do
          conn |> put_status(:not_found) |> json(%{error: "Schema not found"})
        else
          case Platform.delete_event_schema(schema) do
            {:ok, _} ->
              json(conn, %{ok: true})

            {:error, _} ->
              conn |> put_status(:unprocessable_entity) |> json(%{error: "Could not delete"})
          end
        end
    end
  end

  operation(:validate,
    summary: "Validate event payload against schema (dry-run)",
    request_body:
      {"Validation params", "application/json", StreamflixWebWeb.Schemas.EventSchemaValidate},
    responses: [
      ok:
        {"Validation result", "application/json",
         StreamflixWebWeb.Schemas.EventSchemaValidateResponse}
    ]
  )

  def validate(conn, params) do
    project = conn.assigns.current_project
    topic = params["topic"]
    payload = params["payload"] || %{}

    case Platform.dry_validate_event_payload(project.id, topic, payload) do
      :ok ->
        json(conn, %{valid: true, errors: []})

      {:error, {:schema_validation, errors}} ->
        formatted = Enum.map(errors, fn {msg, path} -> %{message: msg, path: path} end)
        json(conn, %{valid: false, errors: formatted})
    end
  end

  defp schema_json(schema) do
    %{
      id: schema.id,
      project_id: schema.project_id,
      topic: schema.topic,
      schema: schema.schema,
      version: schema.version,
      status: schema.status,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp format_errors(_), do: %{}
end
