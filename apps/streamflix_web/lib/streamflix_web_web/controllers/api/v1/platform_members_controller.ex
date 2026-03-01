defmodule StreamflixWebWeb.Api.V1.PlatformMembersController do
  use StreamflixWebWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias StreamflixCore.Teams
  alias StreamflixCore.Platform
  alias StreamflixCore.Notifications
  alias StreamflixAccounts

  tags(["Team Members"])
  security([%{"bearer" => []}])

  operation(:index,
    summary: "List project members",
    parameters: [project_id: [in: :path, type: :string, required: true]],
    responses: [ok: {"Members list", "application/json", StreamflixWebWeb.Schemas.MemberList}]
  )

  def index(conn, %{"project_id" => project_id}) do
    user = conn.assigns.current_user

    if Teams.user_can_access?(project_id, user.id) do
      members = Teams.list_members(project_id)
      json(conn, %{data: Enum.map(members, &member_json/1)})
    else
      conn |> put_status(:forbidden) |> json(%{error: "Access denied"})
    end
  end

  operation(:create,
    summary: "Invite a member to a project",
    parameters: [project_id: [in: :path, type: :string, required: true]],
    request_body: {"Invite params", "application/json", StreamflixWebWeb.Schemas.MemberInvite},
    responses: [
      created: {"Member invited", "application/json", StreamflixWebWeb.Schemas.MemberResponse}
    ]
  )

  def create(conn, %{"project_id" => project_id} = params) do
    user = conn.assigns.current_user

    if Teams.user_can_write?(project_id, user.id) do
      user_id =
        case params do
          %{"user_id" => uid} when is_binary(uid) and uid != "" ->
            uid

          %{"email" => email} when is_binary(email) and email != "" ->
            case StreamflixAccounts.get_user_by_email(email) do
              nil -> nil
              u -> u.id
            end

          _ ->
            nil
        end

      if is_nil(user_id) do
        conn
        |> put_status(422)
        |> json(%{error: "User not found. Provide a valid user_id or email."})
      else
        role = params["role"] || "viewer"
        inviter_role = Teams.get_member_role(project_id, user.id)
        is_owner = inviter_role == "owner" || Platform.get_project(project_id).user_id == user.id

        cond do
          user_id == user.id ->
            conn |> put_status(422) |> json(%{error: "Cannot invite yourself"})

          role in ["editor", "owner"] && !is_owner ->
            conn
            |> put_status(:forbidden)
            |> json(%{error: "Only the project owner can invite editors"})

          true ->
            case Teams.invite_member(project_id, user_id, role, user.id) do
              {:ok, member} ->
                Notifications.notify_team_invite(user_id, project_id, role, member.id)

                conn
                |> put_status(:created)
                |> json(%{data: member_json(member)})

              {:error, changeset} ->
                conn
                |> put_status(:unprocessable_entity)
                |> json(%{error: "Invalid invite", details: format_errors(changeset)})
            end
        end
      end
    else
      conn |> put_status(:forbidden) |> json(%{error: "Access denied"})
    end
  end

  operation(:update,
    summary: "Update member role",
    parameters: [
      project_id: [in: :path, type: :string, required: true],
      id: [in: :path, type: :string, required: true]
    ],
    request_body: {"Role params", "application/json", StreamflixWebWeb.Schemas.MemberUpdate},
    responses: [
      ok: {"Member updated", "application/json", StreamflixWebWeb.Schemas.MemberResponse}
    ]
  )

  def update(conn, %{"project_id" => project_id, "id" => id} = params) do
    user = conn.assigns.current_user

    if Teams.user_can_write?(project_id, user.id) do
      role = params["role"]

      case Teams.update_member_role(id, role) do
        {:ok, updated} ->
          json(conn, %{data: member_json(updated)})

        {:error, :not_found} ->
          conn |> put_status(:not_found) |> json(%{error: "Member not found"})

        {:error, _} ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: "Could not update"})
      end
    else
      conn |> put_status(:forbidden) |> json(%{error: "Access denied"})
    end
  end

  operation(:delete,
    summary: "Remove member from project",
    parameters: [
      project_id: [in: :path, type: :string, required: true],
      id: [in: :path, type: :string, required: true]
    ],
    responses: [
      ok: {"Member removed", "application/json", StreamflixWebWeb.Schemas.MemberResponse}
    ]
  )

  def delete(conn, %{"project_id" => project_id, "id" => id}) do
    user = conn.assigns.current_user

    if Teams.user_can_write?(project_id, user.id) do
      case Teams.remove_member(id) do
        {:ok, _} ->
          json(conn, %{ok: true})

        {:error, :cannot_remove_owner} ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: "Cannot remove owner"})

        {:error, :not_found} ->
          conn |> put_status(:not_found) |> json(%{error: "Member not found"})

        {:error, _} ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: "Could not remove"})
      end
    else
      conn |> put_status(:forbidden) |> json(%{error: "Access denied"})
    end
  end

  operation(:pending,
    summary: "List pending invitations for the authenticated user",
    responses: [
      ok: {"Pending invitations", "application/json", StreamflixWebWeb.Schemas.MemberList}
    ]
  )

  def pending(conn, _params) do
    user = conn.assigns.current_user
    invitations = Teams.list_pending_invitations(user.id)
    json(conn, %{data: invitations})
  end

  operation(:accept,
    summary: "Accept a pending invitation",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Invitation accepted", "application/json", StreamflixWebWeb.Schemas.MemberResponse}
    ]
  )

  def accept(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Teams.get_member(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Invitation not found"})

      member ->
        if member.user_id == user.id do
          case Teams.accept_invitation(id) do
            {:ok, updated} ->
              json(conn, %{data: member_json(updated)})

            {:error, :already_accepted} ->
              conn |> put_status(:unprocessable_entity) |> json(%{error: "Already accepted"})

            {:error, _} ->
              conn |> put_status(:unprocessable_entity) |> json(%{error: "Could not accept"})
          end
        else
          conn |> put_status(:forbidden) |> json(%{error: "Access denied"})
        end
    end
  end

  operation(:reject,
    summary: "Reject a pending invitation",
    parameters: [id: [in: :path, type: :string, required: true]],
    responses: [
      ok: {"Invitation rejected", "application/json", StreamflixWebWeb.Schemas.MemberResponse}
    ]
  )

  def reject(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Teams.get_member(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Invitation not found"})

      member ->
        if member.user_id == user.id do
          case Teams.reject_invitation(id) do
            {:ok, updated} ->
              json(conn, %{data: member_json(updated)})

            {:error, :not_pending} ->
              conn |> put_status(:unprocessable_entity) |> json(%{error: "Not pending"})

            {:error, _} ->
              conn |> put_status(:unprocessable_entity) |> json(%{error: "Could not reject"})
          end
        else
          conn |> put_status(:forbidden) |> json(%{error: "Access denied"})
        end
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
