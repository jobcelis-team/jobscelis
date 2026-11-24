defmodule StreamflixCore.Platform.AuditRegressionsTest do
  @moduledoc "Regression tests for findings of the 2026-11 security audit."
  use StreamflixCore.DataCase, async: false

  alias StreamflixCore.Platform
  alias StreamflixCore.Platform.{DeadLetters, Webhooks}
  alias StreamflixCore.Schemas.{Delivery, Project, WebhookEvent}

  defp webhook!(project, attrs \\ %{}) do
    {:ok, webhook} =
      Webhooks.create_webhook(
        project.id,
        Map.merge(%{"url" => "https://example.com/hook", "topics" => ["*"]}, attrs)
      )

    webhook
  end

  describe "webhook filters" do
    test "a payload whose shape differs from the filter path is stored, not crashed" do
      project = insert(:project)
      webhook!(project, %{"filters" => [%{"path" => "user.id", "op" => "eq", "value" => 1}]})

      assert {:ok, _} =
               Platform.create_event(project.id, %{
                 "topic" => "order.created",
                 "payload" => %{"user" => "bob"}
               })

      assert Repo.aggregate(from(e in WebhookEvent, where: e.project_id == ^project.id), :count) ==
               1
    end

    test "nested paths still match" do
      assert Webhooks.filters_match?(
               [%{"path" => "user.id", "op" => "eq", "value" => 1}],
               "t",
               %{"user" => %{"id" => 1}}
             )

      refute Webhooks.filters_match?(
               [%{"path" => "user.id", "op" => "eq", "value" => 1}],
               "t",
               %{"user" => [1, 2]}
             )
    end
  end

  describe "webhook rate_limit and retry_config validation" do
    test "rejects values that throttled forever or crashed the backoff" do
      project = insert(:project)

      for attrs <- [
            %{"rate_limit" => %{"max_per_second" => 0}},
            %{"rate_limit" => %{"max_per_second" => "10"}},
            %{"retry_config" => %{"base_delay_seconds" => "10"}},
            %{"retry_config" => %{"backoff_seconds" => ["x"]}},
            %{"retry_config" => %{"strategy" => "random"}},
            %{"retry_config" => %{"max_attempts" => 1000}}
          ] do
        assert {:error, %Ecto.Changeset{}} =
                 Webhooks.create_webhook(
                   project.id,
                   Map.merge(%{"url" => "https://example.com/h"}, attrs)
                 ),
               "should reject #{inspect(attrs)}"
      end
    end

    test "accepts the documented settings" do
      project = insert(:project)

      assert %{} =
               webhook!(project, %{
                 "rate_limit" => %{"max_per_second" => 5, "max_per_minute" => 100},
                 "retry_config" => %{
                   "strategy" => "linear",
                   "base_delay_seconds" => 30,
                   "max_attempts" => 8,
                   "jitter" => false
                 }
               })

      assert %{} = webhook!(project, %{"retry_config" => %{"backoff_seconds" => [5, 15, 60]}})
    end
  end

  describe "quotas on reactivation" do
    test "a deactivated webhook cannot be reactivated past the quota" do
      project = insert(:project)
      limit = Platform.Quotas.limit(:webhooks)
      [first | _] = for _ <- 1..limit, do: webhook!(project)

      {:ok, first} = Webhooks.set_webhook_inactive(first)
      _replacement = webhook!(project)

      assert {:error, %Ecto.Changeset{}} = Webhooks.update_webhook(first, %{"status" => "active"})
      assert Repo.reload(first).status == "inactive"
    end
  end

  describe "dead letter retry" do
    test "a dead letter is redelivered only once" do
      project = insert(:project)
      webhook = insert(:webhook, project_id: project.id)
      event = insert(:webhook_event, project_id: project.id)

      dl =
        insert(:dead_letter, project_id: project.id, webhook_id: webhook.id, event_id: event.id)

      assert {:ok, _} = DeadLetters.retry_dead_letter(dl.id)
      assert {:error, :already_resolved} = DeadLetters.retry_dead_letter(dl.id)

      assert Repo.aggregate(from(d in Delivery, where: d.webhook_id == ^webhook.id), :count) == 1
    end
  end

  describe "default project" do
    test "a user cannot make another user's project their default" do
      owner = create_test_user()
      other = create_test_user()
      project = insert(:project, user_id: other.id, is_default: false)

      assert {:error, :not_found} = Platform.set_default_project(owner.id, project.id)
      refute Repo.get!(Project, project.id).is_default
      assert {:error, :not_found} = Platform.set_default_project(owner.id, "not-a-uuid")
    end

    test "the owner can" do
      owner = create_test_user()
      project = insert(:project, user_id: owner.id, is_default: false)

      assert {:ok, %{is_default: true}} = Platform.set_default_project(owner.id, project.id)
    end
  end

  describe "purge with stored invalid retention policies" do
    test "does not crash and does not delete fresh data" do
      bad = insert(:project, retention_policy: %{"events_days" => "30", "audit_logs_days" => -1})
      event = insert(:webhook_event, project_id: bad.id)

      assert :ok = Platform.ObanPurgeWorker.perform(%Oban.Job{args: %{}})
      assert Repo.get(WebhookEvent, event.id)
    end
  end

  describe "pagination" do
    test "a cursor whose row was purged gives an empty page, not page 1 again" do
      project = insert(:project)
      insert(:webhook_event, project_id: project.id)

      page =
        StreamflixCore.Platform.Pagination.paginate_events(project.id,
          cursor: Ecto.UUID.generate()
        )

      assert page.data == []
      refute page.has_next
    end

    test "list-valued filters are ignored instead of raising" do
      project = insert(:project)

      assert %{data: _} =
               StreamflixCore.Platform.Pagination.paginate_events(project.id, topic: ["x"])
    end
  end

  describe "DLQ notifications" do
    test "only one notice per webhook in the throttle window" do
      user = create_test_user()
      project = insert(:project, user_id: user.id)

      assert {:ok, %{}} =
               StreamflixCore.Notifications.notify_dlq_entry(
                 user.id,
                 project.id,
                 "https://x.test"
               )

      assert {:ok, :throttled} =
               StreamflixCore.Notifications.notify_dlq_entry(
                 user.id,
                 project.id,
                 "https://x.test"
               )
    end
  end
end
