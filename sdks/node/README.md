# @jobcelis/sdk

Official Node.js/TypeScript SDK for the [Jobcelis](https://jobcelis.com) Event Infrastructure Platform.

All API calls go to `https://jobcelis.com` by default — you only need your API key to get started.

## Installation

```bash
npm install @jobcelis/sdk
```

## Quick Start

```typescript
import { JobcelisClient } from '@jobcelis/sdk';

// Only your API key is required — connects to https://jobcelis.com automatically
const client = new JobcelisClient({ apiKey: 'your_api_key' });

// Send an event
const event = await client.sendEvent({
  topic: 'order.created',
  payload: { order_id: '123', amount: 99.99 },
});

// Send batch events
const batch = await client.sendEvents([
  { topic: 'order.created', payload: { order_id: '1' } },
  { topic: 'order.created', payload: { order_id: '2' } },
]);

// List webhooks
const webhooks = await client.listWebhooks();

// Create a webhook
const webhook = await client.createWebhook({
  url: 'https://example.com/webhook',
  topics: ['order.*'],
});
```

> **Custom URL:** If you're self-hosting Jobcelis, you can override the base URL:
> ```typescript
> const client = new JobcelisClient({ apiKey: 'key', baseUrl: 'https://your-instance.example.com' });
> ```

## Webhook Signature Verification

```typescript
import { verifyWebhookSignature } from '@jobcelis/sdk';

// Express example
app.post('/webhook', express.raw({ type: 'application/json' }), (req, res) => {
  const isValid = verifyWebhookSignature(
    'your_webhook_secret',
    req.body.toString(),
    req.headers['x-signature'] as string
  );

  if (!isValid) {
    return res.status(401).send('Invalid signature');
  }

  const event = JSON.parse(req.body.toString());
  console.log('Received event:', event.topic);
  res.status(200).send('OK');
});
```

## API Reference

### Events

- `sendEvent(event)` -- Send a single event
- `sendEvents(events)` -- Send up to 1000 events in a batch
- `getEvent(id)` -- Get event details
- `listEvents(opts?)` -- List events (cursor pagination)
- `deleteEvent(id)` -- Deactivate an event

```typescript
const event = await client.sendEvent({
  topic: 'user.signup',
  payload: { user_id: 'u_42', plan: 'pro' },
  idempotency_key: 'signup-u_42',
});

const events = await client.listEvents({ limit: 50 });
```

### Webhooks

- `createWebhook(webhook)` -- Create a webhook
- `getWebhook(id)` -- Get webhook details
- `listWebhooks(opts?)` -- List webhooks
- `updateWebhook(id, updates)` -- Update a webhook
- `deleteWebhook(id)` -- Deactivate a webhook
- `webhookHealth(id)` -- Get webhook health/success rate
- `webhookTemplates()` -- List available webhook templates

```typescript
const webhook = await client.createWebhook({
  url: 'https://api.example.com/hooks',
  topics: ['order.*', 'payment.*'],
  retry_config: { strategy: 'exponential', max_attempts: 5 },
});

const health = await client.webhookHealth(webhook.id);
console.log(`Success rate: ${health.success_rate}%`);

const templates = await client.webhookTemplates();
```

### Deliveries

- `listDeliveries(opts?)` -- List deliveries (filter by event_id, webhook_id, status)
- `retryDelivery(id)` -- Retry a failed delivery

```typescript
const deliveries = await client.listDeliveries({
  webhook_id: 'wh_abc',
  status: 'failed',
});
```

### Dead Letters

- `listDeadLetters(opts?)` -- List dead letters
- `getDeadLetter(id)` -- Get dead letter details
- `retryDeadLetter(id)` -- Retry a dead letter
- `resolveDeadLetter(id)` -- Mark as resolved

### Replays

- `createReplay(replay)` -- Start an event replay
- `listReplays(opts?)` -- List replays
- `getReplay(id)` -- Get replay details
- `cancelReplay(id)` -- Cancel a replay

```typescript
const replay = await client.createReplay({
  topic: 'order.created',
  from_date: '2026-03-01T00:00:00Z',
  to_date: '2026-03-05T00:00:00Z',
  webhook_id: 'wh_abc',
});
```

### Jobs (Scheduled Events)

- `createJob(data)` -- Create a scheduled job
- `listJobs(opts?)` -- List jobs
- `getJob(id)` -- Get job details
- `updateJob(id, updates)` -- Update a job
- `deleteJob(id)` -- Delete a job
- `listJobRuns(jobId, opts?)` -- List runs for a job
- `cronPreview(expression, count?)` -- Preview cron execution times

```typescript
const job = await client.createJob({
  name: 'daily-report',
  schedule: '0 9 * * *',
  topic: 'report.generate',
  payload: { type: 'daily' },
  timezone: 'America/New_York',
});

const runs = await client.listJobRuns(job.id, { limit: 10 });

const preview = await client.cronPreview('*/5 * * * *', 5);
console.log('Next executions:', preview.executions);
```

### Pipelines

- `createPipeline(data)` -- Create an event pipeline
- `listPipelines(opts?)` -- List pipelines
- `getPipeline(id)` -- Get pipeline details
- `updatePipeline(id, updates)` -- Update a pipeline
- `deletePipeline(id)` -- Delete a pipeline
- `testPipeline(id, payload)` -- Test a pipeline with a sample payload

```typescript
const pipeline = await client.createPipeline({
  name: 'order-enrichment',
  source_topic: 'order.created',
  steps: [
    { type: 'filter', config: { field: 'amount', operator: 'gt', value: 100 } },
    { type: 'transform', config: { add_field: 'priority', value: 'high' } },
    { type: 'deliver', config: { topic: 'order.high_value' } },
  ],
});
```

### Event Schemas

- `createEventSchema(data)` -- Create a schema
- `listEventSchemas(opts?)` -- List schemas
- `getEventSchema(id)` -- Get schema details
- `updateEventSchema(id, updates)` -- Update a schema
- `deleteEventSchema(id)` -- Delete a schema
- `validatePayload(topic, payload)` -- Validate a payload against its topic schema

```typescript
const schema = await client.createEventSchema({
  topic: 'order.created',
  version: '1.0',
  schema: {
    type: 'object',
    required: ['order_id', 'amount'],
    properties: {
      order_id: { type: 'string' },
      amount: { type: 'number' },
    },
  },
});

const result = await client.validatePayload('order.created', { order_id: '1' });
if (!result.valid) {
  console.error('Validation errors:', result.errors);
}
```

### Sandbox

- `listSandboxEndpoints()` -- List sandbox endpoints
- `createSandboxEndpoint(name?)` -- Create a sandbox endpoint
- `deleteSandboxEndpoint(id)` -- Delete a sandbox endpoint
- `listSandboxRequests(endpointId, opts?)` -- List requests received by an endpoint

```typescript
const endpoint = await client.createSandboxEndpoint('test-hook');
console.log('Sandbox URL:', endpoint.url);

// Point a webhook at the sandbox URL, send an event, then inspect
const requests = await client.listSandboxRequests(endpoint.id);
```

### Analytics

- `eventsPerDay(days?)` -- Event volume by day
- `deliveriesPerDay(days?)` -- Delivery volume by day
- `topTopics(limit?)` -- Most active topics
- `webhookStats()` -- Per-webhook delivery statistics

```typescript
const volume = await client.eventsPerDay(30);
const topics = await client.topTopics(10);
const stats = await client.webhookStats();
```

### Project (Current)

- `getProject()` -- Get current project
- `updateProject(updates)` -- Update current project
- `listTopics()` -- List all topics in the project
- `getToken()` -- Get current API token info
- `regenerateToken()` -- Regenerate the API token

```typescript
const project = await client.getProject();
const topics = await client.listTopics();
const { token } = await client.regenerateToken();
```

### Projects (Multi-project)

- `listProjects()` -- List all projects
- `createProject(name)` -- Create a new project
- `getProjectById(id)` -- Get project by ID
- `updateProjectById(id, updates)` -- Update a project
- `deleteProject(id)` -- Delete a project
- `setDefaultProject(id)` -- Set the default project

```typescript
const newProject = await client.createProject('staging');
await client.setDefaultProject(newProject.id);
```

### Teams

- `listMembers(projectId)` -- List project members
- `addMember(projectId, email, role?)` -- Invite a member
- `updateMember(projectId, memberId, role)` -- Change member role
- `removeMember(projectId, memberId)` -- Remove a member

```typescript
const member = await client.addMember(project.id, 'dev@example.com', 'editor');
await client.updateMember(project.id, member.id, 'admin');
```

### Invitations

- `listPendingInvitations()` -- List pending invitations
- `acceptInvitation(id)` -- Accept an invitation
- `rejectInvitation(id)` -- Reject an invitation

```typescript
const invitations = await client.listPendingInvitations();
await client.acceptInvitation(invitations.data[0].id);
```

### Audit Log

- `listAuditLogs(opts?)` -- List audit log entries

```typescript
const logs = await client.listAuditLogs({ limit: 100 });
```

### Export (CSV)

- `exportEvents()` -- Export events as CSV text
- `exportDeliveries()` -- Export deliveries as CSV text
- `exportJobs()` -- Export jobs as CSV text
- `exportAuditLog()` -- Export audit log as CSV text

```typescript
const csv = await client.exportEvents();
fs.writeFileSync('events.csv', csv);
```

### Simulate

- `simulateEvent(topic, payload)` -- Simulate an event (dry run)

```typescript
const simulated = await client.simulateEvent('order.created', { order_id: '999' });
```

### GDPR

- `getConsents()` -- List your consent records
- `acceptConsent(purpose)` -- Accept a consent purpose
- `exportMyData()` -- Export your personal data
- `restrictProcessing()` -- Request processing restriction
- `liftRestriction()` -- Lift processing restriction
- `objectToProcessing()` -- Object to data processing
- `restoreConsent()` -- Withdraw objection

```typescript
await client.acceptConsent('analytics');
const myData = await client.exportMyData();
```

### Health

- `health()` -- Check platform health

```typescript
const status = await client.health();
```

## Error Handling

```typescript
import { JobcelisClient, JobcelisError } from '@jobcelis/sdk';

try {
  await client.getEvent('nonexistent');
} catch (err) {
  if (err instanceof JobcelisError) {
    console.error(`API error ${err.status}: ${err.message}`);
  }
}
```

## Pagination

All list methods support cursor-based pagination:

```typescript
let cursor: string | undefined;
do {
  const page = await client.listEvents({ limit: 100, cursor });
  for (const event of page.data) {
    console.log(event.topic);
  }
  cursor = page.has_next ? (page.next_cursor ?? undefined) : undefined;
} while (cursor);
```

## License

MIT
