defmodule StreamflixCore.Platform.DeadLettersTest do
  use StreamflixCore.DataCase, async: true

  alias StreamflixCore.Platform

  describe "create_dead_letter/1" do
    test "creates a dead letter entry" do
      project = insert(:project)

      attrs = %{
        project_id: project.id,
        original_payload: %{"order_id" => 123},
        last_error: "Connection refused",
        last_response_status: 500,
        attempts_exhausted: 5
      }

      assert {:ok, dl} = Platform.create_dead_letter(attrs)
      assert dl.original_payload == %{"order_id" => 123}
      assert dl.resolved == false
    end
  end

  describe "list_dead_letters/2" do
    test "lists unresolved dead letters" do
      project = insert(:project)
      insert(:dead_letter, project_id: project.id, resolved: false)
      insert(:dead_letter, project_id: project.id, resolved: true)

      dead_letters = Platform.list_dead_letters(project.id)
      assert length(dead_letters) == 1
      refute hd(dead_letters).resolved
    end

    test "lists resolved dead letters when requested" do
      project = insert(:project)
      insert(:dead_letter, project_id: project.id, resolved: false)
      insert(:dead_letter, project_id: project.id, resolved: true)

      dead_letters = Platform.list_dead_letters(project.id, resolved: true)
      assert length(dead_letters) == 1
      assert hd(dead_letters).resolved
    end
  end

  describe "resolve_dead_letter/1" do
    test "marks a dead letter as resolved" do
      project = insert(:project)
      dl = insert(:dead_letter, project_id: project.id, resolved: false)

      assert {:ok, updated} = Platform.resolve_dead_letter(dl.id)
      assert updated.resolved == true
      assert updated.resolved_at != nil
    end

    test "returns error for non-existent id" do
      assert {:error, :not_found} = Platform.resolve_dead_letter(Ecto.UUID.generate())
    end
  end

  describe "retry_dead_letter/1" do
    test "creates new delivery and resolves dead letter" do
      project = insert(:project)
      event = insert(:webhook_event, project_id: project.id)
      webhook = insert(:webhook, project_id: project.id, status: "active")

      dl =
        insert(:dead_letter,
          project_id: project.id,
          event_id: event.id,
          webhook_id: webhook.id,
          resolved: false
        )

      # Use manual mode to prevent Oban from executing the worker inline
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, delivery} = Platform.retry_dead_letter(dl.id)
        assert delivery.status == "pending"
        assert delivery.event_id == event.id
        assert delivery.webhook_id == webhook.id

        # Dead letter should be resolved
        updated_dl = Platform.get_dead_letter(dl.id)
        assert updated_dl.resolved == true
      end)
    end

    test "returns error when webhook is inactive" do
      project = insert(:project)
      event = insert(:webhook_event, project_id: project.id)
      webhook = insert(:webhook, project_id: project.id, status: "inactive")

      dl =
        insert(:dead_letter,
          project_id: project.id,
          event_id: event.id,
          webhook_id: webhook.id
        )

      assert {:error, :webhook_inactive} = Platform.retry_dead_letter(dl.id)
    end

    test "returns error for non-existent id" do
      assert {:error, :not_found} = Platform.retry_dead_letter(Ecto.UUID.generate())
    end
  end
end
