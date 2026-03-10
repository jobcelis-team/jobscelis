# Jobcelis

Official Java SDK for the [Jobcelis](https://jobcelis.com) Event Infrastructure Platform.

All API calls go to `https://jobcelis.com` by default -- you only need your API key to get started.

## Installation

### Maven

```xml
<dependency>
    <groupId>com.jobcelis</groupId>
    <artifactId>jobcelis</artifactId>
    <version>1.0.0</version>
</dependency>
```

### Gradle

```groovy
implementation 'com.jobcelis:jobcelis:1.0.0'
```

## Requirements

- Java 11+

## Quick Start

```java
import com.jobcelis.JobcelisClient;
import java.util.Map;

JobcelisClient client = new JobcelisClient("your_api_key");
var event = client.sendEvent("order.created", Map.of("order_id", "123"));
System.out.println(event);
```

> **Custom URL:** If you're self-hosting Jobcelis, you can override the base URL:
> ```java
> var client = new JobcelisClient("your_api_key", "https://your-instance.example.com");
> ```

## Authentication

The auth methods do not require an API key. Use them to register, log in, and manage JWT tokens.

```java
var client = new JobcelisClient("");

// Register a new account
var user = client.register("alice@example.com", "SecurePass123!", "Alice");

// Log in -- returns JWT access token and refresh token
var session = client.login("alice@example.com", "SecurePass123!");
String accessToken = session.get("token").getAsString();
String refreshTok = session.get("refresh_token").getAsString();

// Set the JWT for subsequent authenticated calls
client.setAuthToken(accessToken);

// Refresh an expired token
var newSession = client.refreshToken(refreshTok);
client.setAuthToken(newSession.get("token").getAsString());

// Verify MFA (requires auth token already set)
var result = client.verifyMfa(accessToken, "123456");
```

## Events

```java
// Send a single event
var event = client.sendEvent("order.created", Map.of("order_id", "123", "amount", 99.99));

// Send batch events (up to 1000)
var batch = client.sendEvents(List.of(
    Map.of("topic", "order.created", "payload", Map.of("order_id", "1")),
    Map.of("topic", "order.created", "payload", Map.of("order_id", "2"))
));

// List events with pagination
var events = client.listEvents(25, null);
String cursor = events.has("cursor") ? events.get("cursor").getAsString() : null;
var nextPage = client.listEvents(25, cursor);

// Get / delete a single event
var evt = client.getEvent("evt_abc123");
client.deleteEvent("evt_abc123");
```

## Simulate

```java
var result = client.simulateEvent("order.created", Map.of("order_id", "test"));
```

## Webhooks

```java
// Create a webhook
var webhook = client.createWebhook("https://example.com/webhook", Map.of("topics", List.of("order.*")));

// List, get, update, delete
var webhooks = client.listWebhooks(50, null);
var wh = client.getWebhook("wh_abc123");
client.updateWebhook("wh_abc123", Map.of("url", "https://new-url.com/hook"));
client.deleteWebhook("wh_abc123");

// Health and templates
var health = client.webhookHealth("wh_abc123");
var templates = client.webhookTemplates();
```

## Deliveries

```java
var deliveries = client.listDeliveries(20, null, "failed");
client.retryDelivery("del_abc123");
```

## Dead Letters

```java
var deadLetters = client.listDeadLetters(50, null);
var dl = client.getDeadLetter("dlq_abc123");
client.retryDeadLetter("dlq_abc123");
client.resolveDeadLetter("dlq_abc123");
```

## Replays

```java
var replay = client.createReplay(
    "order.created",
    "2026-01-01T00:00:00Z",
    "2026-01-31T23:59:59Z",
    "wh_abc123"  // optional, pass null to skip
);
var replays = client.listReplays(50, null);
var r = client.getReplay("rpl_abc123");
client.cancelReplay("rpl_abc123");
```

## Scheduled Jobs

```java
// Create a job
var job = client.createJob("daily-report", "default", "0 9 * * *",
    Map.of("payload", Map.of("type", "daily")));

// CRUD
var jobs = client.listJobs(10, null);
var j = client.getJob("job_abc123");
client.updateJob("job_abc123", Map.of("cron_expression", "0 10 * * *"));
client.deleteJob("job_abc123");

// List runs for a job
var runs = client.listJobRuns("job_abc123", 20);

// Preview cron schedule
var preview = client.cronPreview("0 9 * * *", 10);
```

## Pipelines

```java
var pipeline = client.createPipeline("order-processing",
    List.of("order.created"),
    List.of(
        Map.of("type", "filter", "config", Map.of("field", "amount", "gt", 100)),
        Map.of("type", "transform", "config", Map.of("add_field", "priority", "value", "high"))
    )
);

var pipelines = client.listPipelines(50, null);
var p = client.getPipeline("pipe_abc123");
client.updatePipeline("pipe_abc123", Map.of("name", "order-processing-v2"));
client.deletePipeline("pipe_abc123");

// Test a pipeline with a sample payload
var result = client.testPipeline("pipe_abc123",
    Map.of("topic", "order.created", "payload", Map.of("id", "1")));
```

## Event Schemas

```java
var schema = client.createEventSchema("order.created", Map.of(
    "type", "object",
    "properties", Map.of(
        "order_id", Map.of("type", "string"),
        "amount", Map.of("type", "number")
    ),
    "required", List.of("order_id", "amount")
));

var schemas = client.listEventSchemas(50, null);
var s = client.getEventSchema("sch_abc123");
client.updateEventSchema("sch_abc123", Map.of("schema", Map.of("type", "object")));
client.deleteEventSchema("sch_abc123");

// Validate a payload against a topic's schema
var result = client.validatePayload("order.created", Map.of("order_id", "123", "amount", 50));
```

## Sandbox

```java
var endpoint = client.createSandboxEndpoint("my-test");
var endpoints = client.listSandboxEndpoints();
var requests = client.listSandboxRequests("sbx_abc123", 20);
client.deleteSandboxEndpoint("sbx_abc123");
```

## Analytics

```java
var eventsChart = client.eventsPerDay(30);
var deliveriesChart = client.deliveriesPerDay(7);
var topics = client.topTopics(5);
var stats = client.webhookStats();
```

## Project and Token Management

```java
var project = client.getProject();
client.updateProject(Map.of("name", "My Project v2"));
var topics = client.listTopics();
var token = client.getToken();
var newToken = client.regenerateToken();
```

## Multi-Project Management

```java
var projects = client.listProjects();
var newProject = client.createProject("staging-env");
var p = client.getProjectById("proj_abc123");
client.updateProjectById("proj_abc123", Map.of("name", "production-env"));
client.setDefaultProject("proj_abc123");
client.deleteProject("proj_abc123");
```

## Team Members

```java
var members = client.listMembers("proj_abc123");
var member = client.addMember("proj_abc123", "alice@example.com", "admin");
client.updateMember("proj_abc123", "mem_abc123", "viewer");
client.removeMember("proj_abc123", "mem_abc123");
```

## Invitations

```java
var invitations = client.listPendingInvitations();
client.acceptInvitation("inv_abc123");
client.rejectInvitation("inv_def456");
```

## Audit Logs

```java
var logs = client.listAuditLogs(100, null);
```

## Data Export

```java
String csvData = client.exportEvents("csv");
java.nio.file.Files.writeString(java.nio.file.Path.of("events.csv"), csvData);

String jsonData = client.exportDeliveries("json");
client.exportJobs("csv");
client.exportAuditLog("csv");
```

## GDPR / Privacy

```java
var consents = client.getConsents();
client.acceptConsent("marketing");
var myData = client.exportMyData();
client.restrictProcessing();
client.liftRestriction();
client.objectToProcessing();
client.restoreConsent();
```

## Health Check

```java
var health = client.health();
var status = client.status();
```

## Error Handling

```java
import com.jobcelis.JobcelisException;

try {
    var event = client.getEvent("nonexistent");
} catch (JobcelisException e) {
    System.out.println("Status: " + e.getStatusCode());
    System.out.println("Detail: " + e.getDetail());
} catch (IOException e) {
    System.out.println("Network error: " + e.getMessage());
}
```

## Webhook Signature Verification

```java
import com.jobcelis.WebhookVerifier;

String body = "{\"topic\":\"order.created\"}";
String signature = "...";

if (WebhookVerifier.verify("your_webhook_secret", body, signature)) {
    System.out.println("Valid signature!");
} else {
    System.out.println("Invalid signature!");
}
```

## License

BSL-1.1 (Business Source License)
