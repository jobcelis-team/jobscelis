defmodule StreamflixCore.Platform.ReplaysTest do
  use StreamflixCore.DataCase, async: true

  alias StreamflixCore.Platform

  describe "create_replay/3" do
    test "creates a replay with event count" do
      project = insert(:project)
      user_id = Ecto.UUID.generate()
      insert(:webhook_event, project_id: project.id, topic: "order.created")
      insert(:webhook_event, project_id: project.id, topic: "order.created")

      filters = %{"topic" => "order.created"}
      assert {:ok, replay} = Platform.create_replay(project.id, user_id, filters)
      assert replay.status == "pending"
      assert replay.total_events == 2
      assert replay.filters == filters
    end

    test "counts zero events when no match" do
      project = insert(:project)
      user_id = Ecto.UUID.generate()

      filters = %{"topic" => "nonexistent"}
      assert {:ok, replay} = Platform.create_replay(project.id, user_id, filters)
      assert replay.total_events == 0
    end
  end

  describe "list_replays/2" do
    test "lists replays for a project" do
      project = insert(:project)
      insert(:replay, project_id: project.id)
      insert(:replay, project_id: project.id)

      replays = Platform.list_replays(project.id)
      assert length(replays) == 2
    end
  end

  describe "cancel_replay/1" do
    test "cancels a pending replay" do
      project = insert(:project)
      replay = insert(:replay, project_id: project.id, status: "pending")

      assert {:ok, updated} = Platform.cancel_replay(replay.id)
      assert updated.status == "cancelled"
    end

    test "cancels a running replay" do
      project = insert(:project)
      replay = insert(:replay, project_id: project.id, status: "running")

      assert {:ok, updated} = Platform.cancel_replay(replay.id)
      assert updated.status == "cancelled"
    end

    test "returns error for already finished replay" do
      project = insert(:project)
      replay = insert(:replay, project_id: project.id, status: "completed")

      assert {:error, :already_finished} = Platform.cancel_replay(replay.id)
    end

    test "returns error for non-existent id" do
      assert {:error, :not_found} = Platform.cancel_replay(Ecto.UUID.generate())
    end
  end
end
