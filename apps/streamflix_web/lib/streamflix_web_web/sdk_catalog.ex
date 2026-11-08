defmodule StreamflixWebWeb.SdkCatalog do
  @moduledoc """
  Every official SDK and tool, read from `priv/sdk_catalog.json` (the single
  source of truth for /docs and the README).

  Versions shown in install snippets come from the registries at runtime
  (`SdkCatalog.Versions`); the version in the file is only the fallback.
  """

  alias StreamflixWebWeb.SdkCatalog.Versions

  @path Path.expand("../../priv/sdk_catalog.json", __DIR__)
  @external_resource @path
  @catalog @path |> File.read!() |> Jason.decode!()

  def sdks, do: @catalog["sdks"]
  def tools, do: @catalog["tools"]
  def entries, do: sdks() ++ tools()
  def ignored_repos, do: @catalog["ignored_repos"]
  def sdk_ids, do: Enum.map(sdks(), & &1["id"])

  def get!(id),
    do:
      Enum.find(entries(), &(&1["id"] == id)) ||
        raise(ArgumentError, "unknown SDK #{inspect(id)}")

  def label(id), do: get!(id)["label"]

  @doc "Latest known version: the registry's, or the catalog fallback."
  def version(%{"id" => id} = entry), do: Versions.get(id) || entry["version"]
  def version(id) when is_binary(id), do: id |> get!() |> version()

  @doc "Install snippet with `{version}` / `{minor}` filled in."
  def install(id) do
    entry = get!(id)

    case version(entry) do
      nil ->
        entry["install"]

      version ->
        minor = version |> String.split(".") |> Enum.take(2) |> Enum.join(".")

        entry["install"]
        |> String.replace("{version}", version)
        |> String.replace("{minor}", minor)
    end
  end
end
