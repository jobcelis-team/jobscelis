# Jobcelis

Official Dart/Flutter SDK for the [Jobcelis](https://jobcelis.com) Event Infrastructure Platform.

All API calls go to `https://jobcelis.com` by default -- you only need your API key to get started.

## Installation

```yaml
# pubspec.yaml
dependencies:
  jobcelis: ^1.0.0
```

Then run:

```bash
dart pub get
# or for Flutter:
flutter pub get
```

## Requirements

- Dart 3.0+ / Flutter 3.10+

## Quick Start

```dart
import 'package:jobcelis/jobcelis.dart';

// Only your API key is required -- connects to https://jobcelis.com automatically
final client = JobcelisClient(apiKey: 'your_api_key');
final event = await client.sendEvent('order.created', {'order_id': '123'});
print(event);

// Don't forget to close when done
client.close();
```

> **Custom URL:** If you're self-hosting Jobcelis, you can override the base URL:
> ```dart
> final client = JobcelisClient(apiKey: 'your_api_key', baseURL: 'https://your-instance.example.com');
> ```

## Authentication

The auth methods do not require an API key. Use them to register, log in, and manage JWT tokens.

```dart
final client = JobcelisClient(apiKey: '');

// Register a new account
final user = await client.register('alice@example.com', 'SecurePass123!', name: 'Alice');

// Log in -- returns JWT access token and refresh token
final session = await client.login('alice@example.com', 'SecurePass123!');
final accessToken = session['token'] as String;
final refreshTok = session['refresh_token'] as String;

// Set the JWT for subsequent authenticated calls
client.setAuthToken(accessToken);

// Refresh an expired token
final newSession = await client.refreshToken(refreshTok);
client.setAuthToken(newSession['token'] as String);

// Verify MFA (requires auth token already set)
final result = await client.verifyMfa(accessToken, '123456');
```

## Events

```dart
// Send a single event
final event = await client.sendEvent('order.created', {'order_id': '123', 'amount': 99.99});

// Send batch events (up to 1000)
final batch = await client.sendEvents([
  {'topic': 'order.created', 'payload': {'order_id': '1'}},
  {'topic': 'order.created', 'payload': {'order_id': '2'}},
]);

// List events with pagination
final events = await client.listEvents(limit: 25);
final cursor = events['cursor'] as String?;
final nextPage = await client.listEvents(limit: 25, cursor: cursor);

// Get / delete a single event
final evt = await client.getEvent('evt_abc123');
await client.deleteEvent('evt_abc123');
```

## Simulate

```dart
final result = await client.simulateEvent('order.created', {'order_id': 'test'});
```

## Webhooks

```dart
// Create a webhook
final webhook = await client.createWebhook('https://example.com/webhook', extra: {'topics': ['order.*']});

// List, get, update, delete
final webhooks = await client.listWebhooks(limit: 50);
final wh = await client.getWebhook('wh_abc123');
await client.updateWebhook('wh_abc123', {'url': 'https://new-url.com/hook'});
await client.deleteWebhook('wh_abc123');

// Health and templates
final health = await client.webhookHealth('wh_abc123');
final templates = await client.webhookTemplates();
```

## Deliveries

```dart
final deliveries = await client.listDeliveries(limit: 20, status: 'failed');
await client.retryDelivery('del_abc123');
```

## Dead Letters

```dart
final deadLetters = await client.listDeadLetters(limit: 50);
final dl = await client.getDeadLetter('dlq_abc123');
await client.retryDeadLetter('dlq_abc123');
await client.resolveDeadLetter('dlq_abc123');
```

## Replays

```dart
final replay = await client.createReplay(
  'order.created',
  '2026-01-01T00:00:00Z',
  '2026-01-31T23:59:59Z',
  webhookId: 'wh_abc123', // optional
);
final replays = await client.listReplays(limit: 50);
final r = await client.getReplay('rpl_abc123');
await client.cancelReplay('rpl_abc123');
```

## Scheduled Jobs

```dart
// Create a job
final job = await client.createJob('daily-report', 'default', '0 9 * * *',
    extra: {'payload': {'type': 'daily'}});

// CRUD
final jobs = await client.listJobs(limit: 10);
final j = await client.getJob('job_abc123');
await client.updateJob('job_abc123', {'cron_expression': '0 10 * * *'});
await client.deleteJob('job_abc123');

// List runs for a job
final runs = await client.listJobRuns('job_abc123', limit: 20);

// Preview cron schedule
final preview = await client.cronPreview('0 9 * * *', count: 10);
```

## Pipelines

```dart
final pipeline = await client.createPipeline('order-processing', ['order.created'], [
  {'type': 'filter', 'config': {'field': 'amount', 'gt': 100}},
  {'type': 'transform', 'config': {'add_field': 'priority', 'value': 'high'}},
]);

final pipelines = await client.listPipelines(limit: 50);
final p = await client.getPipeline('pipe_abc123');
await client.updatePipeline('pipe_abc123', {'name': 'order-processing-v2'});
await client.deletePipeline('pipe_abc123');

// Test a pipeline with a sample payload
final result = await client.testPipeline('pipe_abc123', {'topic': 'order.created', 'payload': {'id': '1'}});
```

## Event Schemas

```dart
final schema = await client.createEventSchema('order.created', {
  'type': 'object',
  'properties': {
    'order_id': {'type': 'string'},
    'amount': {'type': 'number'},
  },
  'required': ['order_id', 'amount'],
});

final schemas = await client.listEventSchemas(limit: 50);
final s = await client.getEventSchema('sch_abc123');
await client.updateEventSchema('sch_abc123', {'schema': {'type': 'object'}});
await client.deleteEventSchema('sch_abc123');

// Validate a payload against a topic's schema
final result = await client.validatePayload('order.created', {'order_id': '123', 'amount': 50});
```

## Sandbox

```dart
final endpoint = await client.createSandboxEndpoint(name: 'my-test');
final endpoints = await client.listSandboxEndpoints();
final requests = await client.listSandboxRequests('sbx_abc123', limit: 20);
await client.deleteSandboxEndpoint('sbx_abc123');
```

## Analytics

```dart
final eventsChart = await client.eventsPerDay(days: 30);
final deliveriesChart = await client.deliveriesPerDay(days: 7);
final topics = await client.topTopics(limit: 5);
final stats = await client.webhookStats();
```

## Project and Token Management

```dart
final project = await client.getProject();
await client.updateProject({'name': 'My Project v2'});
final topics = await client.listTopics();
final token = await client.getToken();
final newToken = await client.regenerateToken();
```

## Multi-Project Management

```dart
final projects = await client.listProjects();
final newProject = await client.createProject('staging-env');
final p = await client.getProjectById('proj_abc123');
await client.updateProjectById('proj_abc123', {'name': 'production-env'});
await client.setDefaultProject('proj_abc123');
await client.deleteProject('proj_abc123');
```

## Team Members

```dart
final members = await client.listMembers('proj_abc123');
final member = await client.addMember('proj_abc123', 'alice@example.com', role: 'admin');
await client.updateMember('proj_abc123', 'mem_abc123', 'viewer');
await client.removeMember('proj_abc123', 'mem_abc123');
```

## Invitations

```dart
final invitations = await client.listPendingInvitations();
await client.acceptInvitation('inv_abc123');
await client.rejectInvitation('inv_def456');
```

## Audit Logs

```dart
final logs = await client.listAuditLogs(limit: 100);
```

## Data Export

```dart
import 'dart:io';

final csvData = await client.exportEvents(format: 'csv');
File('events.csv').writeAsStringSync(csvData);

final jsonData = await client.exportDeliveries(format: 'json');
await client.exportJobs(format: 'csv');
await client.exportAuditLog(format: 'csv');
```

## GDPR / Privacy

```dart
final consents = await client.getConsents();
await client.acceptConsent('marketing');
final myData = await client.exportMyData();
await client.restrictProcessing();
await client.liftRestriction();
await client.objectToProcessing();
await client.restoreConsent();
```

## Health Check

```dart
final health = await client.health();
final status = await client.status();
```

## Error Handling

```dart
try {
  final event = await client.getEvent('nonexistent');
} on JobcelisException catch (e) {
  print('Status: ${e.statusCode}');
  print('Detail: ${e.detail}');
} catch (e) {
  print('Error: $e');
}
```

## Webhook Signature Verification

```dart
import 'package:jobcelis/jobcelis.dart';

final body = '{"topic":"order.created"}';
final signature = '...';

if (WebhookVerifier.verify('your_webhook_secret', body, signature)) {
  print('Valid signature!');
} else {
  print('Invalid signature!');
}
```

## License

BSL-1.1 (Business Source License)
