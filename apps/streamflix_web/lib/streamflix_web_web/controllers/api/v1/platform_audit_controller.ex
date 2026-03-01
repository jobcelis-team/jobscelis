defmodule StreamflixWebWeb.Api.V1.PlatformAuditController do
  use StreamflixWebWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias StreamflixCore.Audit
  alias StreamflixWebWeb.Schemas

  tags(["Audit Log"])
  security([%{"api_key" => []}])

  operation(:index,
    summary: "List audit log entries",
    parameters: [
      limit: [in: :query, type: :integer, description: "Max results (1-100, default 50)"],
      action: [in: :query, type: :string, description: "Filter by action"],
      resource_type: [in: :query, type: :string, description: "Filter by resource type"]
    ],
    responses: [
      ok:
        {"Audit log entries", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{data: %OpenApiSpex.Schema{type: :array, items: Schemas.AuditLogEntry}}
         }}
    ]
  )

  def index(conn, params) do
    project = conn.assigns.current_project

    opts = [
      limit: min(String.to_integer(params["limit"] || "50"), 100),
      action: params["action"],
      resource_type: params["resource_type"]
    ]

    logs = Audit.list_for_project(project.id, opts)
    json(conn, %{data: Enum.map(logs, &audit_json/1)})
  end

  defp audit_json(log) do
    %{
      id: log.id,
      action: log.action,
      resource_type: log.resource_type,
      resource_id: log.resource_id,
      metadata: log.metadata,
      user_id: log.user_id,
      ip_address: log.ip_address,
      inserted_at: log.inserted_at
    }
  end
end
