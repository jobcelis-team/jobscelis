defmodule StreamflixCore.Platform.Sandbox do
  @moduledoc """
  Sandbox endpoint management: create, list, requests.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{SandboxEndpoint, SandboxRequest}

  @pubsub StreamflixCore.PubSub

  def create_sandbox_endpoint(project_id, name \\ nil) do
    slug = generate_sandbox_slug()
    expires_at = DateTime.utc_now() |> DateTime.add(24, :hour) |> DateTime.truncate(:microsecond)

    %SandboxEndpoint{}
    |> SandboxEndpoint.changeset(%{
      project_id: project_id,
      slug: slug,
      name: name || "Sandbox #{slug}",
      expires_at: expires_at
    })
    |> Repo.insert()
  end

  def list_sandbox_endpoints(project_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    SandboxEndpoint
    |> where([s], s.project_id == ^project_id and s.expires_at > ^now)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  def get_sandbox_by_slug(slug) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    SandboxEndpoint
    |> where([s], s.slug == ^slug and s.expires_at > ^now)
    |> Repo.one()
  end

  def get_sandbox_endpoint(id), do: Repo.get(SandboxEndpoint, id)

  def delete_sandbox_endpoint(id) do
    case Repo.get(SandboxEndpoint, id) do
      nil -> {:error, :not_found}
      endpoint -> Repo.delete(endpoint)
    end
  end

  def record_sandbox_request(endpoint_id, attrs) do
    %SandboxRequest{}
    |> SandboxRequest.changeset(Map.put(attrs, :endpoint_id, endpoint_id))
    |> Repo.insert()
    |> case do
      {:ok, req} ->
        endpoint = Repo.get(SandboxEndpoint, endpoint_id) |> Repo.preload(:project)

        if endpoint do
          Phoenix.PubSub.broadcast(
            @pubsub,
            "project:#{endpoint.project_id}",
            {:sandbox_request, req}
          )
        end

        {:ok, req}

      error ->
        error
    end
  end

  def list_sandbox_requests(endpoint_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    SandboxRequest
    |> where([r], r.endpoint_id == ^endpoint_id)
    |> order_by([r], desc: r.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  defp generate_sandbox_slug() do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false) |> String.downcase()
  end
end
