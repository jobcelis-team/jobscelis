defmodule StreamflixCore.Platform.Projects do
  @moduledoc """
  Project management: CRUD, default project, soft delete.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.Project

  @cache :platform_cache
  @project_ttl :timer.seconds(300)

  def create_project(attrs) do
    user_id = attrs[:user_id] || attrs["user_id"]

    # First project for user auto-sets is_default
    is_default =
      if user_id do
        not Repo.exists?(
          from(p in Project, where: p.user_id == ^user_id and p.status == "active")
        )
      else
        false
      end

    attrs = Map.put(attrs, :is_default, Map.get(attrs, :is_default, is_default))

    case %Project{}
         |> Project.changeset(attrs)
         |> Repo.insert() do
      {:ok, project} ->
        # Auto-create owner membership
        if user_id do
          StreamflixCore.Teams.create_owner_member(project.id, user_id)
        end

        {:ok, project}

      error ->
        error
    end
  end

  def get_project(id), do: Repo.get(Project, id)
  def get_project!(id), do: Repo.get!(Project, id)

  def get_default_project_for_user(user_id) do
    cache_key = {:project_user, user_id}

    case Cachex.get(@cache, cache_key) do
      {:ok, nil} ->
        result =
          Project
          |> where([p], p.user_id == ^user_id and p.status == "active")
          |> order_by([p], desc: p.is_default, asc: p.inserted_at)
          |> limit(1)
          |> Repo.one()

        if result, do: Cachex.put(@cache, cache_key, result, ttl: @project_ttl)
        result

      {:ok, cached} ->
        cached
    end
  end

  def set_default_project(user_id, project_id) do
    Repo.transaction(fn ->
      # Unset all defaults for user
      from(p in Project, where: p.user_id == ^user_id and p.is_default == true)
      |> Repo.update_all(
        set: [
          is_default: false,
          updated_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
        ]
      )

      # Set target as default
      case Repo.get(Project, project_id) do
        nil ->
          Repo.rollback(:not_found)

        project ->
          project
          |> Project.changeset(%{is_default: true})
          |> Repo.update!()
      end
    end)
    |> case do
      {:ok, project} ->
        Cachex.del(@cache, {:project_user, user_id})
        {:ok, project}

      error ->
        error
    end
  end

  def delete_project(%Project{} = project) do
    case set_project_inactive(project) do
      {:ok, updated} ->
        # If deleted project was default, promote next one
        if project.is_default do
          next =
            Project
            |> where(
              [p],
              p.user_id == ^project.user_id and p.status == "active" and p.id != ^project.id
            )
            |> order_by([p], asc: p.inserted_at)
            |> limit(1)
            |> Repo.one()

          if next do
            next |> Project.changeset(%{is_default: true}) |> Repo.update()
          end
        end

        Cachex.del(@cache, {:project_user, project.user_id})
        {:ok, updated}

      error ->
        error
    end
  end

  def list_projects(opts \\ []) do
    include_inactive = Keyword.get(opts, :include_inactive, false)

    Project
    |> maybe_filter_active(include_inactive)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  def list_projects_for_user(user_id, opts \\ []) do
    include_inactive = Keyword.get(opts, :include_inactive, false)

    Project
    |> where([p], p.user_id == ^user_id)
    |> maybe_filter_active(include_inactive)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  def set_project_inactive(%Project{} = project) do
    update_project(project, %{status: "inactive"})
  end

  defp maybe_filter_active(query, true), do: query
  defp maybe_filter_active(query, false), do: where(query, [x], x.status == "active")
end
