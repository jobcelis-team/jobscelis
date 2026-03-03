defmodule StreamflixWebWeb.BrowserExportController do
  @moduledoc """
  Handles export downloads initiated from the browser dashboard.
  Uses session-based authentication (current_user from session).
  """
  use StreamflixWebWeb, :controller

  alias StreamflixCore.Platform
  alias StreamflixCore.Audit
  alias StreamflixCore.Teams
  alias StreamflixCore.GDPR

  @max_export 10_000

  defp require_auth(conn) do
    case conn.assigns[:current_user] do
      nil -> {:error, conn}
      user -> {:ok, user}
    end
  end

  defp get_user_project(user) do
    projects = Teams.list_all_accessible_projects(user.id)
    Enum.find(projects, & &1.is_default) || List.first(projects)
  end

  def events(conn, params) do
    with {:ok, user} <- require_auth(conn),
         project when not is_nil(project) <- get_user_project(user) do
      format = params["format"] || "json"

      events =
        Platform.list_events(project.id,
          limit: @max_export,
          topic: params["topic"]
        )

      rows =
        Enum.map(events, fn e ->
          %{
            id: e.id,
            topic: e.topic,
            status: e.status,
            occurred_at: to_string(e.occurred_at),
            payload: Jason.encode!(e.payload || %{}),
            payload_hash: e.payload_hash || ""
          }
        end)

      export(conn, rows, format, "events", ~w(id topic status occurred_at payload payload_hash))
    else
      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Unauthorized"})
    end
  end

  def deliveries(conn, params) do
    with {:ok, user} <- require_auth(conn),
         project when not is_nil(project) <- get_user_project(user) do
      format = params["format"] || "json"
      deliveries = Platform.list_deliveries(project_id: project.id, limit: @max_export)

      rows =
        Enum.map(deliveries, fn d ->
          %{
            id: d.id,
            event_id: d.event_id,
            webhook_id: d.webhook_id,
            status: d.status,
            attempt_number: d.attempt_number,
            response_status: d.response_status,
            inserted_at: to_string(d.inserted_at)
          }
        end)

      export(
        conn,
        rows,
        format,
        "deliveries",
        ~w(id event_id webhook_id status attempt_number response_status inserted_at)
      )
    else
      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Unauthorized"})
    end
  end

  def jobs(conn, params) do
    with {:ok, user} <- require_auth(conn),
         project when not is_nil(project) <- get_user_project(user) do
      format = params["format"] || "json"
      jobs = Platform.list_jobs(project.id, include_inactive: true)

      rows =
        Enum.map(jobs, fn j ->
          %{
            id: j.id,
            name: j.name,
            status: j.status,
            schedule_type: j.schedule_type,
            action_type: j.action_type,
            inserted_at: to_string(j.inserted_at)
          }
        end)

      export(conn, rows, format, "jobs", ~w(id name status schedule_type action_type inserted_at))
    else
      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Unauthorized"})
    end
  end

  def audit_log(conn, params) do
    with {:ok, user} <- require_auth(conn),
         project when not is_nil(project) <- get_user_project(user) do
      format = params["format"] || "json"
      logs = Audit.list_for_project(project.id, limit: @max_export)

      rows =
        Enum.map(logs, fn l ->
          %{
            id: l.id,
            action: l.action,
            resource_type: l.resource_type,
            resource_id: l.resource_id,
            user_id: l.user_id,
            ip_address: l.ip_address,
            inserted_at: to_string(l.inserted_at)
          }
        end)

      export(
        conn,
        rows,
        format,
        "audit_log",
        ~w(id action resource_type resource_id user_id ip_address inserted_at)
      )
    else
      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Unauthorized"})
    end
  end

  def my_data(conn, _params) do
    with {:ok, user} <- require_auth(conn) do
      data = GDPR.collect_user_data(user)

      Audit.record("gdpr.data_export", user_id: user.id)

      conn
      |> put_resp_content_type("application/json")
      |> put_resp_header("content-disposition", "attachment; filename=\"my-data.json\"")
      |> json(%{data: data})
    else
      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Unauthorized"})
    end
  end

  defp export(conn, rows, "csv", filename, columns) do
    header = Enum.join(columns, ",") <> "\n"

    body =
      Enum.map_join(rows, "\n", fn row ->
        Enum.map_join(columns, ",", fn col ->
          value = Map.get(row, String.to_existing_atom(col), "")
          csv_escape(to_string(value))
        end)
      end)

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}.csv\"")
    |> send_resp(200, header <> body)
  end

  defp export(conn, rows, _format, filename, _columns) do
    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}.json\"")
    |> json(%{data: rows, total: length(rows)})
  end

  defp csv_escape(value) do
    if String.contains?(value, [",", "\"", "\n"]) do
      "\"" <> String.replace(value, "\"", "\"\"") <> "\""
    else
      value
    end
  end
end
