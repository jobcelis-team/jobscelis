defmodule StreamflixCore.Factory do
  use ExMachina.Ecto, repo: StreamflixCore.Repo

  alias StreamflixCore.Schemas.{
    Project,
    ApiKey,
    Webhook,
    WebhookEvent,
    Delivery,
    Job,
    JobRun,
    DeadLetter,
    Replay,
    SandboxEndpoint,
    SandboxRequest,
    EventSchema,
    BatchItem
  }

  def project_factory() do
    %Project{
      id: Ecto.UUID.generate(),
      name: sequence(:project_name, &"Test Project #{&1}"),
      status: "active",
      is_default: false,
      settings: %{}
    }
  end

  def webhook_event_factory() do
    %WebhookEvent{
      id: Ecto.UUID.generate(),
      topic: sequence(:topic, &"test.topic.#{&1}"),
      payload: %{"key" => "value"},
      status: "active",
      occurred_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
    }
  end

  def webhook_factory() do
    %Webhook{
      id: Ecto.UUID.generate(),
      url: sequence(:webhook_url, &"https://example.com/webhook/#{&1}"),
      status: "active",
      topics: ["*"],
      filters: [],
      body_config: %{},
      headers: %{},
      retry_config: %{}
    }
  end

  def delivery_factory() do
    %Delivery{
      id: Ecto.UUID.generate(),
      status: "pending",
      attempt_number: 0,
      response_status: nil,
      response_body: nil
    }
  end

  def api_key_factory() do
    raw_key = "wh_" <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

    %ApiKey{
      id: Ecto.UUID.generate(),
      prefix: String.slice(raw_key, 0, 12),
      key_hash: :crypto.hash(:sha256, raw_key) |> Base.encode64(padding: false),
      name: "Default",
      status: "active",
      scopes: ["*"],
      allowed_ips: []
    }
  end

  def job_factory() do
    %Job{
      id: Ecto.UUID.generate(),
      name: sequence(:job_name, &"Test Job #{&1}"),
      schedule_type: "daily",
      schedule_config: %{"hour" => 8, "minute" => 0},
      action_type: "emit_event",
      action_config: %{"topic" => "test.scheduled", "payload" => %{}},
      status: "active"
    }
  end

  def job_run_factory() do
    %JobRun{
      id: Ecto.UUID.generate(),
      executed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
      status: "success",
      result: %{}
    }
  end

  def dead_letter_factory() do
    %DeadLetter{
      id: Ecto.UUID.generate(),
      original_payload: %{"key" => "value"},
      last_error: "Connection refused",
      last_response_status: 500,
      attempts_exhausted: 5,
      resolved: false
    }
  end

  def replay_factory() do
    %Replay{
      id: Ecto.UUID.generate(),
      status: "pending",
      filters: %{"topic" => "test.topic"},
      total_events: 10,
      processed_events: 0
    }
  end

  def sandbox_endpoint_factory() do
    %SandboxEndpoint{
      id: Ecto.UUID.generate(),
      slug: sequence(:slug, &"sandbox-#{&1}"),
      name: sequence(:sandbox_name, &"Sandbox #{&1}"),
      expires_at: DateTime.utc_now() |> DateTime.add(24, :hour) |> DateTime.truncate(:microsecond)
    }
  end

  def sandbox_request_factory() do
    %SandboxRequest{
      id: Ecto.UUID.generate(),
      method: "POST",
      path: "/",
      headers: %{"content-type" => "application/json"},
      body: ~s({"test": true}),
      query_params: %{}
    }
  end

  def event_schema_factory() do
    %EventSchema{
      id: Ecto.UUID.generate(),
      topic: sequence(:schema_topic, &"schema.topic.#{&1}"),
      schema: %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"}
        },
        "required" => ["name"]
      },
      version: 1,
      status: "active"
    }
  end

  def batch_item_factory() do
    %BatchItem{
      id: Ecto.UUID.generate()
    }
  end

  @doc """
  Creates a minimal user row in the users table for FK constraints.
  Since User schema lives in streamflix_accounts, we insert raw.
  Uses Ecto for proper binary_id encoding.
  """
  def create_test_user(attrs \\ %{}) do
    id = Map.get(attrs, :id, Ecto.UUID.generate())
    email = Map.get(attrs, :email, "test#{System.unique_integer([:positive])}@example.com")

    hmac_secret = Application.get_env(:streamflix_core, :hmac_secret, "test_hmac_secret")

    email_hash =
      :crypto.mac(:hmac, :sha512, hmac_secret, String.downcase(email)) |> Base.encode64()

    # Simple bcrypt-like hash for testing (not using Argon2 since it's in accounts app)
    password_hash = "$argon2id$v=19$m=65536,t=3,p=4$dGVzdHNhbHQ$fakehashfortesting"

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:microsecond)

    {1, _} =
      StreamflixCore.Repo.insert_all(
        "users",
        [
          %{
            id: Ecto.UUID.dump!(id),
            email: email,
            email_hash: email_hash,
            password_hash: password_hash,
            name: email,
            status: "active",
            role: "user",
            processing_consent: true,
            inserted_at: now,
            updated_at: now
          }
        ]
      )

    %{id: id, email: email}
  end
end
