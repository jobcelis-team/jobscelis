defmodule StreamflixWebWeb.Api.V1.PlatformDeadLettersController do
  use StreamflixWebWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias StreamflixCore.Platform
  alias StreamflixWebWeb.Schemas

  tags(["Dead Letter Queue"])
  security([%{"api_key" => []}])

  operation(:index,
    summary: "List dead letter entries",
    parameters: [
      resolved: [in: :query, type: :string, description: "Filter by resolved status (true/false)"]
    ],
    responses: [
      ok:
        {"Dead letters list", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             dead_letters: %OpenApiSpex.Schema{type: :array, items: Schemas.DeadLetter}
           }
         }}
    ]
  )

  def index(conn, params) do
    project = conn.assigns.current_project
    opts = [resolved: params["resolved"] == "true", limit: 50]
    dead_letters = Platform.list_dead_letters(project.id, opts)
    json(conn, %{dead_letters: Enum.map(dead_letters, &dl_json/1)})
  end

  operation(:show,
    summary: "Get dead letter details",
    parameters: [id: [in: :path, type: :string, description: "Dead letter ID"]],
    responses: [
      ok: {"Dead letter details", "application/json", Schemas.DeadLetter},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse}
    ]
  )

  def show(conn, %{"id" => id}) do
    case Platform.get_dead_letter(id) do
      nil ->
        send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))

      dl ->
        project = conn.assigns.current_project

        if dl.project_id != project.id do
          send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
        else
          json(conn, dl_json(dl))
        end
    end
  end

  operation(:retry,
    summary: "Retry a dead letter delivery",
    parameters: [id: [in: :path, type: :string, description: "Dead letter ID"]],
    responses: [
      ok:
        {"Retry initiated", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             status: %OpenApiSpex.Schema{type: :string},
             delivery_id: %OpenApiSpex.Schema{type: :string}
           }
         }},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse},
      unprocessable_entity: {"Webhook inactive", "application/json", Schemas.ErrorResponse}
    ]
  )

  def retry(conn, %{"id" => id} = params) do
    project = conn.assigns.current_project
    modified_payload = params["payload"]

    case Platform.get_dead_letter(id) do
      nil ->
        send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))

      dl ->
        if dl.project_id != project.id do
          send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
        else
          case Platform.retry_dead_letter(id, modified_payload) do
            {:ok, delivery} ->
              json(conn, %{status: "retrying", delivery_id: delivery.id})

            {:error, :webhook_inactive} ->
              conn |> put_status(422) |> json(%{error: "Webhook is inactive"})

            {:error, _} ->
              conn |> put_status(500) |> json(%{error: "Failed to retry"})
          end
        end
    end
  end

  operation(:resolve,
    summary: "Resolve a dead letter entry",
    parameters: [id: [in: :path, type: :string, description: "Dead letter ID"]],
    responses: [
      ok:
        {"Dead letter resolved", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{status: %OpenApiSpex.Schema{type: :string}}
         }},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse}
    ]
  )

  def resolve(conn, %{"id" => id}) do
    project = conn.assigns.current_project

    case Platform.get_dead_letter(id) do
      nil ->
        send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))

      dl ->
        if dl.project_id != project.id do
          send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
        else
          case Platform.resolve_dead_letter(id) do
            {:ok, _} -> json(conn, %{status: "resolved"})
            {:error, _} -> conn |> put_status(500) |> json(%{error: "Failed to resolve"})
          end
        end
    end
  end

  defp dl_json(dl) do
    %{
      id: dl.id,
      project_id: dl.project_id,
      delivery_id: dl.delivery_id,
      event_id: dl.event_id,
      webhook_id: dl.webhook_id,
      webhook_url: if(dl.webhook, do: dl.webhook.url, else: nil),
      original_payload: dl.original_payload,
      last_error: dl.last_error,
      last_response_status: dl.last_response_status,
      attempts_exhausted: dl.attempts_exhausted,
      resolved: dl.resolved,
      resolved_at: dl.resolved_at,
      inserted_at: dl.inserted_at
    }
  end
end
