defmodule StreamflixWebWeb.Api.V1.PlatformMembersController do
  use StreamflixWebWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias StreamflixCore.Teams
  alias StreamflixCore.Notifications

  tags ["Team Members"]
  security [%{"bearer" => []}]

  operation :index,
    summary: "List project members",
    parameters: [project_id: [in: :path, type: :string, required: true]],
    responses: [ok: {"Members list", "application/json", StreamflixWebWeb.Schemas.MemberList}]

  def index(conn, %{"project_id" => project_id}) do
    user = conn.assigns.current_user

    if Teams.user_can_access?(project_id, user.id) do
      members = Teams.list_members(project_id)
      json(conn, %{data: Enum.map(members, &member_json/1)})
    else
      conn |> put_status(:forbidden) |> json(%{error: "Access denied"})
    end
  end

  operation :create,
    summary: "Invite a member to a project",
    parameters: [project_id: [in: :path, type: :string, required: true]],
    request_body: {"Invite params", "application/json", StreamflixWebWeb.Schemas.MemberInvite},
    responses: [created: {"Member invited", "application/json", StreamflixWebWeb.Schemas.MemberResponse}]

  def create(conn, %{"project_id" => project_id} = params) do
    user = conn.assigns.current_user

    if Teams.user_can_write?(project_id, user.id) do
      user_id = params["user_id"]
      role = params["role"] || "viewer"

      case Teams.invite_member(project_id, user_id, role, user.id) do
        {:ok, member} ->
          # Notify the invited user
          Notifications.create(%{
            user_id: user_id,
            type: "team_invite",
            title: "Invitación a proyecto",
            message: "Has sido invitado a un proyecto como #{role}.",
            metadata: %{"project_id" => project_id, "member_id" => member.id}
          })

          conn
          |> put_status(:created)
          |> json(%{data: member_json(member)})

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Invalid invite", details: format_errors(changeset)})
      end
    else
      conn |> put_status(:forbidden) |> json(%{error: "Access denied"})
    end
  end

  operation :update,
    summary: "Update member role",
    parameters: [
      project_id: [in: :path, type: :string, required: true],
      id: [in: :path, type: :string, required: true]
    ],
    request_body: {"Role params", "application/json", StreamflixWebWeb.Schemas.MemberUpdate},
    responses: [ok: {"Member updated", "application/json", StreamflixWebWeb.Schemas.MemberResponse}]

  def update(conn, %{"project_id" => project_id, "id" => id} = params) do
    user = conn.assigns.current_user

    if Teams.user_can_write?(project_id, user.id) do
      role = params["role"]

      case Teams.update_member_role(id, role) do
        {:ok, updated} -> json(conn, %{data: member_json(updated)})
        {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "Member not found"})
        {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Could not update"})
      end
    else
      conn |> put_status(:forbidden) |> json(%{error: "Access denied"})
    end
  end

  operation :delete,
    summary: "Remove member from project",
    parameters: [
      project_id: [in: :path, type: :string, required: true],
      id: [in: :path, type: :string, required: true]
    ],
    responses: [ok: {"Member removed", "application/json", StreamflixWebWeb.Schemas.MemberResponse}]

  def delete(conn, %{"project_id" => project_id, "id" => id}) do
    user = conn.assigns.current_user

    if Teams.user_can_write?(project_id, user.id) do
      case Teams.remove_member(id) do
        {:ok, _} -> json(conn, %{ok: true})
        {:error, :cannot_remove_owner} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Cannot remove owner"})
        {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "Member not found"})
        {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Could not remove"})
      end
    else
      conn |> put_status(:forbidden) |> json(%{error: "Access denied"})
    end
  end

  defp member_json(member) do
    %{
      id: member.id,
      project_id: member.project_id,
      user_id: member.user_id,
      role: member.role,
      status: member.status,
      invited_by: member.invited_by,
      inserted_at: member.inserted_at
    }
  end

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp format_errors(_), do: %{}
end
