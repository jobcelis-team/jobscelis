defmodule StreamflixCore.Platform.DataLimitsTest do
  @moduledoc "Sandbox storage caps, event schema validation and paged exports."
  use StreamflixCore.DataCase, async: false

  alias StreamflixCore.Platform
  alias StreamflixCore.Platform.{Exports, Sandbox}
  alias StreamflixCore.Schemas.{EventSchema, SandboxEndpoint, SandboxRequest}

  describe "sandbox" do
    setup do
      prev_max = Application.get_env(:streamflix_core, :sandbox_max_requests_per_endpoint)
      prev_body = Application.get_env(:streamflix_core, :sandbox_max_stored_body_bytes)
      Application.put_env(:streamflix_core, :sandbox_max_requests_per_endpoint, 3)
      Application.put_env(:streamflix_core, :sandbox_max_stored_body_bytes, 10)

      on_exit(fn ->
        Application.put_env(:streamflix_core, :sandbox_max_requests_per_endpoint, prev_max)
        Application.put_env(:streamflix_core, :sandbox_max_stored_body_bytes, prev_body)
      end)

      project = insert(:project)
      %{endpoint: insert(:sandbox_endpoint, project_id: project.id), project: project}
    end

    test "keeps only the newest N requests per endpoint", %{endpoint: endpoint} do
      for n <- 1..5 do
        {:ok, _} = Sandbox.record_sandbox_request(endpoint.id, %{method: "POST", path: "#{n}"})
      end

      paths =
        endpoint.id
        |> Sandbox.list_sandbox_requests()
        |> Enum.map(& &1.path)
        |> Enum.sort()

      assert paths == ["3", "4", "5"]
    end

    test "stored bodies are truncated", %{endpoint: endpoint} do
      {:ok, req} =
        Sandbox.record_sandbox_request(endpoint.id, %{method: "POST", body: "0123456789abcdef"})

      assert req.body == "0123456789...[truncated]"
    end

    test "purge_expired/0 removes expired endpoints and their requests", %{project: project} do
      expired =
        insert(:sandbox_endpoint,
          project_id: project.id,
          expires_at: DateTime.add(DateTime.utc_now(), -1, :hour)
        )

      insert(:sandbox_request, endpoint_id: expired.id)

      assert {1, 1} = Sandbox.purge_expired()
      refute Repo.get(SandboxEndpoint, expired.id)
      assert Repo.aggregate(where(SandboxRequest, endpoint_id: ^expired.id), :count) == 0
    end

    test "the daily purge worker runs" do
      assert :ok = StreamflixCore.Platform.ObanSandboxPurgeWorker.perform(%Oban.Job{})

      crontab =
        Application.get_env(:streamflix_core, Oban)[:plugins]
        |> Enum.find_value(fn
          {Oban.Plugins.Cron, opts} -> opts[:crontab]
          _ -> nil
        end)

      assert {"30 3 * * *", StreamflixCore.Platform.ObanSandboxPurgeWorker} in crontab
    end
  end

  describe "event schemas" do
    setup do
      %{project: insert(:project)}
    end

    test "remote $ref is rejected on save", %{project: project} do
      schema = %{
        "type" => "object",
        "properties" => %{"a" => %{"$ref" => "http://169.254.169.254/latest"}}
      }

      assert {:error, cs} =
               Platform.create_event_schema(project.id, %{"topic" => "t", "schema" => schema})

      assert %{schema: ["must not use remote $ref" <> _]} = errors_on(cs)
    end

    test "local $ref is accepted", %{project: project} do
      schema = %{
        "definitions" => %{"name" => %{"type" => "string"}},
        "type" => "object",
        "properties" => %{"name" => %{"$ref" => "#/definitions/name"}}
      }

      assert {:ok, _} =
               Platform.create_event_schema(project.id, %{"topic" => "t", "schema" => schema})
    end

    test "invalid and oversized schemas are rejected", %{project: project} do
      assert {:error, cs} =
               Platform.create_event_schema(project.id, %{
                 "topic" => "t",
                 "schema" => %{"type" => 42}
               })

      assert %{schema: ["is not a valid JSON Schema" <> _]} = errors_on(cs)

      big = %{"type" => "object", "description" => String.duplicate("x", 70_000)}

      assert {:error, cs} =
               Platform.create_event_schema(project.id, %{"topic" => "t", "schema" => big})

      assert %{schema: ["is too large" <> _]} = errors_on(cs)
    end

    test "updates are validated too", %{project: project} do
      {:ok, schema} =
        Platform.create_event_schema(project.id, %{
          "topic" => "t",
          "schema" => %{"type" => "object"}
        })

      assert {:error, _} =
               Platform.update_event_schema(schema, %{"schema" => %{"$ref" => "https://x/y"}})
    end

    test "a stored invalid schema makes event creation fail validation, not crash",
         %{project: project} do
      # Inserted directly, as if saved before schemas were validated
      Repo.insert!(%EventSchema{
        project_id: project.id,
        topic: "orders.created",
        schema: %{"properties" => %{"a" => %{"$ref" => "http://remote.example/s.json"}}},
        version: 1,
        status: "active"
      })

      assert {:error, {:schema_validation, [{_msg, "#"}]}} =
               Platform.create_event(project.id, %{"topic" => "orders.created", "a" => 1})
    end

    test "valid schemas still validate payloads (cached)", %{project: project} do
      {:ok, _} =
        Platform.create_event_schema(project.id, %{
          "topic" => "user.created",
          "schema" => %{"type" => "object", "required" => ["name"]}
        })

      for _ <- 1..2 do
        assert {:error, {:schema_validation, _}} =
                 Platform.create_event(project.id, %{"topic" => "user.created"})

        assert {:ok, _} =
                 Platform.create_event(project.id, %{"topic" => "user.created", "name" => "a"})
      end
    end
  end

  describe "exports" do
    test "pages through all rows newest first without duplicates" do
      project = insert(:project)
      base = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      ids =
        for n <- 1..7 do
          insert(:webhook_event,
            project_id: project.id,
            topic: "t",
            occurred_at: DateTime.add(base, -n, :second)
          ).id
        end

      # Same timestamp for two rows: the id tie-breaker keeps paging exact
      tie = insert(:webhook_event, project_id: project.id, topic: "t", occurred_at: base)
      tie2 = insert(:webhook_event, project_id: project.id, topic: "t", occurred_at: base)
      insert(:webhook_event, project_id: project.id, topic: "other")

      pages =
        Exports.reduce_pages(:events, project.id, [topic: "t", page_size: 2], [], fn rows, acc ->
          {:cont, [Enum.map(rows, & &1.id) | acc]}
        end)
        |> Enum.reverse()

      assert Enum.all?(pages, &(length(&1) <= 2))
      exported = List.flatten(pages)
      assert length(exported) == 9
      assert Enum.sort(exported) == Enum.sort([tie.id, tie2.id | ids])
      assert Enum.take(exported, -7) == ids
    end

    test "deliveries export reads only the project's deliveries" do
      project = insert(:project)
      webhook = insert(:webhook, project_id: project.id)
      event = insert(:webhook_event, project_id: project.id)
      d = insert(:delivery, event_id: event.id, webhook_id: webhook.id)

      other = insert(:project)
      other_event = insert(:webhook_event, project_id: other.id)

      insert(:delivery,
        event_id: other_event.id,
        webhook_id: insert(:webhook, project_id: other.id).id
      )

      rows =
        Exports.reduce_pages(:deliveries, project.id, [], [], fn rows, acc ->
          {:cont, acc ++ rows}
        end)

      assert [%{id: id, event_id: event_id}] = rows
      assert id == d.id
      assert event_id == event.id
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
  end
end
