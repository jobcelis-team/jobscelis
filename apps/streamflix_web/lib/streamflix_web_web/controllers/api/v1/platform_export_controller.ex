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
  plug StreamflixWebWeb.Plugs.RequireScope, "audit:read" when action in [:audit_log]

  @max_export 10_000

  # Events and deliveries can be large: rows are read page by page and streamed
  # as a chunked response, so memory stays bounded (see Platform.Exports).
  def events(conn, params) do
    project = conn.assigns.current_project
    format = params["format"] || "json"

    to_row = fn e ->
      %{
        id: e.id,
        topic: e.topic,
        status: e.status,
        occurred_at: to_string(e.occurred_at),
        payload: Jason.encode!(e.payload || %{}),
        payload_hash: e.payload_hash || ""
      }
    end

    stream_export(
      conn,
      {:events, project.id, [topic: params["topic"]]},
      to_row,
      format,
      "events",
      ~w(id topic status occurred_at payload payload_hash)
    )
  end

  def deliveries(conn, params) do
    project = conn.assigns.current_project
    format = params["format"] || "json"

    to_row = fn d ->
      %{
        id: d.id,
        event_id: d.event_id,
        webhook_id: d.webhook_id,
        status: d.status,
        attempt_number: d.attempt_number,
        response_status: d.response_status,
        inserted_at: to_string(d.inserted_at)
      }
    end

    stream_export(
      conn,
      {:deliveries, project.id, []},
      to_row,
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

  # Same output as export/5 (CSV with header line; JSON `{"data": [...], "total": n}`)
  # but written page by page. The content type is one of two fixed values.
  # sobelow_skip ["XSS.ContentType"]
  defp stream_export(conn, {kind, project_id, opts}, to_row, format, filename, columns) do
    csv? = format == "csv"
    ext = if csv?, do: "csv", else: "json"

    conn =
      conn
      |> put_resp_content_type(if csv?, do: "text/csv", else: "application/json")
      |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}.#{ext}\"")
      |> send_chunked(200)

    opening = if csv?, do: Enum.join(columns, ","), else: ~s({"data":[)

    with {:ok, conn} <- chunk(conn, opening) do
      write = fn rows, {:ok, conn, count} ->
        write_page(conn, rows, count, to_row, csv?, columns)
      end

      result = Platform.Exports.reduce_pages(kind, project_id, opts, {:ok, conn, 0}, write)

      case result do
        {:ok, conn, count} ->
          closing =
            cond do
              not csv? -> ~s(],"total":#{count}})
              # export/5 writes "header\n" when there are no rows
              count == 0 -> "\n"
              true -> ""
            end

          case chunk(conn, closing) do
            {:ok, conn} -> conn
            {:error, _} -> conn
          end

        {:error, _} ->
          conn
      end
    else
      {:error, _} -> conn
    end
  end

  defp write_page(conn, rows, count, to_row, csv?, columns) do
    data =
      Enum.map_join(rows, if(csv?, do: "", else: ","), fn row ->
        row = to_row.(row)
        if csv?, do: "\n" <> csv_line(row, columns), else: Jason.encode!(row)
      end)

    data = if not csv? and count > 0, do: "," <> data, else: data

    case chunk(conn, data) do
      {:ok, conn} -> {:cont, {:ok, conn, count + length(rows)}}
      {:error, _} = error -> {:halt, error}
    end
  end

  defp csv_line(row, columns) do
    Enum.map_join(columns, ",", fn col ->
      value = Map.get(row, String.to_existing_atom(col), "")
      csv_escape(to_string(value))
    end)
  end

  # RFC 4180 quoting plus CSV/formula-injection neutralizing, shared with the browser exporter
  defp csv_escape(value), do: StreamflixWebWeb.CSV.escape(value)
end
