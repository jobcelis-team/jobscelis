defmodule StreamflixCore.Platform.DeliveriesTest do
  use StreamflixCore.DataCase, async: true

  alias StreamflixCore.Platform

  describe "list_deliveries/1" do
    test "lists deliveries for a project" do
      project = insert(:project)
      event = insert(:webhook_event, project_id: project.id)
      webhook = insert(:webhook, project_id: project.id)
      insert(:delivery, event_id: event.id, webhook_id: webhook.id)

      deliveries = Platform.list_deliveries(project_id: project.id)
      assert length(deliveries) == 1
    end

    test "filters by status" do
      project = insert(:project)
      event = insert(:webhook_event, project_id: project.id)
      webhook = insert(:webhook, project_id: project.id)
      insert(:delivery, event_id: event.id, webhook_id: webhook.id, status: "pending")
      insert(:delivery, event_id: event.id, webhook_id: webhook.id, status: "success")

      pending = Platform.list_deliveries(project_id: project.id, status: "pending")
      assert length(pending) == 1
      assert hd(pending).status == "pending"
    end

    test "filters by webhook_id" do
      project = insert(:project)
      event = insert(:webhook_event, project_id: project.id)
      wh1 = insert(:webhook, project_id: project.id)
      wh2 = insert(:webhook, project_id: project.id)
      insert(:delivery, event_id: event.id, webhook_id: wh1.id)
      insert(:delivery, event_id: event.id, webhook_id: wh2.id)

      deliveries = Platform.list_deliveries(webhook_id: wh1.id)
      assert length(deliveries) == 1
    end

    test "respects limit" do
      project = insert(:project)
      event = insert(:webhook_event, project_id: project.id)
      webhook = insert(:webhook, project_id: project.id)
      for _ <- 1..5, do: insert(:delivery, event_id: event.id, webhook_id: webhook.id)

      deliveries = Platform.list_deliveries(project_id: project.id, limit: 3)
      assert length(deliveries) == 3
    end
  end

  describe "get_delivery/1" do
    test "returns delivery by id" do
      project = insert(:project)
      event = insert(:webhook_event, project_id: project.id)
      webhook = insert(:webhook, project_id: project.id)
      delivery = insert(:delivery, event_id: event.id, webhook_id: webhook.id)

      assert Platform.get_delivery(delivery.id).id == delivery.id
    end

    test "returns nil for non-existent id" do
      assert Platform.get_delivery(Ecto.UUID.generate()) == nil
    end
  end

  describe "retry_delivery/2" do
    test "retries a delivery" do
      project = insert(:project)
      event = insert(:webhook_event, project_id: project.id)
      webhook = insert(:webhook, project_id: project.id)

      delivery =
        insert(:delivery,
          event_id: event.id,
          webhook_id: webhook.id,
          status: "failed",
          attempt_number: 3
        )

      # Use manual mode to prevent Oban from executing the worker inline
      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, updated} = Platform.retry_delivery(project.id, delivery.id)
        assert updated.status == "pending"
        assert updated.attempt_number == 4
      end)
    end

    test "returns error for non-existent delivery" do
      assert {:error, :not_found} =
               Platform.retry_delivery(Ecto.UUID.generate(), Ecto.UUID.generate())
    end

    test "returns error when event belongs to different project" do
      project1 = insert(:project)
      project2 = insert(:project)
      event = insert(:webhook_event, project_id: project1.id)
      webhook = insert(:webhook, project_id: project1.id)
      delivery = insert(:delivery, event_id: event.id, webhook_id: webhook.id)

      assert {:error, :not_found} = Platform.retry_delivery(project2.id, delivery.id)
    end
  end

  describe "build_webhook_body/2" do
    test "full mode returns payload with metadata" do
      webhook = %{body_config: %{"body_mode" => "full"}}

      event = %{
        id: "event-123",
        topic: "order.created",
        payload: %{"amount" => 100},
        occurred_at: ~U[2026-03-05 12:00:00Z]
      }

      body = Platform.build_webhook_body(webhook, event)
      assert body["amount"] == 100
      assert body["event_id"] == "event-123"
      assert body["topic"] == "order.created"
    end

    test "pick mode selects specific fields" do
      webhook = %{body_config: %{"body_mode" => "pick", "body_pick" => ["amount", "currency"]}}

      event = %{
        id: "event-123",
        topic: "order.created",
        payload: %{"amount" => 100, "currency" => "USD", "internal_id" => "secret"},
        occurred_at: ~U[2026-03-05 12:00:00Z]
      }

      body = Platform.build_webhook_body(webhook, event)
      assert body["amount"] == 100
      assert body["currency"] == "USD"
      refute Map.has_key?(body, "internal_id")
      assert body["event_id"] == "event-123"
    end

    test "rename mode renames fields" do
      webhook = %{
        body_config: %{
          "body_mode" => "full",
          "body_rename" => %{"amount" => "total_amount"}
        }
      }

      event = %{
        id: "event-123",
        topic: "test",
        payload: %{"amount" => 100},
        occurred_at: ~U[2026-03-05 12:00:00Z]
      }

      body = Platform.build_webhook_body(webhook, event)
      assert body["total_amount"] == 100
      refute Map.has_key?(body, "amount")
    end

    test "extra mode merges additional fields" do
      webhook = %{
        body_config: %{
          "body_mode" => "full",
          "body_extra" => %{"source" => "jobcelis", "version" => "1.0"}
        }
      }

      event = %{
        id: "event-123",
        topic: "test",
        payload: %{"data" => "value"},
        occurred_at: ~U[2026-03-05 12:00:00Z]
      }

      body = Platform.build_webhook_body(webhook, event)
      assert body["source"] == "jobcelis"
      assert body["version"] == "1.0"
      assert body["data"] == "value"
    end

    test "handles nil body_config" do
      webhook = %{body_config: nil}

      event = %{
        id: "event-123",
        topic: "test",
        payload: %{"data" => "value"},
        occurred_at: ~U[2026-03-05 12:00:00Z]
      }

      body = Platform.build_webhook_body(webhook, event)
      assert body["data"] == "value"
      assert body["event_id"] == "event-123"
    end
  end
end
