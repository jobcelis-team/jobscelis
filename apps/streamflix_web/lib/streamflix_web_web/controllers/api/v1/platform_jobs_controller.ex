defmodule StreamflixWebWeb.Api.V1.PlatformJobsController do
  use StreamflixWebWeb, :controller

  alias StreamflixCore.Platform

  def index(conn, params) do
    project = conn.assigns.current_project
    opts = [include_inactive: params["include"] == "inactive"]
    jobs = Platform.list_jobs(project.id, opts)
    json(conn, %{jobs: Enum.map(jobs, &job_json/1)})
  end

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
