defmodule StreamflixWebWeb.Api.V1.PlatformSSEController do
  @moduledoc """
  Server-Sent Events stream of a project's events and delivery updates.

  Long-lived connections are bounded:
    * a per-project cap of concurrent streams (429 beyond it),
    * a maximum lifetime, after which the stream ends (clients reconnect),
    * the API key is re-validated on every keepalive: a revoked or regenerated
      key, a removed scope or an IP no longer allowlisted closes the stream.

  Limits are configured under `config :streamflix_web, :sse`.
  """
  use StreamflixWebWeb, :controller

  alias StreamflixWebWeb.Plugs.{ApiKeyAuth, ClientIp}

  plug StreamflixWebWeb.Plugs.RequireScope, "events:read"

  @registry StreamflixWebWeb.SSERegistry

  def stream(conn, _params) do
    project = conn.assigns.current_project
    {:ok, _} = Registry.register(@registry, project.id, nil)

    try do
      if Registry.count_match(@registry, project.id, :_) > config(:max_connections_per_project) do
        conn
        |> put_resp_header("retry-after", "60")
        |> put_status(:too_many_requests)
        |> json(%{
          error: "too_many_streams",
          message: "Too many concurrent streams for this project"
        })
      else
        open_stream(conn, project)
      end
    after
      Registry.unregister(@registry, project.id)
    end
  end

  defp open_stream(conn, project) do
    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> put_resp_header("cache-control", "no-cache")
      |> put_resp_header("connection", "keep-alive")
      |> put_resp_header("x-accel-buffering", "no")
      |> send_chunked(200)

    topic = "project:#{project.id}"
    Phoenix.PubSub.subscribe(StreamflixCore.PubSub, topic)

    state = %{
      api_key_id: conn.assigns[:current_api_key] && conn.assigns.current_api_key.id,
      client_ip: ClientIp.get_client_ip(conn),
      keepalive_ms: config(:keepalive_ms),
      keepalive_ref: Process.send_after(self(), :sse_keepalive, config(:keepalive_ms)),
      lifetime_ref: Process.send_after(self(), :sse_max_lifetime, config(:max_lifetime_ms))
    }

    try do
      case chunk(conn, sse_data(%{type: "connected", project_id: project.id})) do
        {:ok, conn} -> sse_loop(conn, state)
        {:error, _} -> conn
      end
    after
      # The request process can be reused for the next keep-alive request:
      # leave no subscription, timers or stray timer messages behind.
      Phoenix.PubSub.unsubscribe(StreamflixCore.PubSub, topic)
      cancel_timers(state)
    end
  end

  defp sse_loop(conn, state) do
    receive do
      {:event_created, event} ->
        %{
          type: "event.created",
          data: %{
            id: event.id,
            topic: event.topic,
            payload: event.payload,
            occurred_at: event.occurred_at
          }
        }
        |> send_and_continue(conn, state)

      {:delivery_updated, delivery} ->
        %{
          type: "delivery.updated",
          data: %{id: delivery.id, status: delivery.status, event_id: delivery.event_id}
        }
        |> send_and_continue(conn, state)

      :sse_keepalive ->
        if key_still_valid?(state) do
          state = %{
            state
            | keepalive_ref: Process.send_after(self(), :sse_keepalive, state.keepalive_ms)
          }

          case chunk(conn, ": keepalive\n\n") do
            {:ok, conn} -> sse_loop(conn, state)
            {:error, _} -> conn
          end
        else
          close_with(conn, "unauthorized")
        end

      :sse_max_lifetime ->
        close_with(conn, "stream_expired")

      _ ->
        sse_loop(conn, state)
    end
  end

  defp send_and_continue(data, conn, state) do
    case chunk(conn, sse_data(data)) do
      {:ok, conn} -> sse_loop(conn, state)
      {:error, _} -> conn
    end
  end

  defp close_with(conn, reason) do
    case chunk(conn, sse_data(%{type: "close", reason: reason})) do
      {:ok, conn} -> conn
      {:error, _} -> conn
    end
  end

  defp key_still_valid?(%{api_key_id: nil}), do: false

  defp key_still_valid?(%{api_key_id: id, client_ip: client_ip}) do
    case StreamflixCore.Platform.get_active_api_key(id) do
      nil ->
        false

      api_key ->
        scopes = api_key.scopes || ["*"]

        ("*" in scopes or "events:read" in scopes) and
          ApiKeyAuth.ip_allowed?(api_key, client_ip)
    end
  end

  defp cancel_timers(state) do
    Process.cancel_timer(state.keepalive_ref)
    Process.cancel_timer(state.lifetime_ref)

    receive do
      :sse_keepalive -> :ok
    after
      0 -> :ok
    end

    receive do
      :sse_max_lifetime -> :ok
    after
      0 -> :ok
    end
  end

  defp sse_data(data), do: "data: #{Jason.encode!(data)}\n\n"

  @defaults [max_lifetime_ms: 3_600_000, keepalive_ms: 30_000, max_connections_per_project: 10]

  defp config(key) do
    :streamflix_web
    |> Application.get_env(:sse, [])
    |> Keyword.get(key, Keyword.fetch!(@defaults, key))
  end
end
