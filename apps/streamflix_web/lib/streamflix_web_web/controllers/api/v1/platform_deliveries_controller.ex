defmodule StreamflixWebWeb.Api.V1.PlatformDeliveriesController do
  use StreamflixWebWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias StreamflixCore.Platform
  alias StreamflixWebWeb.Schemas

  plug StreamflixWebWeb.Plugs.RequireScope, "deliveries:read" when action in [:index]
  plug StreamflixWebWeb.Plugs.RequireScope, "deliveries:retry" when action in [:retry]

  tags(["Deliveries"])
  security([%{"api_key" => []}])

  operation(:index,
    summary: "List deliveries",
    parameters: [
      event_id: [in: :query, type: :string, description: "Filter by event ID"],
      webhook_id: [in: :query, type: :string, description: "Filter by webhook ID"],
      status: [in: :query, type: :string, description: "Filter by status"],
      limit: [in: :query, type: :integer, description: "Max results (1-200, default 50)"],
      cursor: [in: :query, type: :string, description: "Cursor for pagination (ID of last item)"]
    ],
    responses: [
      ok:
        {"Deliveries list", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{deliveries: %OpenApiSpex.Schema{type: :array, items: Schemas.Delivery}}
         }}
    ]
  )

  def index(conn, params) do
    project = conn.assigns.current_project

    opts = [
      project_id: project.id,
      webhook_id: params["webhook_id"],
      status: params["status"],
      limit: parse_int(params["limit"], 50),
      cursor: params["cursor"]
    ]

    page = Platform.paginate_deliveries(opts)

    json(conn, %{
      deliveries: Enum.map(page.data, &delivery_json/1),
      has_next: page.has_next,
      next_cursor: page.next_cursor
    })
  end

  operation(:retry,
    summary: "Retry a delivery",
    parameters: [id: [in: :path, type: :string, description: "Delivery ID"]],
    responses: [
      ok:
        {"Retry queued", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{status: %OpenApiSpex.Schema{type: :string}}
         }},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse}
    ]
  )

  def retry(conn, %{"id" => id}) do
    project = conn.assigns.current_project

    case Platform.retry_delivery(project.id, id) do
      {:ok, _updated} ->
        json(conn, %{status: "retry_queued"})

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{error: "Not found"})
    end
  end

  defp delivery_json(d) do
    %{
      id: d.id,
      event_id: d.event_id,
      webhook_id: d.webhook_id,
      status: d.status,
      attempt_number: d.attempt_number,
      response_status: d.response_status,
      response_body: d.response_body,
      response_headers: d.response_headers,
      response_latency_ms: d.response_latency_ms,
      request_headers: d.request_headers,
      request_body: d.request_body,
      destination_ip: d.destination_ip,
      next_retry_at: d.next_retry_at,
      inserted_at: d.inserted_at
    }
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
