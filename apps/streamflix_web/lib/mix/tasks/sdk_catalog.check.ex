defmodule Mix.Tasks.SdkCatalog.Check do
  @shortdoc "Checks that the SDK catalog matches what is published"

  @moduledoc """
  Fails when /docs and the README would show something wrong:

    * a public jobcelis-team repository or an `sdks/` directory is not in
      `priv/sdk_catalog.json`
    * a package is not published in its registry
    * a published Go module declares a different path than the docs install
    * a catalog link is broken, or the README does not link an entry

  Runs in CI on every pull request and daily. Run from the umbrella root or
  `apps/streamflix_web`: `mix sdk_catalog.check`.
  """

  use Mix.Task

  alias StreamflixWebWeb.SdkCatalog
  alias StreamflixWebWeb.SdkCatalog.Registry

  @org "jobcelis-team"
  # npmjs.com answers 403 to non-browser clients; npm packages are verified
  # through the registry API instead.
  @unfetchable_hosts ["www.npmjs.com"]

  @impl true
  def run(_args) do
    Mix.Task.run("app.config")
    {:ok, _} = Application.ensure_all_started(:req)

    root = Mix.Project.config()[:deps_path] |> Path.expand() |> Path.dirname()

    problems =
      missing_repos() ++
        missing_sdk_dirs(root) ++
        unpublished_packages() ++
        go_module_mismatches() ++
        broken_links() ++
        readme_gaps(root)

    case problems do
      [] ->
        Mix.shell().info("SDK catalog OK: #{length(SdkCatalog.entries())} entries checked.")

      _ ->
        Enum.each(problems, &Mix.shell().error("  - " <> &1))

        Mix.raise(
          "SDK catalog check failed (#{length(problems)} problem(s)), see apps/streamflix_web/priv/sdk_catalog.json"
        )
    end
  end

  defp catalog_repos, do: MapSet.new(SdkCatalog.entries(), & &1["repo"])

  defp missing_repos do
    known = MapSet.union(catalog_repos(), MapSet.new(SdkCatalog.ignored_repos()))

    case github("https://api.github.com/orgs/#{@org}/repos?type=public&per_page=100") do
      {:ok, repos} ->
        for %{"full_name" => name, "archived" => false, "fork" => false} <- repos,
            not MapSet.member?(known, name),
            do: "repository #{name} is not in the catalog (add it, or to ignored_repos)"

      {:error, reason} ->
        ["could not list #{@org} repositories: #{inspect(reason)}"]
    end
  end

  defp missing_sdk_dirs(root) do
    paths = SdkCatalog.entries() |> Enum.map(& &1["path"]) |> MapSet.new()
    sdks = Path.join(root, "sdks")

    for dir <- File.ls!(sdks),
        File.dir?(Path.join(sdks, dir)),
        not MapSet.member?(paths, "sdks/" <> dir),
        do: "sdks/#{dir} is not in the catalog"
  end

  defp unpublished_packages do
    for %{"latest" => latest} = entry when not is_nil(latest) <- SdkCatalog.entries(),
        {:error, reason} <- [Registry.latest(latest)],
        do:
          "#{entry["id"]}: #{latest["package"]} not found in #{latest["source"]} (#{inspect(reason)})"
  end

  # `go get <path>` fails when the published go.mod declares another path
  defp go_module_mismatches do
    for %{"latest" => %{"source" => "go", "package" => path}} = entry <- SdkCatalog.entries(),
        problem <- go_module_problem(entry["id"], path),
        do: problem
  end

  defp go_module_problem(id, path) do
    with {:ok, version} <- Registry.latest(%{"source" => "go", "package" => path}),
         {:ok, %Req.Response{status: 200, body: gomod}} <-
           Req.get("https://proxy.golang.org/#{path}/@v/v#{version}.mod", retry: false) do
      case Regex.run(~r/^module\s+(\S+)/m, gomod) do
        [_, ^path] ->
          []

        [_, other] ->
          ["#{id}: v#{version} declares module #{other}, but the docs install #{path}"]

        _ ->
          ["#{id}: v#{version} has no module line"]
      end
    else
      error -> ["#{id}: could not read the published go.mod (#{inspect(error)})"]
    end
  end

  defp broken_links do
    urls =
      SdkCatalog.entries()
      |> Enum.flat_map(&[&1["url"], "https://github.com/" <> &1["repo"]])
      |> Enum.uniq()
      |> Enum.reject(&(URI.parse(&1).host in @unfetchable_hosts))

    urls
    |> Task.async_stream(&{&1, link_status(&1)}, max_concurrency: 4, timeout: 30_000)
    |> Enum.flat_map(fn
      {:ok, {_url, 200}} -> []
      {:ok, {url, status}} -> ["broken link #{url} (#{inspect(status)})"]
      {:exit, reason} -> ["link check crashed: #{inspect(reason)}"]
    end)
  end

  defp link_status(url) do
    case Req.get(url,
           retry: false,
           receive_timeout: 15_000,
           headers: [{"user-agent", "Mozilla/5.0 (jobcelis link check)"}, {"accept", "text/html"}]
         ) do
      {:ok, %Req.Response{status: status}} -> status
      {:error, error} -> error
    end
  end

  defp readme_gaps(root) do
    readme = File.read!(Path.join(root, "README.md"))

    for entry <- SdkCatalog.entries(),
        not String.contains?(readme, entry["url"]),
        do: "README.md does not link #{entry["label"]} (#{entry["url"]})"
  end

  defp github(url) do
    headers =
      case System.get_env("GITHUB_TOKEN") do
        token when token in [nil, ""] -> []
        token -> [{"authorization", "Bearer #{token}"}]
      end

    case Req.get(url, headers: headers, retry: false) do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
      {:ok, %Req.Response{status: status}} -> {:error, {:http_status, status}}
      {:error, error} -> {:error, error}
    end
  end
end
