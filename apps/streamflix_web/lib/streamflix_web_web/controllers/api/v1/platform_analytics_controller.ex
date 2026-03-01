defmodule StreamflixWebWeb.Api.V1.PlatformAnalyticsController do
  use StreamflixWebWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias StreamflixCore.Platform
  alias StreamflixWebWeb.Schemas

  tags ["Analytics"]
  security [%{"api_key" => []}]

  operation :events_per_day,
    summary: "Get events count per day",
    parameters: [
      days: [in: :query, type: :integer, description: "Number of days (max 90, default 30)"]
    ],
    responses: [
      ok: {"Events per day", "application/json", Schemas.AnalyticsTimeSeries}
    ]

  def events_per_day(conn, params) do
    project = conn.assigns.current_project
    days = String.to_integer(params["days"] || "30")
    data = Platform.events_per_day(project.id, min(days, 90))
    json(conn, %{data: data})
  end

  operation :deliveries_per_day,
    summary: "Get deliveries count per day",
    parameters: [
      days: [in: :query, type: :integer, description: "Number of days (max 90, default 30)"]
    ],
    responses: [
      ok: {"Deliveries per day", "application/json", Schemas.AnalyticsTimeSeries}
    ]

  def deliveries_per_day(conn, params) do
    project = conn.assigns.current_project
    days = String.to_integer(params["days"] || "30")
    data = Platform.deliveries_per_day(project.id, min(days, 90))
    json(conn, %{data: data})
  end

  operation :top_topics,
    summary: "Get top event topics",
    parameters: [
      limit: [in: :query, type: :integer, description: "Max topics (max 50, default 10)"]
    ],
    responses: [
      ok: {"Top topics", "application/json", %OpenApiSpex.Schema{type: :object, properties: %{data: %OpenApiSpex.Schema{type: :array, items: %OpenApiSpex.Schema{type: :object}}}}}
    ]

  def top_topics(conn, params) do
    project = conn.assigns.current_project
    limit = String.to_integer(params["limit"] || "10")
    data = Platform.top_topics(project.id, min(limit, 50))
    json(conn, %{data: data})
  end

  operation :webhook_stats,
    summary: "Get delivery stats per webhook",
    responses: [
      ok: {"Webhook delivery stats", "application/json", %OpenApiSpex.Schema{type: :object, properties: %{data: %OpenApiSpex.Schema{type: :array, items: %OpenApiSpex.Schema{type: :object}}}}}
    ]

  def webhook_stats(conn, _params) do
    project = conn.assigns.current_project
    data = Platform.delivery_stats_by_webhook(project.id)
    json(conn, %{data: data})
  end
end
