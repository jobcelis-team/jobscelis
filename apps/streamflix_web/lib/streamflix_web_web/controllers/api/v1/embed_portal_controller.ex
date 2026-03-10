defmodule StreamflixWebWeb.Api.V1.EmbedPortalController do
  @moduledoc """
  API controller for the embeddable portal.
  Authenticated via embed tokens (end-users of your platform).
  Provides webhook management and delivery viewing capabilities.
  """
  use StreamflixWebWeb, :controller

  alias StreamflixCore.Platform

  plug StreamflixWebWeb.Plugs.RequireEmbedScope,
       "webhooks:read" when action in [:list_webhooks, :get_webhook]

  plug StreamflixWebWeb.Plugs.RequireEmbedScope,
       "webhooks:write" when action in [:create_webhook, :update_webhook, :delete_webhook]

  plug StreamflixWebWeb.Plugs.RequireEmbedScope,
       "deliveries:read" when action in [:list_deliveries]

  plug StreamflixWebWeb.Plugs.RequireEmbedScope,
       "deliveries:retry" when action in [:retry_delivery]

  action_fallback StreamflixWebWeb.FallbackController

  # --- Webhooks ---

  def list_webhooks(conn, params) do
    project = conn.assigns.current_project
    include_inactive = params["include"] == "inactive"
    webhooks = Platform.list_webhooks(project.id, include_inactive: include_inactive)
    json(conn, %{data: Enum.map(webhooks, &webhook_json/1)})
  end

  def get_webhook(conn, %{"id" => id}) do
    case Platform.get_webhook(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Webhook not found"})

      webhook ->
        if webhook.project_id == conn.assigns.current_project.id do
          json(conn, %{data: webhook_json(webhook)})
        else
          conn |> put_status(:not_found) |> json(%{error: "Webhook not found"})
        end
    end
  end

  def create_webhook(conn, params) do
    project = conn.assigns.current_project

    attrs = %{
      "url" => params["url"],
      "topics" => params["topics"] || [],
      "secret" => params["secret"]
    }

    case Platform.create_webhook(project.id, attrs) do
      {:ok, webhook} ->
        conn |> put_status(:created) |> json(%{data: webhook_json(webhook)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: format_errors(changeset)})
    end
  end

  def update_webhook(conn, %{"id" => id} = params) do
    with webhook when not is_nil(webhook) <- Platform.get_webhook(id),
         true <- webhook.project_id == conn.assigns.current_project.id do
      attrs =
        params
        |> Map.take(["url", "topics", "secret", "status"])
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new()

      case Platform.update_webhook(webhook, attrs) do
        {:ok, updated} ->
          json(conn, %{data: webhook_json(updated)})

        {:error, changeset} ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: format_errors(changeset)})
      end
    else
      _ -> conn |> put_status(:not_found) |> json(%{error: "Webhook not found"})
    end
  end

  def delete_webhook(conn, %{"id" => id}) do
    with webhook when not is_nil(webhook) <- Platform.get_webhook(id),
         true <- webhook.project_id == conn.assigns.current_project.id do
      case Platform.set_webhook_inactive(webhook) do
        {:ok, _} ->
          json(conn, %{status: "deleted"})

        {:error, _} ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: "Could not delete"})
      end
    else
      _ -> conn |> put_status(:not_found) |> json(%{error: "Webhook not found"})
    end
  end

  # --- Deliveries ---

  def list_deliveries(conn, params) do
    project = conn.assigns.current_project
    limit = min(String.to_integer(params["limit"] || "50"), 100)

    opts =
      [project_id: project.id, limit: limit]
      |> maybe_add(:webhook_id, params["webhook_id"])
      |> maybe_add(:status, params["status"])

    result = Platform.paginate_deliveries(opts)

    json(conn, %{
      data: Enum.map(result.data, &delivery_json/1),
      has_next: result.has_next,
      next_cursor: result.next_cursor
    })
  end

  def retry_delivery(conn, %{"id" => delivery_id}) do
    project = conn.assigns.current_project

    case Platform.retry_delivery(project.id, delivery_id) do
      {:ok, _delivery} ->
        json(conn, %{status: "retry_queued"})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Delivery not found"})
    end
  end

  # --- Helpers ---

  defp webhook_json(w) do
    %{
      id: w.id,
      url: w.url,
      status: w.status,
      topics: w.topics,
      circuit_state: w.circuit_state,
      inserted_at: w.inserted_at,
      updated_at: w.updated_at
    }
  end

  defp delivery_json(d) do
    %{
      id: d.id,
      status: d.status,
      attempt_number: d.attempt_number,
      response_status: d.response_status,
      response_latency_ms: d.response_latency_ms,
      webhook_id: d.webhook_id,
      event_id: d.event_id,
      inserted_at: d.inserted_at
    }
  end

  defp maybe_add(opts, _key, nil), do: opts
  defp maybe_add(opts, _key, ""), do: opts
  defp maybe_add(opts, key, val), do: Keyword.put(opts, key, val)

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
