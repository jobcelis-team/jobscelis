defmodule StreamflixCatalog.MixProject do
  use Mix.Project

  def project do
    [
      app: :streamflix_catalog,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {StreamflixCatalog.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Internal dependencies
      {:streamflix_core, in_umbrella: true},

      # Utilities
      {:jason, "~> 1.4"},
      {:slugify, "~> 1.3"}
    ]
  end
end
