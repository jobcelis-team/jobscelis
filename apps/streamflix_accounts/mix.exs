defmodule StreamflixAccounts.MixProject do
  use Mix.Project

  def project do
    [
      app: :streamflix_accounts,
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
      mod: {StreamflixAccounts.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Internal dependencies
      {:streamflix_core, in_umbrella: true},

      # Authentication
      {:guardian, "~> 2.4"},
      # PBKDF2-SHA512 with 210,000 rounds (OWASP-compliant)
      # To upgrade to Argon2: add {:argon2_elixir, "~> 4.1"} and update
      # User.hash_password/1 + Authentication.verify_password/2
      # Requires C compiler — won't compile on Windows paths with spaces.
      {:pbkdf2_elixir, "~> 2.2"},

      # Utilities
      {:jason, "~> 1.4"}
    ]
  end
end
