# Jobcelis Go SDK

Go client for the [Jobcelis](https://jobcelis.com) Event Infrastructure Platform.

Covers 100% of the Jobcelis REST API: events, webhooks, deliveries, dead letters, replays, jobs, pipelines, event schemas, sandbox, analytics, project management, teams, invitations, audit logs, exports, simulation, GDPR, auth, and health.

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

    ctx := context.Background()

    // Send an event
    resp, err := client.SendEvent(ctx, jobcelis.EventRequest{
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
// Custom base URL (self-hosted)
client := jobcelis.NewClient("key").WithBaseURL("https://your-instance.example.com")

// Custom timeout
client := jobcelis.NewClient("key").WithTimeout(10 * time.Second)
```

## Authentication

The SDK supports two authentication modes:

1. **API Key** (default) -- for project-scoped endpoints (events, webhooks, deliveries, etc.). Set via `NewClient("your_api_key")`.
2. **Bearer Token** -- for user-scoped endpoints (projects multi, teams, invitations, GDPR). Obtained via `Login` or `Register`, then set via `SetAuthToken`.

```go
client := jobcelis.NewClient("your_api_key")

// For user-scoped endpoints, authenticate first:
authResp, err := client.Login(ctx, "user@example.com", "password123")
if err != nil {
    log.Fatal(err)
}

// If MFA is required, verify the TOTP code:
if authResp.MFARequired {
    authResp, err = client.VerifyMFA(ctx, authResp.MFAToken, "123456")
    if err != nil {
        log.Fatal(err)
    }
}

// Set the Bearer token for subsequent calls
client.SetAuthToken(authResp.Token)

// Now you can call user-scoped endpoints
projects, err := client.ListProjects(ctx)
```

## Auth

Auth endpoints are public (no API key or Bearer token required). They return JWT tokens.

```go
ctx := context.Background()

// Register a new account
authResp, err := client.Register(ctx, "user@example.com", "SecurePass123!", "Jane Doe")
fmt.Printf("Token: %s\n", authResp.Token)

// Login
authResp, err = client.Login(ctx, "user@example.com", "SecurePass123!")

// Handle MFA if required
if authResp.MFARequired {
    authResp, err = client.VerifyMFA(ctx, authResp.MFAToken, "123456")
}

// Refresh an expired token
refreshed, err := client.RefreshToken(ctx, authResp.RefreshToken)
fmt.Printf("New token: %s\n", refreshed.Token)

// Set token for user-scoped endpoints
client.SetAuthToken(authResp.Token)
```

## Events

```go
ctx := context.Background()

// Send a single event
resp, err := client.SendEvent(ctx, jobcelis.EventRequest{
    Topic:   "order.created",
    Payload: map[string]interface{}{"order_id": "123", "amount": 99.99},
})
fmt.Printf("Event ID: %s\n", resp.EventID)

// Send a single event with idempotency key
resp, err = client.SendEvent(ctx, jobcelis.EventRequest{
    Topic:          "order.created",
    Payload:        map[string]interface{}{"order_id": "123"},
    IdempotencyKey: "unique-key-123",
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
fmt.Printf("Topic: %s, Status: %s\n", event.Topic, event.Status)

// List events with filters
params := url.Values{"topic": {"order.created"}, "limit": {"10"}}
events, err := client.ListEvents(ctx, params)
for _, e := range events.Data {
    fmt.Printf("%s: %s\n", e.ID, e.Topic)
}

// Paginate through events
if events.HasNext {
    params.Set("cursor", events.NextCursor)
    nextPage, err := client.ListEvents(ctx, params)
    _ = nextPage
    _ = err
}

// Delete an event
err = client.DeleteEvent(ctx, "event-id")
```

## Webhooks

```go
ctx := context.Background()

// Create a webhook
webhook, err := client.CreateWebhook(ctx, jobcelis.WebhookRequest{
    URL:    "https://example.com/webhook",
    Secret: "my-secret",
    Topics: []string{"order.created", "order.updated"},
    Headers: map[string]string{"X-Custom": "value"},
})
fmt.Printf("Webhook ID: %s\n", webhook.ID)

// List all webhooks
webhooks, err := client.ListWebhooks(ctx)
for _, wh := range webhooks {
    fmt.Printf("%s -> %s\n", wh.ID, wh.URL)
}

// Get a webhook by ID
webhook, err = client.GetWebhook(ctx, "webhook-id")

// Update a webhook
updated, err := client.UpdateWebhook(ctx, "webhook-id", jobcelis.WebhookRequest{
    URL:    "https://example.com/new-webhook",
    Topics: []string{"order.*"},
})

// Delete a webhook
err = client.DeleteWebhook(ctx, "webhook-id")

// Check webhook health
health, err := client.WebhookHealth(ctx, "webhook-id")
fmt.Printf("Health: %v\n", health)

// List available webhook templates
templates, err := client.WebhookTemplates(ctx)
for _, t := range templates {
    fmt.Printf("Template: %v\n", t["name"])
}
```

## Deliveries

```go
ctx := context.Background()

// List deliveries with filters
params := url.Values{"status": {"failed"}, "webhook_id": {"wh-id"}}
deliveries, err := client.ListDeliveries(ctx, params)
for _, d := range deliveries.Data {
    fmt.Printf("Delivery %s: status=%s attempt=%d latency=%dms\n", d.ID, d.Status, d.AttemptNumber, *d.ResponseLatencyMs)
}

// List all deliveries (no filters)
allDeliveries, err := client.ListDeliveries(ctx, nil)
_ = allDeliveries

// Retry a failed delivery
err = client.RetryDelivery(ctx, "delivery-id")
```

## Dead Letters

```go
ctx := context.Background()

// List dead-lettered events
deadLetters, err := client.ListDeadLetters(ctx, nil)
for _, dl := range deadLetters.Data {
    fmt.Printf("Dead letter %s: event=%s error=%s\n", dl.ID, dl.EventID, dl.Error)
}

// List with filters
params := url.Values{"webhook_id": {"wh-id"}}
filtered, err := client.ListDeadLetters(ctx, params)
_ = filtered

// Get a specific dead letter
dl, err := client.GetDeadLetter(ctx, "dead-letter-id")
fmt.Printf("Resolved: %v\n", dl.Resolved)

// Retry a dead letter
err = client.RetryDeadLetter(ctx, "dead-letter-id")

// Mark as resolved
err = client.ResolveDeadLetter(ctx, "dead-letter-id")
```

## Replays

```go
ctx := context.Background()

// Create a replay
replay, err := client.CreateReplay(ctx, jobcelis.ReplayRequest{
    Topic:    "order.created",
    FromDate: "2026-01-01",
    ToDate:   "2026-01-31",
})
fmt.Printf("Replay ID: %s, Status: %s\n", replay.ID, replay.Status)

// Create a replay for a specific webhook
webhookID := "wh-id"
replay, err = client.CreateReplay(ctx, jobcelis.ReplayRequest{
    Topic:     "order.created",
    FromDate:  "2026-01-01",
    ToDate:    "2026-01-31",
    WebhookID: &webhookID,
})

// List replays
replays, err := client.ListReplays(ctx, nil)
for _, r := range replays.Data {
    fmt.Printf("%s: %d/%d events\n", r.ID, r.ProcessedEvents, r.TotalEvents)
}

// Get replay status
replay, err = client.GetReplay(ctx, "replay-id")

// Cancel an in-progress replay
err = client.CancelReplay(ctx, "replay-id")
```

## Jobs

```go
ctx := context.Background()

// Create a scheduled job
job, err := client.CreateJob(ctx, jobcelis.JobRequest{
    Name:           "Daily digest",
    Queue:          "scheduled_job",
    CronExpression: "0 9 * * *",
    Topics:         []string{"order.created"},
})
fmt.Printf("Job ID: %s\n", job.ID)

// List all jobs
jobs, err := client.ListJobs(ctx, nil)
for _, j := range jobs.Data {
    fmt.Printf("%s: %s (%s)\n", j.ID, j.Name, j.Status)
}

// Get a job by ID
job, err = client.GetJob(ctx, "job-id")

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
for _, r := range runs.Data {
    fmt.Printf("Run %s: %s\n", r.ID, r.Status)
}

// Preview cron execution times
times, err := client.CronPreview(ctx, "0 9 * * *")
for _, t := range times {
    fmt.Println(t)
}
```

## Pipelines

```go
ctx := context.Background()

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
fmt.Printf("Pipeline ID: %s\n", pipeline.ID)

// List pipelines
pipelines, err := client.ListPipelines(ctx, nil)
for _, p := range pipelines.Data {
    fmt.Printf("%s: %s (%s)\n", p.ID, p.Name, p.Status)
}

// Get a pipeline by ID
pipeline, err = client.GetPipeline(ctx, "pipeline-id")

// Update a pipeline
updated, err := client.UpdatePipeline(ctx, "pipeline-id", jobcelis.PipelineRequest{
    Name:        "Updated pipeline",
    Description: "Updated description",
    Topics:      []string{"order.*"},
    Steps:       []map[string]interface{}{{"type": "filter", "condition": "true"}},
})

// Delete a pipeline
err = client.DeletePipeline(ctx, "pipeline-id")

// Test a pipeline with a sample payload
result, err := client.TestPipeline(ctx, "pipeline-id", map[string]interface{}{
    "order_id": "test-123",
    "amount":   150.00,
})
fmt.Printf("Test result: %v\n", result)
```

## Event Schemas

```go
ctx := context.Background()

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
fmt.Printf("Schema ID: %s\n", schema.ID)

// List schemas
schemas, err := client.ListEventSchemas(ctx, nil)
for _, s := range schemas.Data {
    fmt.Printf("%s: %s v%s\n", s.ID, s.Topic, s.Version)
}

// Get schema by ID
schema, err = client.GetEventSchema(ctx, "schema-id")

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
fmt.Printf("Valid: %v\n", result)
```

## Sandbox

```go
ctx := context.Background()

// List sandbox endpoints
endpoints, err := client.ListSandboxEndpoints(ctx)
for _, ep := range endpoints {
    fmt.Printf("%s: %s (slug: %s)\n", ep.ID, ep.Name, ep.Slug)
}

// Create a sandbox endpoint
endpoint, err := client.CreateSandboxEndpoint(ctx, "my-test-endpoint")
fmt.Printf("Created: %s\n", endpoint.ID)

// List captured requests for an endpoint
requests, err := client.ListSandboxRequests(ctx, "endpoint-id", nil)
for _, r := range requests.Data {
    fmt.Printf("[%s] %s %s\n", r.InsertedAt, r.Method, r.Path)
}

// List with pagination
params := url.Values{"limit": {"20"}}
requests, err = client.ListSandboxRequests(ctx, "endpoint-id", params)

// Delete a sandbox endpoint
err = client.DeleteSandboxEndpoint(ctx, "endpoint-id")
```

## Analytics

```go
ctx := context.Background()

// Events per day (last 30 days)
points, err := client.EventsPerDay(ctx, 30)
for _, p := range points {
    fmt.Printf("%s: %d events\n", p.Date, p.Count)
}

// Deliveries per day (last 7 days)
deliveryPoints, err := client.DeliveriesPerDay(ctx, 7)
for _, p := range deliveryPoints {
    fmt.Printf("%s: %d deliveries\n", p.Date, p.Count)
}

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

## Project (Current)

These endpoints operate on the project scoped by your API key.

```go
ctx := context.Background()

// Get the current project
project, err := client.GetCurrentProject(ctx)
fmt.Printf("Project: %s (%s)\n", project.Name, project.ID)

// Update the current project
updated, err := client.UpdateCurrentProject(ctx, map[string]interface{}{
    "name": "Renamed Project",
})
fmt.Printf("Updated: %s\n", updated.Name)

// List all topics in the current project
topics, err := client.ListTopics(ctx)
for _, t := range topics {
    fmt.Printf("Topic: %s (%d events)\n", t.Name, t.EventCount)
}

// Get API token metadata
token, err := client.GetToken(ctx)
fmt.Printf("Token: %s\n", token.Token)

// Regenerate the API token (invalidates the current one)
newToken, err := client.RegenerateToken(ctx)
fmt.Printf("New token: %s\n", newToken.Token)
// Important: update the client with the new API key
client.APIKey = newToken.Token
```

## Projects (Multi)

These endpoints require Bearer token authentication. Call `SetAuthToken` first.

```go
ctx := context.Background()

// Authenticate first
authResp, _ := client.Login(ctx, "user@example.com", "password")
client.SetAuthToken(authResp.Token)

// List all projects
projects, err := client.ListProjects(ctx)
for _, p := range projects {
    fmt.Printf("%s: %s (%s)\n", p.ID, p.Name, p.Status)
}

// Create a project
project, err := client.CreateProject(ctx, jobcelis.ProjectRequest{Name: "My Project"})
fmt.Printf("Created: %s\n", project.ID)

// Get a project by ID
project, err = client.GetProjectByID(ctx, "project-id")

// Update a project
updated, err := client.UpdateProjectByID(ctx, "project-id", jobcelis.ProjectRequest{
    Name: "Renamed Project",
})

// Delete a project
err = client.DeleteProject(ctx, "project-id")

// Set a project as the default
err = client.SetDefaultProject(ctx, "project-id")
```

## Teams

Team management requires Bearer token authentication.

```go
ctx := context.Background()
client.SetAuthToken(authResp.Token)

// List members for a project
members, err := client.ListMembers(ctx, "project-id")
for _, m := range members {
    fmt.Printf("%s: %s (%s)\n", m.ID, m.Email, m.Role)
}

// Add a member
member, err := client.AddMember(ctx, "project-id", "user@example.com", "editor")
fmt.Printf("Added: %s\n", member.ID)

// Update a member's role
updated, err := client.UpdateMember(ctx, "project-id", "member-id", "admin")
fmt.Printf("Updated role: %s\n", updated.Role)

// Remove a member
err = client.RemoveMember(ctx, "project-id", "member-id")
```

## Invitations

Invitation management requires Bearer token authentication.

```go
ctx := context.Background()
client.SetAuthToken(authResp.Token)

// List pending invitations for the authenticated user
invitations, err := client.ListPendingInvitations(ctx)
for _, inv := range invitations {
    fmt.Printf("Invitation %s: project=%s role=%s\n", inv.ID, inv.ProjectName, inv.Role)
}

// Accept an invitation
err = client.AcceptInvitation(ctx, "invitation-id")

// Reject an invitation
err = client.RejectInvitation(ctx, "invitation-id")
```

## Audit

```go
ctx := context.Background()

// List audit logs with filters
params := url.Values{"action": {"webhook.created"}, "limit": {"50"}}
logs, err := client.ListAuditLogs(ctx, params)
for _, entry := range logs.Data {
    fmt.Printf("[%s] %s by %s\n", entry.InsertedAt, entry.Action, entry.ActorID)
}

// List all audit logs
allLogs, err := client.ListAuditLogs(ctx, nil)
_ = allLogs

// Paginate
if logs.HasNext {
    params.Set("cursor", logs.NextCursor)
    nextPage, _ := client.ListAuditLogs(ctx, params)
    _ = nextPage
}
```

## Export

All export methods return raw CSV bytes.

```go
ctx := context.Background()

// Export events as CSV
csvData, err := client.ExportEvents(ctx)
os.WriteFile("events.csv", csvData, 0644)

// Export deliveries as CSV
csvData, err = client.ExportDeliveries(ctx)
os.WriteFile("deliveries.csv", csvData, 0644)

// Export jobs as CSV
csvData, err = client.ExportJobs(ctx)
os.WriteFile("jobs.csv", csvData, 0644)

// Export audit log as CSV
csvData, err = client.ExportAuditLog(ctx)
os.WriteFile("audit-log.csv", csvData, 0644)
```

## Simulate

```go
ctx := context.Background()

// Simulate an event (testing without persisting)
result, err := client.SimulateEvent(ctx, "order.created", map[string]interface{}{
    "order_id": "test-123",
    "amount":   49.99,
})
fmt.Printf("Simulation result: %v\n", result)
```

## GDPR

GDPR endpoints require Bearer token authentication.

```go
ctx := context.Background()
client.SetAuthToken(authResp.Token)

// Get current consent records
consents, err := client.GetConsents(ctx)
for _, c := range consents {
    fmt.Printf("%s: accepted=%v\n", c.Purpose, c.Accepted)
}

// Accept a consent purpose
err = client.AcceptConsent(ctx, "analytics")

// Export personal data (right of access, Article 15)
data, err := client.ExportMyData(ctx)
fmt.Printf("My data: %v\n", data)

// Restrict processing (Article 18)
err = client.RestrictProcessing(ctx)

// Lift restriction
err = client.LiftRestriction(ctx)

// Object to processing (Article 21)
err = client.ObjectToProcessing(ctx)

// Withdraw objection
err = client.RestoreConsent(ctx)
```

## Health

```go
ctx := context.Background()

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
        switch apiErr.StatusCode {
        case 401:
            fmt.Println("Unauthorized: check your API key or auth token")
        case 404:
            fmt.Println("Resource not found")
        case 422:
            fmt.Printf("Validation error: %s\n", apiErr.Message)
        case 429:
            fmt.Println("Rate limited: slow down requests")
        default:
            fmt.Printf("API error %d: %s\n", apiErr.StatusCode, apiErr.Message)
        }
    } else {
        fmt.Printf("Network error: %s\n", err)
    }
}
```

## API Methods Reference

| Category | Method | Auth | Description |
|----------|--------|------|-------------|
| **Auth** | `Register(ctx, email, password, name)` | None | Register a new account |
| | `Login(ctx, email, password)` | None | Login and get JWT token |
| | `RefreshToken(ctx, refreshToken)` | None | Refresh an expired token |
| | `VerifyMFA(ctx, mfaToken, code)` | None | Verify TOTP code for MFA |
| | `SetAuthToken(token)` | -- | Set Bearer token on client |
| **Events** | `SendEvent(ctx, req)` | API Key | Send a single event |
| | `SendEvents(ctx, req)` | API Key | Send a batch of events |
| | `GetEvent(ctx, id)` | API Key | Get event by ID |
| | `ListEvents(ctx, params)` | API Key | List events (paginated) |
| | `DeleteEvent(ctx, id)` | API Key | Delete an event |
| **Webhooks** | `CreateWebhook(ctx, req)` | API Key | Create a webhook |
| | `ListWebhooks(ctx)` | API Key | List all webhooks |
| | `GetWebhook(ctx, id)` | API Key | Get webhook by ID |
| | `UpdateWebhook(ctx, id, req)` | API Key | Update a webhook |
| | `DeleteWebhook(ctx, id)` | API Key | Delete a webhook |
| | `WebhookHealth(ctx, id)` | API Key | Check webhook health |
| | `WebhookTemplates(ctx)` | API Key | List webhook templates |
| **Deliveries** | `ListDeliveries(ctx, params)` | API Key | List deliveries |
| | `RetryDelivery(ctx, id)` | API Key | Retry a delivery |
| **Dead Letters** | `ListDeadLetters(ctx, params)` | API Key | List dead letters |
| | `GetDeadLetter(ctx, id)` | API Key | Get dead letter by ID |
| | `RetryDeadLetter(ctx, id)` | API Key | Retry a dead letter |
| | `ResolveDeadLetter(ctx, id)` | API Key | Resolve a dead letter |
| **Replays** | `CreateReplay(ctx, req)` | API Key | Create a replay |
| | `ListReplays(ctx, params)` | API Key | List replays |
| | `GetReplay(ctx, id)` | API Key | Get replay by ID |
| | `CancelReplay(ctx, id)` | API Key | Cancel a replay |
| **Jobs** | `CreateJob(ctx, req)` | API Key | Create a scheduled job |
| | `ListJobs(ctx, params)` | API Key | List jobs |
| | `GetJob(ctx, id)` | API Key | Get job by ID |
| | `UpdateJob(ctx, id, req)` | API Key | Update a job |
| | `DeleteJob(ctx, id)` | API Key | Delete a job |
| | `ListJobRuns(ctx, jobId, params)` | API Key | List job runs |
| | `CronPreview(ctx, expr)` | API Key | Preview cron schedule |
| **Pipelines** | `CreatePipeline(ctx, req)` | API Key | Create a pipeline |
| | `ListPipelines(ctx, params)` | API Key | List pipelines |
| | `GetPipeline(ctx, id)` | API Key | Get pipeline by ID |
| | `UpdatePipeline(ctx, id, req)` | API Key | Update a pipeline |
| | `DeletePipeline(ctx, id)` | API Key | Delete a pipeline |
| | `TestPipeline(ctx, id, payload)` | API Key | Test a pipeline |
| **Schemas** | `CreateEventSchema(ctx, req)` | API Key | Create an event schema |
| | `ListEventSchemas(ctx, params)` | API Key | List event schemas |
| | `GetEventSchema(ctx, id)` | API Key | Get schema by ID |
| | `UpdateEventSchema(ctx, id, req)` | API Key | Update a schema |
| | `DeleteEventSchema(ctx, id)` | API Key | Delete a schema |
| | `ValidatePayload(ctx, topic, payload)` | API Key | Validate against schema |
| **Sandbox** | `ListSandboxEndpoints(ctx)` | API Key | List sandbox endpoints |
| | `CreateSandboxEndpoint(ctx, name)` | API Key | Create sandbox endpoint |
| | `DeleteSandboxEndpoint(ctx, id)` | API Key | Delete sandbox endpoint |
| | `ListSandboxRequests(ctx, id, params)` | API Key | List captured requests |
| **Analytics** | `EventsPerDay(ctx, days)` | API Key | Events per day |
| | `DeliveriesPerDay(ctx, days)` | API Key | Deliveries per day |
| | `TopTopics(ctx, limit)` | API Key | Top topics by count |
| | `WebhookStats(ctx)` | API Key | Webhook delivery stats |
| **Project** | `GetCurrentProject(ctx)` | API Key | Get current project |
| | `UpdateCurrentProject(ctx, updates)` | API Key | Update current project |
| | `ListTopics(ctx)` | API Key | List project topics |
| | `GetToken(ctx)` | API Key | Get API token metadata |
| | `RegenerateToken(ctx)` | API Key | Regenerate API token |
| **Projects** | `ListProjects(ctx)` | Bearer | List all projects |
| | `CreateProject(ctx, req)` | Bearer | Create a project |
| | `GetProjectByID(ctx, id)` | Bearer | Get project by ID |
| | `UpdateProjectByID(ctx, id, req)` | Bearer | Update a project |
| | `DeleteProject(ctx, id)` | Bearer | Delete a project |
| | `SetDefaultProject(ctx, id)` | Bearer | Set default project |
| **Teams** | `ListMembers(ctx, projectId)` | Bearer | List project members |
| | `AddMember(ctx, projectId, email, role)` | Bearer | Add a member |
| | `UpdateMember(ctx, projectId, memberId, role)` | Bearer | Update member role |
| | `RemoveMember(ctx, projectId, memberId)` | Bearer | Remove a member |
| **Invitations** | `ListPendingInvitations(ctx)` | Bearer | List pending invitations |
| | `AcceptInvitation(ctx, id)` | Bearer | Accept an invitation |
| | `RejectInvitation(ctx, id)` | Bearer | Reject an invitation |
| **Audit** | `ListAuditLogs(ctx, params)` | API Key | List audit log entries |
| **Export** | `ExportEvents(ctx)` | API Key | Export events as CSV |
| | `ExportDeliveries(ctx)` | API Key | Export deliveries as CSV |
| | `ExportJobs(ctx)` | API Key | Export jobs as CSV |
| | `ExportAuditLog(ctx)` | API Key | Export audit log as CSV |
| **Simulate** | `SimulateEvent(ctx, topic, payload)` | API Key | Simulate an event |
| **GDPR** | `GetConsents(ctx)` | Bearer | Get consent records |
| | `AcceptConsent(ctx, purpose)` | Bearer | Accept a consent |
| | `ExportMyData(ctx)` | Bearer | Export personal data |
| | `RestrictProcessing(ctx)` | Bearer | Restrict processing |
| | `LiftRestriction(ctx)` | Bearer | Lift restriction |
| | `ObjectToProcessing(ctx)` | Bearer | Object to processing |
| | `RestoreConsent(ctx)` | Bearer | Withdraw objection |
| **Health** | `Health(ctx)` | API Key | Check platform health |

## License

MIT
