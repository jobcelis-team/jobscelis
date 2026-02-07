defmodule StreamflixWebWeb.Api.V1.PlatformWebhooksController do
  use StreamflixWebWeb, :controller

  alias StreamflixCore.Platform

  action_fallback StreamflixWebWeb.FallbackController

  def index(conn, params) do
    project = conn.assigns.current_project
    opts = [include_inactive: params["include"] == "inactive"]
    webhooks = Platform.list_webhooks(project.id, opts)
    json(conn, %{webhooks: Enum.map(webhooks, &webhook_json/1)})
  end

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

  def create(conn, params) do
    project = conn.assigns.current_project
    attrs = %{
      "url" => params["url"],
      "secret_encrypted" => params["secret"],
      "topics" => params["topics"] || [],
      "filters" => params["filters"] || [],
      "body_config" => params["body_config"] || %{},
      "headers" => params["headers"] || %{}
    }
    case Platform.create_webhook(project.id, attrs) do
      {:ok, w} -> conn |> put_status(:created) |> json(webhook_json(w))
      {:error, changeset} -> conn |> put_status(422) |> json(%{errors: format_errors(changeset)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    project = conn.assigns.current_project
    case Platform.get_webhook(id) do
      nil ->
        send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
      w ->
        if w.project_id != project.id do
          send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
        else
          attrs = Map.take(params, ["url", "secret_encrypted", "topics", "filters", "body_config", "headers", "status"])
          attrs = if Map.has_key?(params, "secret"), do: Map.put(attrs, "secret_encrypted", params["secret"]), else: attrs
          attrs = Enum.reject(attrs, fn {_, v} -> is_nil(v) end) |> Map.new()
          case Platform.update_webhook(w, attrs) do
            {:ok, updated} -> json(conn, webhook_json(updated))
            {:error, changeset} -> conn |> put_status(422) |> json(%{errors: format_errors(changeset)})
          end
        end
    end
  end

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

  defp webhook_json(w) do
    %{
      id: w.id,
      url: w.url,
      status: w.status,
      topics: w.topics || [],
      filters: w.filters || [],
      body_config: w.body_config || %{},
      headers: w.headers || %{},
      inserted_at: w.inserted_at
    }
  end

  defp format_errors(c), do: Ecto.Changeset.traverse_errors(c, fn {msg, _} -> msg end)
end
