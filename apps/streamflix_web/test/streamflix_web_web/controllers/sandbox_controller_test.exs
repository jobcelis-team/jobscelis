defmodule StreamflixWebWeb.SandboxControllerTest do
  use StreamflixWebWeb.ConnCase, async: false

  alias StreamflixCore.Platform

  setup do
    project = insert(:project)
    {:ok, endpoint} = Platform.create_sandbox_endpoint(project.id, "test")
    %{endpoint: endpoint}
  end

  defp last_request(endpoint) do
    endpoint.id |> Platform.list_sandbox_requests() |> List.first()
  end

  test "captures JSON bodies already parsed by Plug.Parsers", %{conn: conn, endpoint: ep} do
    conn
    |> put_req_header("content-type", "application/json")
    |> post("/sandbox/#{ep.slug}", Jason.encode!(%{"order_id" => "ORD-1", "total" => 10}))
    |> json_response(200)

    assert Jason.decode!(last_request(ep).body) == %{"order_id" => "ORD-1", "total" => 10}
  end

  test "captures JSON arrays", %{conn: conn, endpoint: ep} do
    conn
    |> put_req_header("content-type", "application/json")
    |> post("/sandbox/#{ep.slug}", Jason.encode!([1, 2]))
    |> json_response(200)

    assert Jason.decode!(last_request(ep).body) == [1, 2]
  end

  test "keeps raw bodies of unparsed content types", %{conn: conn, endpoint: ep} do
    conn
    |> put_req_header("content-type", "text/plain")
    |> post("/sandbox/#{ep.slug}", "hello")
    |> json_response(200)

    assert last_request(ep).body == "hello"
  end
end
