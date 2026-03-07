# Jobcelis

Official Elixir SDK for the [Jobcelis](https://jobcelis.com) Event Infrastructure Platform.

All API calls go to `https://jobcelis.com` by default -- you only need your API key to get started.

## Installation

Add `jobcelis` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:jobcelis, "~> 1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Quick Start

```elixir
# Only your API key is required -- connects to https://jobcelis.com automatically
client = Jobcelis.client("your_api_key")

{:ok, event} = Jobcelis.send_event(client, "order.created", %{order_id: "123", amount: 99.99})
```

> **Custom URL:** If you're self-hosting Jobcelis, you can override the base URL:
> ```elixir
> client = Jobcelis.client("your_api_key", base_url: "https://your-instance.example.com")
> ```

## Authentication

The auth methods do not require an API key. Use them to register, log in, and manage JWT tokens.

```elixir
client = Jobcelis.client("")

# Register a new account
{:ok, user} = Jobcelis.register(client, "alice@example.com", "SecurePass123!", name: "Alice")

# Log in -- returns JWT access token and refresh token
{:ok, session} = Jobcelis.login(client, "alice@example.com", "SecurePass123!")
access_token = session["token"]
refresh_token = session["refresh_token"]

# Set the JWT for subsequent authenticated calls
client = Jobcelis.set_auth_token(client, access_token)

# Refresh an expired token
{:ok, new_session} = Jobcelis.refresh_token(client, refresh_token)
client = Jobcelis.set_auth_token(client, new_session["token"])

# Verify MFA (requires auth token already set)
{:ok, result} = Jobcelis.verify_mfa(client, access_token, "123456")
```

## Events

```elixir
# Send a single event
{:ok, event} = Jobcelis.send_event(client, "order.created", %{order_id: "123", amount: 99.99})

# Send batch events (up to 1000)
{:ok, batch} = Jobcelis.send_events(client, [
  %{topic: "order.created", payload: %{order_id: "1"}},
  %{topic: "order.created", payload: %{order_id: "2"}}
])

# List events with pagination
{:ok, events} = Jobcelis.list_events(client, limit: 25)
{:ok, next_page} = Jobcelis.list_events(client, limit: 25, cursor: events["cursor"])

# Get / delete a single event
{:ok, event} = Jobcelis.get_event(client, "evt_abc123")
:ok = Jobcelis.delete_event(client, "evt_abc123")
```

## Simulate

```elixir
# Dry-run an event to see which webhooks would fire
{:ok, result} = Jobcelis.simulate_event(client, "order.created", %{order_id: "test"})
```

## Webhooks

```elixir
# Create a webhook
{:ok, webhook} = Jobcelis.create_webhook(client, "https://example.com/webhook",
  topics: ["order.*"]
)

# List, get, update, delete
{:ok, webhooks} = Jobcelis.list_webhooks(client)
{:ok, wh} = Jobcelis.get_webhook(client, "wh_abc123")
{:ok, _} = Jobcelis.update_webhook(client, "wh_abc123", %{url: "https://new-url.com/hook"})
:ok = Jobcelis.delete_webhook(client, "wh_abc123")

# Health and templates
{:ok, health} = Jobcelis.webhook_health(client, "wh_abc123")
{:ok, templates} = Jobcelis.webhook_templates(client)
```

## Deliveries

```elixir
{:ok, deliveries} = Jobcelis.list_deliveries(client, limit: 20, status: "failed")
{:ok, _} = Jobcelis.retry_delivery(client, "del_abc123")
```

## Dead Letters

```elixir
{:ok, dead_letters} = Jobcelis.list_dead_letters(client)
{:ok, dl} = Jobcelis.get_dead_letter(client, "dlq_abc123")
{:ok, _} = Jobcelis.retry_dead_letter(client, "dlq_abc123")
{:ok, _} = Jobcelis.resolve_dead_letter(client, "dlq_abc123")
```

## Replays

```elixir
{:ok, replay} = Jobcelis.create_replay(client, "order.created",
  "2026-01-01T00:00:00Z",
  "2026-01-31T23:59:59Z",
  webhook_id: "wh_abc123"  # optional
)
{:ok, replays} = Jobcelis.list_replays(client)
{:ok, r} = Jobcelis.get_replay(client, "rpl_abc123")
:ok = Jobcelis.cancel_replay(client, "rpl_abc123")
```

## Scheduled Jobs

```elixir
# Create a job
{:ok, job} = Jobcelis.create_job(client, "daily-report", "default", "0 9 * * *",
  payload: %{type: "daily"}
)

# CRUD
{:ok, jobs} = Jobcelis.list_jobs(client, limit: 10)
{:ok, job} = Jobcelis.get_job(client, "job_abc123")
{:ok, _} = Jobcelis.update_job(client, "job_abc123", %{cron_expression: "0 10 * * *"})
:ok = Jobcelis.delete_job(client, "job_abc123")

# List runs for a job
{:ok, runs} = Jobcelis.list_job_runs(client, "job_abc123", limit: 20)

# Preview cron schedule
{:ok, preview} = Jobcelis.cron_preview(client, "0 9 * * *", count: 10)
```

## Pipelines

```elixir
{:ok, pipeline} = Jobcelis.create_pipeline(client, "order-processing",
  ["order.created"],
  [
    %{type: "filter", config: %{field: "amount", gt: 100}},
    %{type: "transform", config: %{add_field: "priority", value: "high"}}
  ]
)

{:ok, pipelines} = Jobcelis.list_pipelines(client)
{:ok, p} = Jobcelis.get_pipeline(client, "pipe_abc123")
{:ok, _} = Jobcelis.update_pipeline(client, "pipe_abc123", %{name: "order-processing-v2"})
:ok = Jobcelis.delete_pipeline(client, "pipe_abc123")

# Test a pipeline with a sample payload
{:ok, result} = Jobcelis.test_pipeline(client, "pipe_abc123", %{
  topic: "order.created",
  payload: %{id: "1"}
})
```

## Event Schemas

```elixir
{:ok, schema} = Jobcelis.create_event_schema(client, "order.created", %{
  type: "object",
  properties: %{
    order_id: %{type: "string"},
    amount: %{type: "number"}
  },
  required: ["order_id", "amount"]
})

{:ok, schemas} = Jobcelis.list_event_schemas(client)
{:ok, s} = Jobcelis.get_event_schema(client, "sch_abc123")
{:ok, _} = Jobcelis.update_event_schema(client, "sch_abc123", %{schema: %{type: "object"}})
:ok = Jobcelis.delete_event_schema(client, "sch_abc123")

# Validate a payload against a topic's schema
{:ok, result} = Jobcelis.validate_payload(client, "order.created", %{order_id: "123", amount: 50})
```

## Sandbox

```elixir
# Create a temporary endpoint for testing
{:ok, endpoint} = Jobcelis.create_sandbox_endpoint(client, name: "my-test")
{:ok, endpoints} = Jobcelis.list_sandbox_endpoints(client)

# Inspect received requests
{:ok, requests} = Jobcelis.list_sandbox_requests(client, "sbx_abc123", limit: 20)

:ok = Jobcelis.delete_sandbox_endpoint(client, "sbx_abc123")
```

## Analytics

```elixir
{:ok, events_chart} = Jobcelis.events_per_day(client, days: 30)
{:ok, deliveries_chart} = Jobcelis.deliveries_per_day(client, days: 7)
{:ok, topics} = Jobcelis.top_topics(client, limit: 5)
{:ok, stats} = Jobcelis.webhook_stats(client)
```

## Project and Token Management

```elixir
# Current project
{:ok, project} = Jobcelis.get_project(client)
{:ok, _} = Jobcelis.update_project(client, %{name: "My Project v2"})

# Topics
{:ok, topics} = Jobcelis.list_topics(client)

# API token
{:ok, token} = Jobcelis.get_token(client)
{:ok, new_token} = Jobcelis.regenerate_token(client)
```

## Multi-Project Management

```elixir
{:ok, projects} = Jobcelis.list_projects(client)
{:ok, new_project} = Jobcelis.create_project(client, "staging-env")
{:ok, p} = Jobcelis.get_project_by_id(client, "proj_abc123")
{:ok, _} = Jobcelis.update_project_by_id(client, "proj_abc123", %{name: "production-env"})
{:ok, _} = Jobcelis.set_default_project(client, "proj_abc123")
:ok = Jobcelis.delete_project(client, "proj_abc123")
```

## Team Members

```elixir
{:ok, members} = Jobcelis.list_members(client, "proj_abc123")
{:ok, member} = Jobcelis.add_member(client, "proj_abc123", "alice@example.com", role: "admin")
{:ok, _} = Jobcelis.update_member(client, "proj_abc123", "mem_abc123", "viewer")
:ok = Jobcelis.remove_member(client, "proj_abc123", "mem_abc123")
```

## Invitations

```elixir
# List pending invitations
{:ok, invitations} = Jobcelis.list_pending_invitations(client)

# Accept or reject
{:ok, _} = Jobcelis.accept_invitation(client, "inv_abc123")
{:ok, _} = Jobcelis.reject_invitation(client, "inv_def456")
```

## Audit Logs

```elixir
{:ok, logs} = Jobcelis.list_audit_logs(client, limit: 100)
{:ok, next_page} = Jobcelis.list_audit_logs(client, cursor: logs["cursor"])
```

## Data Export

Export methods return raw binary (CSV or JSON).

```elixir
# Export as CSV
{:ok, csv_data} = Jobcelis.export_events(client, format: "csv")
File.write!("events.csv", csv_data)

# Export as JSON
{:ok, json_data} = Jobcelis.export_deliveries(client, format: "json")

# Other exports
{:ok, _} = Jobcelis.export_jobs(client, format: "csv")
{:ok, _} = Jobcelis.export_audit_log(client, format: "csv")
```

## GDPR / Privacy

```elixir
# Consent management
{:ok, consents} = Jobcelis.get_consents(client)
{:ok, _} = Jobcelis.accept_consent(client, "marketing")

# Data portability
{:ok, my_data} = Jobcelis.export_my_data(client)

# Processing restrictions
{:ok, _} = Jobcelis.restrict_processing(client)
:ok = Jobcelis.lift_restriction(client)

# Right to object
{:ok, _} = Jobcelis.object_to_processing(client)
:ok = Jobcelis.restore_consent(client)
```

## Health Check

```elixir
{:ok, health} = Jobcelis.health(client)
{:ok, status} = Jobcelis.status(client)
```

## Error Handling

All API calls return `{:ok, result}` on success or `{:error, %Jobcelis.Error{}}` on failure.

```elixir
case Jobcelis.get_event(client, "nonexistent") do
  {:ok, event} ->
    IO.inspect(event)

  {:error, %Jobcelis.Error{status: 404, detail: detail}} ->
    IO.puts("Not found: #{inspect(detail)}")

  {:error, %Jobcelis.Error{status: status, detail: detail}} ->
    IO.puts("Error #{status}: #{inspect(detail)}")
end
```

## Webhook Signature Verification

```elixir
# In a Phoenix controller
def webhook(conn, _params) do
  {:ok, body, conn} = Plug.Conn.read_body(conn)
  signature = Plug.Conn.get_req_header(conn, "x-signature") |> List.first("")

  if Jobcelis.WebhookVerifier.verify("your_webhook_secret", body, signature) do
    event = Jason.decode!(body)
    IO.puts("Received: #{event["topic"]}")
    send_resp(conn, 200, "OK")
  else
    send_resp(conn, 401, "Invalid signature")
  end
end
```

## License

MIT
