# jobcelis

Official Ruby SDK for the [Jobcelis](https://jobcelis.com) Event Infrastructure Platform.

All API calls go to `https://jobcelis.com` by default -- you only need your API key to get started.

## Installation

Add to your Gemfile:

```ruby
gem "jobcelis"
```

Then run:

```bash
bundle install
```

Or install directly:

```bash
gem install jobcelis
```

## Quick Start

```ruby
require "jobcelis"

# Only your API key is required -- connects to https://jobcelis.com automatically
client = Jobcelis::Client.new(api_key: "your_api_key")
```

> **Custom URL:** If you're self-hosting Jobcelis, you can override the base URL:
> ```ruby
> client = Jobcelis::Client.new(api_key: "your_api_key", base_url: "https://your-instance.example.com")
> ```

## Authentication

The auth methods do not require an API key. Use them to register, log in, and manage JWT tokens.

```ruby
require "jobcelis"

client = Jobcelis::Client.new(api_key: "")

# Register a new account
user = client.register(email: "alice@example.com", password: "SecurePass123!", name: "Alice")

# Log in -- returns JWT access token and refresh token
session = client.login(email: "alice@example.com", password: "SecurePass123!")
access_token = session["token"]
refresh_tok = session["refresh_token"]

# Set the JWT for subsequent authenticated calls
client.set_auth_token(access_token)

# Refresh an expired token
new_session = client.refresh_token(refresh_tok)
client.set_auth_token(new_session["token"])

# Verify MFA (requires Bearer token already set)
result = client.verify_mfa(token: access_token, code: "123456")
```

## Events

```ruby
# Send a single event
event = client.send_event("order.created", { order_id: "123", amount: 99.99 })

# Send batch events (up to 1000)
batch = client.send_events([
  { topic: "order.created", payload: { order_id: "1" } },
  { topic: "order.created", payload: { order_id: "2" } },
])

# List events with pagination
events = client.list_events(limit: 25)
next_page = client.list_events(limit: 25, cursor: events["cursor"])

# Get / delete a single event
event = client.get_event("evt_abc123")
client.delete_event("evt_abc123")
```

## Simulate

```ruby
# Dry-run an event to see which webhooks would fire
result = client.simulate_event("order.created", { order_id: "test" })
```

## Webhooks

```ruby
# Create a webhook
webhook = client.create_webhook(
  url: "https://example.com/webhook",
  topics: ["order.*"],
)

# List, get, update, delete
webhooks = client.list_webhooks
wh = client.get_webhook("wh_abc123")
client.update_webhook("wh_abc123", url: "https://new-url.com/hook")
client.delete_webhook("wh_abc123")

# Health and templates
health = client.webhook_health("wh_abc123")
templates = client.webhook_templates
```

## Deliveries

```ruby
deliveries = client.list_deliveries(limit: 20, status: "failed")
client.retry_delivery("del_abc123")
```

## Dead Letters

```ruby
dead_letters = client.list_dead_letters
dl = client.get_dead_letter("dlq_abc123")
client.retry_dead_letter("dlq_abc123")
client.resolve_dead_letter("dlq_abc123")
```

## Replays

```ruby
replay = client.create_replay(
  topic: "order.created",
  from_date: "2026-01-01T00:00:00Z",
  to_date: "2026-01-31T23:59:59Z",
  webhook_id: "wh_abc123",  # optional
)
replays = client.list_replays
r = client.get_replay("rpl_abc123")
client.cancel_replay("rpl_abc123")
```

## Scheduled Jobs

```ruby
# Create a job
job = client.create_job(
  name: "daily-report",
  queue: "default",
  cron_expression: "0 9 * * *",
  payload: { type: "daily" },
)

# CRUD
jobs = client.list_jobs(limit: 10)
job = client.get_job("job_abc123")
client.update_job("job_abc123", cron_expression: "0 10 * * *")
client.delete_job("job_abc123")

# List runs for a job
runs = client.list_job_runs("job_abc123", limit: 20)

# Preview cron schedule
preview = client.cron_preview("0 9 * * *", count: 10)
```

## Pipelines

```ruby
pipeline = client.create_pipeline(
  name: "order-processing",
  topics: ["order.created"],
  steps: [
    { type: "filter", config: { field: "amount", gt: 100 } },
    { type: "transform", config: { add_field: "priority", value: "high" } },
  ],
)

pipelines = client.list_pipelines
p = client.get_pipeline("pipe_abc123")
client.update_pipeline("pipe_abc123", name: "order-processing-v2")
client.delete_pipeline("pipe_abc123")

# Test a pipeline with a sample payload
result = client.test_pipeline("pipe_abc123", { topic: "order.created", payload: { id: "1" } })
```

## Event Schemas

```ruby
schema = client.create_event_schema(
  topic: "order.created",
  schema: {
    type: "object",
    properties: {
      order_id: { type: "string" },
      amount: { type: "number" },
    },
    required: ["order_id", "amount"],
  },
)

schemas = client.list_event_schemas
s = client.get_event_schema("sch_abc123")
client.update_event_schema("sch_abc123", schema: { type: "object" })
client.delete_event_schema("sch_abc123")

# Validate a payload against a topic's schema
result = client.validate_payload("order.created", { order_id: "123", amount: 50 })
```

## Sandbox

```ruby
# Create a temporary endpoint for testing
endpoint = client.create_sandbox_endpoint(name: "my-test")
endpoints = client.list_sandbox_endpoints

# Inspect received requests
requests = client.list_sandbox_requests("sbx_abc123", limit: 20)

client.delete_sandbox_endpoint("sbx_abc123")
```

## Analytics

```ruby
events_chart = client.events_per_day(days: 30)
deliveries_chart = client.deliveries_per_day(days: 7)
topics = client.top_topics(limit: 5)
stats = client.webhook_stats
```

## Project and Token Management

```ruby
# Current project
project = client.get_project
client.update_project(name: "My Project v2")

# Topics
topics = client.list_topics

# API token
token = client.get_token
new_token = client.regenerate_token
```

## Multi-Project Management

```ruby
projects = client.list_projects
new_project = client.create_project("staging-env")
p = client.get_project_by_id("proj_abc123")
client.update_project_by_id("proj_abc123", name: "production-env")
client.set_default_project("proj_abc123")
client.delete_project("proj_abc123")
```

## Team Members

```ruby
members = client.list_members("proj_abc123")
member = client.add_member("proj_abc123", email: "alice@example.com", role: "admin")
client.update_member("proj_abc123", "mem_abc123", role: "viewer")
client.remove_member("proj_abc123", "mem_abc123")
```

## Invitations

```ruby
# List pending invitations
invitations = client.list_pending_invitations

# Accept or reject
client.accept_invitation("inv_abc123")
client.reject_invitation("inv_def456")
```

## Audit Logs

```ruby
logs = client.list_audit_logs(limit: 100)
next_page = client.list_audit_logs(cursor: logs["cursor"])
```

## Data Export

Export methods return raw strings (CSV or JSON).

```ruby
# Export as CSV
csv_data = client.export_events(format: "csv")
File.write("events.csv", csv_data)

# Export as JSON
json_data = client.export_deliveries(format: "json")

# Other exports
client.export_jobs(format: "csv")
client.export_audit_log(format: "csv")
```

## GDPR / Privacy

```ruby
# Consent management
consents = client.get_consents
client.accept_consent("marketing")

# Data portability
my_data = client.export_my_data

# Processing restrictions
client.restrict_processing
client.lift_restriction

# Right to object
client.object_to_processing
client.restore_consent
```

## Health Check

```ruby
health = client.health
status = client.status
```

## Error Handling

```ruby
require "jobcelis"

client = Jobcelis::Client.new(api_key: "your_api_key")

begin
  event = client.get_event("nonexistent")
rescue Jobcelis::Error => e
  puts "Status: #{e.status}"   # 404
  puts "Detail: #{e.detail}"   # {"message"=>"Not found"}
end
```

## Webhook Signature Verification

```ruby
require "jobcelis"

# Sinatra example
post "/webhook" do
  body = request.body.read
  signature = request.env["HTTP_X_SIGNATURE"]

  unless Jobcelis::WebhookVerifier.verify(
    secret: "your_webhook_secret",
    body: body,
    signature: signature
  )
    halt 401, "Invalid signature"
  end

  event = JSON.parse(body)
  puts "Received: #{event['topic']}"
  status 200
  "OK"
end
```

## License

MIT
