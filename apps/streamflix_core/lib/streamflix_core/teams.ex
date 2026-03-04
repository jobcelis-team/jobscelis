defmodule StreamflixCore.Teams do
  @moduledoc """
  Context for team/collaborator management on projects.
  Handles invitations, roles (owner/editor/viewer), and access checks.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{ProjectMember, Project}

  def invite_member(project_id, user_id, role \\ "viewer", invited_by \\ nil) do
    attrs = %{
      project_id: project_id,
      user_id: user_id,
      role: role,
      status: "pending",
      invited_by: invited_by
    }

    %ProjectMember{}
    |> ProjectMember.changeset(attrs)
    |> Repo.insert()
  end

  def accept_invitation(member_id) do
    case Repo.get(ProjectMember, member_id) do
      nil ->
        {:error, :not_found}

      %{status: "pending"} = member ->
        member
        |> ProjectMember.changeset(%{status: "active"})
        |> Repo.update()

      _ ->
        {:error, :already_accepted}
    end
  end

  def reject_invitation(member_id) do
    case Repo.get(ProjectMember, member_id) do
      nil ->
        {:error, :not_found}

      %{status: "pending"} = member ->
        member
        |> ProjectMember.changeset(%{status: "removed"})
        |> Repo.update()

      _ ->
        {:error, :not_pending}
    end
  end

  def list_pending_invitations(user_id) do
    ProjectMember
    |> where([m], m.user_id == ^user_id and m.status == "pending")
    |> join(:inner, [m], p in Project, on: p.id == m.project_id)
    |> select([m, p], %{id: m.id, role: m.role, project_id: p.id, project_name: p.name})
    |> order_by([m], desc: m.inserted_at)
    |> Repo.all()
  end

  def remove_member(member_id) do
    case Repo.get(ProjectMember, member_id) do
      nil ->
        {:error, :not_found}

      %{role: "owner"} ->
        {:error, :cannot_remove_owner}

      member ->
        member
        |> ProjectMember.changeset(%{status: "removed"})
        |> Repo.update()
    end
  end

  def update_member_role(member_id, role) do
    case Repo.get(ProjectMember, member_id) do
      nil ->
        {:error, :not_found}

      member ->
        member
        |> ProjectMember.changeset(%{role: role})
        |> Repo.update()
    end
  end

  def list_members(project_id) do
    ProjectMember
    |> where([m], m.project_id == ^project_id and m.status != "removed")
    |> order_by([m], asc: m.inserted_at)
    |> Repo.all()
  end

  def list_projects_for_member(user_id) do
    ProjectMember
    |> where([m], m.user_id == ^user_id and m.status == "active")
    |> join(:inner, [m], p in Project, on: p.id == m.project_id and p.status == "active")
    |> select([m, p], p)
    |> Repo.all()
  end

  def get_member(id), do: Repo.get(ProjectMember, id)

  def get_member_role(project_id, user_id) do
    ProjectMember
    |> where(
      [m],
      m.project_id == ^project_id and m.user_id == ^user_id and m.status in ["active", "pending"]
    )
    |> select([m], m.role)
    |> Repo.one()
  end

  def user_can_access?(project_id, user_id) do
    from(p in Project,
      where: p.id == ^project_id,
      where:
        p.user_id == ^user_id or
          exists(
            from(m in ProjectMember,
              where:
                m.project_id == ^project_id and m.user_id == ^user_id and m.status == "active"
            )
          )
    )
    |> Repo.exists?()
  end

  def user_can_write?(project_id, user_id) do
    project = Repo.get(Project, project_id)

    cond do
      is_nil(project) ->
        false

      project.user_id == user_id ->
        true

      true ->
        ProjectMember
        |> where(
          [m],
          m.project_id == ^project_id and m.user_id == ^user_id and m.status == "active" and
            m.role in ["owner", "editor"]
        )
        |> Repo.exists?()
    end
  end

  def create_owner_member(project_id, user_id) do
    %ProjectMember{}
    |> ProjectMember.changeset(%{
      project_id: project_id,
      user_id: user_id,
      role: "owner",
      status: "active"
    })
    |> Repo.insert(on_conflict: :nothing)
  end

  def list_all_accessible_projects(user_id) do
    from(p in Project,
      left_join: m in ProjectMember,
      on: m.project_id == p.id and m.user_id == ^user_id and m.status == "active",
      where: p.status == "active",
      where: p.user_id == ^user_id or not is_nil(m.id),
      distinct: true,
      order_by: [desc: p.inserted_at]
    )
    |> Repo.all()
  end
end
