defmodule StreamflixWebWeb.Schemas do
  alias OpenApiSpex.Schema

  defmodule Event do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Event",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        topic: %Schema{type: :string, example: "order.created"},
        payload: %Schema{type: :object},
        status: %Schema{type: :string, enum: ["active", "inactive"]},
        payload_hash: %Schema{
          type: :string,
          description: "SHA-256 hex digest of the canonical payload"
        },
        idempotency_key: %Schema{
          type: :string,
          nullable: true,
          description: "Client-provided deduplication key"
        },
        occurred_at: %Schema{type: :string, format: :"date-time"},
        inserted_at: %Schema{type: :string, format: :"date-time"}
      },
      example: %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        topic: "order.created",
        payload: %{order_id: "12345", customer: "john@example.com", amount: 99.99},
        status: "active",
        payload_hash: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2",
        idempotency_key: "order-12345-create",
        occurred_at: "2026-03-06T12:00:00.000000Z",
        inserted_at: "2026-03-06T12:00:00.123456Z"
      }
    })
  end

  defmodule EventCreate do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "EventCreate",
      type: :object,
      properties: %{
        topic: %Schema{type: :string, example: "order.created"},
        payload: %Schema{type: :object, description: "Any JSON object"},
        idempotency_key: %Schema{
          type: :string,
          nullable: true,
          description: "Optional deduplication key (unique per project)"
        }
      },
      example: %{
        topic: "order.created",
        payload: %{order_id: "12345", customer: "john@example.com", amount: 99.99},
        idempotency_key: "order-12345-create"
      }
    })
  end

  defmodule EventResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "EventResponse",
      type: :object,
      properties: %{
        event_id: %Schema{type: :string, format: :uuid},
        payload_hash: %Schema{
          type: :string,
          description: "SHA-256 hex digest of the canonical payload"
        }
      },
      example: %{
        event_id: "550e8400-e29b-41d4-a716-446655440000",
        payload_hash: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
      }
    })
  end

  defmodule Webhook do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Webhook",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        url: %Schema{type: :string, format: :uri},
        status: %Schema{type: :string, enum: ["active", "inactive"]},
        topics: %Schema{type: :array, items: %Schema{type: :string}},
        filters: %Schema{type: :array, items: %Schema{type: :string}},
        body_config: %Schema{type: :object},
        headers: %Schema{type: :object},
        retry_config: %Schema{type: :object},
        inserted_at: %Schema{type: :string, format: :"date-time"}
      },
      example: %{
        id: "7c9e6679-7425-40de-944b-e07fc1f90ae7",
        url: "https://api.example.com/webhooks/receiver",
        status: "active",
        topics: ["order.*", "user.created"],
        filters: [],
        body_config: %{},
        headers: %{"X-Custom-Header" => "my-value"},
        retry_config: %{max_retries: 5, backoff: "exponential"},
        inserted_at: "2026-03-06T10:30:00.000000Z"
      }
    })
  end

  defmodule WebhookCreate do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "WebhookCreate",
      type: :object,
      required: [:url],
      properties: %{
        url: %Schema{type: :string, format: :uri},
        secret: %Schema{type: :string},
        topics: %Schema{type: :array, items: %Schema{type: :string}},
        filters: %Schema{type: :array, items: %Schema{type: :string}},
        body_config: %Schema{type: :object},
        headers: %Schema{type: :object},
        retry_config: %Schema{type: :object}
      },
      example: %{
        url: "https://api.example.com/webhooks/receiver",
        secret: "whsec_MK8pFg2xR7YzQ3nV",
        topics: ["order.*", "user.created"],
        headers: %{"X-Custom-Header" => "my-value"}
      }
    })
  end

  defmodule WebhookHealth do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "WebhookHealth",
      type: :object,
      properties: %{
        webhook_id: %Schema{type: :string, format: :uuid},
        url: %Schema{type: :string},
        health: %Schema{
          type: :object,
          properties: %{
            status: %Schema{type: :string, enum: ["healthy", "degraded", "failing", "unknown"]},
            success_rate: %Schema{type: :number, format: :float},
            last_attempt_at: %Schema{type: :string, format: :"date-time", nullable: true},
            last_response_status: %Schema{type: :integer, nullable: true}
          }
        }
      },
      example: %{
        webhook_id: "7c9e6679-7425-40de-944b-e07fc1f90ae7",
        url: "https://api.example.com/webhooks/receiver",
        health: %{
          status: "healthy",
          success_rate: 99.5,
          last_attempt_at: "2026-03-06T11:59:30.000000Z",
          last_response_status: 200
        }
      }
    })
  end

  defmodule Delivery do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Delivery",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        status: %Schema{type: :string},
        attempt_number: %Schema{type: :integer},
        inserted_at: %Schema{type: :string, format: :"date-time"}
      },
      example: %{
        id: "f47ac10b-58cc-4372-a567-0e02b2c3d479",
        status: "delivered",
        attempt_number: 1,
        inserted_at: "2026-03-06T12:00:01.234567Z"
      }
    })
  end

  defmodule DeadLetter do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "DeadLetter",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        delivery_id: %Schema{type: :string, format: :uuid},
        event_id: %Schema{type: :string, format: :uuid},
        webhook_id: %Schema{type: :string, format: :uuid},
        webhook_url: %Schema{type: :string, nullable: true},
        original_payload: %Schema{type: :object},
        last_error: %Schema{type: :string},
        last_response_status: %Schema{type: :integer, nullable: true},
        resolved: %Schema{type: :boolean},
        resolved_at: %Schema{type: :string, format: :"date-time", nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"}
      },
      example: %{
        id: "a3bb189e-8bf9-3888-9912-ace4e6543002",
        delivery_id: "f47ac10b-58cc-4372-a567-0e02b2c3d479",
        event_id: "550e8400-e29b-41d4-a716-446655440000",
        webhook_id: "7c9e6679-7425-40de-944b-e07fc1f90ae7",
        webhook_url: "https://api.example.com/webhooks/receiver",
        original_payload: %{order_id: "12345", amount: 99.99},
        last_error: "Connection refused",
        last_response_status: nil,
        resolved: false,
        resolved_at: nil,
        inserted_at: "2026-03-06T12:05:00.000000Z"
      }
    })
  end

  defmodule Replay do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "Replay",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        status: %Schema{
          type: :string,
          enum: ["pending", "running", "completed", "failed", "cancelled"]
        },
        filters: %Schema{type: :object},
        total_events: %Schema{type: :integer},
        processed_events: %Schema{type: :integer},
        started_at: %Schema{type: :string, format: :"date-time", nullable: true},
        completed_at: %Schema{type: :string, format: :"date-time", nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"}
      },
      example: %{
        id: "b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e",
        status: "completed",
        filters: %{topic: "order.*", from: "2026-03-01T00:00:00Z", to: "2026-03-06T00:00:00Z"},
        total_events: 150,
        processed_events: 150,
        started_at: "2026-03-06T12:00:00.000000Z",
        completed_at: "2026-03-06T12:02:30.000000Z",
        inserted_at: "2026-03-06T11:59:50.000000Z"
      }
    })
  end

  defmodule SandboxEndpoint do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "SandboxEndpoint",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        slug: %Schema{type: :string},
        name: %Schema{type: :string},
        url: %Schema{type: :string},
        expires_at: %Schema{type: :string, format: :"date-time"},
        inserted_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule AuditLogEntry do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AuditLogEntry",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        action: %Schema{type: :string, example: "event.created"},
        resource_type: %Schema{type: :string},
        resource_id: %Schema{type: :string},
        metadata: %Schema{type: :object},
        user_id: %Schema{type: :string, format: :uuid, nullable: true},
        ip_address: %Schema{type: :string, nullable: true},
        inserted_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule AnalyticsTimeSeries do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "AnalyticsTimeSeries",
      type: :object,
      properties: %{
        data: %Schema{
          type: :array,
          items: %Schema{
            type: :object,
            properties: %{
              date: %Schema{type: :string, format: :date},
              count: %Schema{type: :integer}
            }
          }
        }
      }
    })
  end

  defmodule HealthResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "HealthResponse",
      type: :object,
      properties: %{
        status: %Schema{type: :string, enum: ["healthy", "degraded", "unhealthy"]},
        timestamp: %Schema{type: :string, format: :"date-time"}
      },
      example: %{
        status: "healthy",
        timestamp: "2026-03-06T12:00:00.000000Z"
      }
    })
  end

  defmodule ErrorResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ErrorResponse",
      type: :object,
      properties: %{
        error: %Schema{type: :string}
      },
      example: %{
        error: "Not found"
      }
    })
  end

  # ---- Phase 5: B11 Multi-Project ----

  defmodule ProjectResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ProjectResponse",
      type: :object,
      properties: %{
        data: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :string, format: :uuid},
            name: %Schema{type: :string},
            status: %Schema{type: :string},
            is_default: %Schema{type: :boolean},
            settings: %Schema{type: :object},
            inserted_at: %Schema{type: :string, format: :"date-time"},
            updated_at: %Schema{type: :string, format: :"date-time"}
          }
        }
      }
    })
  end

  defmodule ProjectList do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ProjectList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: ProjectResponse}
      }
    })
  end

  defmodule ProjectCreate do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ProjectCreate",
      type: :object,
      required: [:name],
      properties: %{
        name: %Schema{type: :string},
        settings: %Schema{type: :object}
      },
      example: %{
        name: "My Production App",
        settings: %{timezone: "America/New_York"}
      }
    })
  end

  # ---- Phase 5: B12 API Key Scopes ----

  defmodule ApiKeyResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ApiKeyResponse",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        prefix: %Schema{type: :string},
        name: %Schema{type: :string},
        scopes: %Schema{type: :array, items: %Schema{type: :string}},
        status: %Schema{type: :string},
        inserted_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  # ---- Phase 5: B14 Event Schemas ----

  defmodule EventSchemaResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "EventSchemaResponse",
      type: :object,
      properties: %{
        data: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :string, format: :uuid},
            topic: %Schema{type: :string},
            schema: %Schema{type: :object},
            version: %Schema{type: :integer},
            status: %Schema{type: :string},
            inserted_at: %Schema{type: :string, format: :"date-time"}
          }
        }
      }
    })
  end

  defmodule EventSchemaList do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "EventSchemaList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: EventSchemaResponse}
      }
    })
  end

  defmodule EventSchemaCreate do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "EventSchemaCreate",
      type: :object,
      required: [:topic, :schema],
      properties: %{
        topic: %Schema{type: :string, example: "order.created"},
        schema: %Schema{type: :object, description: "JSON Schema object"},
        version: %Schema{type: :integer, default: 1}
      },
      example: %{
        topic: "order.created",
        schema: %{
          type: "object",
          required: ["order_id", "amount"],
          properties: %{
            order_id: %{type: "string"},
            amount: %{type: "number", minimum: 0},
            currency: %{type: "string", default: "USD"}
          }
        },
        version: 1
      }
    })
  end

  defmodule EventSchemaValidate do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "EventSchemaValidate",
      type: :object,
      required: [:topic, :payload],
      properties: %{
        topic: %Schema{type: :string},
        payload: %Schema{type: :object}
      }
    })
  end

  defmodule EventSchemaValidateResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "EventSchemaValidateResponse",
      type: :object,
      properties: %{
        valid: %Schema{type: :boolean},
        errors: %Schema{type: :array, items: %Schema{type: :object}}
      }
    })
  end

  # ---- Phase 6: Cursor Pagination ----

  defmodule PaginatedResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "PaginatedResponse",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: %Schema{type: :object}},
        has_next: %Schema{type: :boolean},
        next_cursor: %Schema{type: :string, nullable: true}
      },
      example: %{
        data: [%{id: "550e8400-e29b-41d4-a716-446655440000", topic: "order.created"}],
        has_next: true,
        next_cursor: "eyJpZCI6IjU1MGU4NDAwLWUyOWItNDFkNC1hNzE2LTQ0NjY1NTQ0MDAwMCJ9"
      }
    })
  end

  # ---- Phase 6: Batch Ingestion ----

  defmodule BatchEventsCreate do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "BatchEventsCreate",
      type: :object,
      required: [:events],
      properties: %{
        events: %Schema{
          type: :array,
          items: EventCreate,
          description: "List of events (max 1000)",
          maxItems: 1000
        }
      },
      example: %{
        events: [
          %{topic: "order.created", payload: %{order_id: "123", amount: 150, currency: "USD"}},
          %{topic: "user.signup", payload: %{user_id: "456", email: "test@example.com"}}
        ]
      }
    })
  end

  defmodule BatchEventResult do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "BatchEventResult",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, nullable: true},
        topic: %Schema{type: :string, nullable: true},
        status: %Schema{type: :string, enum: ["accepted", "rejected"]}
      }
    })
  end

  defmodule BatchEventsResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "BatchEventsResponse",
      type: :object,
      properties: %{
        accepted: %Schema{type: :integer},
        rejected: %Schema{type: :integer},
        events: %Schema{type: :array, items: BatchEventResult}
      },
      example: %{
        accepted: 2,
        rejected: 0,
        events: [
          %{
            id: "550e8400-e29b-41d4-a716-446655440000",
            topic: "order.created",
            status: "accepted"
          },
          %{id: "660f9511-f3ac-52e5-b827-557766551111", topic: "user.signup", status: "accepted"}
        ]
      }
    })
  end

  # ---- Phase 6: Batch Delivery Config ----

  defmodule BatchConfig do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "BatchConfig",
      type: :object,
      properties: %{
        enabled: %Schema{type: :boolean, default: false},
        window_seconds: %Schema{type: :integer, default: 60},
        max_batch_size: %Schema{type: :integer, default: 100}
      }
    })
  end

  # ---- Phase 6: Export ----

  defmodule ExportParams do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ExportParams",
      type: :object,
      properties: %{
        format: %Schema{type: :string, enum: ["json", "csv"], default: "json"},
        days: %Schema{type: :integer, default: 30}
      }
    })
  end

  # ---- Phase 6: Webhook Templates ----

  defmodule WebhookTemplate do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "WebhookTemplate",
      type: :object,
      properties: %{
        id: %Schema{type: :string},
        name: %Schema{type: :string},
        description: %Schema{type: :string},
        headers: %Schema{type: :object},
        body_config: %Schema{type: :object}
      }
    })
  end

  # ---- Phase 6: Cron Preview ----

  defmodule CronPreviewResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "CronPreviewResponse",
      type: :object,
      properties: %{
        expression: %Schema{type: :string},
        next_executions: %Schema{
          type: :array,
          items: %Schema{type: :string, format: :"date-time"}
        }
      }
    })
  end

  # ---- Phase 5: B20 Teams ----

  defmodule MemberResponse do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "MemberResponse",
      type: :object,
      properties: %{
        data: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :string, format: :uuid},
            project_id: %Schema{type: :string, format: :uuid},
            user_id: %Schema{type: :string, format: :uuid},
            role: %Schema{type: :string, enum: ["owner", "editor", "viewer"]},
            status: %Schema{type: :string, enum: ["pending", "active", "removed"]},
            invited_by: %Schema{type: :string, format: :uuid, nullable: true},
            inserted_at: %Schema{type: :string, format: :"date-time"}
          }
        }
      }
    })
  end

  defmodule MemberList do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "MemberList",
      type: :object,
      properties: %{
        data: %Schema{type: :array, items: MemberResponse}
      }
    })
  end

  defmodule MemberInvite do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "MemberInvite",
      type: :object,
      required: [:user_id],
      properties: %{
        user_id: %Schema{type: :string, format: :uuid},
        role: %Schema{type: :string, enum: ["editor", "viewer"], default: "viewer"}
      }
    })
  end

  defmodule MemberUpdate do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "MemberUpdate",
      type: :object,
      required: [:role],
      properties: %{
        role: %Schema{type: :string, enum: ["editor", "viewer"]}
      }
    })
  end
end
