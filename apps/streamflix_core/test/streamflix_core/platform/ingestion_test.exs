defmodule StreamflixCore.Platform.IngestionTest do
  @moduledoc """
  Event ingestion writes events, deliveries and delivery jobs in a few
  statements, and the caches it reads are cleared as soon as their data changes.
  """
  use StreamflixCore.DataCase, async: false

  import Ecto.Query

  alias StreamflixCore.Platform
  alias StreamflixCore.Schemas.{Delivery, WebhookEvent}

  defp project_with_webhooks(n) do
    project = insert(:project)
    for _ <- 1..n, do: insert(:webhook, project_id: project.id, topics: ["order.*"])
    project
  end

  defp deliveries_for(event_id),
    do: Repo.aggregate(from(d in Delivery, where: d.event_id == ^event_id), :count)

  # Counts queries made by this process while running fun
  defp count_queries(fun) do
    parent = self()
    ref = make_ref()
    id = {__MODULE__, ref}

    :telemetry.attach(
      id,
      [:streamflix_core, :repo, :query],
      fn _event, _measurements, _meta, _ ->
        if self() == parent, do: send(parent, {ref, :query})
      end,
      nil
    )

    result = fun.()
    :telemetry.detach(id)
    {result, drain(ref, [])}
  end

  defp drain(ref, sources) do
    receive do
      {^ref, :query, source} -> drain(ref, [source | sources])
    after
      0 -> sources
    end
  end

  describe "batch" do
    test "a large batch is written with a bounded number of queries" do
      project = project_with_webhooks(3)
      # warm the caches (owner, consent, webhooks, pipelines, schemas)
      {:ok, _} = Platform.create_event(project.id, %{"topic" => "order.warm"})

      events = for i <- 1..200, do: %{"topic" => "order.created", "payload" => %{"i" => i}}

      {{:ok, result}, sources} =
        count_queries(fn -> Platform.create_events_batch(project.id, events) end)

      assert result.accepted == 200
      # Before: ~11 queries per event (2200+). Now a handful for the whole batch.
      queries = length(sources)
      assert queries <= 10, "batch used #{queries} queries: #{inspect(Enum.frequencies(sources))}"

      ids = Enum.map(result.events, & &1.id)
      assert Repo.aggregate(from(d in Delivery, where: d.event_id in ^ids), :count) == 600
    end

    test "repeated and already used idempotency keys resolve to one event" do
      project = project_with_webhooks(2)

      {:ok, old} =
        Platform.create_event(project.id, %{"topic" => "order.a", "idempotency_key" => "old"})

      {:ok, result} =
        Platform.create_events_batch(project.id, [
          %{"topic" => "order.a", "idempotency_key" => "dup"},
          %{"topic" => "order.a", "idempotency_key" => "dup"},
          %{"topic" => "order.a", "idempotency_key" => "old"},
          "not an object",
          %{"topic" => "order.a", "idempotency_key" => ""},
          %{"topic" => "order.a", "deliver_at" => "tomorrow"},
          %{"topic" => "order." <> String.duplicate("x", 300)}
        ])

      [dup1, dup2, existing | rejected] = result.events
      assert dup1.status == "accepted" and dup1.id == dup2.id
      assert existing.id == old.id
      assert Enum.all?(rejected, &(&1.status == "rejected"))
      assert result.accepted == 3 and result.rejected == 4

      # the repeated key produced one event, delivered once per webhook
      assert Repo.aggregate(
               from(e in WebhookEvent,
                 where: e.project_id == ^project.id and e.idempotency_key == "dup"
               ),
               :count
             ) == 1

      assert deliveries_for(dup1.id) == 2
    end
  end

  describe "caches are cleared when their data changes" do
    test "a new or removed event schema applies to the next event" do
      project = insert(:project)
      {:ok, _} = Platform.create_event(project.id, %{"topic" => "typed", "id" => 1})

      {:ok, schema} =
        Platform.create_event_schema(project.id, %{
          "topic" => "typed",
          "schema" => %{"type" => "object", "properties" => %{"id" => %{"type" => "string"}}}
        })

      assert {:error, {:schema_validation, _}} =
               Platform.create_event(project.id, %{"topic" => "typed", "id" => 1})

      {:ok, _} = Platform.delete_event_schema(schema)
      assert {:ok, _} = Platform.create_event(project.id, %{"topic" => "typed", "id" => 1})
    end

    test "a new pipeline takes over its webhook on the next event" do
      project = insert(:project)
      webhook = insert(:webhook, project_id: project.id, topics: ["order.*"])
      {:ok, _} = Platform.create_event(project.id, %{"topic" => "order.warm"})

      {:ok, _} =
        StreamflixCore.Platform.Pipelines.create_pipeline(project.id, %{
          "name" => "big only",
          "topics" => ["order.*"],
          "webhook_id" => webhook.id,
          "steps" => [
            %{"type" => "filter", "field" => "amount", "operator" => "gte", "value" => 100}
          ]
        })

      {:ok, small} =
        Platform.create_event(project.id, %{"topic" => "order.created", "amount" => 5})

      {:ok, big} =
        Platform.create_event(project.id, %{"topic" => "order.created", "amount" => 500})

      assert deliveries_for(small.id) == 0
      assert deliveries_for(big.id) == 1
    end
  end
end
