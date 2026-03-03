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
      example: %{topic: "order.created", amount: 150, currency: "USD"}
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
        checks: %Schema{
          type: :object,
          properties: %{
            database: %Schema{type: :string, enum: ["ok", "error"]},
            oban: %Schema{type: :string, enum: ["ok", "error"]},
            cache: %Schema{type: :string, enum: ["ok", "error"]}
          }
        },
        timestamp: %Schema{type: :string, format: :"date-time"}
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
      }
    })
  end

  # ---- Phase 6: Batch Events ----

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
