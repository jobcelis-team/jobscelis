defmodule StreamflixCore.Platform.SandboxTest do
  use StreamflixCore.DataCase, async: true

  alias StreamflixCore.Platform

  describe "create_sandbox_endpoint/2" do
    test "creates a sandbox endpoint with slug" do
      project = insert(:project)

      assert {:ok, endpoint} = Platform.create_sandbox_endpoint(project.id)
      assert endpoint.slug != nil
      assert endpoint.project_id == project.id
      assert DateTime.compare(endpoint.expires_at, DateTime.utc_now()) == :gt
    end

    test "creates with custom name" do
      project = insert(:project)

      assert {:ok, endpoint} = Platform.create_sandbox_endpoint(project.id, "My Sandbox")
      assert endpoint.name == "My Sandbox"
    end
  end

  describe "list_sandbox_endpoints/1" do
    test "lists non-expired endpoints" do
      project = insert(:project)
      # Active endpoint
      insert(:sandbox_endpoint,
        project_id: project.id,
        expires_at:
          DateTime.utc_now() |> DateTime.add(24, :hour) |> DateTime.truncate(:microsecond)
      )

      # Expired endpoint
      insert(:sandbox_endpoint,
        project_id: project.id,
        expires_at:
          DateTime.utc_now() |> DateTime.add(-1, :hour) |> DateTime.truncate(:microsecond)
      )

      endpoints = Platform.list_sandbox_endpoints(project.id)
      assert length(endpoints) == 1
    end
  end

  describe "get_sandbox_by_slug/1" do
    test "returns active endpoint by slug" do
      project = insert(:project)

      endpoint =
        insert(:sandbox_endpoint,
          project_id: project.id,
          slug: "test-slug-123",
          expires_at:
            DateTime.utc_now() |> DateTime.add(24, :hour) |> DateTime.truncate(:microsecond)
        )

      assert Platform.get_sandbox_by_slug("test-slug-123").id == endpoint.id
    end

    test "returns nil for expired endpoint" do
      project = insert(:project)

      insert(:sandbox_endpoint,
        project_id: project.id,
        slug: "expired-slug",
        expires_at:
          DateTime.utc_now() |> DateTime.add(-1, :hour) |> DateTime.truncate(:microsecond)
      )

      assert Platform.get_sandbox_by_slug("expired-slug") == nil
    end
  end

  describe "delete_sandbox_endpoint/1" do
    test "deletes an endpoint" do
      project = insert(:project)
      endpoint = insert(:sandbox_endpoint, project_id: project.id)

      assert {:ok, _} = Platform.delete_sandbox_endpoint(endpoint.id)
      assert Platform.get_sandbox_endpoint(endpoint.id) == nil
    end

    test "returns error for non-existent id" do
      assert {:error, :not_found} = Platform.delete_sandbox_endpoint(Ecto.UUID.generate())
    end
  end

  describe "sandbox requests" do
    test "records and lists requests" do
      project = insert(:project)
      endpoint = insert(:sandbox_endpoint, project_id: project.id)

      assert {:ok, req} =
               Platform.record_sandbox_request(endpoint.id, %{
                 method: "POST",
                 path: "/test",
                 headers: %{"content-type" => "application/json"},
                 body: ~s({"test": true})
               })

      assert req.method == "POST"

      requests = Platform.list_sandbox_requests(endpoint.id)
      assert length(requests) == 1
    end
  end
end
