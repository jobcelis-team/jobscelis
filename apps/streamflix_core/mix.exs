defmodule StreamflixCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :streamflix_core,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {StreamflixCore.Application, []},
      extra_applications: [:logger, :runtime_tools, :crypto]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Database
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.21"},

      # Distributed Systems
      {:libcluster, "~> 3.5"},
      {:horde, "~> 0.10"},
      {:delta_crdt, "~> 0.6"},

      # PubSub
      {:phoenix_pubsub, "~> 2.2"},

      # Background Jobs
      {:oban, "~> 2.20"},

      # Caching
      {:nebulex, "~> 2.6"},
      {:decorator, "~> 1.4"},
      {:telemetry, "~> 1.3"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.1"},

      # Utilities
      {:jason, "~> 1.4"},
      {:timex, "~> 3.7"},
      {:uuid, "~> 1.1"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
