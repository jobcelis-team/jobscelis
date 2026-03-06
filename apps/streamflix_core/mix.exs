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
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.21"},
      {:phoenix_pubsub, "~> 2.2"},
      {:oban, "~> 2.20"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.5"},
      {:uuid, "~> 1.1"},
      {:cachex, "~> 4.0"},
      {:cloak_ecto, "~> 1.3"},
      {:cloak, "~> 1.1"},
      {:ex_json_schema, "~> 0.10"},
      {:crontab, "~> 1.1"},
      {:logger_json, "~> 7.0"},
      {:ex_machina, "~> 2.8", only: :test}
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
