defmodule Streamflix.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      # Umbrella test runs share one VM: protocols consolidated without test-only deps
      # (e.g. LazyHTML for LiveView tests) would be missing their implementations
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),
      aliases: aliases(),
      releases: releases(),
      listeners: [Phoenix.CodeReloader],
      test_coverage: [tool: ExCoveralls],
      dialyzer: [plt_add_apps: [:mix, :ex_unit], ignore_warnings: ".dialyzer_ignore.exs"],
      # Advisories with no compatible fix that do not affect how we use the
      # package (`mix hex.audit` fails on any other). Re-check on upgrades.
      hex: [
        ignore_advisories: [
          # cloak: affects the AES-CTR cipher; our vault uses AES-GCM only.
          "CVE-2026-95105",
          # cloak_ecto: affects Cloak.Ecto.PBKDF2 fields, which we do not use.
          "CVE-2026-94206",
          # cowboy/cowlib: no fixed release yet. The app is served by Bandit;
          # Cowboy only runs the PromEx metrics server on port 4021, which the
          # container does not expose (only 4000).
          "CVE-2026-43966",
          "CVE-2026-115701",
          "CVE-2026-113431"
        ]
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [
        test: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test
      ]
    ]
  end

  defp deps do
    [
      # Dev/Test tools
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": [
        "ecto.create",
        "ecto.migrate",
        "run apps/streamflix_core/priv/repo/seeds.exs"
      ],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end

  defp releases do
    [
      streamflix: [
        applications: [
          streamflix_core: :permanent,
          streamflix_accounts: :permanent,
          streamflix_web: :permanent
        ]
      ]
    ]
  end
end
