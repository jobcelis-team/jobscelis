defmodule StreamflixCore.Platform.ObanReplayWorkerTest do
  @moduledoc """
  Tests for the ObanReplayWorker: event replay processing.
  """
  use StreamflixCore.DataCase, async: false

  alias StreamflixCore.Platform.ObanReplayWorker

  setup do
    user = create_test_user()
    project = insert(:project, user_id: user.id)
    webhook = insert(:webhook, project_id: project.id, status: "active", topics: ["*"])
    %{project: project, webhook: webhook, user: user}
  end

  describe "perform/1" do
    test "non-existent replay returns :ok" do
      job = %Oban.Job{args: %{"replay_id" => Ecto.UUID.generate()}}
      assert :ok = ObanReplayWorker.perform(job)
    end

    test "cancelled replay is skipped", %{project: project} do
      replay =
        insert(:replay,
          project_id: project.id,
          status: "cancelled",
          filters: %{"topic" => "test"}
        )

      job = %Oban.Job{args: %{"replay_id" => replay.id}}
      assert :ok = ObanReplayWorker.perform(job)

      updated = Repo.get(StreamflixCore.Schemas.Replay, replay.id)
      assert updated.status == "cancelled"
    end

    test "replay with no matching events completes with 0 processed", %{project: project} do
      replay =
        insert(:replay,
          project_id: project.id,
          status: "pending",
          filters: %{"topic" => "nonexistent.topic"},
          total_events: 0
        )

      Oban.Testing.with_testing_mode(:manual, fn ->
        job = %Oban.Job{args: %{"replay_id" => replay.id}}
        assert :ok = ObanReplayWorker.perform(job)
      end)

      updated = Repo.get(StreamflixCore.Schemas.Replay, replay.id)
      assert updated.status == "completed"
      assert updated.processed_events == 0
    end

    test "replay processes events and creates deliveries", %{project: project} do
      # Use topics: [] (empty = match all) to ensure webhook matches
      insert(:webhook, project_id: project.id, status: "active", topics: [])
      insert(:webhook_event, project_id: project.id, topic: "user.created")
      insert(:webhook_event, project_id: project.id, topic: "user.created")

      replay =
        insert(:replay,
          project_id: project.id,
          status: "pending",
          filters: %{"topic" => "user.created"},
          total_events: 2
        )

      Oban.Testing.with_testing_mode(:manual, fn ->
        job = %Oban.Job{args: %{"replay_id" => replay.id}}
        assert :ok = ObanReplayWorker.perform(job)
      end)

      updated = Repo.get(StreamflixCore.Schemas.Replay, replay.id)
      assert updated.status == "completed"
      assert updated.processed_events == 2

      # Verify deliveries were created
      deliveries =
        StreamflixCore.Schemas.Delivery
        |> Ecto.Query.where([d], d.status == "pending")
        |> Repo.all()

      assert length(deliveries) >= 2
    end
  end
end
