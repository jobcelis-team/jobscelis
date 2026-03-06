defmodule StreamflixCore.Platform.WebhooksTest do
  use StreamflixCore.DataCase, async: true

  alias StreamflixCore.Platform

  describe "create_webhook/2" do
    test "creates a webhook with valid data" do
      project = insert(:project)

      attrs = %{
        "url" => "https://example.com/webhook",
        "topics" => ["order.created"]
      }

      assert {:ok, webhook} = Platform.create_webhook(project.id, attrs)
      assert webhook.url == "https://example.com/webhook"
      assert webhook.status == "active"
      assert webhook.topics == ["order.created"]
    end

    test "rejects webhook without URL" do
      project = insert(:project)
      assert {:error, changeset} = Platform.create_webhook(project.id, %{})
      assert %{url: _} = errors_on(changeset)
    end

    test "creates webhook with default empty topics" do
      project = insert(:project)
      attrs = %{"url" => "https://example.com/hook"}

      assert {:ok, webhook} = Platform.create_webhook(project.id, attrs)
      assert webhook.url == "https://example.com/hook"
    end
  end

  describe "list_webhooks/1" do
    test "lists active webhooks for a project" do
      project = insert(:project)
      insert(:webhook, project_id: project.id, status: "active")
      insert(:webhook, project_id: project.id, status: "inactive")

      webhooks = Platform.list_webhooks(project.id)
      assert length(webhooks) == 1
    end

    test "includes inactive when requested" do
      project = insert(:project)
      insert(:webhook, project_id: project.id, status: "active")
      insert(:webhook, project_id: project.id, status: "inactive")

      webhooks = Platform.list_webhooks(project.id, include_inactive: true)
      assert length(webhooks) == 2
    end
  end

  describe "update_webhook/2" do
    test "updates webhook attributes" do
      project = insert(:project)
      webhook = insert(:webhook, project_id: project.id)

      assert {:ok, updated} = Platform.update_webhook(webhook, %{url: "https://new-url.com/hook"})
      assert updated.url == "https://new-url.com/hook"
    end
  end

  describe "set_webhook_inactive/1" do
    test "soft deletes a webhook" do
      project = insert(:project)
      webhook = insert(:webhook, project_id: project.id, status: "active")

      assert {:ok, updated} = Platform.set_webhook_inactive(webhook)
      assert updated.status == "inactive"
    end
  end

  describe "webhook_matches_event?/2" do
    test "matches when topics list is empty (wildcard)" do
      webhook = %{topics: [], filters: []}
      event = %{topic: "anything", payload: %{}}

      assert Platform.webhook_matches_event?(webhook, event)
    end

    test "matches when event topic is in webhook topics" do
      webhook = %{topics: ["order.created", "order.updated"], filters: []}
      event = %{topic: "order.created", payload: %{}}

      assert Platform.webhook_matches_event?(webhook, event)
    end

    test "does not match when event topic is not in webhook topics" do
      webhook = %{topics: ["order.created"], filters: []}
      event = %{topic: "user.signup", payload: %{}}

      refute Platform.webhook_matches_event?(webhook, event)
    end

    test "matches with eq filter" do
      webhook = %{
        topics: [],
        filters: [%{"path" => "status", "op" => "eq", "value" => "active"}]
      }

      event = %{topic: "test", payload: %{"status" => "active"}}
      assert Platform.webhook_matches_event?(webhook, event)
    end

    test "does not match with failing eq filter" do
      webhook = %{
        topics: [],
        filters: [%{"path" => "status", "op" => "eq", "value" => "active"}]
      }

      event = %{topic: "test", payload: %{"status" => "inactive"}}
      refute Platform.webhook_matches_event?(webhook, event)
    end

    test "matches with gt filter" do
      webhook = %{
        topics: [],
        filters: [%{"path" => "amount", "op" => "gt", "value" => 50}]
      }

      event = %{topic: "test", payload: %{"amount" => 100}}
      assert Platform.webhook_matches_event?(webhook, event)
    end

    test "matches with in filter" do
      webhook = %{
        topics: [],
        filters: [%{"path" => "status", "op" => "in", "value" => ["active", "pending"]}]
      }

      event = %{topic: "test", payload: %{"status" => "active"}}
      assert Platform.webhook_matches_event?(webhook, event)
    end

    test "matches with contains filter on string" do
      webhook = %{
        topics: [],
        filters: [%{"path" => "name", "op" => "contains", "value" => "test"}]
      }

      event = %{topic: "test", payload: %{"name" => "my test project"}}
      assert Platform.webhook_matches_event?(webhook, event)
    end

    test "matches with exists filter" do
      webhook = %{
        topics: [],
        filters: [%{"path" => "email", "op" => "exists", "value" => true}]
      }

      event = %{topic: "test", payload: %{"email" => "test@example.com"}}
      assert Platform.webhook_matches_event?(webhook, event)
    end

    test "requires all filters to match (AND logic)" do
      webhook = %{
        topics: ["order.created"],
        filters: [
          %{"path" => "amount", "op" => "gt", "value" => 50},
          %{"path" => "status", "op" => "eq", "value" => "paid"}
        ]
      }

      # Both match
      event_match = %{topic: "order.created", payload: %{"amount" => 100, "status" => "paid"}}
      assert Platform.webhook_matches_event?(webhook, event_match)

      # Only one matches
      event_partial = %{
        topic: "order.created",
        payload: %{"amount" => 100, "status" => "pending"}
      }

      refute Platform.webhook_matches_event?(webhook, event_partial)
    end

    test "nil event topic does not match non-empty topics list" do
      webhook = %{topics: ["order.created"], filters: []}
      event = %{topic: nil, payload: %{}}

      refute Platform.webhook_matches_event?(webhook, event)
    end
  end

  describe "webhook_templates/0" do
    test "returns all templates" do
      templates = Platform.webhook_templates()
      assert length(templates) >= 4
      ids = Enum.map(templates, & &1.id)
      assert "slack" in ids
      assert "discord" in ids
      assert "generic" in ids
    end
  end

  describe "simulate_event/2" do
    test "returns matching webhooks without sending" do
      project = insert(:project)
      insert(:webhook, project_id: project.id, topics: ["order.created"], status: "active")
      insert(:webhook, project_id: project.id, topics: ["user.signup"], status: "active")

      # Need to clear the cache so list_active_webhooks picks up the inserts
      Cachex.clear(:platform_cache)

      result =
        Platform.simulate_event(project.id, %{"topic" => "order.created", "data" => "test"})

      assert is_list(result)
      assert length(result) == 1
      assert hd(result).webhook_url =~ "example.com"
    end

    test "returns error for non-map payload" do
      assert {:error, :invalid_payload} = Platform.simulate_event("project-id", "bad")
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
