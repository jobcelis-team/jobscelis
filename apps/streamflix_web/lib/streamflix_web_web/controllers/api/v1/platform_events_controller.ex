defmodule StreamflixWebWeb.Api.V1.PlatformEventsController do
  use StreamflixWebWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias StreamflixCore.Platform
  alias StreamflixWebWeb.Schemas

  plug StreamflixWebWeb.Plugs.RequireScope, "events:read" when action in [:index, :show]
  plug StreamflixWebWeb.Plugs.RequireScope, "events:write" when action in [:create, :delete, :simulate]

  action_fallback StreamflixWebWeb.FallbackController

  tags ["Events"]
  security [%{"api_key" => []}]

  operation :create,
    summary: "Send an event",
    description: "Send a JSON event. The body is the event payload. Include 'topic' for routing.",
    request_body: {"Event payload", "application/json", Schemas.EventCreate},
    responses: [
      accepted: {"Event accepted", "application/json", Schemas.EventResponse},
      unprocessable_entity: {"Invalid payload", "application/json", Schemas.ErrorResponse}
    ]

  @doc """
  POST /api/v1/send or /api/v1/events - Send an event (body = any JSON).
  """
  def create(conn, body) when is_map(body) do
    project = conn.assigns.current_project

    case Platform.create_event(project.id, body) do
      {:ok, event} ->
        resp = %{event_id: event.id}
        resp = if event.deliver_at, do: Map.put(resp, :deliver_at, event.deliver_at), else: resp

        conn
        |> put_status(:accepted)
        |> json(resp)

      {:error, {:schema_validation, errors}} ->
        formatted = Enum.map(errors, fn {msg, path} -> %{message: msg, path: path} end)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Schema validation failed", validation_errors: formatted})

      {:error, :invalid_payload} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid payload"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def create(conn, _), do: send_resp(conn, 422, Jason.encode!(%{error: "Body must be a JSON object"}))

  operation :index,
    summary: "List events",
    description: "List events for the project. Supports cursor-based pagination.",
    parameters: [
      include: [in: :query, type: :string, description: "Set to 'inactive' to include inactive events"],
      topic: [in: :query, type: :string, description: "Filter by topic"],
      limit: [in: :query, type: :integer, description: "Max results (1-200, default 50)"],
      cursor: [in: :query, type: :string, description: "Cursor for pagination (ID of last item)"]
    ],
    responses: [
      ok: {"Events list", "application/json", %OpenApiSpex.Schema{type: :object, properties: %{events: %OpenApiSpex.Schema{type: :array, items: Schemas.Event}}}}
    ]

  def index(conn, params) do
    project = conn.assigns.current_project
    opts = [
      topic: params["topic"],
      limit: parse_int(params["limit"], 50),
      cursor: params["cursor"]
    ]
    page = Platform.paginate_events(project.id, opts)
    json(conn, %{
      events: Enum.map(page.data, &event_json/1),
      has_next: page.has_next,
      next_cursor: page.next_cursor
    })
  end

  operation :show,
    summary: "Get event details",
    description: "Get a single event with its deliveries.",
    parameters: [id: [in: :path, type: :string, description: "Event ID"]],
    responses: [
      ok: {"Event details", "application/json", Schemas.Event},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse}
    ]

  def show(conn, %{"id" => id}) do
    project = conn.assigns.current_project
    case Platform.get_event(id) do
      nil -> send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
      event ->
        if event.project_id != project.id do
          send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
        else
          deliveries = Platform.list_deliveries(event_id: event.id)
          json(conn, event_json(event) |> Map.put(:deliveries, Enum.map(deliveries, &delivery_mini/1)))
        end
    end
  end

  operation :delete,
    summary: "Deactivate event",
    description: "Soft-delete an event (sets status to inactive).",
    parameters: [id: [in: :path, type: :string, description: "Event ID"]],
    responses: [
      ok: {"Event deactivated", "application/json", %OpenApiSpex.Schema{type: :object, properties: %{status: %OpenApiSpex.Schema{type: :string}}}},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse}
    ]

  def delete(conn, %{"id" => id}) do
    project = conn.assigns.current_project
    case Platform.get_event(id) do
      nil -> send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
      event ->
        if event.project_id != project.id do
          send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
        else
          {:ok, _} = Platform.set_event_inactive(event)
          send_resp(conn, 200, Jason.encode!(%{status: "inactive"}))
        end
    end
  end

  operation :simulate,
    summary: "Simulate event (dry-run)",
    description: "Test which webhooks would match without actually sending the event.",
    request_body: {"Event payload", "application/json", Schemas.EventCreate},
    responses: [
      ok: {"Simulation results", "application/json", %OpenApiSpex.Schema{type: :object, properties: %{simulation: %OpenApiSpex.Schema{type: :boolean}, matching_webhooks: %OpenApiSpex.Schema{type: :integer}, results: %OpenApiSpex.Schema{type: :array, items: %OpenApiSpex.Schema{type: :object}}}}},
      unprocessable_entity: {"Invalid payload", "application/json", Schemas.ErrorResponse}
    ]

  def simulate(conn, body) when is_map(body) do
    project = conn.assigns.current_project

    case Platform.simulate_event(project.id, body) do
      matches when is_list(matches) ->
        json(conn, %{
          simulation: true,
          matching_webhooks: length(matches),
          results: matches
        })

      {:error, :invalid_payload} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid payload"})
    end
  end

  def simulate(conn, _), do: send_resp(conn, 422, Jason.encode!(%{error: "Body must be a JSON object"}))

  defp event_json(e) do
    %{
      id: e.id,
      topic: e.topic,
      payload: e.payload,
      status: e.status,
      occurred_at: e.occurred_at,
      deliver_at: e.deliver_at,
      inserted_at: e.inserted_at
    }
  end

  defp delivery_mini(d) do
    %{id: d.id, status: d.status, attempt_number: d.attempt_number}
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp parse_int(nil, default), do: default
  defp parse_int(s, default) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> n
      _ -> default
    end
  end
  defp parse_int(_, default), do: default
end
