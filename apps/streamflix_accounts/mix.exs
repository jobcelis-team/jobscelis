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
      # Argon2id — OWASP #1 recommendation, memory-hard (RFC 9106)
      {:argon2_elixir, "~> 4.1"},
      # PBKDF2 kept for verifying legacy hashes during migration
      {:pbkdf2_elixir, "~> 2.2"},

      # MFA / TOTP
      {:nimble_totp, "~> 1.0"},

      # Utilities
      {:jason, "~> 1.4"}
    ]
  end
end
