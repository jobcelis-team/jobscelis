defmodule StreamflixCore.Platform.QuotasTest do
  use StreamflixCore.DataCase, async: false

  alias StreamflixCore.Platform
  alias StreamflixCore.Platform.{EventRateLimit, Quotas}

  setup do
    previous = Application.get_env(:streamflix_core, :quotas)

    Application.put_env(:streamflix_core, :quotas,
      webhooks_per_project: 2,
      jobs_per_project: 1,
      pipelines_per_project: 1,
      sandbox_endpoints_per_project: 1,
      embed_tokens_per_project: 1,
      event_schemas_per_project: 1,
      projects_per_user: 1
    )

    on_exit(fn -> Application.put_env(:streamflix_core, :quotas, previous) end)
    %{project: insert(:project)}
  end

  defp assert_quota_error({:error, %Ecto.Changeset{} = cs}) do
    assert Quotas.quota_exceeded?(cs)
    assert {"limit reached: maximum " <> _, _} = cs.errors[:base]
  end

  test "defaults come from config" do
    Application.delete_env(:streamflix_core, :quotas)
    assert Quotas.limit(:webhooks) == 50
    assert Quotas.limit(:projects) == 10
    assert Quotas.limit(:event_schemas) == 100
    assert Quotas.limit(:sandbox_endpoints) == 20
  end

  test "webhooks per project, deleted ones free their slot", %{project: project} do
    attrs = fn n -> %{"url" => "https://example.com/hook/#{n}"} end
    assert {:ok, w1} = Platform.create_webhook(project.id, attrs.(1))
    assert {:ok, _} = Platform.create_webhook(project.id, attrs.(2))
    assert_quota_error(Platform.create_webhook(project.id, attrs.(3)))

    {:ok, _} = Platform.set_webhook_inactive(w1)
    assert {:ok, _} = Platform.create_webhook(project.id, attrs.(4))

    # Other projects are not affected
    assert {:ok, _} = Platform.create_webhook(insert(:project).id, attrs.(5))
  end

  test "jobs per project", %{project: project} do
    attrs = %{
      "name" => "job",
      "schedule_type" => "daily",
      "schedule_config" => %{"hour" => 1, "minute" => 0},
      "action_type" => "emit_event",
      "action_config" => %{"topic" => "t"}
    }

    assert {:ok, _} = Platform.create_job(project.id, attrs)
    assert_quota_error(Platform.create_job(project.id, attrs))
  end

  test "sandbox endpoints per project", %{project: project} do
    assert {:ok, _} = Platform.create_sandbox_endpoint(project.id)
    assert_quota_error(Platform.create_sandbox_endpoint(project.id))
  end

  test "embed tokens per project", %{project: project} do
    assert {:ok, _raw, _token} = StreamflixCore.EmbedTokens.create(project.id, %{name: "a"})
    assert_quota_error(StreamflixCore.EmbedTokens.create(project.id, %{name: "b"}))
  end

  test "event schemas per project", %{project: project} do
    schema = %{"type" => "object"}

    assert {:ok, _} =
             Platform.create_event_schema(project.id, %{"topic" => "a", "schema" => schema})

    assert_quota_error(
      Platform.create_event_schema(project.id, %{"topic" => "b", "schema" => schema})
    )
  end

  test "pipelines per project", %{project: project} do
    webhook = insert(:webhook, project_id: project.id)
    attrs = %{"name" => "p", "topics" => ["*"], "steps" => [], "webhook_id" => webhook.id}
    assert {:ok, _} = StreamflixCore.Platform.Pipelines.create_pipeline(project.id, attrs)
    assert_quota_error(StreamflixCore.Platform.Pipelines.create_pipeline(project.id, attrs))
  end

  test "projects per user" do
    user = create_test_user()
    assert {:ok, _} = Platform.create_project(%{user_id: user.id, name: "one"})
    assert_quota_error(Platform.create_project(%{user_id: user.id, name: "two"}))
  end

  describe "EventRateLimit" do
    test "counts every event of a batch and rejects without consuming" do
      project = %{id: Ecto.UUID.generate(), rate_limit_events_per_minute: 10}

      assert :ok = EventRateLimit.consume(project, 6)
      assert {:error, {:rate_limited, retry_after, 10}} = EventRateLimit.consume(project, 5)
      assert retry_after in 1..60
      # The rejected batch consumed nothing: 4 more still fit
      assert :ok = EventRateLimit.consume(project, 4)
      assert {:error, {:rate_limited, _, 10}} = EventRateLimit.consume(project, 1)
    end
  end
end
