defmodule StreamflixWebWeb.Api.V1.PlatformWebhooksController do
  use StreamflixWebWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias StreamflixCore.Platform
  alias StreamflixWebWeb.Schemas

  plug StreamflixWebWeb.Plugs.RequireScope,
       "webhooks:read" when action in [:index, :show, :health, :templates]

  plug StreamflixWebWeb.Plugs.RequireScope,
       "webhooks:write" when action in [:create, :update, :delete, :test]

  action_fallback StreamflixWebWeb.FallbackController

  tags(["Webhooks"])
  security([%{"api_key" => []}])

  operation(:index,
    summary: "List webhooks",
    parameters: [
      include: [
        in: :query,
        type: :string,
        description: "Set to 'inactive' to include inactive webhooks"
      ]
    ],
    responses: [
      ok:
        {"Webhooks list", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{webhooks: %OpenApiSpex.Schema{type: :array, items: Schemas.Webhook}}
         }}
    ]
  )

  def index(conn, params) do
    project = conn.assigns.current_project
    opts = [include_inactive: params["include"] == "inactive"]
    webhooks = Platform.list_webhooks(project.id, opts)
    json(conn, %{webhooks: Enum.map(webhooks, &webhook_json/1)})
  end

  operation(:show,
    summary: "Get webhook details",
    parameters: [id: [in: :path, type: :string, description: "Webhook ID"]],
    responses: [
      ok: {"Webhook details", "application/json", Schemas.Webhook},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse}
    ]
  )

  def show(conn, %{"id" => id}) do
    project = conn.assigns.current_project

    case Platform.get_webhook(id) do
      nil ->
        send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))

      w ->
        if w.project_id != project.id do
          send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
        else
          json(conn, webhook_json(w))
        end
    end
  end

  operation(:create,
    summary: "Create a webhook",
    request_body: {"Webhook attributes", "application/json", Schemas.WebhookCreate},
    responses: [
      created: {"Webhook created", "application/json", Schemas.Webhook},
      unprocessable_entity: {"Validation errors", "application/json", Schemas.ErrorResponse}
    ]
  )

  def create(conn, params) do
    project = conn.assigns.current_project

    attrs = %{
      "url" => params["url"],
      "secret_encrypted" => params["secret"],
      "topics" => params["topics"] || [],
      "filters" => params["filters"] || [],
      "body_config" => params["body_config"] || %{},
      "headers" => params["headers"] || %{},
      "retry_config" => params["retry_config"] || %{},
      "rate_limit" => params["rate_limit"] || %{}
    }

    case Platform.create_webhook(project.id, attrs) do
      {:ok, w} -> conn |> put_status(:created) |> json(webhook_json(w))
      {:error, changeset} -> conn |> put_status(422) |> json(%{errors: format_errors(changeset)})
    end
  end

  operation(:update,
    summary: "Update a webhook",
    parameters: [id: [in: :path, type: :string, description: "Webhook ID"]],
    request_body: {"Webhook attributes", "application/json", Schemas.WebhookCreate},
    responses: [
      ok: {"Webhook updated", "application/json", Schemas.Webhook},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse},
      unprocessable_entity: {"Validation errors", "application/json", Schemas.ErrorResponse}
    ]
  )

  def update(conn, %{"id" => id} = params) do
    project = conn.assigns.current_project

    case Platform.get_webhook(id) do
      nil ->
        send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))

      w ->
        if w.project_id != project.id do
          send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
        else
          attrs =
            Map.take(params, [
              "url",
              "secret_encrypted",
              "topics",
              "filters",
              "body_config",
              "headers",
              "status",
              "retry_config",
              "rate_limit"
            ])

          attrs =
            if Map.has_key?(params, "secret"),
              do: Map.put(attrs, "secret_encrypted", params["secret"]),
              else: attrs

          attrs = Enum.reject(attrs, fn {_, v} -> is_nil(v) end) |> Map.new()

          case Platform.update_webhook(w, attrs) do
            {:ok, updated} ->
              json(conn, webhook_json(updated))

            {:error, changeset} ->
              conn |> put_status(422) |> json(%{errors: format_errors(changeset)})
          end
        end
    end
  end

  operation(:delete,
    summary: "Deactivate a webhook",
    parameters: [id: [in: :path, type: :string, description: "Webhook ID"]],
    responses: [
      ok:
        {"Webhook deactivated", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{status: %OpenApiSpex.Schema{type: :string}}
         }},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse}
    ]
  )

  def delete(conn, %{"id" => id}) do
    project = conn.assigns.current_project

    case Platform.get_webhook(id) do
      nil ->
        send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))

      w ->
        if w.project_id != project.id do
          send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
        else
          {:ok, _} = Platform.set_webhook_inactive(w)
          send_resp(conn, 200, Jason.encode!(%{status: "inactive"}))
        end
    end
  end

  operation(:health,
    summary: "Get webhook health status",
    parameters: [id: [in: :path, type: :string, description: "Webhook ID"]],
    responses: [
      ok: {"Webhook health", "application/json", Schemas.WebhookHealth},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse}
    ]
  )

  def health(conn, %{"id" => id}) do
    project = conn.assigns.current_project

    case Platform.get_webhook(id) do
      nil ->
        send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))

      w ->
        if w.project_id != project.id do
          send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
        else
          health = Platform.webhook_health(w.id)
          json(conn, %{webhook_id: w.id, url: w.url, health: health})
        end
    end
  end

  defp webhook_json(w) do
    %{
      id: w.id,
      url: w.url,
      status: w.status,
      topics: w.topics || [],
      filters: w.filters || [],
      body_config: w.body_config || %{},
      headers: w.headers || %{},
      retry_config: w.retry_config || %{},
      rate_limit: w.rate_limit || %{},
      inserted_at: w.inserted_at
    }
  end

  operation(:test,
    summary: "Send a test ping to a webhook",
    parameters: [id: [in: :path, type: :string, description: "Webhook ID"]],
    responses: [
      ok: {"Test result", "application/json", Schemas.WebhookTestResult},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse},
      unprocessable_entity: {"Test failed", "application/json", Schemas.WebhookTestResult}
    ]
  )

  def test(conn, %{"id" => webhook_id}) do
    project = conn.assigns.current_project

    case Platform.get_webhook(webhook_id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "webhook not found"})

      webhook ->
        if webhook.project_id != project.id do
          conn |> put_status(:not_found) |> json(%{error: "webhook not found"})
        else
          case Platform.test_webhook(webhook_id) do
            {:ok, result} ->
              json(conn, %{
                success: true,
                status: result.status,
                latency_ms: result.latency_ms,
                webhook_id: result.webhook_id
              })

            {:error, result} ->
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{success: false, reason: result.reason, webhook_id: result.webhook_id})
          end
        end
    end
  end

  def templates(conn, _params) do
    templates = Platform.webhook_templates()
    json(conn, %{templates: templates})
  end

  defp format_errors(c), do: Ecto.Changeset.traverse_errors(c, fn {msg, _} -> msg end)
end
