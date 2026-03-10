defmodule Jobcelis.MixProject do
  use Mix.Project

  @version "1.2.0"
  @source_url "https://github.com/vladimirCeli/jobcelis-elixir"

  def project do
    [
      app: :jobcelis,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      name: "Jobcelis",
      description: "Official Elixir SDK for the Jobcelis Event Infrastructure Platform",
      source_url: @source_url,
      homepage_url: "https://jobcelis.com"
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Jobcelis.Application, []}
    ]
  end

  defp deps do
    [
      {:finch, "~> 0.18"},
      {:jason, "~> 1.4"},
      {:plug_crypto, "~> 2.0"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: "jobcelis",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Documentation" => "https://jobcelis.com/docs"
      },
      maintainers: ["Jobcelis"],
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
