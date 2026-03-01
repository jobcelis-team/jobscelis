defmodule StreamflixWebWeb.Api.V1.PlatformJobsController do
  use StreamflixWebWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias StreamflixCore.Platform
  alias StreamflixWebWeb.Schemas

  plug StreamflixWebWeb.Plugs.RequireScope, "jobs:read" when action in [:index, :show, :runs, :cron_preview]
  plug StreamflixWebWeb.Plugs.RequireScope, "jobs:write" when action in [:create, :update, :delete]

  tags ["Jobs"]
  security [%{"api_key" => []}]

  operation :index,
    summary: "List scheduled jobs",
    parameters: [
      include: [in: :query, type: :string, description: "Set to 'inactive' to include inactive jobs"]
    ],
    responses: [
      ok: {"Jobs list", "application/json", %OpenApiSpex.Schema{type: :object, properties: %{jobs: %OpenApiSpex.Schema{type: :array, items: %OpenApiSpex.Schema{type: :object}}}}}
    ]

  def index(conn, params) do
    project = conn.assigns.current_project
    opts = [include_inactive: params["include"] == "inactive"]
    jobs = Platform.list_jobs(project.id, opts)
    json(conn, %{jobs: Enum.map(jobs, &job_json/1)})
  end

  operation :show,
    summary: "Get job details with runs",
    parameters: [id: [in: :path, type: :string, description: "Job ID"]],
    responses: [
      ok: {"Job details", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse}
    ]

  def show(conn, %{"id" => id}) do
    project = conn.assigns.current_project
    case Platform.get_job(id) do
      nil ->
        send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
      job ->
        if job.project_id != project.id do
          send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
        else
          runs = Platform.list_job_runs(job.id, limit: 10)
          json(conn, job_json(job) |> Map.put(:recent_runs, Enum.map(runs, &run_json/1)))
        end
    end
  end

  operation :create,
    summary: "Create a scheduled job",
    request_body: {"Job attributes", "application/json", %OpenApiSpex.Schema{type: :object, properties: %{name: %OpenApiSpex.Schema{type: :string}, schedule_type: %OpenApiSpex.Schema{type: :string}, schedule_config: %OpenApiSpex.Schema{type: :object}, action_type: %OpenApiSpex.Schema{type: :string}, action_config: %OpenApiSpex.Schema{type: :object}}}},
    responses: [
      created: {"Job created", "application/json", %OpenApiSpex.Schema{type: :object}},
      unprocessable_entity: {"Validation errors", "application/json", Schemas.ErrorResponse}
    ]

  def create(conn, params) do
    project = conn.assigns.current_project
    attrs = %{
      "name" => params["name"],
      "schedule_type" => params["schedule_type"] || "daily",
      "schedule_config" => params["schedule_config"] || %{},
      "action_type" => params["action_type"] || "emit_event",
      "action_config" => params["action_config"] || %{}
    }
    case Platform.create_job(project.id, attrs) do
      {:ok, job} -> conn |> put_status(:created) |> json(job_json(job))
      {:error, changeset} -> conn |> put_status(422) |> json(%{errors: format_errors(changeset)})
    end
  end

  operation :update,
    summary: "Update a scheduled job",
    parameters: [id: [in: :path, type: :string, description: "Job ID"]],
    request_body: {"Job attributes", "application/json", %OpenApiSpex.Schema{type: :object, properties: %{name: %OpenApiSpex.Schema{type: :string}, schedule_type: %OpenApiSpex.Schema{type: :string}, schedule_config: %OpenApiSpex.Schema{type: :object}, action_type: %OpenApiSpex.Schema{type: :string}, action_config: %OpenApiSpex.Schema{type: :object}, status: %OpenApiSpex.Schema{type: :string}}}},
    responses: [
      ok: {"Job updated", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse},
      unprocessable_entity: {"Validation errors", "application/json", Schemas.ErrorResponse}
    ]

  def update(conn, %{"id" => id} = params) do
    project = conn.assigns.current_project
    case Platform.get_job(id) do
      nil ->
        send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
      job ->
        if job.project_id != project.id do
          send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
        else
          attrs =
            params
            |> Map.take(["name", "schedule_type", "schedule_config", "action_type", "action_config", "status"])
            |> Enum.reject(fn {_, v} -> is_nil(v) end)
            |> Map.new()
          case Platform.update_job(job, attrs) do
            {:ok, updated} -> json(conn, job_json(updated))
            {:error, changeset} -> conn |> put_status(422) |> json(%{errors: format_errors(changeset)})
          end
        end
    end
  end

  operation :delete,
    summary: "Deactivate a scheduled job",
    parameters: [id: [in: :path, type: :string, description: "Job ID"]],
    responses: [
      ok: {"Job deactivated", "application/json", %OpenApiSpex.Schema{type: :object, properties: %{status: %OpenApiSpex.Schema{type: :string}}}},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse}
    ]

  def delete(conn, %{"id" => id}) do
    project = conn.assigns.current_project
    case Platform.get_job(id) do
      nil ->
        send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
      job ->
        if job.project_id != project.id do
          send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
        else
          {:ok, _} = Platform.set_job_inactive(job)
          send_resp(conn, 200, Jason.encode!(%{status: "inactive"}))
        end
    end
  end

  operation :runs,
    summary: "List job execution runs",
    parameters: [
      id: [in: :path, type: :string, description: "Job ID"],
      limit: [in: :query, type: :integer, description: "Max results (1-100, default 20)"]
    ],
    responses: [
      ok: {"Job runs list", "application/json", %OpenApiSpex.Schema{type: :object, properties: %{runs: %OpenApiSpex.Schema{type: :array, items: %OpenApiSpex.Schema{type: :object}}}}},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse}
    ]

  def runs(conn, %{"id" => id} = params) do
    project = conn.assigns.current_project
    case Platform.get_job(id) do
      nil ->
        send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
      job ->
        if job.project_id != project.id do
          send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
        else
          limit = min(parse_int(params["limit"], 20), 100)
          runs = Platform.list_job_runs(job.id, limit: limit)
          json(conn, %{runs: Enum.map(runs, &run_json/1)})
        end
    end
  end

  def cron_preview(conn, %{"expression" => expr}) when is_binary(expr) do
    executions = Platform.next_cron_executions(expr, 5)
    json(conn, %{
      expression: expr,
      next_executions: Enum.map(executions, &DateTime.to_iso8601/1)
    })
  end

  def cron_preview(conn, _) do
    conn |> put_status(422) |> json(%{error: "Missing 'expression' parameter"})
  end

  defp job_json(j) do
    %{
      id: j.id,
      name: j.name,
      schedule_type: j.schedule_type,
      schedule_config: j.schedule_config || %{},
      action_type: j.action_type,
      action_config: j.action_config || %{},
      status: j.status,
      inserted_at: j.inserted_at
    }
  end

  defp run_json(r) do
    %{id: r.id, executed_at: r.executed_at, status: r.status, result: r.result}
  end

  defp format_errors(c), do: Ecto.Changeset.traverse_errors(c, fn {msg, _} -> msg end)

  defp parse_int(nil, default), do: default
  defp parse_int(s, default) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> n
      _ -> default
    end
  end
  defp parse_int(_, default), do: default
end
