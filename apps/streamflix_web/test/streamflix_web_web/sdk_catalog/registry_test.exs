defmodule StreamflixWebWeb.SdkCatalog.RegistryTest do
  use ExUnit.Case, async: true

  alias StreamflixWebWeb.SdkCatalog.Registry

  defp stub(fun), do: Req.Test.stub(Registry, fun)

  test "reads the version from a JSON registry" do
    stub(fn conn ->
      assert conn.host == "registry.npmjs.org"
      assert conn.request_path == "/@jobcelis/sdk/latest"
      Req.Test.json(conn, %{"version" => "1.9.1"})
    end)

    assert {:ok, "1.9.1"} = Registry.latest(%{"source" => "npm", "package" => "@jobcelis/sdk"})
  end

  test "picks the highest stable version from a list, ignoring pre-releases" do
    stub(fn conn ->
      Req.Test.json(conn, [
        %{"name" => "v1.2.9"},
        %{"name" => "v1.10.0"},
        %{"name" => "v2.0.0-rc.1"},
        %{"name" => "not-a-version"}
      ])
    end)

    assert {:ok, "1.10.0"} =
             Registry.latest(%{
               "source" => "github_tags",
               "package" => "jobcelis-team/jobcelis-swift"
             })
  end

  test "reads the release from Maven metadata" do
    stub(fn conn ->
      assert conn.request_path == "/maven2/com/jobcelis/jobcelis-kotlin/maven-metadata.xml"

      Plug.Conn.send_resp(
        conn,
        200,
        "<metadata><versioning><release>1.3.1</release></versioning></metadata>"
      )
    end)

    assert {:ok, "1.3.1"} =
             Registry.latest(%{"source" => "maven", "package" => "com.jobcelis:jobcelis-kotlin"})
  end

  test "case-encodes Go module paths for the proxy" do
    stub(fn conn ->
      assert conn.request_path == "/github.com/!some!org/mod/@latest"
      Req.Test.json(conn, %{"Version" => "v1.5.0"})
    end)

    assert {:ok, "1.5.0"} =
             Registry.latest(%{"source" => "go", "package" => "github.com/SomeOrg/mod"})
  end

  test "errors instead of returning anything that is not a version" do
    stub(fn conn -> Req.Test.json(conn, %{"info" => %{"version" => "<script>"}}) end)
    assert {:error, :no_stable_version} = Registry.latest(%{"source" => "pypi", "package" => "x"})

    stub(fn conn -> Plug.Conn.send_resp(conn, 404, "not found") end)

    assert {:error, {:http_status, 404, _}} =
             Registry.latest(%{"source" => "hex", "package" => "x"})

    assert {:error, :no_registry} = Registry.latest(nil)
  end
end
