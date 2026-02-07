defmodule StreamflixWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :streamflix_web,
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
      mod: {StreamflixWeb.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Internal dependencies
      {:streamflix_core, in_umbrella: true},
      {:streamflix_accounts, in_umbrella: true},

      # Phoenix
      {:phoenix, "~> 1.8"},
      {:phoenix_html, "~> 4.2"},
      {:phoenix_live_reload, "~> 1.5", only: :dev},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_live_dashboard, "~> 0.8"},

      # Assets
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.4", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.5",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},

      # HTTP Server
      {:bandit, "~> 1.10"},

      # Auth
      {:guardian, "~> 2.4"},

      # Telemetry
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.1"},

      # i18n
      {:gettext, "~> 0.26"},

      # Utilities
      {:jason, "~> 1.4"},
      {:dns_cluster, "~> 0.1"},
      {:plug_cowboy, "~> 2.7"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind streamflix_web", "esbuild streamflix_web"],
      "assets.deploy": [
        "tailwind streamflix_web --minify",
        "esbuild streamflix_web --minify",
        "phx.digest"
      ]
    ]
  end
end
