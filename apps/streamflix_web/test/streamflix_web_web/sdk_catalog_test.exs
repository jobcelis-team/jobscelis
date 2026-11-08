defmodule StreamflixWebWeb.SdkCatalogTest do
  use ExUnit.Case, async: true

  alias StreamflixWebWeb.SdkCatalog

  test "every entry is complete and ids are unique" do
    entries = SdkCatalog.entries()

    for entry <- entries do
      for key <- ~w(id label registry url repo install),
          do: assert(is_binary(entry[key]), "#{entry["id"]}: #{key}")

      assert String.starts_with?(entry["url"], "https://")
      # Placeholders need a version to fill them in
      if entry["install"] =~ ~r/\{(version|minor)\}/,
        do: assert(entry["version"] && entry["latest"])
    end

    assert length(entries) == entries |> Enum.map(& &1["id"]) |> Enum.uniq() |> length()
  end

  test "install snippets are filled in with the version" do
    for entry <- SdkCatalog.entries(),
        do: refute(SdkCatalog.install(entry["id"]) =~ ~r/\{(version|minor)\}/)

    version = SdkCatalog.version("kotlin")

    assert SdkCatalog.install("kotlin") ==
             ~s|implementation("com.jobcelis:jobcelis-kotlin:#{version}")|
  end

  # The marketing pages (home, pricing, FAQ, changelog, meta descriptions) say
  # "12 SDKs". When an SDK is added or removed, update them (grep "12 SDK")
  # and this number together.
  test "the SDK count matches the marketing copy" do
    assert length(SdkCatalog.sdks()) == 12
  end
end
