defmodule StreamflixWebWeb.Api.V1.PlatformSandboxController do
  use StreamflixWebWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias StreamflixCore.Platform
  alias StreamflixCore.Audit
  alias StreamflixWebWeb.Schemas

  alias StreamflixWebWeb.Plugs.RequireScope

  plug RequireScope, "sandbox:read" when action in [:index, :requests]
  plug RequireScope, "sandbox:write" when action in [:create, :delete]

  tags(["Sandbox"])
  security([%{"api_key" => []}])

  operation(:index,
    summary: "List sandbox endpoints",
    responses: [
      ok:
        {"Sandbox endpoints list", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{data: %OpenApiSpex.Schema{type: :array, items: Schemas.SandboxEndpoint}}
         }}
    ]
  )

  def index(conn, _params) do
    project = conn.assigns.current_project
    endpoints = Platform.list_sandbox_endpoints(project.id)
    json(conn, %{data: Enum.map(endpoints, &endpoint_json/1)})
  end

  operation(:create,
    summary: "Create a sandbox endpoint",
    request_body:
      {"Sandbox endpoint attributes", "application/json",
       %OpenApiSpex.Schema{type: :object, properties: %{name: %OpenApiSpex.Schema{type: :string}}}},
    responses: [
      created: {"Sandbox endpoint created", "application/json", Schemas.SandboxEndpoint},
      unprocessable_entity: {"Creation failed", "application/json", Schemas.ErrorResponse}
    ]
  )

  def create(conn, params) do
    project = conn.assigns.current_project

    case Platform.create_sandbox_endpoint(project.id, params["name"]) do
      {:ok, endpoint} ->
        Audit.record("sandbox.created",
          user_id: project.user_id,
          project_id: project.id,
          resource_type: "sandbox_endpoint",
          resource_id: endpoint.id,
          metadata: %{"slug" => endpoint.slug}
        )

        conn
        |> put_status(:created)
        |> json(endpoint_json(endpoint))

      {:error, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create sandbox endpoint"})
    end
  end

  operation(:delete,
    summary: "Delete a sandbox endpoint",
    parameters: [id: [in: :path, type: :string, description: "Sandbox endpoint ID"]],
    responses: [
      ok:
        {"Sandbox endpoint deleted", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{status: %OpenApiSpex.Schema{type: :string}}
         }},
      not_found: {"Not found", "application/json", Schemas.ErrorResponse}
    ]
  )

  def delete(conn, %{"id" => id}) do
    project = conn.assigns.current_project

    case Platform.get_sandbox_endpoint(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      ep ->
        if ep.project_id != project.id do
          conn |> put_status(:not_found) |> json(%{error: "not_found"})
        else
          case Platform.delete_sandbox_endpoint(id) do
            {:ok, _} -> json(conn, %{status: "deleted"})
            {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "not_found"})
          end
        end
    end
  end

  operation(:requests,
    summary: "List sandbox endpoint requests",
    parameters: [id: [in: :path, type: :string, description: "Sandbox endpoint ID"]],
    responses: [
      ok:
        {"Sandbox requests list", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             data: %OpenApiSpex.Schema{type: :array, items: %OpenApiSpex.Schema{type: :object}}
           }
         }}
    ]
  )

  def requests(conn, %{"id" => id}) do
    project = conn.assigns.current_project

    case Platform.get_sandbox_endpoint(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      ep ->
        if ep.project_id != project.id do
          conn |> put_status(:not_found) |> json(%{error: "not_found"})
        else
          reqs = Platform.list_sandbox_requests(id)
          json(conn, %{data: Enum.map(reqs, &request_json/1)})
        end
    end
  end

  defp endpoint_json(ep) do
    %{
      id: ep.id,
      slug: ep.slug,
      name: ep.name,
      url: "/sandbox/#{ep.slug}",
      expires_at: ep.expires_at,
      inserted_at: ep.inserted_at
    }
  end

  defp request_json(req) do
    %{
      id: req.id,
      method: req.method,
      path: req.path,
      headers: req.headers,
      body: req.body,
      query_params: req.query_params,
      ip: req.ip,
      inserted_at: req.inserted_at
    }
  end
end
