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

  describe "request control fields" do
    test "deliver_at and idempotency_key are not stored in the payload" do
      project = insert(:project)
      deliver_at = DateTime.utc_now() |> DateTime.add(3600) |> DateTime.to_iso8601()

      {:ok, event} =
        Platform.create_event(project.id, %{
          "topic" => "order.created",
          "amount" => 1,
          "deliver_at" => deliver_at,
          "idempotency_key" => "k-1"
        })

      assert event.payload == %{"amount" => 1}
      assert event.idempotency_key == "k-1"
      assert event.deliver_at
    end

    test "deliver_at without offset is interpreted as UTC" do
      project = insert(:project)
      naive = NaiveDateTime.utc_now() |> NaiveDateTime.add(3600) |> NaiveDateTime.to_iso8601()

      {:ok, event} =
        Platform.create_event(project.id, %{"topic" => "t", "deliver_at" => naive})

      assert %DateTime{time_zone: "Etc/UTC"} = event.deliver_at
      assert DateTime.compare(event.deliver_at, DateTime.utc_now()) == :gt
    end
  end

  describe "SDK envelope" do
    test "a {topic, payload} body stores the payload fields, not a nested payload" do
      project = insert(:project)

      {:ok, event} =
        Platform.create_event(project.id, %{
          "topic" => "order.created",
          "payload" => %{"order_id" => "ord_1", "amount" => 10},
          "idempotency_key" => "sdk-1"
        })

      assert event.payload == %{"order_id" => "ord_1", "amount" => 10}
      assert event.idempotency_key == "sdk-1"
    end

    test "schema validation applies to the unwrapped payload" do
      project = insert(:project)

      insert(:event_schema,
        project_id: project.id,
        topic: "payment.completed",
        schema: %{"type" => "object", "required" => ["amount"]}
      )

      assert {:ok, _} =
               Platform.create_event(project.id, %{
                 "topic" => "payment.completed",
                 "payload" => %{"amount" => 5}
               })

      assert {:error, {:schema_validation, _}} =
               Platform.create_event(project.id, %{
                 "topic" => "payment.completed",
                 "payload" => %{"currency" => "USD"}
               })
    end

    test "a payload field next to other fields is kept as a regular field" do
      project = insert(:project)

      {:ok, event} =
        Platform.create_event(project.id, %{
          "topic" => "t",
          "payload" => %{"a" => 1},
          "source" => "api"
        })

      assert event.payload == %{"payload" => %{"a" => 1}, "source" => "api"}
    end

    test "batch items in SDK shape are unwrapped too" do
      project = insert(:project)

      {:ok, %{accepted: 1}} =
        Platform.create_events_batch(project.id, [
          %{"topic" => "order.created", "payload" => %{"order_id" => "ord_2"}}
        ])

      [event] = Platform.list_events(project.id)
      assert event.payload == %{"order_id" => "ord_2"}
    end
  end

  describe "process_delayed_events/0" do
    test "an event matching no webhook is dispatched only once" do
      project = insert(:project)
      past = DateTime.utc_now() |> DateTime.add(-60) |> DateTime.truncate(:microsecond)

      insert(:webhook_event,
        project_id: project.id,
        topic: "nobody.listens",
        deliver_at: past
      )

      assert {:ok, 1} = Platform.process_delayed_events()
      assert {:ok, 0} = Platform.process_delayed_events()
    end

    test "a past deliver_at is dispatched at creation and not picked up again" do
      project = insert(:project)
      past = DateTime.utc_now() |> DateTime.add(-60) |> DateTime.to_iso8601()

      {:ok, event} = Platform.create_event(project.id, %{"topic" => "t", "deliver_at" => past})

      assert event.dispatched_at
      assert {:ok, 0} = Platform.process_delayed_events()
    end
  end

  describe "count_events_since/2" do
    test "counts all recent active events, not just a capped list" do
      project = insert(:project)
      insert_list(25, :webhook_event, project_id: project.id)
      insert(:webhook_event, project_id: project.id, status: "inactive")

      old = DateTime.utc_now() |> DateTime.add(-2, :day) |> DateTime.truncate(:microsecond)
      insert(:webhook_event, project_id: project.id, occurred_at: old)

      since = DateTime.utc_now() |> DateTime.add(-24, :hour)
      assert Platform.count_events_since(project.id, since) == 25
    end
  end

  describe "success_rate_since/2" do
    test "ignores pending deliveries and other projects" do
      project = insert(:project)
      webhook = insert(:webhook, project_id: project.id)
      event = insert(:webhook_event, project_id: project.id)

      for status <- ~w(success success failed pending) do
        insert(:delivery, event_id: event.id, webhook_id: webhook.id, status: status)
      end

      other = insert(:project)
      other_event = insert(:webhook_event, project_id: other.id)
      other_webhook = insert(:webhook, project_id: other.id)
      insert(:delivery, event_id: other_event.id, webhook_id: other_webhook.id, status: "failed")

      since = DateTime.utc_now() |> DateTime.add(-24, :hour)
      assert Platform.success_rate_since(project.id, since) == 66.7
    end
  end
end
