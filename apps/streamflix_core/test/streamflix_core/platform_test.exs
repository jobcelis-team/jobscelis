defmodule StreamflixCore.PlatformTest do
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
    end

    test "rejects invalid payload" do
      project = insert(:project)
      assert {:error, _} = Platform.create_event(project.id, "not a map")
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
  end

  describe "create_webhook/2" do
    test "creates a webhook with valid data" do
      project = insert(:project)

      attrs = %{
        url: "https://example.com/webhook",
        topics: ["order.created"]
      }

      assert {:ok, webhook} = Platform.create_webhook(project.id, attrs)
      assert webhook.url == "https://example.com/webhook"
      assert webhook.status == "active"
    end

    test "rejects webhook without URL" do
      project = insert(:project)
      assert {:error, changeset} = Platform.create_webhook(project.id, %{})
      assert %{url: _} = errors_on(changeset)
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
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
