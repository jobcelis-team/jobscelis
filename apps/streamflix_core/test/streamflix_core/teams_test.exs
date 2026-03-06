defmodule StreamflixCore.TeamsTest do
  use StreamflixCore.DataCase

  alias StreamflixCore.Teams

  setup do
    user = create_test_user()
    user2 = create_test_user()
    project = insert(:project, user_id: user.id)
    %{user: user, user2: user2, project: project}
  end

  describe "invite_member/4" do
    test "creates a pending invitation", %{project: project, user2: user2, user: user} do
      assert {:ok, member} =
               Teams.invite_member(project.id, user2.id, "editor", user.id)

      assert member.status == "pending"
      assert member.role == "editor"
      assert member.invited_by == user.id
    end

    test "defaults to viewer role", %{project: project, user2: user2} do
      assert {:ok, member} = Teams.invite_member(project.id, user2.id)
      assert member.role == "viewer"
    end
  end

  describe "accept_invitation/1" do
    test "activates a pending invitation", %{project: project, user2: user2} do
      {:ok, member} = Teams.invite_member(project.id, user2.id)
      assert {:ok, updated} = Teams.accept_invitation(member.id)
      assert updated.status == "active"
    end

    test "returns error for already accepted", %{project: project, user2: user2} do
      {:ok, member} = Teams.invite_member(project.id, user2.id)
      {:ok, _} = Teams.accept_invitation(member.id)
      assert {:error, :already_accepted} = Teams.accept_invitation(member.id)
    end

    test "returns error for not found" do
      assert {:error, :not_found} = Teams.accept_invitation(Ecto.UUID.generate())
    end
  end

  describe "reject_invitation/1" do
    test "marks invitation as removed", %{project: project, user2: user2} do
      {:ok, member} = Teams.invite_member(project.id, user2.id)
      assert {:ok, updated} = Teams.reject_invitation(member.id)
      assert updated.status == "removed"
    end

    test "returns error if not pending", %{project: project, user2: user2} do
      {:ok, member} = Teams.invite_member(project.id, user2.id)
      {:ok, _} = Teams.accept_invitation(member.id)
      assert {:error, :not_pending} = Teams.reject_invitation(member.id)
    end
  end

  describe "remove_member/1" do
    test "removes an editor", %{project: project, user2: user2} do
      {:ok, member} = Teams.invite_member(project.id, user2.id, "editor")
      {:ok, _} = Teams.accept_invitation(member.id)
      assert {:ok, removed} = Teams.remove_member(member.id)
      assert removed.status == "removed"
    end

    test "cannot remove owner", %{project: project, user: user} do
      {:ok, owner} = Teams.create_owner_member(project.id, user.id)
      assert {:error, :cannot_remove_owner} = Teams.remove_member(owner.id)
    end
  end

  describe "update_member_role/2" do
    test "changes role", %{project: project, user2: user2} do
      {:ok, member} = Teams.invite_member(project.id, user2.id, "viewer")
      assert {:ok, updated} = Teams.update_member_role(member.id, "editor")
      assert updated.role == "editor"
    end
  end

  describe "list_members/1" do
    test "lists non-removed members", %{project: project, user: user, user2: user2} do
      {:ok, _} = Teams.create_owner_member(project.id, user.id)
      {:ok, member} = Teams.invite_member(project.id, user2.id)
      {:ok, _} = Teams.accept_invitation(member.id)

      members = Teams.list_members(project.id)
      assert length(members) == 2
    end
  end

  describe "access checks" do
    test "owner can access project", %{project: project, user: user} do
      assert Teams.user_can_access?(project.id, user.id)
    end

    test "active member can access project", %{project: project, user2: user2} do
      {:ok, member} = Teams.invite_member(project.id, user2.id)
      {:ok, _} = Teams.accept_invitation(member.id)
      assert Teams.user_can_access?(project.id, user2.id)
    end

    test "owner can write", %{project: project, user: user} do
      assert Teams.user_can_write?(project.id, user.id)
    end

    test "viewer cannot write", %{project: project, user2: user2} do
      {:ok, member} = Teams.invite_member(project.id, user2.id, "viewer")
      {:ok, _} = Teams.accept_invitation(member.id)
      refute Teams.user_can_write?(project.id, user2.id)
    end

    test "editor can write", %{project: project, user2: user2} do
      {:ok, member} = Teams.invite_member(project.id, user2.id, "editor")
      {:ok, _} = Teams.accept_invitation(member.id)
      assert Teams.user_can_write?(project.id, user2.id)
    end
  end

  describe "list_pending_invitations/1" do
    test "returns pending invitations for user", %{project: project, user2: user2} do
      {:ok, _} = Teams.invite_member(project.id, user2.id, "editor")
      invitations = Teams.list_pending_invitations(user2.id)
      assert length(invitations) == 1
      assert hd(invitations).role == "editor"
    end
  end

  describe "get_member_role/2" do
    test "returns role for active member", %{project: project, user2: user2} do
      {:ok, member} = Teams.invite_member(project.id, user2.id, "editor")
      {:ok, _} = Teams.accept_invitation(member.id)
      assert "editor" = Teams.get_member_role(project.id, user2.id)
    end

    test "returns nil for non-member", %{project: project} do
      assert is_nil(Teams.get_member_role(project.id, Ecto.UUID.generate()))
    end
  end
end
