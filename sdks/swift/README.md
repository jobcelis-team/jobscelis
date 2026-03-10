# Jobcelis

Official Swift SDK for the [Jobcelis](https://jobcelis.com) Event Infrastructure Platform.

All API calls go to `https://jobcelis.com` by default -- you only need your API key to get started.

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/vladimirCeli/jobcelis-swift.git", from: "1.0.0")
]
```

Or in Xcode: **File > Add Package Dependencies** and enter:

```
https://github.com/vladimirCeli/jobcelis-swift
```

## Requirements

- Swift 5.9+
- macOS 13+ / iOS 16+ / tvOS 16+ / watchOS 9+

## Quick Start

```swift
import Jobcelis

// Only your API key is required -- connects to https://jobcelis.com automatically
let client = JobcelisClient(apiKey: "your_api_key")

let event = try await client.sendEvent(topic: "order.created", payload: ["order_id": "123"])
print(event)
```

> **Custom URL:** If you're self-hosting Jobcelis, you can override the base URL:
> ```swift
> let client = JobcelisClient(apiKey: "your_api_key", baseURL: "https://your-instance.example.com")
> ```

## Authentication

The auth methods do not require an API key. Use them to register, log in, and manage JWT tokens.

```swift
let client = JobcelisClient(apiKey: "")

// Register a new account
let user = try await client.register(email: "alice@example.com", password: "SecurePass123!", name: "Alice")

// Log in -- returns JWT access token and refresh token
let session = try await client.login(email: "alice@example.com", password: "SecurePass123!")
let accessToken = session["token"] as! String
let refreshTok = session["refresh_token"] as! String

// Set the JWT for subsequent authenticated calls
client.setAuthToken(accessToken)

// Refresh an expired token
let newSession = try await client.refreshToken(refreshTok)
client.setAuthToken(newSession["token"] as! String)

// Verify MFA (requires auth token already set)
let result = try await client.verifyMfa(token: accessToken, code: "123456")
```

## Events

```swift
// Send a single event
let event = try await client.sendEvent(topic: "order.created", payload: ["order_id": "123", "amount": 99.99])

// Send batch events (up to 1000)
let batch = try await client.sendEvents([
    ["topic": "order.created", "payload": ["order_id": "1"]],
    ["topic": "order.created", "payload": ["order_id": "2"]],
])

// List events with pagination
let events = try await client.listEvents(limit: 25)
let cursor = events["cursor"] as? String
let nextPage = try await client.listEvents(limit: 25, cursor: cursor)

// Get / delete a single event
let evt = try await client.getEvent("evt_abc123")
try await client.deleteEvent("evt_abc123")
```

## Simulate

```swift
let result = try await client.simulateEvent(topic: "order.created", payload: ["order_id": "test"])
```

## Webhooks

```swift
// Create a webhook
let webhook = try await client.createWebhook(url: "https://example.com/webhook", extra: ["topics": ["order.*"]])

// List, get, update, delete
let webhooks = try await client.listWebhooks(limit: 50)
let wh = try await client.getWebhook("wh_abc123")
let updated = try await client.updateWebhook("wh_abc123", data: ["url": "https://new-url.com/hook"])
try await client.deleteWebhook("wh_abc123")

// Health and templates
let health = try await client.webhookHealth("wh_abc123")
let templates = try await client.webhookTemplates()
```

## Deliveries

```swift
let deliveries = try await client.listDeliveries(limit: 20, status: "failed")
let retried = try await client.retryDelivery("del_abc123")
```

## Dead Letters

```swift
let deadLetters = try await client.listDeadLetters(limit: 50)
let dl = try await client.getDeadLetter("dlq_abc123")
let retried = try await client.retryDeadLetter("dlq_abc123")
let resolved = try await client.resolveDeadLetter("dlq_abc123")
```

## Replays

```swift
let replay = try await client.createReplay(
    topic: "order.created",
    fromDate: "2026-01-01T00:00:00Z",
    toDate: "2026-01-31T23:59:59Z",
    webhookId: "wh_abc123"  // optional
)
let replays = try await client.listReplays(limit: 50)
let r = try await client.getReplay("rpl_abc123")
try await client.cancelReplay("rpl_abc123")
```

## Scheduled Jobs

```swift
// Create a job
let job = try await client.createJob(
    name: "daily-report", queue: "default", cronExpression: "0 9 * * *",
    extra: ["payload": ["type": "daily"]]
)

// CRUD
let jobs = try await client.listJobs(limit: 10)
let j = try await client.getJob("job_abc123")
let updated = try await client.updateJob("job_abc123", data: ["cron_expression": "0 10 * * *"])
try await client.deleteJob("job_abc123")

// List runs for a job
let runs = try await client.listJobRuns("job_abc123", limit: 20)

// Preview cron schedule
let preview = try await client.cronPreview("0 9 * * *", count: 10)
```

## Pipelines

```swift
let pipeline = try await client.createPipeline(
    name: "order-processing",
    topics: ["order.created"],
    steps: [
        ["type": "filter", "config": ["field": "amount", "gt": 100]],
        ["type": "transform", "config": ["add_field": "priority", "value": "high"]],
    ]
)

let pipelines = try await client.listPipelines(limit: 50)
let p = try await client.getPipeline("pipe_abc123")
let updated = try await client.updatePipeline("pipe_abc123", data: ["name": "order-processing-v2"])
try await client.deletePipeline("pipe_abc123")

// Test a pipeline with a sample payload
let result = try await client.testPipeline("pipe_abc123", payload: ["topic": "order.created", "payload": ["id": "1"]])
```

## Event Schemas

```swift
let schema = try await client.createEventSchema(
    topic: "order.created",
    schema: [
        "type": "object",
        "properties": [
            "order_id": ["type": "string"],
            "amount": ["type": "number"],
        ],
        "required": ["order_id", "amount"],
    ]
)

let schemas = try await client.listEventSchemas(limit: 50)
let s = try await client.getEventSchema("sch_abc123")
let updated = try await client.updateEventSchema("sch_abc123", data: ["schema": ["type": "object"]])
try await client.deleteEventSchema("sch_abc123")

// Validate a payload against a topic's schema
let result = try await client.validatePayload(topic: "order.created", payload: ["order_id": "123", "amount": 50])
```

## Sandbox

```swift
let endpoint = try await client.createSandboxEndpoint(name: "my-test")
let endpoints = try await client.listSandboxEndpoints()
let requests = try await client.listSandboxRequests("sbx_abc123", limit: 20)
try await client.deleteSandboxEndpoint("sbx_abc123")
```

## Analytics

```swift
let eventsChart = try await client.eventsPerDay(days: 30)
let deliveriesChart = try await client.deliveriesPerDay(days: 7)
let topics = try await client.topTopics(limit: 5)
let stats = try await client.webhookStats()
```

## Project and Token Management

```swift
let project = try await client.getProject()
let updated = try await client.updateProject(["name": "My Project v2"])
let topics = try await client.listTopics()
let token = try await client.getToken()
let newToken = try await client.regenerateToken()
```

## Multi-Project Management

```swift
let projects = try await client.listProjects()
let newProject = try await client.createProject("staging-env")
let p = try await client.getProjectById("proj_abc123")
let updated = try await client.updateProjectById("proj_abc123", data: ["name": "production-env"])
let def = try await client.setDefaultProject("proj_abc123")
try await client.deleteProject("proj_abc123")
```

## Team Members

```swift
let members = try await client.listMembers("proj_abc123")
let member = try await client.addMember("proj_abc123", email: "alice@example.com", role: "admin")
let updated = try await client.updateMember("proj_abc123", memberId: "mem_abc123", role: "viewer")
try await client.removeMember("proj_abc123", memberId: "mem_abc123")
```

## Invitations

```swift
let invitations = try await client.listPendingInvitations()
let accepted = try await client.acceptInvitation("inv_abc123")
let rejected = try await client.rejectInvitation("inv_def456")
```

## Audit Logs

```swift
let logs = try await client.listAuditLogs(limit: 100)
```

## Data Export

```swift
let csvData = try await client.exportEvents(format: "csv")
try csvData.write(toFile: "events.csv", atomically: true, encoding: .utf8)

let jsonData = try await client.exportDeliveries(format: "json")
let jobsCsv = try await client.exportJobs(format: "csv")
let auditCsv = try await client.exportAuditLog(format: "csv")
```

## GDPR / Privacy

```swift
let consents = try await client.getConsents()
let accepted = try await client.acceptConsent("marketing")
let myData = try await client.exportMyData()
let restricted = try await client.restrictProcessing()
try await client.liftRestriction()
let objected = try await client.objectToProcessing()
try await client.restoreConsent()
```

## Health Check

```swift
let health = try await client.health()
let status = try await client.status()
```

## Error Handling

```swift
do {
    let event = try await client.getEvent("nonexistent")
} catch let error as JobcelisError {
    print("Status: \(error.statusCode)")
    print("Detail: \(String(describing: error.detail))")
} catch {
    print("Error: \(error)")
}
```

## Webhook Signature Verification

```swift
import Jobcelis

let body = #"{"topic":"order.created"}"#
let signature = "..."

if WebhookVerifier.verify(secret: "your_webhook_secret", body: body, signature: signature) {
    print("Valid signature!")
} else {
    print("Invalid signature!")
}
```

## License

BSL-1.1 (Business Source License)
