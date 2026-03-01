defmodule StreamflixWebWeb.Api.V1.PlatformExportController do
  @moduledoc """
  Export data as CSV or JSON. Supports events, deliveries, jobs, and audit logs.
  """
  use StreamflixWebWeb, :controller

  alias StreamflixCore.Platform
  alias StreamflixCore.Audit

  plug StreamflixWebWeb.Plugs.RequireScope, "events:read" when action in [:events]
  plug StreamflixWebWeb.Plugs.RequireScope, "deliveries:read" when action in [:deliveries]
  plug StreamflixWebWeb.Plugs.RequireScope, "jobs:read" when action in [:jobs]

  @max_export 10_000

  def events(conn, params) do
    project = conn.assigns.current_project
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
          payload: Jason.encode!(e.payload || %{})
        }
      end)

    export(conn, rows, format, "events", ~w(id topic status occurred_at payload))
  end

  def deliveries(conn, params) do
    project = conn.assigns.current_project
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
  end

  def jobs(conn, params) do
    project = conn.assigns.current_project
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
  end

  def audit_log(conn, params) do
    project = conn.assigns.current_project
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
