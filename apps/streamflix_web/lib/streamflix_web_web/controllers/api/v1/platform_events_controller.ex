defmodule StreamflixWebWeb.Api.V1.PlatformEventsController do
  use StreamflixWebWeb, :controller

  alias StreamflixCore.Platform

  action_fallback StreamflixWebWeb.FallbackController

  @doc """
  POST /api/v1/send or /api/v1/events - Send an event (body = any JSON).
  """
  def create(conn, body) when is_map(body) do
    project = conn.assigns.current_project

    case Platform.create_event(project.id, body) do
      {:ok, event} ->
        conn
        |> put_status(:accepted)
        |> json(%{event_id: event.id})

      {:error, :invalid_payload} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Invalid payload"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def create(conn, _), do: send_resp(conn, 422, Jason.encode!(%{error: "Body must be a JSON object"}))

  @doc """
  GET /api/v1/events - List events for the project.
  """
  def index(conn, params) do
    project = conn.assigns.current_project
    opts = [
      include_inactive: params["include"] == "inactive",
      topic: params["topic"],
      limit: min(parse_int(params["limit"], 50), 100)
    ]
    events = Platform.list_events(project.id, opts)
    json(conn, %{events: Enum.map(events, &event_json/1)})
  end

  @doc """
  GET /api/v1/events/:id - Get a single event.
  """
  def show(conn, %{"id" => id}) do
    project = conn.assigns.current_project
    case Platform.get_event(id) do
      nil -> send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
      event ->
        if event.project_id != project.id do
          send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
        else
          deliveries = Platform.list_deliveries(event_id: event.id)
          json(conn, event_json(event) |> Map.put(:deliveries, Enum.map(deliveries, &delivery_mini/1)))
        end
    end
  end

  @doc """
  DELETE /api/v1/events/:id - Set event to inactive (soft delete).
  """
  def delete(conn, %{"id" => id}) do
    project = conn.assigns.current_project
    case Platform.get_event(id) do
      nil -> send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
      event ->
        if event.project_id != project.id do
          send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
        else
          {:ok, _} = Platform.set_event_inactive(event)
          send_resp(conn, 200, Jason.encode!(%{status: "inactive"}))
        end
    end
  end

  defp event_json(e) do
    %{
      id: e.id,
      topic: e.topic,
      payload: e.payload,
      status: e.status,
      occurred_at: e.occurred_at,
      inserted_at: e.inserted_at
    }
  end

  defp delivery_mini(d) do
    %{id: d.id, status: d.status, attempt_number: d.attempt_number}
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
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
