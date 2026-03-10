# Jobcelis

Official Kotlin SDK for the [Jobcelis](https://jobcelis.com) Event Infrastructure Platform.

All API calls go to `https://jobcelis.com` by default -- you only need your API key to get started.

## Installation

### Gradle (Kotlin DSL)

```kotlin
implementation("com.jobcelis:jobcelis-kotlin:1.0.0")
```

### Gradle (Groovy)

```groovy
implementation 'com.jobcelis:jobcelis-kotlin:1.0.0'
```

### Maven

```xml
<dependency>
    <groupId>com.jobcelis</groupId>
    <artifactId>jobcelis-kotlin</artifactId>
    <version>1.0.0</version>
</dependency>
```

## Requirements

- Kotlin 1.9+ / Java 11+
- Coroutines support (`kotlinx-coroutines-core`)

## Quick Start

```kotlin
import com.jobcelis.JobcelisClient
import kotlinx.coroutines.runBlocking

fun main() = runBlocking {
    val client = JobcelisClient("your_api_key")
    val event = client.sendEvent("order.created", mapOf("order_id" to "123"))
    println(event)
    client.close()
}
```

> **Custom URL:** If you're self-hosting Jobcelis, you can override the base URL:
> ```kotlin
> val client = JobcelisClient("your_api_key", baseURL = "https://your-instance.example.com")
> ```

## Authentication

The auth methods do not require an API key. Use them to register, log in, and manage JWT tokens.

```kotlin
val client = JobcelisClient("")

// Register a new account
val user = client.register("alice@example.com", "SecurePass123!", "Alice")

// Log in -- returns JWT access token and refresh token
val session = client.login("alice@example.com", "SecurePass123!")
val accessToken = session["token"].asString
val refreshTok = session["refresh_token"].asString

// Set the JWT for subsequent authenticated calls
client.setAuthToken(accessToken)

// Refresh an expired token
val newSession = client.refreshToken(refreshTok)
client.setAuthToken(newSession["token"].asString)

// Verify MFA (requires auth token already set)
val result = client.verifyMfa(accessToken, "123456")
```

## Events

```kotlin
// Send a single event
val event = client.sendEvent("order.created", mapOf("order_id" to "123", "amount" to 99.99))

// Send batch events (up to 1000)
val batch = client.sendEvents(listOf(
    mapOf("topic" to "order.created", "payload" to mapOf("order_id" to "1")),
    mapOf("topic" to "order.created", "payload" to mapOf("order_id" to "2"))
))

// List events with pagination
val events = client.listEvents(25)
val cursor = events["cursor"]?.asString
val nextPage = client.listEvents(25, cursor)

// Get / delete a single event
val evt = client.getEvent("evt_abc123")
client.deleteEvent("evt_abc123")
```

## Simulate

```kotlin
val result = client.simulateEvent("order.created", mapOf("order_id" to "test"))
```

## Webhooks

```kotlin
// Create a webhook
val webhook = client.createWebhook("https://example.com/webhook", mapOf("topics" to listOf("order.*")))

// List, get, update, delete
val webhooks = client.listWebhooks(50)
val wh = client.getWebhook("wh_abc123")
client.updateWebhook("wh_abc123", mapOf("url" to "https://new-url.com/hook"))
client.deleteWebhook("wh_abc123")

// Health and templates
val health = client.webhookHealth("wh_abc123")
val templates = client.webhookTemplates()
```

## Deliveries

```kotlin
val deliveries = client.listDeliveries(20, status = "failed")
client.retryDelivery("del_abc123")
```

## Dead Letters

```kotlin
val deadLetters = client.listDeadLetters(50)
val dl = client.getDeadLetter("dlq_abc123")
client.retryDeadLetter("dlq_abc123")
client.resolveDeadLetter("dlq_abc123")
```

## Replays

```kotlin
val replay = client.createReplay(
    "order.created",
    "2026-01-01T00:00:00Z",
    "2026-01-31T23:59:59Z",
    "wh_abc123"  // optional, pass null to skip
)
val replays = client.listReplays(50)
val r = client.getReplay("rpl_abc123")
client.cancelReplay("rpl_abc123")
```

## Scheduled Jobs

```kotlin
// Create a job
val job = client.createJob("daily-report", "default", "0 9 * * *",
    mapOf("payload" to mapOf("type" to "daily")))

// CRUD
val jobs = client.listJobs(10)
val j = client.getJob("job_abc123")
client.updateJob("job_abc123", mapOf("cron_expression" to "0 10 * * *"))
client.deleteJob("job_abc123")

// List runs for a job
val runs = client.listJobRuns("job_abc123", 20)

// Preview cron schedule
val preview = client.cronPreview("0 9 * * *", 10)
```

## Pipelines

```kotlin
val pipeline = client.createPipeline("order-processing",
    listOf("order.created"),
    listOf(
        mapOf("type" to "filter", "config" to mapOf("field" to "amount", "gt" to 100)),
        mapOf("type" to "transform", "config" to mapOf("add_field" to "priority", "value" to "high"))
    )
)

val pipelines = client.listPipelines(50)
val p = client.getPipeline("pipe_abc123")
client.updatePipeline("pipe_abc123", mapOf("name" to "order-processing-v2"))
client.deletePipeline("pipe_abc123")

// Test a pipeline with a sample payload
val testResult = client.testPipeline("pipe_abc123",
    mapOf("topic" to "order.created", "payload" to mapOf("id" to "1")))
```

## Event Schemas

```kotlin
val schema = client.createEventSchema("order.created", mapOf(
    "type" to "object",
    "properties" to mapOf(
        "order_id" to mapOf("type" to "string"),
        "amount" to mapOf("type" to "number")
    ),
    "required" to listOf("order_id", "amount")
))

val schemas = client.listEventSchemas(50)
val s = client.getEventSchema("sch_abc123")
client.updateEventSchema("sch_abc123", mapOf("schema" to mapOf("type" to "object")))
client.deleteEventSchema("sch_abc123")

// Validate a payload against a topic's schema
val valid = client.validatePayload("order.created", mapOf("order_id" to "123", "amount" to 50))
```

## Sandbox

```kotlin
val endpoint = client.createSandboxEndpoint("my-test")
val endpoints = client.listSandboxEndpoints()
val requests = client.listSandboxRequests("sbx_abc123", 20)
client.deleteSandboxEndpoint("sbx_abc123")
```

## Analytics

```kotlin
val eventsChart = client.eventsPerDay(30)
val deliveriesChart = client.deliveriesPerDay(7)
val topics = client.topTopics(5)
val stats = client.webhookStats()
```

## Project and Token Management

```kotlin
val project = client.getProject()
client.updateProject(mapOf("name" to "My Project v2"))
val topics = client.listTopics()
val token = client.getToken()
val newToken = client.regenerateToken()
```

## Multi-Project Management

```kotlin
val projects = client.listProjects()
val newProject = client.createProject("staging-env")
val p = client.getProjectById("proj_abc123")
client.updateProjectById("proj_abc123", mapOf("name" to "production-env"))
client.setDefaultProject("proj_abc123")
client.deleteProject("proj_abc123")
```

## Team Members

```kotlin
val members = client.listMembers("proj_abc123")
val member = client.addMember("proj_abc123", "alice@example.com", "admin")
client.updateMember("proj_abc123", "mem_abc123", "viewer")
client.removeMember("proj_abc123", "mem_abc123")
```

## Invitations

```kotlin
val invitations = client.listPendingInvitations()
client.acceptInvitation("inv_abc123")
client.rejectInvitation("inv_def456")
```

## Audit Logs

```kotlin
val logs = client.listAuditLogs(100)
```

## Data Export

```kotlin
val csvData = client.exportEvents("csv")
java.io.File("events.csv").writeText(csvData)

val jsonData = client.exportDeliveries("json")
client.exportJobs("csv")
client.exportAuditLog("csv")
```

## GDPR / Privacy

```kotlin
val consents = client.getConsents()
client.acceptConsent("marketing")
val myData = client.exportMyData()
client.restrictProcessing()
client.liftRestriction()
client.objectToProcessing()
client.restoreConsent()
```

## Health Check

```kotlin
val health = client.health()
val status = client.status()
```

## Error Handling

All methods are `suspend` functions and throw `JobcelisException` on API errors:

```kotlin
import com.jobcelis.JobcelisException

try {
    val event = client.getEvent("nonexistent")
} catch (e: JobcelisException) {
    println("Status: ${e.statusCode}")
    println("Detail: ${e.detail}")
} catch (e: Exception) {
    println("Network error: ${e.message}")
}
```

## Webhook Signature Verification

```kotlin
import com.jobcelis.WebhookVerifier

val body = """{"topic":"order.created"}"""
val signature = "..."

if (WebhookVerifier.verify("your_webhook_secret", body, signature)) {
    println("Valid signature!")
} else {
    println("Invalid signature!")
}
```

## License

BSL-1.1 (Business Source License)
