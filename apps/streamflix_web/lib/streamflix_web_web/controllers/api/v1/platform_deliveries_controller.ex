defmodule StreamflixWebWeb.Api.V1.PlatformDeliveriesController do
  use StreamflixWebWeb, :controller

  alias StreamflixCore.Platform

  def index(conn, params) do
    project = conn.assigns.current_project
    opts = [
      project_id: project.id,
      event_id: params["event_id"],
      webhook_id: params["webhook_id"],
      status: params["status"],
      limit: min(parse_int(params["limit"], 50), 100)
    ]
    deliveries = Platform.list_deliveries(opts)
    json(conn, %{deliveries: Enum.map(deliveries, &delivery_json/1)})
  end

  def retry(conn, %{"id" => id}) do
    project = conn.assigns.current_project
    case Platform.get_delivery(id) do
      nil -> send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
      d ->
        event = d.event || StreamflixCore.Platform.get_event(d.event_id)
        if is_nil(event) or event.project_id != project.id do
          send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
        else
          # Reset delivery to pending and enqueue Oban
          StreamflixCore.Platform.update_delivery_to_pending(d)
          Oban.insert(StreamflixCore.Platform.ObanDeliveryWorker.new(%{delivery_id: d.id}))
          send_resp(conn, 200, Jason.encode!(%{status: "retry_queued"}))
        end
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
