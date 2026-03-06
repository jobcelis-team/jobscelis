defmodule StreamflixCore.Platform.ProjectsTest do
  use StreamflixCore.DataCase, async: false

  alias StreamflixCore.Platform

  describe "create_project/1" do
    test "creates a project with valid data" do
      user = create_test_user()
      attrs = %{name: "My Project", user_id: user.id}

      assert {:ok, project} = Platform.create_project(attrs)
      assert project.name == "My Project"
      assert project.status == "active"
    end

    test "first project for user is set as default" do
      user = create_test_user()
      attrs = %{name: "First Project", user_id: user.id}

      assert {:ok, project} = Platform.create_project(attrs)
      assert project.is_default == true
    end

    test "subsequent projects are not default" do
      user = create_test_user()
      assert {:ok, _} = Platform.create_project(%{name: "First", user_id: user.id})
      assert {:ok, second} = Platform.create_project(%{name: "Second", user_id: user.id})
      assert second.is_default == false
    end
  end

  describe "list_projects_for_user/2" do
    test "lists active projects for a user" do
      user = create_test_user()
      insert(:project, user_id: user.id, status: "active")
      insert(:project, user_id: user.id, status: "inactive")

      projects = Platform.list_projects_for_user(user.id)
      assert length(projects) == 1
    end

    test "includes inactive when requested" do
      user = create_test_user()
      insert(:project, user_id: user.id, status: "active")
      insert(:project, user_id: user.id, status: "inactive")

      projects = Platform.list_projects_for_user(user.id, include_inactive: true)
      assert length(projects) == 2
    end
  end

  describe "delete_project/1" do
    test "soft deletes a project" do
      project = insert(:project, status: "active")

      assert {:ok, updated} = Platform.delete_project(project)
      assert updated.status == "inactive"
    end

    test "promotes next project to default when default is deleted" do
      user = create_test_user()
      first = insert(:project, user_id: user.id, is_default: true, status: "active")
      second = insert(:project, user_id: user.id, is_default: false, status: "active")

      assert {:ok, _} = Platform.delete_project(first)

      updated_second = Platform.get_project(second.id)
      assert updated_second.is_default == true
    end
  end

  describe "update_project/2" do
    test "updates project name" do
      project = insert(:project)

      assert {:ok, updated} = Platform.update_project(project, %{name: "New Name"})
      assert updated.name == "New Name"
    end
  end

  describe "get_project/1" do
    test "returns project by id" do
      project = insert(:project)
      assert Platform.get_project(project.id).id == project.id
    end

    test "returns nil for non-existent id" do
      assert Platform.get_project(Ecto.UUID.generate()) == nil
    end
  end
end
