defmodule StreamflixWebWeb.Api.V1.PlatformReplaysController do
  use StreamflixWebWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias StreamflixCore.Platform
  alias StreamflixCore.Audit
  alias StreamflixWebWeb.Schemas

  tags ["Event Replay"]
  security [%{"api_key" => []}]

  operation :create,
    summary: "Start an event replay",
    request_body: {"Replay filters", "application/json", %OpenApiSpex.Schema{type: :object, properties: %{topic: %OpenApiSpex.Schema{type: :string}, from_date: %OpenApiSpex.Schema{type: :string}, to_date: %OpenApiSpex.Schema{type: :string}, webhook_id: %OpenApiSpex.Schema{type: :string}}}},
    responses: [
      created: {"Replay started", "application/json", Schemas.Replay},
      unprocessable_entity: {"Invalid filters", "application/json", Schemas.ErrorResponse}
    ]

  def create(conn, params) do
    project = conn.assigns.current_project

    filters = %{
      "topic" => params["topic"],
      "from_date" => params["from_date"] || params["from"],
      "to_date" => params["to_date"] || params["to"],
      "webhook_id" => params["webhook_id"]
    }

    case Platform.create_replay(project.id, project.user_id, filters) do
      {:ok, replay} ->
        Audit.record("replay.started",
          user_id: project.user_id,
          project_id: project.id,
          resource_type: "replay",
          resource_id: replay.id,
          metadata: filters
        )

        conn
        |> put_status(:created)
        |> json(replay_json(replay))

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create replay", details: inspect(changeset)})
    end
  end

  operation :index,
    summary: "List event replays",
    responses: [
      ok: {"Replays list", "application/json", %OpenApiSpex.Schema{type: :object, properties: %{data: %OpenApiSpex.Schema{type: :array, items: Schemas.Replay}}}}
    ]

  def index(conn, _params) do
    project = conn.assigns.current_project
    replays = Platform.list_replays(project.id)
    json(conn, %{data: Enum.map(replays, &replay_json/1)})
  end

  operation :show,
    summary: "Get replay details",
    parameters: [id: [in: :path, type: :string, description: "Replay ID"]],
    responses: [
      ok: {"Replay details", "application/json", Schemas.Replay},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse}
    ]

  def show(conn, %{"id" => id}) do
    case Platform.get_replay(id) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "not_found"})
      replay -> json(conn, replay_json(replay))
    end
  end

  operation :cancel,
    summary: "Cancel a running replay",
    parameters: [id: [in: :path, type: :string, description: "Replay ID"]],
    responses: [
      ok: {"Replay cancelled", "application/json", Schemas.Replay},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse},
      conflict: {"Already finished", "application/json", Schemas.ErrorResponse}
    ]

  def cancel(conn, %{"id" => id}) do
    project = conn.assigns.current_project

    case Platform.cancel_replay(id) do
      {:ok, replay} ->
        Audit.record("replay.cancelled",
          user_id: project.user_id,
          project_id: project.id,
          resource_type: "replay",
          resource_id: replay.id
        )

        json(conn, replay_json(replay))

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      {:error, :already_finished} ->
        conn |> put_status(:conflict) |> json(%{error: "Replay already finished"})
    end
  end

  defp replay_json(replay) do
    %{
      id: replay.id,
      status: replay.status,
      filters: replay.filters,
      total_events: replay.total_events,
      processed_events: replay.processed_events,
      started_at: replay.started_at,
      completed_at: replay.completed_at,
      inserted_at: replay.inserted_at
    }
  end
end
