defmodule StreamflixCore.Platform.Quotas do
  @moduledoc """
  Per-project and per-user resource quotas, enforced in the core `create_*`
  functions so the API, the dashboard and any other caller respect them.

  Limits come from config and can be changed without code changes:

      config :streamflix_core, :quotas,
        webhooks_per_project: 50,
        jobs_per_project: 50,
        pipelines_per_project: 50,
        sandbox_endpoints_per_project: 20,
        embed_tokens_per_project: 50,
        event_schemas_per_project: 100,
        projects_per_user: 10

  Only live resources count (active rows, unexpired sandbox endpoints), so
  deleting a resource frees its slot. The check and the insert run in one
  transaction holding an advisory lock on (resource, owner), so concurrent
  requests cannot overshoot the limit.

  When the limit is reached the create function returns
  `{:error, %Ecto.Changeset{}}` with a `:base` error and
  `quota_exceeded: true` in the changeset's error metadata.
  """

  import Ecto.Query

  alias StreamflixCore.Repo

  alias StreamflixCore.Schemas.{
    EmbedToken,
    EventSchema,
    Job,
    Pipeline,
    Project,
    SandboxEndpoint,
    Webhook
  }

  @defaults [
    webhooks_per_project: 50,
    jobs_per_project: 50,
    pipelines_per_project: 50,
    sandbox_endpoints_per_project: 20,
    embed_tokens_per_project: 50,
    event_schemas_per_project: 100,
    projects_per_user: 10
  ]

  @resources %{
    webhooks: {:webhooks_per_project, Webhook, "webhooks per project"},
    jobs: {:jobs_per_project, Job, "jobs per project"},
    pipelines: {:pipelines_per_project, Pipeline, "pipelines per project"},
    sandbox_endpoints:
      {:sandbox_endpoints_per_project, SandboxEndpoint, "sandbox endpoints per project"},
    embed_tokens: {:embed_tokens_per_project, EmbedToken, "embed tokens per project"},
    event_schemas: {:event_schemas_per_project, EventSchema, "event schemas per project"},
    projects: {:projects_per_user, Project, "projects per user"}
  }

  @type resource ::
          :webhooks
          | :jobs
          | :pipelines
          | :sandbox_endpoints
          | :embed_tokens
          | :event_schemas
          | :projects

  @doc "Configured limit for a resource."
  @spec limit(resource) :: pos_integer()
  def limit(resource) do
    {key, _schema, _label} = Map.fetch!(@resources, resource)
    config = Application.get_env(:streamflix_core, :quotas, [])
    Keyword.get(config, key, Keyword.fetch!(@defaults, key))
  end

  @doc "Number of live resources currently counted against the quota."
  @spec usage(resource, Ecto.UUID.t()) :: non_neg_integer()
  def usage(resource, owner_id), do: resource |> count_query(owner_id) |> Repo.aggregate(:count)

  @doc """
  Runs `fun` (which must return `{:ok, _}`, `{:ok, _, _}` or `{:error, _}`) only
  if the owner (project, or user for `:projects`) is below the quota.
  """
  def with_quota(resource, nil, fun) when is_atom(resource), do: fun.()

  def with_quota(resource, owner_id, fun) do
    result =
      Repo.transaction(fn ->
        advisory_lock(resource, owner_id)

        if usage(resource, owner_id) >= limit(resource) do
          Repo.rollback(quota_error(resource))
        else
          case fun.() do
            {:error, reason} -> Repo.rollback(reason)
            ok -> ok
          end
        end
      end)

    case result do
      {:ok, ok} -> ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Changeset carrying the quota error for a resource."
  def quota_error(resource) do
    {_key, schema, label} = Map.fetch!(@resources, resource)
    limit = limit(resource)

    schema
    |> struct()
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.add_error(:base, "limit reached: maximum #{limit} #{label}",
      limit: limit,
      quota_exceeded: true
    )
    |> Map.put(:action, :insert)
  end

  @doc "True when a changeset was rejected because a quota was reached."
  def quota_exceeded?(%Ecto.Changeset{errors: errors}),
    do: Enum.any?(errors, fn {_field, {_msg, meta}} -> Keyword.get(meta, :quota_exceeded) end)

  def quota_exceeded?(_), do: false

  defp advisory_lock(resource, owner_id) do
    Repo.query!("SELECT pg_advisory_xact_lock(hashtext($1))", ["quota:#{resource}:#{owner_id}"])
  end

  defp count_query(:projects, user_id),
    do: from(p in Project, where: p.user_id == ^user_id and p.status == "active")

  defp count_query(:sandbox_endpoints, project_id) do
    now = DateTime.utc_now()
    from(s in SandboxEndpoint, where: s.project_id == ^project_id and s.expires_at > ^now)
  end

  defp count_query(resource, project_id) do
    {_key, schema, _label} = Map.fetch!(@resources, resource)
    from(r in schema, where: r.project_id == ^project_id and r.status == "active")
  end
end
