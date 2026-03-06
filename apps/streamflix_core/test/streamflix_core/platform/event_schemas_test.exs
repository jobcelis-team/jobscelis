defmodule StreamflixCore.Platform.EventSchemasTest do
  use StreamflixCore.DataCase, async: true

  alias StreamflixCore.Platform

  describe "create_event_schema/2" do
    test "creates an event schema" do
      project = insert(:project)

      attrs = %{
        "topic" => "order.created",
        "schema" => %{
          "type" => "object",
          "properties" => %{"amount" => %{"type" => "number"}},
          "required" => ["amount"]
        }
      }

      assert {:ok, schema} = Platform.create_event_schema(project.id, attrs)
      assert schema.topic == "order.created"
      assert schema.version == 1
    end
  end

  describe "list_event_schemas/2" do
    test "lists active schemas for a project" do
      project = insert(:project)
      insert(:event_schema, project_id: project.id, status: "active")
      insert(:event_schema, project_id: project.id, status: "inactive")

      schemas = Platform.list_event_schemas(project.id)
      assert length(schemas) == 1
    end
  end

  describe "validate_event_payload/3" do
    test "passes when no schema exists" do
      project = insert(:project)
      assert :ok = Platform.validate_event_payload(project.id, "any.topic", %{"data" => "value"})
    end

    test "passes when payload matches schema" do
      project = insert(:project)

      insert(:event_schema,
        project_id: project.id,
        topic: "order.created",
        schema: %{
          "type" => "object",
          "properties" => %{"amount" => %{"type" => "number"}},
          "required" => ["amount"]
        }
      )

      assert :ok =
               Platform.validate_event_payload(project.id, "order.created", %{"amount" => 99.99})
    end

    test "fails when payload does not match schema" do
      project = insert(:project)

      insert(:event_schema,
        project_id: project.id,
        topic: "order.created",
        schema: %{
          "type" => "object",
          "properties" => %{"amount" => %{"type" => "number"}},
          "required" => ["amount"]
        }
      )

      assert {:error, {:schema_validation, _}} =
               Platform.validate_event_payload(project.id, "order.created", %{
                 "name" => "missing amount"
               })
    end

    test "passes for nil topic" do
      project = insert(:project)
      assert :ok = Platform.validate_event_payload(project.id, nil, %{"data" => "value"})
    end

    test "passes for empty topic" do
      project = insert(:project)
      assert :ok = Platform.validate_event_payload(project.id, "", %{"data" => "value"})
    end

    test "uses latest version of schema" do
      project = insert(:project)

      # v1 requires "name"
      insert(:event_schema,
        project_id: project.id,
        topic: "order.created",
        version: 1,
        schema: %{
          "type" => "object",
          "properties" => %{"name" => %{"type" => "string"}},
          "required" => ["name"]
        }
      )

      # v2 requires "amount" instead
      insert(:event_schema,
        project_id: project.id,
        topic: "order.created",
        version: 2,
        schema: %{
          "type" => "object",
          "properties" => %{"amount" => %{"type" => "number"}},
          "required" => ["amount"]
        }
      )

      # Should validate against v2 (latest)
      assert :ok =
               Platform.validate_event_payload(project.id, "order.created", %{"amount" => 100})

      assert {:error, {:schema_validation, _}} =
               Platform.validate_event_payload(project.id, "order.created", %{
                 "name" => "only v1"
               })
    end
  end

  describe "delete_event_schema/1" do
    test "soft deletes a schema" do
      project = insert(:project)
      schema = insert(:event_schema, project_id: project.id)

      assert {:ok, updated} = Platform.delete_event_schema(schema)
      assert updated.status == "inactive"
    end
  end
end
