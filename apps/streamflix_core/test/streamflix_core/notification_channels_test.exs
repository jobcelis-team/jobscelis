defmodule StreamflixCore.NotificationChannelsTest do
  use StreamflixCore.DataCase, async: true

  alias StreamflixCore.NotificationChannels
  alias StreamflixCore.Schemas.NotificationChannel

  setup do
    project = insert(:project)
    {:ok, project: project}
  end

  describe "create/1" do
    test "creates a notification channel with valid attrs", %{project: project} do
      attrs = %{
        project_id: project.id,
        email_enabled: true,
        email_address: "alerts@example.com"
      }

      assert {:ok, %NotificationChannel{} = ch} = NotificationChannels.create(attrs)
      assert ch.project_id == project.id
      assert ch.email_enabled == true
      assert ch.email_address == "alerts@example.com"
      assert ch.slack_enabled == false
      assert ch.discord_enabled == false
      assert ch.meta_webhook_enabled == false
    end

    test "requires email_address when email_enabled is true", %{project: project} do
      attrs = %{project_id: project.id, email_enabled: true}
      assert {:error, changeset} = NotificationChannels.create(attrs)
      assert errors_on(changeset).email_address
    end

    test "requires slack_webhook_url when slack_enabled is true", %{project: project} do
      attrs = %{project_id: project.id, slack_enabled: true}
      assert {:error, changeset} = NotificationChannels.create(attrs)
      assert errors_on(changeset).slack_webhook_url
    end

    test "validates slack URL format", %{project: project} do
      attrs = %{
        project_id: project.id,
        slack_enabled: true,
        slack_webhook_url: "https://example.com/not-slack"
      }

      assert {:error, changeset} = NotificationChannels.create(attrs)
      assert errors_on(changeset).slack_webhook_url
    end

    test "requires discord_webhook_url when discord_enabled is true", %{project: project} do
      attrs = %{project_id: project.id, discord_enabled: true}
      assert {:error, changeset} = NotificationChannels.create(attrs)
      assert errors_on(changeset).discord_webhook_url
    end

    test "requires meta_webhook_url when meta_webhook_enabled is true", %{project: project} do
      attrs = %{project_id: project.id, meta_webhook_enabled: true}
      assert {:error, changeset} = NotificationChannels.create(attrs)
      assert errors_on(changeset).meta_webhook_url
    end

    test "validates event_types contain only valid types", %{project: project} do
      attrs = %{project_id: project.id, event_types: ["invalid_type"]}
      assert {:error, changeset} = NotificationChannels.create(attrs)
      assert errors_on(changeset).event_types
    end

    test "accepts valid event_types", %{project: project} do
      attrs = %{
        project_id: project.id,
        event_types: ["dlq_entry", "circuit_open", "job_failed"]
      }

      assert {:ok, ch} = NotificationChannels.create(attrs)
      assert ch.event_types == ["dlq_entry", "circuit_open", "job_failed"]
    end

    test "enforces unique project_id constraint", %{project: project} do
      attrs = %{project_id: project.id}
      assert {:ok, _} = NotificationChannels.create(attrs)
      assert {:error, changeset} = NotificationChannels.create(attrs)
      assert errors_on(changeset).project_id
    end
  end

  describe "get_by_project/1" do
    test "returns nil when no channel exists", %{project: project} do
      assert NotificationChannels.get_by_project(project.id) == nil
    end

    test "returns the channel for the project", %{project: project} do
      {:ok, ch} = NotificationChannels.create(%{project_id: project.id, email_enabled: false})
      assert NotificationChannels.get_by_project(project.id).id == ch.id
    end
  end

  describe "update/2" do
    test "updates a channel", %{project: project} do
      {:ok, ch} = NotificationChannels.create(%{project_id: project.id})

      assert {:ok, updated} =
               NotificationChannels.update(ch, %{
                 email_enabled: true,
                 email_address: "new@example.com"
               })

      assert updated.email_enabled == true
      assert updated.email_address == "new@example.com"
    end
  end

  describe "delete/1" do
    test "deletes a channel", %{project: project} do
      {:ok, ch} = NotificationChannels.create(%{project_id: project.id})
      assert {:ok, _} = NotificationChannels.delete(ch)
      assert NotificationChannels.get_by_project(project.id) == nil
    end
  end

  describe "upsert/2" do
    test "creates when none exists", %{project: project} do
      assert {:ok, ch} =
               NotificationChannels.upsert(project.id, %{
                 email_enabled: true,
                 email_address: "a@b.com"
               })

      assert ch.email_enabled == true
    end

    test "updates when already exists", %{project: project} do
      {:ok, _} =
        NotificationChannels.create(%{
          project_id: project.id,
          email_enabled: false
        })

      assert {:ok, ch} =
               NotificationChannels.upsert(project.id, %{
                 email_enabled: true,
                 email_address: "a@b.com"
               })

      assert ch.email_enabled == true
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  describe "dispatch/3" do
    test "returns :ok when no channel configured", %{project: project} do
      assert :ok == NotificationChannels.dispatch(project.id, "dlq_entry", %{"message" => "test"})
    end

    test "returns :ok when channel has no enabled channels", %{project: project} do
      {:ok, _} = NotificationChannels.create(%{project_id: project.id})
      assert :ok == NotificationChannels.dispatch(project.id, "dlq_entry", %{"message" => "test"})
    end

    test "enqueues job when channel is configured and event type matches", %{project: project} do
      {:ok, _} =
        NotificationChannels.create(%{
          project_id: project.id,
          meta_webhook_enabled: true,
          meta_webhook_url: "https://example.com/hook"
        })

      assert {:ok, _job} =
               NotificationChannels.dispatch(project.id, "dlq_entry", %{"message" => "test"})
    end

    test "skips when event_type not in filter", %{project: project} do
      {:ok, _} =
        NotificationChannels.create(%{
          project_id: project.id,
          meta_webhook_enabled: true,
          meta_webhook_url: "https://example.com/hook",
          event_types: ["circuit_open"]
        })

      assert :ok ==
               NotificationChannels.dispatch(project.id, "dlq_entry", %{"message" => "test"})
    end
  end
end
