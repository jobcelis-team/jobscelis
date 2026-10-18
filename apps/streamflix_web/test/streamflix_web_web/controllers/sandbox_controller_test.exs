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

  test "keeps the sender's headers but not the ones added by the hosting proxy",
       %{conn: conn, endpoint: ep} do
    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("x-test-header", "acme")
    |> put_req_header("client-ip", "203.0.113.7:51000")
    |> put_req_header("x-forwarded-for", "203.0.113.7")
    |> put_req_header("was-default-hostname", "internal.example.net")
    |> put_req_header("x-arr-ssl", "on")
    |> post("/sandbox/#{ep.slug}", "{}")
    |> json_response(200)

    headers = last_request(ep).headers
    assert headers["x-test-header"] == "acme"
    assert headers["content-type"] == "application/json"
    refute Map.has_key?(headers, "client-ip")
    refute Map.has_key?(headers, "x-forwarded-for")
    refute Map.has_key?(headers, "was-default-hostname")
    refute Map.has_key?(headers, "x-arr-ssl")
  end
end
