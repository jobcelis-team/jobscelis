defmodule StreamflixWebWeb.SdkCatalog.Registry do
  @moduledoc """
  Looks up the latest stable version of a package in its public registry.
  Used to keep the docs current and by `mix sdk_catalog.check`.
  """

  @user_agent "jobcelis-docs (+https://jobcelis.com)"

  @spec latest(map() | nil) :: {:ok, String.t()} | {:error, term()}
  def latest(nil), do: {:error, :no_registry}

  def latest(%{"source" => source, "package" => package}) do
    case fetch(source, package) do
      {:ok, versions} when is_list(versions) -> max_stable(versions)
      {:ok, version} -> max_stable([version])
      error -> error
    end
  end

  defp fetch("npm", pkg), do: get_json("https://registry.npmjs.org/#{pkg}/latest", ["version"])
  defp fetch("pypi", pkg), do: get_json("https://pypi.org/pypi/#{pkg}/json", ["info", "version"])

  defp fetch("go", pkg),
    do: get_json("https://proxy.golang.org/#{go_escape(pkg)}/@latest", ["Version"])

  defp fetch("rubygems", pkg),
    do: get_json("https://rubygems.org/api/v1/versions/#{pkg}/latest.json", ["version"])

  defp fetch("hex", pkg),
    do: get_json("https://hex.pm/api/packages/#{pkg}", ["latest_stable_version"])

  defp fetch("crates", pkg),
    do: get_json("https://crates.io/api/v1/crates/#{pkg}", ["crate", "max_stable_version"])

  defp fetch("pub", pkg),
    do: get_json("https://pub.dev/api/packages/#{pkg}", ["latest", "version"])

  defp fetch("terraform", pkg),
    do: get_json("https://registry.terraform.io/v1/providers/#{pkg}", ["version"])

  defp fetch("nuget", pkg),
    do:
      get_json("https://api.nuget.org/v3-flatcontainer/#{String.downcase(pkg)}/index.json", [
        "versions"
      ])

  defp fetch("packagist", pkg) do
    with {:ok, releases} <-
           get_json("https://repo.packagist.org/p2/#{pkg}.json", ["packages", pkg]) do
      {:ok, Enum.map(releases, & &1["version"])}
    end
  end

  defp fetch("github_tags", repo) do
    with {:ok, tags} <- get_json("https://api.github.com/repos/#{repo}/tags?per_page=100", []) do
      {:ok, Enum.map(tags, & &1["name"])}
    end
  end

  defp fetch("maven", coordinates) do
    [group, artifact] = String.split(coordinates, ":")

    url =
      "https://repo1.maven.org/maven2/#{String.replace(group, ".", "/")}/#{artifact}/maven-metadata.xml"

    with {:ok, body} <- get(url) do
      case Regex.run(~r{<release>([^<]+)</release>}, body) do
        [_, version] -> {:ok, version}
        _ -> {:error, :no_release}
      end
    end
  end

  defp fetch(source, _pkg), do: {:error, {:unknown_source, source}}

  defp get_json(url, path) do
    with {:ok, body} when is_map(body) or is_list(body) <- get(url),
         value when not is_nil(value) <- dig(body, path) do
      {:ok, value}
    else
      {:error, _} = error -> error
      _ -> {:error, {:unexpected_response, url}}
    end
  end

  defp dig(body, []), do: body
  defp dig(body, [key | rest]) when is_map(body), do: body |> Map.get(key) |> dig(rest)
  defp dig(_body, _path), do: nil

  defp get(url) do
    opts =
      [
        headers: headers(url),
        receive_timeout: 10_000,
        connect_options: [timeout: 5_000],
        retry: false
      ]
      |> Keyword.merge(Application.get_env(:streamflix_web, __MODULE__, [])[:req_options] || [])

    case Req.get(url, opts) do
      {:ok, %Req.Response{status: 200, body: body}} -> {:ok, body}
      {:ok, %Req.Response{status: status}} -> {:error, {:http_status, status, url}}
      {:error, error} -> {:error, error}
    end
  end

  # api.github.com allows 60 unauthenticated requests per hour; CI passes a token
  defp headers("https://api.github.com/" <> _) do
    case System.get_env("GITHUB_TOKEN") do
      token when token in [nil, ""] -> [{"user-agent", @user_agent}]
      token -> [{"user-agent", @user_agent}, {"authorization", "Bearer #{token}"}]
    end
  end

  defp headers(_url), do: [{"user-agent", @user_agent}]

  # Module paths are case-encoded in the Go proxy: "A" -> "!a"
  defp go_escape(path), do: Regex.replace(~r/[A-Z]/, path, &("!" <> String.downcase(&1)))

  defp max_stable(versions) do
    versions
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.trim_leading(&1, "v"))
    |> Enum.flat_map(fn v ->
      case Version.parse(v) do
        {:ok, %Version{pre: []} = parsed} -> [parsed]
        _ -> []
      end
    end)
    |> Enum.max(Version, fn -> nil end)
    |> case do
      nil -> {:error, :no_stable_version}
      version -> {:ok, to_string(version)}
    end
  end
end
