defmodule StreamflixCore.TelemetryEvents do
  @moduledoc """
  Emits Telemetry events for domain-specific metrics.
  Used by the PromEx custom plugin for Prometheus counters, gauges, and histograms.
  """

  @doc "Emit when a new event is created."
  def event_created(project_id, topic) do
    :telemetry.execute(
      [:jobcelis, :event, :created],
      %{count: 1},
      %{project_id: project_id, topic: topic}
    )
  end

  @doc "Emit when a delivery succeeds."
  def delivery_success(project_id, webhook_id, topic, latency_ms) do
    :telemetry.execute(
      [:jobcelis, :delivery, :success],
      %{count: 1, latency_ms: latency_ms},
      %{project_id: project_id, webhook_id: webhook_id, topic: topic}
    )
  end

  @doc "Emit when a delivery fails."
  def delivery_failure(project_id, webhook_id, topic) do
    :telemetry.execute(
      [:jobcelis, :delivery, :failure],
      %{count: 1},
      %{project_id: project_id, webhook_id: webhook_id, topic: topic}
    )
  end

  @doc "Emit when a circuit breaker opens."
  def circuit_opened(project_id, webhook_id) do
    :telemetry.execute(
      [:jobcelis, :circuit_breaker, :opened],
      %{count: 1},
      %{project_id: project_id, webhook_id: webhook_id}
    )
  end

  @doc "Emit when a circuit breaker closes."
  def circuit_closed(project_id, webhook_id) do
    :telemetry.execute(
      [:jobcelis, :circuit_breaker, :closed],
      %{count: 1},
      %{project_id: project_id, webhook_id: webhook_id}
    )
  end
end
