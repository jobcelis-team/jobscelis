defmodule StreamflixCore.Platform.SilentFailuresTest do
  use StreamflixCore.DataCase, async: false

  alias StreamflixCore.Platform
  alias StreamflixCore.Platform.ObanBatchWorker
  alias StreamflixCore.Schemas.{BatchItem, Delivery}

  describe "batch deliveries" do
    test "a flushed batch carries every event, not just the first" do
      project = insert(:project)

      webhook =
        insert(:webhook,
          project_id: project.id,
          batch_config: %{"enabled" => true, "window_seconds" => 0, "max_batch_size" => 10}
        )

      events = for _ <- 1..3, do: insert(:webhook_event, project_id: project.id)
      for e <- events, do: insert(:batch_item, webhook_id: webhook.id, event_id: e.id)

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert :ok = ObanBatchWorker.perform(%Oban.Job{})
      end)

      [delivery] = Repo.all(from(d in Delivery, where: d.webhook_id == ^webhook.id))
      event = Repo.get(StreamflixCore.Schemas.WebhookEvent, delivery.event_id)
      body = Platform.delivery_body(webhook, event, delivery.payload_override)

      assert %{"batch" => true, "batch_size" => 3, "events" => sent} = body
      assert Enum.sort(Enum.map(sent, & &1["event_id"])) == Enum.sort(Enum.map(events, & &1.id))
      assert Repo.aggregate(BatchItem, :count) == 0
    end
  end

  describe "retries" do
    test "a successful delivery is not re-sent" do
      project = insert(:project)
      webhook = insert(:webhook, project_id: project.id)
      event = insert(:webhook_event, project_id: project.id)
      d = insert(:delivery, event_id: event.id, webhook_id: webhook.id, status: "success")

      assert {:error, :already_succeeded} = Platform.retry_delivery(project.id, d.id)
      assert {:error, :not_found} = Platform.retry_delivery(project.id, "garbage")
    end

    test "a manual retry replaces an already scheduled automatic retry" do
      project = insert(:project)
      webhook = insert(:webhook, project_id: project.id)
      event = insert(:webhook_event, project_id: project.id)
      d = insert(:delivery, event_id: event.id, webhook_id: webhook.id, status: "failed")

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, _} =
          %{delivery_id: d.id}
          |> StreamflixCore.Platform.ObanDeliveryWorker.new(schedule_in: 600)
          |> Oban.insert()

        assert {:ok, _} = Platform.retry_delivery(project.id, d.id)

        states =
          Repo.all(
            from(j in Oban.Job,
              where: fragment("?->>'delivery_id' = ?", j.args, ^d.id),
              select: j.state
            )
          )

        assert Enum.sort(states) == ["available", "cancelled"]
      end)
    end

    test "a delivery dead-lettered twice keeps a single open entry" do
      project = insert(:project)
      webhook = insert(:webhook, project_id: project.id)
      event = insert(:webhook_event, project_id: project.id)
      d = insert(:delivery, event_id: event.id, webhook_id: webhook.id, status: "failed")

      attrs = %{
        project_id: project.id,
        delivery_id: d.id,
        event_id: event.id,
        webhook_id: webhook.id,
        original_payload: %{},
        last_error: "boom",
        attempts_exhausted: 5
      }

      {:ok, first} = Platform.create_dead_letter(attrs)
      {:ok, second} = Platform.create_dead_letter(%{attrs | last_error: "boom again"})

      assert first.id == second.id
      assert second.last_error == "boom again"
    end

    test "a dead letter retried with a modified payload sends that payload" do
      project = insert(:project)
      webhook = insert(:webhook, project_id: project.id)
      event = insert(:webhook_event, project_id: project.id)
      d = insert(:delivery, event_id: event.id, webhook_id: webhook.id, status: "failed")

      dl =
        insert(:dead_letter,
          project_id: project.id,
          event_id: event.id,
          webhook_id: webhook.id,
          delivery_id: d.id
        )

      Oban.Testing.with_testing_mode(:manual, fn ->
        assert {:ok, delivery} = Platform.retry_dead_letter(dl.id, %{"fixed" => true})
        assert delivery.payload_override == %{"fixed" => true}
        assert {:error, :invalid_payload} = Platform.retry_dead_letter(dl.id, "nope")
      end)
    end
  end

  describe "event ingestion" do
    test "an unparseable deliver_at is rejected instead of delivering immediately" do
      project = insert(:project)

      assert {:error, :invalid_deliver_at} =
               Platform.create_event(project.id, %{"topic" => "a", "deliver_at" => "tomorrow"})

      assert {:error, :invalid_deliver_at} =
               Platform.create_event(project.id, %{"topic" => "a", "deliver_at" => 123})
    end

    test "a non-string idempotency key is rejected, not a crash" do
      project = insert(:project)

      assert {:error, :invalid_idempotency_key} =
               Platform.create_event(project.id, %{"topic" => "a", "idempotency_key" => 42})
    end
  end

  describe "pagination input" do
    test "malformed cursors and ids return an empty page instead of crashing" do
      project = insert(:project)
      insert(:webhook_event, project_id: project.id)

      assert %{data: []} = Platform.paginate_events(project.id, cursor: "abc")
      assert %{data: []} = Platform.paginate_deliveries(project_id: project.id, cursor: "abc")
      assert %{data: []} = Platform.paginate_deliveries(project_id: project.id, webhook_id: "x")
      assert %{data: [_]} = Platform.paginate_events(project.id, limit: -5)
    end
  end

  describe "api key regeneration" do
    test "the old key stops working at once, other cache entries survive" do
      project = insert(:project)
      {:ok, _key, raw} = Platform.create_api_key(project.id, %{name: "Default"})

      # Warm the cache
      assert Platform.verify_api_key(nil, raw)
      Cachex.put(:platform_cache, {:unrelated, 1}, :kept)

      {:ok, _new, _raw} = Platform.regenerate_api_key(project.id)

      refute Platform.verify_api_key(nil, raw)
      assert {:ok, :kept} = Cachex.get(:platform_cache, {:unrelated, 1})
    end
  end
end
