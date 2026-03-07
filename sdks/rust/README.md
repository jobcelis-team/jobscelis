# jobcelis

Official Rust SDK for the [Jobcelis](https://jobcelis.com) Event Infrastructure Platform.

All API calls go to `https://jobcelis.com` by default -- you only need your API key to get started.

## Installation

Add to your `Cargo.toml`:

```toml
[dependencies]
jobcelis = "1"
tokio = { version = "1", features = ["full"] }
serde_json = "1"
```

## Quick Start

```rust
use jobcelis::JobcelisClient;
use serde_json::json;

#[tokio::main]
async fn main() -> Result<(), jobcelis::JobcelisError> {
    // Only your API key is required -- connects to https://jobcelis.com automatically
    let client = JobcelisClient::new("your_api_key");

    let event = client.send_event("order.created", json!({"order_id": "123"})).await?;
    println!("{:?}", event);
    Ok(())
}
```

> **Custom URL:** If you're self-hosting Jobcelis, you can override the base URL:
> ```rust
> let client = JobcelisClient::with_base_url("your_api_key", "https://your-instance.example.com");
> ```

## Authentication

The auth methods do not require an API key. Use them to register, log in, and manage JWT tokens.

```rust
let client = JobcelisClient::new("");

// Register a new account
let user = client.register("alice@example.com", "SecurePass123!", Some("Alice")).await?;

// Log in -- returns JWT access token and refresh token
let session = client.login("alice@example.com", "SecurePass123!").await?;
let access_token = session["token"].as_str().unwrap();
let refresh_tok = session["refresh_token"].as_str().unwrap();

// Set the JWT for subsequent authenticated calls
let mut client = client;
client.set_auth_token(access_token);

// Refresh an expired token
let new_session = client.refresh_token(refresh_tok).await?;
client.set_auth_token(new_session["token"].as_str().unwrap());

// Verify MFA (requires auth token already set)
let result = client.verify_mfa(access_token, "123456").await?;
```

## Events

```rust
// Send a single event
let event = client.send_event("order.created", json!({"order_id": "123", "amount": 99.99})).await?;

// Send batch events (up to 1000)
let batch = client.send_events(vec![
    json!({"topic": "order.created", "payload": {"order_id": "1"}}),
    json!({"topic": "order.created", "payload": {"order_id": "2"}}),
]).await?;

// List events with pagination
let events = client.list_events(25, None).await?;
let cursor = events["cursor"].as_str();
let next_page = client.list_events(25, cursor).await?;

// Get / delete a single event
let event = client.get_event("evt_abc123").await?;
client.delete_event("evt_abc123").await?;
```

## Simulate

```rust
let result = client.simulate_event("order.created", json!({"order_id": "test"})).await?;
```

## Webhooks

```rust
// Create a webhook
let webhook = client.create_webhook("https://example.com/webhook",
    Some(json!({"topics": ["order.*"]}))).await?;

// List, get, update, delete
let webhooks = client.list_webhooks(50, None).await?;
let wh = client.get_webhook("wh_abc123").await?;
client.update_webhook("wh_abc123", json!({"url": "https://new-url.com/hook"})).await?;
client.delete_webhook("wh_abc123").await?;

// Health and templates
let health = client.webhook_health("wh_abc123").await?;
let templates = client.webhook_templates().await?;
```

## Deliveries

```rust
let deliveries = client.list_deliveries(20, None, Some("failed")).await?;
client.retry_delivery("del_abc123").await?;
```

## Dead Letters

```rust
let dead_letters = client.list_dead_letters(50, None).await?;
let dl = client.get_dead_letter("dlq_abc123").await?;
client.retry_dead_letter("dlq_abc123").await?;
client.resolve_dead_letter("dlq_abc123").await?;
```

## Replays

```rust
let replay = client.create_replay(
    "order.created",
    "2026-01-01T00:00:00Z",
    "2026-01-31T23:59:59Z",
    Some("wh_abc123"),  // optional
).await?;
let replays = client.list_replays(50, None).await?;
let r = client.get_replay("rpl_abc123").await?;
client.cancel_replay("rpl_abc123").await?;
```

## Scheduled Jobs

```rust
// Create a job
let job = client.create_job("daily-report", "default", "0 9 * * *",
    Some(json!({"payload": {"type": "daily"}}))).await?;

// CRUD
let jobs = client.list_jobs(10, None).await?;
let job = client.get_job("job_abc123").await?;
client.update_job("job_abc123", json!({"cron_expression": "0 10 * * *"})).await?;
client.delete_job("job_abc123").await?;

// List runs for a job
let runs = client.list_job_runs("job_abc123", 20).await?;

// Preview cron schedule
let preview = client.cron_preview("0 9 * * *", 10).await?;
```

## Pipelines

```rust
let pipeline = client.create_pipeline("order-processing",
    vec!["order.created"],
    vec![
        json!({"type": "filter", "config": {"field": "amount", "gt": 100}}),
        json!({"type": "transform", "config": {"add_field": "priority", "value": "high"}}),
    ],
).await?;

let pipelines = client.list_pipelines(50, None).await?;
let p = client.get_pipeline("pipe_abc123").await?;
client.update_pipeline("pipe_abc123", json!({"name": "order-processing-v2"})).await?;
client.delete_pipeline("pipe_abc123").await?;

// Test a pipeline with a sample payload
let result = client.test_pipeline("pipe_abc123",
    json!({"topic": "order.created", "payload": {"id": "1"}})).await?;
```

## Event Schemas

```rust
let schema = client.create_event_schema("order.created", json!({
    "type": "object",
    "properties": {
        "order_id": {"type": "string"},
        "amount": {"type": "number"},
    },
    "required": ["order_id", "amount"],
})).await?;

let schemas = client.list_event_schemas(50, None).await?;
let s = client.get_event_schema("sch_abc123").await?;
client.update_event_schema("sch_abc123", json!({"schema": {"type": "object"}})).await?;
client.delete_event_schema("sch_abc123").await?;

// Validate a payload against a topic's schema
let result = client.validate_payload("order.created", json!({"order_id": "123", "amount": 50})).await?;
```

## Sandbox

```rust
let endpoint = client.create_sandbox_endpoint(Some("my-test")).await?;
let endpoints = client.list_sandbox_endpoints().await?;
let requests = client.list_sandbox_requests("sbx_abc123", 20).await?;
client.delete_sandbox_endpoint("sbx_abc123").await?;
```

## Analytics

```rust
let events_chart = client.events_per_day(30).await?;
let deliveries_chart = client.deliveries_per_day(7).await?;
let topics = client.top_topics(5).await?;
let stats = client.webhook_stats().await?;
```

## Project and Token Management

```rust
let project = client.get_project().await?;
client.update_project(json!({"name": "My Project v2"})).await?;
let topics = client.list_topics().await?;
let token = client.get_token().await?;
let new_token = client.regenerate_token().await?;
```

## Multi-Project Management

```rust
let projects = client.list_projects().await?;
let new_project = client.create_project("staging-env").await?;
let p = client.get_project_by_id("proj_abc123").await?;
client.update_project_by_id("proj_abc123", json!({"name": "production-env"})).await?;
client.set_default_project("proj_abc123").await?;
client.delete_project("proj_abc123").await?;
```

## Team Members

```rust
let members = client.list_members("proj_abc123").await?;
let member = client.add_member("proj_abc123", "alice@example.com", Some("admin")).await?;
client.update_member("proj_abc123", "mem_abc123", "viewer").await?;
client.remove_member("proj_abc123", "mem_abc123").await?;
```

## Invitations

```rust
let invitations = client.list_pending_invitations().await?;
client.accept_invitation("inv_abc123").await?;
client.reject_invitation("inv_def456").await?;
```

## Audit Logs

```rust
let logs = client.list_audit_logs(100, None).await?;
```

## Data Export

```rust
let csv_data = client.export_events("csv").await?;
std::fs::write("events.csv", &csv_data).unwrap();

let json_data = client.export_deliveries("json").await?;
client.export_jobs("csv").await?;
client.export_audit_log("csv").await?;
```

## GDPR / Privacy

```rust
let consents = client.get_consents().await?;
client.accept_consent("marketing").await?;
let my_data = client.export_my_data().await?;
client.restrict_processing().await?;
client.lift_restriction().await?;
client.object_to_processing().await?;
client.restore_consent().await?;
```

## Health Check

```rust
let health = client.health().await?;
let status = client.status().await?;
```

## Error Handling

```rust
use jobcelis::{JobcelisClient, JobcelisError};

let client = JobcelisClient::new("your_api_key");

match client.get_event("nonexistent").await {
    Ok(event) => println!("{:?}", event),
    Err(JobcelisError::Api { status, detail }) => {
        println!("Status: {status}");
        println!("Detail: {detail}");
    }
    Err(e) => println!("Error: {e}"),
}
```

## Webhook Signature Verification

```rust
use jobcelis::verify_webhook_signature;

let body = r#"{"topic":"order.created"}"#;
let signature = "...";

if verify_webhook_signature("your_webhook_secret", body, signature) {
    println!("Valid signature!");
} else {
    println!("Invalid signature!");
}
```

## License

MIT
