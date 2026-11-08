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

    StreamflixCore.Platform.Quotas.with_quota(:sandbox_endpoints, project_id, fn ->
      %SandboxEndpoint{}
      |> SandboxEndpoint.changeset(%{
        project_id: project_id,
        slug: slug,
        name: name || "Sandbox #{slug}",
        expires_at: expires_at
      })
      |> Repo.insert()
    end)
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

  def get_sandbox_endpoint(id), do: Repo.get_uuid(SandboxEndpoint, id)

  def delete_sandbox_endpoint(id) do
    case Repo.get(SandboxEndpoint, id) do
      nil -> {:error, :not_found}
      endpoint -> Repo.delete(endpoint)
    end
  end

  @doc "Max captured requests kept per sandbox endpoint (older ones are dropped)."
  def max_requests_per_endpoint,
    do: Application.get_env(:streamflix_core, :sandbox_max_requests_per_endpoint, 100)

  @doc "Max bytes of a captured request body that are stored."
  def max_stored_body,
    do: Application.get_env(:streamflix_core, :sandbox_max_stored_body_bytes, 64_000)

  def record_sandbox_request(endpoint_id, attrs) do
    attrs = Map.update(attrs, :body, nil, &truncate_body/1)

    %SandboxRequest{}
    |> SandboxRequest.changeset(Map.put(attrs, :endpoint_id, endpoint_id))
    |> Repo.insert()
    |> case do
      {:ok, req} ->
        trim_requests(endpoint_id)
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

  # Keep only the newest requests of the endpoint: a public sandbox URL cannot
  # be used to fill the database.
  defp trim_requests(endpoint_id) do
    keep = max_requests_per_endpoint()

    cutoff =
      from(r in SandboxRequest,
        where: r.endpoint_id == ^endpoint_id,
        order_by: [desc: r.inserted_at, desc: r.id],
        offset: ^keep,
        limit: 1,
        select: r.inserted_at
      )
      |> Repo.one()

    if cutoff do
      from(r in SandboxRequest,
        where: r.endpoint_id == ^endpoint_id and r.inserted_at <= ^cutoff
      )
      |> Repo.delete_all()
    end

    :ok
  end

  defp truncate_body(body) when is_binary(body) do
    max = max_stored_body()

    if byte_size(body) > max do
      body
      |> binary_part(0, max)
      |> String.replace_invalid("")
      |> Kernel.<>("...[truncated]")
    else
      body
    end
  end

  defp truncate_body(body), do: body

  @doc """
  Deletes expired sandbox endpoints and their captured requests.
  Returns `{endpoints_deleted, requests_deleted}`.
  """
  def purge_expired(now \\ DateTime.utc_now()) do
    expired_ids =
      from(s in SandboxEndpoint, where: s.expires_at < ^now, select: s.id)
      |> Repo.all()

    if expired_ids == [] do
      {0, 0}
    else
      {req_count, _} =
        from(r in SandboxRequest, where: r.endpoint_id in ^expired_ids) |> Repo.delete_all()

      {endpoint_count, _} =
        from(s in SandboxEndpoint, where: s.id in ^expired_ids) |> Repo.delete_all()

      {endpoint_count, req_count}
    end
  end

  defp generate_sandbox_slug() do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false) |> String.downcase()
  end
end
