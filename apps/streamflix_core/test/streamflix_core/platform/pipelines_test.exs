defmodule StreamflixCore.Platform.PipelinesTest do
  use StreamflixCore.DataCase, async: false
  use Oban.Testing, repo: StreamflixCore.Repo

  alias StreamflixCore.Platform
  alias StreamflixCore.Platform.{Pipelines, Transformer}
  alias StreamflixCore.Schemas.Delivery

  defp pipeline_attrs(webhook, overrides \\ %{}) do
    Map.merge(
      %{
        "name" => "Paid orders",
        "topics" => ["order.#"],
        "webhook_id" => webhook.id,
        "steps" => []
      },
      overrides
    )
  end

  defp deliveries_for(event_id), do: Repo.all(from(d in Delivery, where: d.event_id == ^event_id))

  defp errors_on(changeset), do: traverse_errors(changeset, fn {msg, _opts} -> msg end)

  describe "create_pipeline/2" do
    test "rejects a target webhook from another project" do
      project = insert(:project)
      other_webhook = insert(:webhook, project_id: insert(:project).id)

      assert {:error, changeset} =
               Pipelines.create_pipeline(project.id, pipeline_attrs(other_webhook))

      assert %{webhook_id: ["does not belong to this project"]} = errors_on(changeset)
    end

    test "rejects transform steps without an operation" do
      project = insert(:project)
      webhook = insert(:webhook, project_id: project.id)
      steps = [%{"type" => "transform", "mapping" => %{"a" => "b"}}]

      assert {:error, changeset} =
               Pipelines.create_pipeline(project.id, pipeline_attrs(webhook, %{"steps" => steps}))

      assert %{steps: [msg]} = errors_on(changeset)
      assert msg =~ "operation"
    end

    test "update cannot move the pipeline to another project" do
      project = insert(:project)
      webhook = insert(:webhook, project_id: project.id)
      {:ok, pipeline} = Pipelines.create_pipeline(project.id, pipeline_attrs(webhook))

      {:ok, updated} =
        Pipelines.update_pipeline(pipeline, %{"project_id" => insert(:project).id, "name" => "X"})

      assert updated.project_id == project.id
      assert updated.name == "X"
    end
  end

  describe "matching_pipelines/2" do
    test "uses the same wildcard semantics as webhooks and tolerates nil topics" do
      project = insert(:project)
      webhook = insert(:webhook, project_id: project.id)
      {:ok, _} = Pipelines.create_pipeline(project.id, pipeline_attrs(webhook))

      assert [_] = Pipelines.matching_pipelines(project.id, "order.item.created")
      assert [] = Pipelines.matching_pipelines(project.id, "user.created")
      assert [] = Pipelines.matching_pipelines(project.id, nil)
    end

    test "regex characters in topics do not crash matching" do
      project = insert(:project)
      webhook = insert(:webhook, project_id: project.id)

      {:ok, _} =
        Pipelines.create_pipeline(project.id, pipeline_attrs(webhook, %{"topics" => ["order.("]}))

      assert [] = Pipelines.matching_pipelines(project.id, "order.created")
    end
  end

  describe "event delivery through pipelines" do
    setup do
      project = insert(:project)
      webhook = insert(:webhook, project_id: project.id, topics: ["order.#"])
      %{project: project, webhook: webhook}
    end

    test "filtered events produce no delivery for the pipeline's webhook", ctx do
      steps = [%{"type" => "filter", "field" => "status", "operator" => "eq", "value" => "paid"}]

      {:ok, _} =
        Pipelines.create_pipeline(
          ctx.project.id,
          pipeline_attrs(ctx.webhook, %{"steps" => steps})
        )

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, event} =
          Platform.create_event(ctx.project.id, %{
            "topic" => "order.created",
            "status" => "pending"
          })

        assert deliveries_for(event.id) == []
      end)
    end

    test "transformed payload is stored on the delivery and the delay is scheduled", ctx do
      steps = [
        %{"type" => "filter", "field" => "status", "operator" => "eq", "value" => "paid"},
        %{"type" => "transform", "operation" => "rename", "mapping" => %{"amount" => "total"}},
        %{"type" => "delay", "seconds" => 120}
      ]

      {:ok, _} =
        Pipelines.create_pipeline(
          ctx.project.id,
          pipeline_attrs(ctx.webhook, %{"steps" => steps})
        )

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, event} =
          Platform.create_event(ctx.project.id, %{
            "topic" => "order.created",
            "status" => "paid",
            "amount" => 10
          })

        assert [delivery] = deliveries_for(event.id)
        assert delivery.webhook_id == ctx.webhook.id
        assert delivery.payload_override == %{"status" => "paid", "total" => 10}

        [job] = all_enqueued(worker: StreamflixCore.Platform.ObanDeliveryWorker)
        assert job.args["delivery_id"] == delivery.id
        assert DateTime.diff(job.scheduled_at, DateTime.utc_now()) in 100..120
      end)
    end

    test "webhooks without a pipeline still receive the raw event", ctx do
      other = insert(:webhook, project_id: ctx.project.id, topics: ["order.#"])
      steps = [%{"type" => "filter", "field" => "status", "operator" => "eq", "value" => "paid"}]

      {:ok, _} =
        Pipelines.create_pipeline(
          ctx.project.id,
          pipeline_attrs(ctx.webhook, %{"steps" => steps})
        )

      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, event} =
          Platform.create_event(ctx.project.id, %{"topic" => "order.created", "status" => "new"})

        assert [delivery] = deliveries_for(event.id)
        assert delivery.webhook_id == other.id
        assert delivery.payload_override == nil
      end)
    end
  end

  describe "total_delay_seconds/1" do
    test "sums delay steps and ignores invalid values" do
      steps = [
        %{"type" => "delay", "seconds" => 30},
        %{"type" => "delay", "seconds" => "x"},
        %{"type" => "filter"},
        %{"type" => "delay", "seconds" => 15}
      ]

      assert Pipelines.total_delay_seconds(steps) == 45
      assert Pipelines.total_delay_seconds(nil) == 0
    end
  end

  describe "Transformer" do
    test "rename keeps the other fields" do
      assert {:ok, %{"total" => 5, "id" => 1}} =
               Transformer.apply_transform(
                 %{"operation" => "rename", "mapping" => %{"amount" => "total"}},
                 %{"amount" => 5, "id" => 1}
               )
    end

    test "pick keeps every requested field, including nested ones" do
      payload = %{"a" => 1, "b" => 2, "c" => 3, "user" => %{"email" => "x@y.z", "name" => "N"}}

      assert {:ok, %{"a" => 1, "b" => 2, "user" => %{"email" => "x@y.z"}}} =
               Transformer.apply_transform(
                 %{"operation" => "pick", "fields" => ["a", "b", "user.email"]},
                 payload
               )
    end

    test "malformed step config is a no-op instead of raising" do
      assert {:ok, %{"a" => 1}} =
               Transformer.apply_transform(%{"operation" => "pick", "fields" => "a"}, %{"a" => 1})
    end

    test "templates encode maps as JSON" do
      assert {:ok, %{"items" => ~s({"n":1})}} =
               Transformer.apply_template(%{"x" => %{"n" => 1}}, %{"items" => "{{ x }}"})
    end
  end
end
