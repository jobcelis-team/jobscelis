defmodule StreamflixWebWeb.Api.V1.PlatformSSEController do
  use StreamflixWebWeb, :controller

  def stream(conn, _params) do
    project = conn.assigns.current_project

    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> put_resp_header("x-accel-buffering", "no")
      |> send_chunked(200)

    Phoenix.PubSub.subscribe(StreamflixCore.PubSub, "project:#{project.id}")

    # Send initial connection event
    {:ok, conn} =
      chunk(conn, "data: #{Jason.encode!(%{type: "connected", project_id: project.id})}\n\n")

    # Schedule keepalive
    Process.send_after(self(), :keepalive, 30_000)

    sse_loop(conn)
  end

  defp sse_loop(conn) do
    receive do
      {:event_created, event} ->
        data = %{
          type: "event.created",
          data: %{
            id: event.id,
            topic: event.topic,
            payload: event.payload,
            occurred_at: event.occurred_at
          }
        }

        case chunk(conn, "data: #{Jason.encode!(data)}\n\n") do
          {:ok, conn} -> sse_loop(conn)
          {:error, _} -> conn
        end

      {:delivery_updated, delivery} ->
        data = %{
          type: "delivery.updated",
          data: %{
            id: delivery.id,
            status: delivery.status,
            event_id: delivery.event_id
          }
        }

        case chunk(conn, "data: #{Jason.encode!(data)}\n\n") do
          {:ok, conn} -> sse_loop(conn)
          {:error, _} -> conn
        end

      :keepalive ->
        Process.send_after(self(), :keepalive, 30_000)

        case chunk(conn, ": keepalive\n\n") do
          {:ok, conn} -> sse_loop(conn)
          {:error, _} -> conn
        end

      _ ->
        sse_loop(conn)
    after
      120_000 ->
        conn
    end
  end
end
