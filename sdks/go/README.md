# Jobcelis Go SDK

Go client for the [Jobcelis](https://jobcelis.com) Event Infrastructure Platform.

## Installation

```bash
go get github.com/vladimirCeli/go-jobcelis
```

## Quick Start

```go
package main

import (
    "context"
    "fmt"
    "log"

    jobcelis "github.com/vladimirCeli/go-jobcelis"
)

func main() {
    client := jobcelis.NewClient("your_api_key")

    // Send an event
    resp, err := client.SendEvent(context.Background(), jobcelis.EventRequest{
        Topic:   "order.created",
        Payload: map[string]interface{}{
            "order_id": "12345",
            "amount":   99.99,
        },
    })
    if err != nil {
        log.Fatal(err)
    }
    fmt.Printf("Event sent: %s\n", resp.EventID)
}
```

## Configuration

```go
// Custom base URL (staging or self-hosted)
client := jobcelis.NewClient("key").WithBaseURL("https://staging.jobcelis.com")

// Custom timeout
client := jobcelis.NewClient("key").WithTimeout(10 * time.Second)
```

## Webhook Signature Verification

```go
package main

import (
    "io"
    "net/http"

    jobcelis "github.com/vladimirCeli/go-jobcelis"
)

func webhookHandler(w http.ResponseWriter, r *http.Request) {
    body, _ := io.ReadAll(r.Body)
    signature := r.Header.Get("X-Signature")

    if !jobcelis.VerifySignature("your_secret", body, signature) {
        http.Error(w, "Invalid signature", http.StatusUnauthorized)
        return
    }

    // Process the webhook...
    w.WriteHeader(http.StatusOK)
}
```

## Resources

### Events

```go
ctx := context.Background()

// Send a single event
resp, err := client.SendEvent(ctx, jobcelis.EventRequest{
    Topic:   "order.created",
    Payload: map[string]interface{}{"order_id": "123"},
})

// Send a batch of events
batch, err := client.SendEvents(ctx, jobcelis.BatchRequest{
    Events: []jobcelis.EventRequest{
        {Topic: "order.created", Payload: map[string]interface{}{"id": "1"}},
        {Topic: "order.updated", Payload: map[string]interface{}{"id": "2"}},
    },
})
fmt.Printf("Accepted: %d, Rejected: %d\n", batch.Accepted, batch.Rejected)

// Get an event by ID
event, err := client.GetEvent(ctx, "event-id")

// List events with filters
params := url.Values{"topic": {"order.created"}, "limit": {"10"}}
events, err := client.ListEvents(ctx, params)
for _, e := range events.Data {
    fmt.Printf("%s: %s\n", e.ID, e.Topic)
}

// Delete an event
err = client.DeleteEvent(ctx, "event-id")
```

### Webhooks

```go
// Create a webhook
webhook, err := client.CreateWebhook(ctx, jobcelis.WebhookRequest{
    URL:    "https://example.com/webhook",
    Secret: "my-secret",
    Topics: []string{"order.created", "order.updated"},
})

// List all webhooks
webhooks, err := client.ListWebhooks(ctx)

// Get a webhook by ID
webhook, err := client.GetWebhook(ctx, "webhook-id")

// Update a webhook
updated, err := client.UpdateWebhook(ctx, "webhook-id", jobcelis.WebhookRequest{
    URL:    "https://example.com/new-webhook",
    Topics: []string{"order.*"},
})

// Delete a webhook
err = client.DeleteWebhook(ctx, "webhook-id")

// Check webhook health
health, err := client.WebhookHealth(ctx, "webhook-id")

// List available webhook templates
templates, err := client.WebhookTemplates(ctx)
```

### Deliveries

```go
// List deliveries with filters
params := url.Values{"status": {"failed"}, "webhook_id": {"wh-id"}}
deliveries, err := client.ListDeliveries(ctx, params)

// Retry a failed delivery
err = client.RetryDelivery(ctx, "delivery-id")
```

### Dead Letters

```go
// List dead-lettered events
deadLetters, err := client.ListDeadLetters(ctx, nil)

// Get a specific dead letter
dl, err := client.GetDeadLetter(ctx, "dead-letter-id")

// Retry a dead letter
err = client.RetryDeadLetter(ctx, "dead-letter-id")

// Mark as resolved
err = client.ResolveDeadLetter(ctx, "dead-letter-id")
```

### Replays

```go
// Create a replay
replay, err := client.CreateReplay(ctx, jobcelis.ReplayRequest{
    Topic:    "order.created",
    FromDate: "2026-01-01",
    ToDate:   "2026-01-31",
})

// List replays
replays, err := client.ListReplays(ctx, nil)

// Get replay status
replay, err := client.GetReplay(ctx, "replay-id")

// Cancel an in-progress replay
err = client.CancelReplay(ctx, "replay-id")
```

### Scheduled Jobs

```go
// Create a scheduled job
job, err := client.CreateJob(ctx, jobcelis.JobRequest{
    Name:           "Daily digest",
    Queue:          "scheduled_job",
    CronExpression: "0 9 * * *",
    Topics:         []string{"order.created"},
})

// List all jobs
jobs, err := client.ListJobs(ctx, nil)

// Get a job by ID
job, err := client.GetJob(ctx, "job-id")

// Update a job
updated, err := client.UpdateJob(ctx, "job-id", jobcelis.JobRequest{
    Name:           "Weekly digest",
    Queue:          "scheduled_job",
    CronExpression: "0 9 * * 1",
    Topics:         []string{"order.created"},
})

// Delete a job
err = client.DeleteJob(ctx, "job-id")

// List job runs
runs, err := client.ListJobRuns(ctx, "job-id", nil)

// Preview cron execution times
times, err := client.CronPreview(ctx, "0 9 * * *")
```

### Pipelines

```go
// Create a pipeline
pipeline, err := client.CreatePipeline(ctx, jobcelis.PipelineRequest{
    Name:        "Order processing",
    Description: "Process order events through multiple stages",
    Topics:      []string{"order.created"},
    Steps: []map[string]interface{}{
        {"type": "filter", "condition": "payload.amount > 100"},
        {"type": "transform", "template": "enriched"},
    },
})

// List pipelines
pipelines, err := client.ListPipelines(ctx, nil)

// Get a pipeline by ID
pipeline, err := client.GetPipeline(ctx, "pipeline-id")

// Update a pipeline
updated, err := client.UpdatePipeline(ctx, "pipeline-id", jobcelis.PipelineRequest{
    Name:        "Updated pipeline",
    Description: "Updated description",
    Topics:      []string{"order.*"},
    Steps:       []map[string]interface{}{{"type": "filter", "condition": "true"}},
})

// Delete a pipeline
err = client.DeletePipeline(ctx, "pipeline-id")
```

### Event Schemas

```go
// Create a schema
schema, err := client.CreateEventSchema(ctx, jobcelis.EventSchemaRequest{
    Topic:   "order.created",
    Version: "1.0",
    Schema: map[string]interface{}{
        "type": "object",
        "properties": map[string]interface{}{
            "order_id": map[string]interface{}{"type": "string"},
            "amount":   map[string]interface{}{"type": "number"},
        },
        "required": []string{"order_id", "amount"},
    },
})

// List schemas
schemas, err := client.ListEventSchemas(ctx, nil)

// Get schema by ID
schema, err := client.GetEventSchema(ctx, "schema-id")

// Update a schema
updated, err := client.UpdateEventSchema(ctx, "schema-id", jobcelis.EventSchemaRequest{
    Topic:   "order.created",
    Version: "1.1",
    Schema:  map[string]interface{}{"type": "object"},
})

// Delete a schema
err = client.DeleteEventSchema(ctx, "schema-id")

// Validate a payload against a schema
result, err := client.ValidatePayload(ctx, "order.created", map[string]interface{}{
    "order_id": "123",
    "amount":   99.99,
})
```

### Sandbox

```go
// List sandbox endpoints
endpoints, err := client.ListSandboxEndpoints(ctx)

// Create a sandbox endpoint
endpoint, err := client.CreateSandboxEndpoint(ctx, "my-test-endpoint")

// List captured requests
requests, err := client.ListSandboxRequests(ctx, "endpoint-id", nil)

// Delete a sandbox endpoint
err = client.DeleteSandboxEndpoint(ctx, "endpoint-id")
```

### Analytics

```go
// Events per day (last 30 days)
points, err := client.EventsPerDay(ctx, 30)
for _, p := range points {
    fmt.Printf("%s: %d events\n", p.Date, p.Count)
}

// Deliveries per day
deliveryPoints, err := client.DeliveriesPerDay(ctx, 7)

// Top topics by event count
topics, err := client.TopTopics(ctx, 10)
for _, t := range topics {
    fmt.Printf("%s: %d\n", t.Topic, t.Count)
}

// Webhook delivery statistics
stats, err := client.WebhookStats(ctx)
for _, s := range stats {
    fmt.Printf("Webhook %s: %d total, %d success, %d failed\n",
        s.WebhookID, s.Total, s.Success, s.Failed)
}
```

### Projects

```go
// List all projects
projects, err := client.ListProjects(ctx)

// Create a project
project, err := client.CreateProject(ctx, jobcelis.ProjectRequest{Name: "My Project"})

// Get a project by ID
project, err := client.GetProject(ctx, "project-id")

// Update a project
updated, err := client.UpdateProject(ctx, "project-id", jobcelis.ProjectRequest{
    Name: "Renamed Project",
})

// Delete a project
err = client.DeleteProject(ctx, "project-id")

// Set a project as the default
err = client.SetDefaultProject(ctx, "project-id")
```

### Teams

```go
// List members for a project
members, err := client.ListMembers(ctx, "project-id")

// Add a member
member, err := client.AddMember(ctx, "project-id", "user@example.com", "editor")

// Update a member's role
updated, err := client.UpdateMember(ctx, "project-id", "member-id", "admin")

// Remove a member
err = client.RemoveMember(ctx, "project-id", "member-id")
```

### Audit Logs

```go
// List audit logs with filters
params := url.Values{"action": {"webhook.created"}, "limit": {"50"}}
logs, err := client.ListAuditLogs(ctx, params)
for _, log := range logs.Data {
    fmt.Printf("[%s] %s by %s\n", log.InsertedAt, log.Action, log.ActorID)
}
```

### Export

```go
// Export events as CSV
csvData, err := client.ExportEvents(ctx)
os.WriteFile("events.csv", csvData, 0644)

// Export deliveries as CSV
csvData, err = client.ExportDeliveries(ctx)

// Export jobs as CSV
csvData, err = client.ExportJobs(ctx)

// Export audit log as CSV
csvData, err = client.ExportAuditLog(ctx)
```

### Simulate

```go
// Simulate an event (testing without persisting)
result, err := client.SimulateEvent(ctx, "order.created", map[string]interface{}{
    "order_id": "test-123",
    "amount":   49.99,
})
```

### GDPR

```go
// Get current consent records
consents, err := client.GetConsents(ctx)

// Accept a consent purpose
err = client.AcceptConsent(ctx, "analytics")

// Export personal data (right of access)
data, err := client.ExportMyData(ctx)

// Restrict processing (Article 18)
err = client.RestrictProcessing(ctx)

// Lift restriction
err = client.LiftRestriction(ctx)

// Object to processing (Article 21)
err = client.ObjectToProcessing(ctx)

// Withdraw objection
err = client.RestoreConsent(ctx)
```

### Health

```go
health, err := client.Health(ctx)
fmt.Printf("Status: %s\n", health["status"])
```

## Error Handling

All methods return errors that may be of type `*jobcelis.APIError`, which includes the HTTP status code and error message:

```go
event, err := client.GetEvent(ctx, "nonexistent-id")
if err != nil {
    var apiErr *jobcelis.APIError
    if errors.As(err, &apiErr) {
        fmt.Printf("API error %d: %s\n", apiErr.StatusCode, apiErr.Message)
    } else {
        fmt.Printf("Network error: %s\n", err)
    }
}
```

## API Methods Reference

| Category | Method | Description |
|----------|--------|-------------|
| **Events** | `SendEvent(ctx, req)` | Send a single event |
| | `SendEvents(ctx, req)` | Send a batch of events |
| | `GetEvent(ctx, id)` | Get event by ID |
| | `ListEvents(ctx, params)` | List events (paginated) |
| | `DeleteEvent(ctx, id)` | Delete an event |
| **Webhooks** | `CreateWebhook(ctx, req)` | Create a webhook |
| | `ListWebhooks(ctx)` | List all webhooks |
| | `GetWebhook(ctx, id)` | Get webhook by ID |
| | `UpdateWebhook(ctx, id, req)` | Update a webhook |
| | `DeleteWebhook(ctx, id)` | Delete a webhook |
| | `WebhookHealth(ctx, id)` | Check webhook health |
| | `WebhookTemplates(ctx)` | List webhook templates |
| **Deliveries** | `ListDeliveries(ctx, params)` | List deliveries |
| | `RetryDelivery(ctx, id)` | Retry a delivery |
| **Dead Letters** | `ListDeadLetters(ctx, params)` | List dead letters |
| | `GetDeadLetter(ctx, id)` | Get dead letter by ID |
| | `RetryDeadLetter(ctx, id)` | Retry a dead letter |
| | `ResolveDeadLetter(ctx, id)` | Resolve a dead letter |
| **Replays** | `CreateReplay(ctx, req)` | Create a replay |
| | `ListReplays(ctx, params)` | List replays |
| | `GetReplay(ctx, id)` | Get replay by ID |
| | `CancelReplay(ctx, id)` | Cancel a replay |
| **Jobs** | `CreateJob(ctx, req)` | Create a scheduled job |
| | `ListJobs(ctx, params)` | List jobs |
| | `GetJob(ctx, id)` | Get job by ID |
| | `UpdateJob(ctx, id, req)` | Update a job |
| | `DeleteJob(ctx, id)` | Delete a job |
| | `ListJobRuns(ctx, jobId, params)` | List job runs |
| | `CronPreview(ctx, expr)` | Preview cron schedule |
| **Pipelines** | `CreatePipeline(ctx, req)` | Create a pipeline |
| | `ListPipelines(ctx, params)` | List pipelines |
| | `GetPipeline(ctx, id)` | Get pipeline by ID |
| | `UpdatePipeline(ctx, id, req)` | Update a pipeline |
| | `DeletePipeline(ctx, id)` | Delete a pipeline |
| **Schemas** | `CreateEventSchema(ctx, req)` | Create an event schema |
| | `ListEventSchemas(ctx, params)` | List event schemas |
| | `GetEventSchema(ctx, id)` | Get schema by ID |
| | `UpdateEventSchema(ctx, id, req)` | Update a schema |
| | `DeleteEventSchema(ctx, id)` | Delete a schema |
| | `ValidatePayload(ctx, topic, payload)` | Validate against schema |
| **Sandbox** | `ListSandboxEndpoints(ctx)` | List sandbox endpoints |
| | `CreateSandboxEndpoint(ctx, name)` | Create sandbox endpoint |
| | `DeleteSandboxEndpoint(ctx, id)` | Delete sandbox endpoint |
| | `ListSandboxRequests(ctx, id, params)` | List captured requests |
| **Analytics** | `EventsPerDay(ctx, days)` | Events per day |
| | `DeliveriesPerDay(ctx, days)` | Deliveries per day |
| | `TopTopics(ctx, limit)` | Top topics by count |
| | `WebhookStats(ctx)` | Webhook delivery stats |
| **Projects** | `ListProjects(ctx)` | List all projects |
| | `CreateProject(ctx, req)` | Create a project |
| | `GetProject(ctx, id)` | Get project by ID |
| | `UpdateProject(ctx, id, req)` | Update a project |
| | `DeleteProject(ctx, id)` | Delete a project |
| | `SetDefaultProject(ctx, id)` | Set default project |
| **Teams** | `ListMembers(ctx, projectId)` | List project members |
| | `AddMember(ctx, projectId, email, role)` | Add a member |
| | `UpdateMember(ctx, projectId, memberId, role)` | Update member role |
| | `RemoveMember(ctx, projectId, memberId)` | Remove a member |
| **Audit** | `ListAuditLogs(ctx, params)` | List audit log entries |
| **Export** | `ExportEvents(ctx)` | Export events as CSV |
| | `ExportDeliveries(ctx)` | Export deliveries as CSV |
| | `ExportJobs(ctx)` | Export jobs as CSV |
| | `ExportAuditLog(ctx)` | Export audit log as CSV |
| **Simulate** | `SimulateEvent(ctx, topic, payload)` | Simulate an event |
| **GDPR** | `GetConsents(ctx)` | Get consent records |
| | `AcceptConsent(ctx, purpose)` | Accept a consent |
| | `ExportMyData(ctx)` | Export personal data |
| | `RestrictProcessing(ctx)` | Restrict processing |
| | `LiftRestriction(ctx)` | Lift restriction |
| | `ObjectToProcessing(ctx)` | Object to processing |
| | `RestoreConsent(ctx)` | Withdraw objection |
| **Health** | `Health(ctx)` | Check platform health |

## License

MIT
