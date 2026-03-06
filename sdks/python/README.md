# jobcelis

Official Python SDK for the Jobcelis Event Infrastructure Platform.

## Installation

```bash
pip install jobcelis
```

## Quick Start

```python
from jobcelis import JobcelisClient

client = JobcelisClient(
    api_key="your_api_key",
    base_url="https://jobcelis.com",  # optional
)
```

## Events

```python
# Send a single event
event = client.send_event("order.created", {"order_id": "123", "amount": 99.99})

# Send batch events (up to 1000)
batch = client.send_events([
    {"topic": "order.created", "payload": {"order_id": "1"}},
    {"topic": "order.created", "payload": {"order_id": "2"}},
])

# List events with pagination
events = client.list_events(limit=25)
next_page = client.list_events(limit=25, cursor=events["cursor"])

# Get / delete a single event
event = client.get_event("evt_abc123")
client.delete_event("evt_abc123")
```

## Webhooks

```python
# Create a webhook
webhook = client.create_webhook(
    url="https://example.com/webhook",
    topics=["order.*"],
)

# List, get, update, delete
webhooks = client.list_webhooks()
wh = client.get_webhook("wh_abc123")
client.update_webhook("wh_abc123", url="https://new-url.com/hook")
client.delete_webhook("wh_abc123")

# Health and templates
health = client.webhook_health("wh_abc123")
templates = client.webhook_templates()
```

## Deliveries

```python
deliveries = client.list_deliveries(limit=20, status="failed")
client.retry_delivery("del_abc123")
```

## Dead Letters

```python
dead_letters = client.list_dead_letters()
dl = client.get_dead_letter("dlq_abc123")
client.retry_dead_letter("dlq_abc123")
client.resolve_dead_letter("dlq_abc123")
```

## Replays

```python
replay = client.create_replay(
    topic="order.created",
    from_date="2026-01-01T00:00:00Z",
    to_date="2026-01-31T23:59:59Z",
    webhook_id="wh_abc123",  # optional
)
replays = client.list_replays()
r = client.get_replay("rpl_abc123")
client.cancel_replay("rpl_abc123")
```

## Scheduled Jobs

```python
# Create a job
job = client.create_job(
    name="daily-report",
    queue="default",
    cron_expression="0 9 * * *",
    payload={"type": "daily"},
)

# CRUD
jobs = client.list_jobs(limit=10)
job = client.get_job("job_abc123")
client.update_job("job_abc123", cron_expression="0 10 * * *")
client.delete_job("job_abc123")

# List runs for a job
runs = client.list_job_runs("job_abc123", limit=20)

# Preview cron schedule
preview = client.cron_preview("0 9 * * *", count=10)
```

## Pipelines

```python
pipeline = client.create_pipeline(
    name="order-processing",
    topics=["order.created"],
    steps=[
        {"type": "filter", "config": {"field": "amount", "gt": 100}},
        {"type": "transform", "config": {"add_field": "priority", "value": "high"}},
    ],
)

pipelines = client.list_pipelines()
p = client.get_pipeline("pipe_abc123")
client.update_pipeline("pipe_abc123", name="order-processing-v2")
client.delete_pipeline("pipe_abc123")

# Test a pipeline with a sample payload
result = client.test_pipeline("pipe_abc123", {"topic": "order.created", "payload": {"id": "1"}})
```

## Invitations

```python
# List pending invitations
invitations = client.list_pending_invitations()

# Accept or reject
client.accept_invitation("inv_abc123")
client.reject_invitation("inv_def456")
```

## Event Schemas

```python
schema = client.create_event_schema(
    topic="order.created",
    schema={
        "type": "object",
        "properties": {
            "order_id": {"type": "string"},
            "amount": {"type": "number"},
        },
        "required": ["order_id", "amount"],
    },
)

schemas = client.list_event_schemas()
s = client.get_event_schema("sch_abc123")
client.update_event_schema("sch_abc123", schema={"type": "object"})
client.delete_event_schema("sch_abc123")

# Validate a payload against a topic's schema
result = client.validate_payload("order.created", {"order_id": "123", "amount": 50})
```

## Sandbox

```python
# Create a temporary endpoint for testing
endpoint = client.create_sandbox_endpoint(name="my-test")
endpoints = client.list_sandbox_endpoints()

# Inspect received requests
requests = client.list_sandbox_requests("sbx_abc123", limit=20)

client.delete_sandbox_endpoint("sbx_abc123")
```

## Analytics

```python
events_chart = client.events_per_day(days=30)
deliveries_chart = client.deliveries_per_day(days=7)
topics = client.top_topics(limit=5)
stats = client.webhook_stats()
```

## Project and Token Management

```python
# Current project
project = client.get_project()
client.update_project(name="My Project v2")

# Topics
topics = client.list_topics()

# API token
token = client.get_token()
new_token = client.regenerate_token()
```

## Multi-Project Management

```python
projects = client.list_projects()
new_project = client.create_project("staging-env")
p = client.get_project_by_id("proj_abc123")
client.update_project_by_id("proj_abc123", name="production-env")
client.set_default_project("proj_abc123")
client.delete_project("proj_abc123")
```

## Team Members

```python
members = client.list_members("proj_abc123")
member = client.add_member("proj_abc123", "alice@example.com", role="admin")
client.update_member("proj_abc123", "mem_abc123", role="viewer")
client.remove_member("proj_abc123", "mem_abc123")
```

## Audit Logs

```python
logs = client.list_audit_logs(limit=100)
next_page = client.list_audit_logs(cursor=logs["cursor"])
```

## Data Export

Export methods return raw bytes (CSV or JSON).

```python
# Export as CSV
csv_data = client.export_events(format="csv")
with open("events.csv", "wb") as f:
    f.write(csv_data)

# Export as JSON
json_data = client.export_deliveries(format="json")

# Other exports
client.export_jobs(format="csv")
client.export_audit_log(format="csv")
```

## Simulate

```python
# Dry-run an event to see which webhooks would fire
result = client.simulate_event("order.created", {"order_id": "test"})
```

## GDPR / Privacy

```python
# Consent management
consents = client.get_consents()
client.accept_consent("marketing")

# Data portability
my_data = client.export_my_data()

# Processing restrictions
client.restrict_processing()
client.lift_restriction()

# Right to object
client.object_to_processing()
client.restore_consent()
```

## Health Check

```python
health = client.health()
status = client.status()
```

## Error Handling

```python
from jobcelis import JobcelisClient, JobcelisError

client = JobcelisClient(api_key="your_api_key")

try:
    event = client.get_event("nonexistent")
except JobcelisError as e:
    print(f"Status: {e.status}")   # 404
    print(f"Detail: {e.detail}")   # {"message": "Not found"}
```

## Webhook Signature Verification

```python
from jobcelis import verify_webhook_signature

# Flask example
@app.route('/webhook', methods=['POST'])
def handle_webhook():
    is_valid = verify_webhook_signature(
        secret='your_webhook_secret',
        body=request.get_data(as_text=True),
        signature=request.headers.get('X-Signature', '')
    )

    if not is_valid:
        return 'Invalid signature', 401

    event = request.get_json()
    print(f"Received: {event['topic']}")
    return 'OK', 200
```

## License

MIT
