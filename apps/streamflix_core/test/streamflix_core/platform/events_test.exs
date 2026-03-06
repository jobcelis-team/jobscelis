defmodule StreamflixCore.Platform.EventsTest do
  use StreamflixCore.DataCase, async: true

  alias StreamflixCore.Platform

  describe "create_event/2" do
    test "creates an event with valid data" do
      project = insert(:project)
      payload = %{"topic" => "order.created", "amount" => 100}

      assert {:ok, event} = Platform.create_event(project.id, payload)
      assert event.topic == "order.created"
      assert event.payload == %{"amount" => 100}
      assert event.project_id == project.id
      assert event.status == "active"
      assert event.payload_hash != nil
    end

    test "rejects non-map payload" do
      project = insert(:project)
      assert {:error, :invalid_payload} = Platform.create_event(project.id, "not a map")
    end

    test "creates event with nil topic when none provided" do
      project = insert(:project)
      payload = %{"amount" => 100}

      assert {:ok, event} = Platform.create_event(project.id, payload)
      assert event.topic == nil
    end

    test "idempotency: returns existing event for same key" do
      project = insert(:project)

      payload = %{
        "topic" => "order.created",
        "amount" => 100,
        "idempotency_key" => "unique-key-123"
      }

      assert {:ok, event1} = Platform.create_event(project.id, payload)
      assert {:ok, event2} = Platform.create_event(project.id, payload)
      assert event1.id == event2.id
    end

    test "different idempotency keys create different events" do
      project = insert(:project)

      assert {:ok, e1} =
               Platform.create_event(project.id, %{
                 "topic" => "test",
                 "idempotency_key" => "key-1"
               })

      assert {:ok, e2} =
               Platform.create_event(project.id, %{
                 "topic" => "test",
                 "idempotency_key" => "key-2"
               })

      assert e1.id != e2.id
    end

    test "creates event with deliver_at for delayed delivery" do
      project = insert(:project)
      future = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_iso8601()

      payload = %{"topic" => "test.delayed", "deliver_at" => future}

      assert {:ok, event} = Platform.create_event(project.id, payload)
      assert event.deliver_at != nil
    end

    test "schema validation rejects invalid payload" do
      project = insert(:project)

      insert(:event_schema,
        project_id: project.id,
        topic: "order.created",
        schema: %{
          "type" => "object",
          "properties" => %{"name" => %{"type" => "string"}},
          "required" => ["name"]
        }
      )

      # Missing required "name" field
      assert {:error, {:schema_validation, _}} =
               Platform.create_event(project.id, %{
                 "topic" => "order.created",
                 "amount" => 100
               })
    end

    test "schema validation passes for valid payload" do
      project = insert(:project)

      insert(:event_schema,
        project_id: project.id,
        topic: "order.created",
        schema: %{
          "type" => "object",
          "properties" => %{"name" => %{"type" => "string"}},
          "required" => ["name"]
        }
      )

      assert {:ok, _event} =
               Platform.create_event(project.id, %{
                 "topic" => "order.created",
                 "name" => "Test Order"
               })
    end

    test "computes payload_hash as SHA256" do
      project = insert(:project)

      assert {:ok, event} =
               Platform.create_event(project.id, %{"topic" => "test", "data" => "value"})

      expected_hash =
        :crypto.hash(:sha256, Jason.encode!(%{"data" => "value"}))
        |> Base.encode16(case: :lower)

      assert event.payload_hash == expected_hash
    end
  end

  describe "list_events/2" do
    test "lists events for a project" do
      project = insert(:project)
      insert(:webhook_event, project_id: project.id, topic: "a")
      insert(:webhook_event, project_id: project.id, topic: "b")

      events = Platform.list_events(project.id)
      assert length(events) == 2
    end

    test "filters by topic" do
      project = insert(:project)
      insert(:webhook_event, project_id: project.id, topic: "order.created")
      insert(:webhook_event, project_id: project.id, topic: "user.signup")

      events = Platform.list_events(project.id, topic: "order.created")
      assert length(events) == 1
      assert hd(events).topic == "order.created"
    end

    test "excludes inactive events by default" do
      project = insert(:project)
      insert(:webhook_event, project_id: project.id, status: "active")
      insert(:webhook_event, project_id: project.id, status: "inactive")

      events = Platform.list_events(project.id)
      assert length(events) == 1
    end

    test "includes inactive events when requested" do
      project = insert(:project)
      insert(:webhook_event, project_id: project.id, status: "active")
      insert(:webhook_event, project_id: project.id, status: "inactive")

      events = Platform.list_events(project.id, include_inactive: true)
      assert length(events) == 2
    end

    test "respects limit option" do
      project = insert(:project)
      for _ <- 1..5, do: insert(:webhook_event, project_id: project.id)

      events = Platform.list_events(project.id, limit: 3)
      assert length(events) == 3
    end

    test "does not include events from other projects" do
      project1 = insert(:project)
      project2 = insert(:project)
      insert(:webhook_event, project_id: project1.id)
      insert(:webhook_event, project_id: project2.id)

      events = Platform.list_events(project1.id)
      assert length(events) == 1
    end
  end

  describe "get_event/1" do
    test "returns event by id" do
      project = insert(:project)
      event = insert(:webhook_event, project_id: project.id)

      assert Platform.get_event(event.id).id == event.id
    end

    test "returns nil for non-existent id" do
      assert Platform.get_event(Ecto.UUID.generate()) == nil
    end
  end

  describe "set_event_inactive/1" do
    test "soft deletes an event" do
      project = insert(:project)
      event = insert(:webhook_event, project_id: project.id, status: "active")

      assert {:ok, updated} = Platform.set_event_inactive(event)
      assert updated.status == "inactive"
    end
  end

  describe "list_topics_used/1" do
    test "returns distinct topics" do
      project = insert(:project)
      insert(:webhook_event, project_id: project.id, topic: "order.created")
      insert(:webhook_event, project_id: project.id, topic: "order.created")
      insert(:webhook_event, project_id: project.id, topic: "user.signup")

      topics = Platform.list_topics_used(project.id)
      assert length(topics) == 2
      assert "order.created" in topics
      assert "user.signup" in topics
    end

    test "excludes inactive events" do
      project = insert(:project)
      insert(:webhook_event, project_id: project.id, topic: "active.topic", status: "active")
      insert(:webhook_event, project_id: project.id, topic: "inactive.topic", status: "inactive")

      topics = Platform.list_topics_used(project.id)
      assert topics == ["active.topic"]
    end
  end
end
