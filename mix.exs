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
      dialyzer: [plt_add_apps: [:mix, :ex_unit]],
      # Advisories with no compatible fix that do not affect how we use the
      # package (`mix hex.audit` fails on any other). Re-check on upgrades.
      hex: [
        ignore_advisories: [
          # decimal: fix is 3.x, Ecto requires ~> 2.0; we never build Decimals
          # from user input (only convert DB aggregates to floats).
          "CVE-2026-97853",
          "CVE-2026-32686",
          # cloak: affects the AES-CTR cipher; our vault uses AES-GCM only.
          "CVE-2026-95105",
          # cloak_ecto: affects Cloak.Ecto.PBKDF2 fields, which we do not use.
          "CVE-2026-94206",
          # cowlib: structured-header escaping in Cowboy; the app is served by
          # Bandit (Cowboy only runs the internal metrics endpoint).
          "CVE-2026-43966"
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
