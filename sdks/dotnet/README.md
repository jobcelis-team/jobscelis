# Jobcelis

Official .NET SDK for the [Jobcelis](https://jobcelis.com) Event Infrastructure Platform.

All API calls go to `https://jobcelis.com` by default -- you only need your API key to get started.

## Installation

```bash
dotnet add package Jobcelis
```

## Quick Start

```csharp
using Jobcelis;

// Only your API key is required -- connects to https://jobcelis.com automatically
var client = new JobcelisClient("your_api_key");

var evt = await client.SendEventAsync("order.created", new { order_id = "123", amount = 99.99 });
var webhooks = await client.ListWebhooksAsync();
```

> **Custom URL:** If you're self-hosting Jobcelis, you can override the base URL:
> ```csharp
> var client = new JobcelisClient("your_api_key", baseUrl: "https://your-instance.example.com");
> ```

## Authentication

The auth methods do not require an API key. Use them to register, log in, and manage JWT tokens.

```csharp
using Jobcelis;

var client = new JobcelisClient("");

// Register a new account
var user = await client.RegisterAsync("alice@example.com", "SecurePass123!", name: "Alice");

// Log in -- returns JWT access token and refresh token
var session = await client.LoginAsync("alice@example.com", "SecurePass123!");
var accessToken = session.GetProperty("token").GetString()!;
var refreshToken = session.GetProperty("refresh_token").GetString()!;

// Set the JWT for subsequent authenticated calls
client.SetAuthToken(accessToken);

// Refresh an expired token
var newSession = await client.RefreshTokenAsync(refreshToken);
client.SetAuthToken(newSession.GetProperty("token").GetString()!);

// Verify MFA (requires auth token already set)
var result = await client.VerifyMfaAsync(accessToken, "123456");
```

## Events

```csharp
// Send a single event
var evt = await client.SendEventAsync("order.created", new { order_id = "123", amount = 99.99 });

// Send batch events (up to 1000)
var batch = await client.SendEventsAsync(new[]
{
    new { topic = "order.created", payload = new { order_id = "1" } },
    new { topic = "order.created", payload = new { order_id = "2" } },
});

// List events with pagination
var events = await client.ListEventsAsync(limit: 25);

// Get / delete a single event
var detail = await client.GetEventAsync("evt_abc123");
await client.DeleteEventAsync("evt_abc123");
```

## Simulate

```csharp
// Dry-run an event to see which webhooks would fire
var result = await client.SimulateEventAsync("order.created", new { order_id = "test" });
```

## Webhooks

```csharp
// Create a webhook
var webhook = await client.CreateWebhookAsync("https://example.com/webhook",
    new() { ["topics"] = new[] { "order.*" } });

// List, get, update, delete
var webhooks = await client.ListWebhooksAsync();
var wh = await client.GetWebhookAsync("wh_abc123");
await client.UpdateWebhookAsync("wh_abc123", new { url = "https://new-url.com/hook" });
await client.DeleteWebhookAsync("wh_abc123");

// Health and templates
var health = await client.WebhookHealthAsync("wh_abc123");
var templates = await client.WebhookTemplatesAsync();
```

## Deliveries

```csharp
var deliveries = await client.ListDeliveriesAsync(limit: 20, status: "failed");
await client.RetryDeliveryAsync("del_abc123");
```

## Dead Letters

```csharp
var deadLetters = await client.ListDeadLettersAsync();
var dl = await client.GetDeadLetterAsync("dlq_abc123");
await client.RetryDeadLetterAsync("dlq_abc123");
await client.ResolveDeadLetterAsync("dlq_abc123");
```

## Replays

```csharp
var replay = await client.CreateReplayAsync(
    "order.created",
    "2026-01-01T00:00:00Z",
    "2026-01-31T23:59:59Z",
    webhookId: "wh_abc123"  // optional
);
var replays = await client.ListReplaysAsync();
var r = await client.GetReplayAsync("rpl_abc123");
await client.CancelReplayAsync("rpl_abc123");
```

## Scheduled Jobs

```csharp
// Create a job
var job = await client.CreateJobAsync("daily-report", "default", "0 9 * * *",
    new() { ["payload"] = new { type = "daily" } });

// CRUD
var jobs = await client.ListJobsAsync(limit: 10);
var j = await client.GetJobAsync("job_abc123");
await client.UpdateJobAsync("job_abc123", new { cron_expression = "0 10 * * *" });
await client.DeleteJobAsync("job_abc123");

// List runs for a job
var runs = await client.ListJobRunsAsync("job_abc123", limit: 20);

// Preview cron schedule
var preview = await client.CronPreviewAsync("0 9 * * *", count: 10);
```

## Pipelines

```csharp
var pipeline = await client.CreatePipelineAsync("order-processing",
    new[] { "order.created" },
    new object[]
    {
        new { type = "filter", config = new { field = "amount", gt = 100 } },
        new { type = "transform", config = new { add_field = "priority", value = "high" } },
    }
);

var pipelines = await client.ListPipelinesAsync();
var p = await client.GetPipelineAsync("pipe_abc123");
await client.UpdatePipelineAsync("pipe_abc123", new { name = "order-processing-v2" });
await client.DeletePipelineAsync("pipe_abc123");

// Test a pipeline with a sample payload
var testResult = await client.TestPipelineAsync("pipe_abc123", new
{
    topic = "order.created",
    payload = new { id = "1" }
});
```

## Event Schemas

```csharp
var schema = await client.CreateEventSchemaAsync("order.created", new
{
    type = "object",
    properties = new
    {
        order_id = new { type = "string" },
        amount = new { type = "number" },
    },
    required = new[] { "order_id", "amount" },
});

var schemas = await client.ListEventSchemasAsync();
var s = await client.GetEventSchemaAsync("sch_abc123");
await client.UpdateEventSchemaAsync("sch_abc123", new { schema = new { type = "object" } });
await client.DeleteEventSchemaAsync("sch_abc123");

// Validate a payload against a topic's schema
var valid = await client.ValidatePayloadAsync("order.created", new { order_id = "123", amount = 50 });
```

## Sandbox

```csharp
// Create a temporary endpoint for testing
var endpoint = await client.CreateSandboxEndpointAsync(name: "my-test");
var endpoints = await client.ListSandboxEndpointsAsync();

// Inspect received requests
var requests = await client.ListSandboxRequestsAsync("sbx_abc123", limit: 20);

await client.DeleteSandboxEndpointAsync("sbx_abc123");
```

## Analytics

```csharp
var eventsChart = await client.EventsPerDayAsync(days: 30);
var deliveriesChart = await client.DeliveriesPerDayAsync(days: 7);
var topics = await client.TopTopicsAsync(limit: 5);
var stats = await client.WebhookStatsAsync();
```

## Project and Token Management

```csharp
// Current project
var project = await client.GetProjectAsync();
await client.UpdateProjectAsync(new { name = "My Project v2" });

// Topics
var topics = await client.ListTopicsAsync();

// API token
var token = await client.GetTokenAsync();
var newToken = await client.RegenerateTokenAsync();
```

## Multi-Project Management

```csharp
var projects = await client.ListProjectsAsync();
var newProject = await client.CreateProjectAsync("staging-env");
var proj = await client.GetProjectByIdAsync("proj_abc123");
await client.UpdateProjectByIdAsync("proj_abc123", new { name = "production-env" });
await client.SetDefaultProjectAsync("proj_abc123");
await client.DeleteProjectAsync("proj_abc123");
```

## Team Members

```csharp
var members = await client.ListMembersAsync("proj_abc123");
var member = await client.AddMemberAsync("proj_abc123", "alice@example.com", role: "admin");
await client.UpdateMemberAsync("proj_abc123", "mem_abc123", "viewer");
await client.RemoveMemberAsync("proj_abc123", "mem_abc123");
```

## Invitations

```csharp
// List pending invitations
var invitations = await client.ListPendingInvitationsAsync();

// Accept or reject
await client.AcceptInvitationAsync("inv_abc123");
await client.RejectInvitationAsync("inv_def456");
```

## Audit Logs

```csharp
var logs = await client.ListAuditLogsAsync(limit: 100);
```

## Data Export

Export methods return raw strings (CSV or JSON).

```csharp
// Export as CSV
var csvData = await client.ExportEventsAsync(format: "csv");
File.WriteAllText("events.csv", csvData);

// Export as JSON
var jsonData = await client.ExportDeliveriesAsync(format: "json");

// Other exports
await client.ExportJobsAsync(format: "csv");
await client.ExportAuditLogAsync(format: "csv");
```

## GDPR / Privacy

```csharp
// Consent management
var consents = await client.GetConsentsAsync();
await client.AcceptConsentAsync("marketing");

// Data portability
var myData = await client.ExportMyDataAsync();

// Processing restrictions
await client.RestrictProcessingAsync();
await client.LiftRestrictionAsync();

// Right to object
await client.ObjectToProcessingAsync();
await client.RestoreConsentAsync();
```

## Health Check

```csharp
var health = await client.HealthAsync();
var status = await client.StatusAsync();
```

## Error Handling

```csharp
using Jobcelis;

var client = new JobcelisClient("your_api_key");

try
{
    var evt = await client.GetEventAsync("nonexistent");
}
catch (JobcelisException ex)
{
    Console.WriteLine($"Status: {ex.StatusCode}");  // 404
    Console.WriteLine($"Detail: {ex.Detail}");
}
```

## Webhook Signature Verification

```csharp
using Jobcelis;

// In an ASP.NET Core controller
[HttpPost("webhook")]
public async Task<IActionResult> HandleWebhook()
{
    using var reader = new StreamReader(Request.Body);
    var body = await reader.ReadToEndAsync();
    var signature = Request.Headers["X-Signature"].FirstOrDefault() ?? "";

    if (!WebhookVerifier.Verify("your_webhook_secret", body, signature))
        return Unauthorized("Invalid signature");

    // Process the event...
    return Ok();
}
```

## License

BSL-1.1 (Business Source License)
