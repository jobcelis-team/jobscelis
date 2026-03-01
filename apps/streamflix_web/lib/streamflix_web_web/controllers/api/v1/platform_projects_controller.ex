defmodule StreamflixWebWeb.Api.V1.PlatformProjectsController do
  use StreamflixWebWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias StreamflixCore.Platform

  action_fallback StreamflixWebWeb.FallbackController

  tags(["Projects"])
  security([%{"bearer" => []}])

  operation(:index,
    summary: "List all projects",
    responses: [ok: {"Projects list", "application/json", StreamflixWebWeb.Schemas.ProjectList}]
  )

  def index(conn, _params) do
    user = conn.assigns.current_user
    projects = Platform.list_projects_for_user(user.id)
    json(conn, %{data: Enum.map(projects, &project_json/1)})
  end

  operation(:create,
    summary: "Create a new project",
    request_body: {"Project params", "application/json", StreamflixWebWeb.Schemas.ProjectCreate},
    responses: [
      created: {"Project created", "application/json", StreamflixWebWeb.Schemas.ProjectResponse}
    ]
  )

  def create(conn, params) do
    user = conn.assigns.current_user

    attrs = %{
      user_id: user.id,
      name: params["name"] || "New Project",
      settings: params["settings"] || %{}
    }

    case Platform.create_project(attrs) do
      {:ok, project} ->
        conn
        |> put_status(:created)
        |> json(%{data: project_json(project)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid project params", details: format_errors(changeset)})
    end
  end

  operation(:show,
    summary: "Get project details",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Project details", "application/json", StreamflixWebWeb.Schemas.ProjectResponse}
    ]
  )

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Platform.get_project(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Project not found"})

      project ->
        if project.user_id == user.id or
             StreamflixCore.Teams.user_can_access?(project.id, user.id) do
          json(conn, %{data: project_json(project)})
        else
          conn |> put_status(:forbidden) |> json(%{error: "Access denied"})
        end
    end
  end

  operation(:update,
    summary: "Update project",
    parameters: [id: [in: :path, type: :string, required: true]],
    request_body: {"Project params", "application/json", StreamflixWebWeb.Schemas.ProjectCreate},
    responses: [
      ok: {"Project updated", "application/json", StreamflixWebWeb.Schemas.ProjectResponse}
    ]
  )

  def update(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    case Platform.get_project(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Project not found"})

      project ->
        if project.user_id == user.id or StreamflixCore.Teams.user_can_write?(project.id, user.id) do
          attrs = Map.take(params, ["name", "settings"])

          case Platform.update_project(project, attrs) do
            {:ok, updated} ->
              json(conn, %{data: project_json(updated)})

            {:error, changeset} ->
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{error: "Invalid params", details: format_errors(changeset)})
          end
        else
          conn |> put_status(:forbidden) |> json(%{error: "Access denied"})
        end
    end
  end

  operation(:delete,
    summary: "Delete (soft) project",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Project deleted", "application/json", StreamflixWebWeb.Schemas.ProjectResponse}
    ]
  )

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Platform.get_project(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Project not found"})

      project ->
        if project.user_id != user.id do
          conn |> put_status(:forbidden) |> json(%{error: "Only owner can delete"})
        else
          case Platform.delete_project(project) do
            {:ok, _} ->
              json(conn, %{ok: true})

            {:error, _} ->
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{error: "Could not delete project"})
          end
        end
    end
  end

  operation(:set_default,
    summary: "Set project as default",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [ok: {"Default set", "application/json", StreamflixWebWeb.Schemas.ProjectResponse}]
  )

  def set_default(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Platform.set_default_project(user.id, id) do
      {:ok, project} ->
        json(conn, %{data: project_json(project)})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Project not found"})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Could not set default"})
    end
  end

  defp project_json(project) do
    %{
      id: project.id,
      name: project.name,
      status: project.status,
      is_default: project.is_default,
      settings: project.settings,
      inserted_at: project.inserted_at,
      updated_at: project.updated_at
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
