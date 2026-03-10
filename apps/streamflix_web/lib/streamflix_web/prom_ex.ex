defmodule StreamflixWeb.PromEx do
  @moduledoc """
  PromEx configuration for Prometheus metrics.
  Exposes /metrics endpoint for scraping by Prometheus-compatible systems.
  """
  use PromEx, otp_app: :streamflix_web

  alias PromEx.Plugins

  @impl true
  def plugins do
    [
      Plugins.Application,
      Plugins.Beam,
      {Plugins.Phoenix, router: StreamflixWebWeb.Router, endpoint: StreamflixWebWeb.Endpoint},
      {Plugins.Ecto, repos: [StreamflixCore.Repo]},
      {Plugins.Oban, oban_supervisors: [Oban]},
      {StreamflixWeb.PromEx.JobcelisPlugin, poll_rate: 15_000}
    ]
  end

  @impl true
  def dashboard_assigns do
    [
      datasource_id: "prometheus",
      default_selected_interval: "30s"
    ]
  end

  @impl true
  def dashboards do
    [
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"},
      {:prom_ex, "phoenix.json"},
      {:prom_ex, "ecto.json"},
      {:prom_ex, "oban.json"}
    ]
  end
end
