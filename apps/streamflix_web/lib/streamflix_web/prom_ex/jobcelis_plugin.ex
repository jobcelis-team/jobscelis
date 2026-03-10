defmodule StreamflixWeb.PromEx.JobcelisPlugin do
  @moduledoc """
  Custom PromEx plugin for Jobcelis domain metrics.

  Counters:
  - jobcelis_events_created_total (by project, topic)
  - jobcelis_deliveries_success_total (by project, webhook, topic)
  - jobcelis_deliveries_failed_total (by project, webhook, topic)
  - jobcelis_circuit_breaker_opened_total (by project, webhook)
  - jobcelis_circuit_breaker_closed_total (by project, webhook)

  Histograms:
  - jobcelis_delivery_latency_milliseconds (by project, webhook, topic)

  Gauges (polled):
  - jobcelis_webhooks_active (by project)
  - jobcelis_circuit_breakers_open (by project)
  - jobcelis_deliveries_pending
  """
  use PromEx.Plugin

  @impl true
  def event_metrics(_opts) do
    [
      counters(),
      histograms()
    ]
  end

  @impl true
  def polling_metrics(opts) do
    poll_rate = Keyword.get(opts, :poll_rate, 15_000)

    [
      gauge_metrics(poll_rate)
    ]
  end

  defp counters do
    Event.build(
      :jobcelis_domain_counters,
      [
        counter(
          [:jobcelis, :events, :created, :total],
          event_name: [:jobcelis, :event, :created],
          measurement: :count,
          tags: [:project_id, :topic],
          description: "Total events created"
        ),
        counter(
          [:jobcelis, :deliveries, :success, :total],
          event_name: [:jobcelis, :delivery, :success],
          measurement: :count,
          tags: [:project_id, :webhook_id, :topic],
          description: "Total successful deliveries"
        ),
        counter(
          [:jobcelis, :deliveries, :failed, :total],
          event_name: [:jobcelis, :delivery, :failure],
          measurement: :count,
          tags: [:project_id, :webhook_id, :topic],
          description: "Total failed deliveries"
        ),
        counter(
          [:jobcelis, :circuit, :breaker, :opened, :total],
          event_name: [:jobcelis, :circuit_breaker, :opened],
          measurement: :count,
          tags: [:project_id, :webhook_id],
          description: "Total circuit breaker open events"
        ),
        counter(
          [:jobcelis, :circuit, :breaker, :closed, :total],
          event_name: [:jobcelis, :circuit_breaker, :closed],
          measurement: :count,
          tags: [:project_id, :webhook_id],
          description: "Total circuit breaker close events"
        )
      ]
    )
  end

  defp histograms do
    Event.build(
      :jobcelis_domain_histograms,
      [
        distribution(
          [:jobcelis, :delivery, :latency, :milliseconds],
          event_name: [:jobcelis, :delivery, :success],
          measurement: :latency_ms,
          tags: [:project_id, :webhook_id, :topic],
          description: "Delivery response latency in milliseconds",
          reporter_options: [
            buckets: [10, 25, 50, 100, 250, 500, 1_000, 2_500, 5_000, 10_000]
          ]
        )
      ]
    )
  end

  defp gauge_metrics(poll_rate) do
    Polling.build(
      :jobcelis_domain_gauges,
      poll_rate,
      {__MODULE__, :poll_metrics, []},
      [
        last_value(
          [:jobcelis, :webhooks, :active],
          event_name: [:jobcelis, :gauge, :webhooks_active],
          measurement: :count,
          description: "Number of active webhooks"
        ),
        last_value(
          [:jobcelis, :circuit, :breakers, :open],
          event_name: [:jobcelis, :gauge, :circuits_open],
          measurement: :count,
          description: "Number of open circuit breakers"
        ),
        last_value(
          [:jobcelis, :deliveries, :pending],
          event_name: [:jobcelis, :gauge, :deliveries_pending],
          measurement: :count,
          description: "Number of pending deliveries in queue"
        )
      ]
    )
  end

  @doc false
  def poll_metrics do
    import Ecto.Query

    repo = StreamflixCore.Repo

    # Active webhooks count
    active_webhooks =
      repo.one(from(w in "webhooks", where: w.status == "active", select: count(w.id))) || 0

    :telemetry.execute([:jobcelis, :gauge, :webhooks_active], %{count: active_webhooks}, %{})

    # Open circuit breakers count
    open_circuits =
      repo.one(
        from(w in "webhooks",
          where: w.status == "active" and w.circuit_state == "open",
          select: count(w.id)
        )
      ) || 0

    :telemetry.execute([:jobcelis, :gauge, :circuits_open], %{count: open_circuits}, %{})

    # Pending deliveries (Oban jobs in available state for delivery queue)
    pending =
      repo.one(
        from(j in "oban_jobs",
          where: j.queue == "delivery" and j.state == "available",
          select: count(j.id)
        )
      ) || 0

    :telemetry.execute([:jobcelis, :gauge, :deliveries_pending], %{count: pending}, %{})
  end
end
