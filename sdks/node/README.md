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

## Authentication

Two credentials exist:

- **API key** (`apiKey`, sent as `X-Api-Key`): events, webhooks, deliveries, jobs, pipelines, project
  settings... everything scoped to one project.
- **User JWT** (`authToken`, sent as `Authorization: Bearer <token>`): the account routes
  `/projects*`, `/projects/:id/members*`, `/invitations*` and `/me/*` (GDPR). With only an API key these
  return 401.

`login()`, `register()`, `verifyMfa()` and `refreshToken()` need no API key and store the returned JWT
on the client:

```typescript
const client = new JobcelisClient({ apiKey: 'your_api_key' });

const res = await client.login('you@example.com', 'password');
if ('mfa_required' in res) {
  await client.verifyMfa(res.mfa_token, '123456'); // TOTP code
}

const projects = await client.listProjects(); // uses the stored JWT

// Or pass a JWT you already have
client.setAuthToken(process.env.JOBCELIS_TOKEN);
const sameClient = new JobcelisClient({ apiKey: 'your_api_key', authToken: 'eyJ...' });

// Refresh before it expires (defaults to the stored token)
await client.refreshToken();
```

## Webhook Signature Verification

```typescript
import { verifyWebhookSignature } from '@jobcelis/sdk';

// Express example
app.post('/webhook', express.raw({ type: 'application/json' }), (req, res) => {
  const isValid = verifyWebhookSignature(
    'your_webhook_secret',
    req.body, // raw Buffer (a string works too)
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
// Emit an event on a cron schedule
const job = await client.createJob({
  name: 'daily-report',
  schedule: '0 9 * * *', // cron expression, or 'daily' | 'weekly' | 'monthly'
  topic: 'report.generate',
  payload: { type: 'daily' },
});

// Or POST to a URL
await client.createJob({ name: 'ping', schedule: 'daily', url: 'https://example.com/ping' });

const runs = await client.listJobRuns(job.id, { limit: 10 });

const preview = await client.cronPreview('*/5 * * * *', 5);
console.log('Next executions:', preview.next_executions);
```

### Pipelines

- `createPipeline(data)` -- Create an event pipeline
- `listPipelines(opts?)` -- List pipelines
- `getPipeline(id)` -- Get pipeline details
- `updatePipeline(id, updates)` -- Update a pipeline
- `deletePipeline(id)` -- Delete a pipeline
- `testPipeline(id, payload)` -- Test a pipeline with a sample payload

```typescript
const { data: pipeline } = await client.createPipeline({
  name: 'order-enrichment',
  topics: ['order.created'],
  webhook_id: 'wh_abc', // required: where the processed events are delivered
  steps: [
    { type: 'filter', field: 'amount', operator: 'gt', value: 100 },
    { type: 'transform', operation: 'set', values: { priority: 'high' } },
    { type: 'delay', seconds: 60 },
  ],
});

const result = await client.testPipeline(pipeline.id, { amount: 150 });
console.log(result.status, result.output); // 'passed' { amount: 150, priority: 'high' }
```

Step types are `filter`, `transform` and `delay`. Transform steps need an `operation`: `pick` / `remove`
(`fields`), `rename` (`mapping`), `set` (`values`), `template` (`template`) or `flatten`.

### Event Schemas

- `createEventSchema(data)` -- Create a schema
- `listEventSchemas(opts?)` -- List schemas
- `getEventSchema(id)` -- Get schema details
- `updateEventSchema(id, updates)` -- Update a schema
- `deleteEventSchema(id)` -- Delete a schema
- `validatePayload(topic, payload)` -- Validate a payload against its topic schema

```typescript
const { data: schema } = await client.createEventSchema({
  topic: 'order.created',
  version: 1,
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
- `updateTokenRestrictions({ scopes, allowed_ips })` -- Limit the token to scopes and client IPs

```typescript
const project = await client.getProject();
const topics = await client.listTopics();
const { token } = await client.regenerateToken();

// Limit the token to scopes and client IPs (empty allowed_ips = any IP)
await client.updateTokenRestrictions({ scopes: ['events:read', 'events:write'], allowed_ips: ['203.0.113.10'] });
```

### Projects (Multi-project)

- `listProjects()` -- List all projects
- `createProject(name)` -- Create a new project
- `getProjectById(id)` -- Get project by ID
- `updateProjectById(id, updates)` -- Update a project
- `deleteProject(id)` -- Delete a project
- `setDefaultProject(id)` -- Set the default project

```typescript
// Requires a user JWT (see Authentication)
const { data: newProject } = await client.createProject('staging');
await client.setDefaultProject(newProject.id);
```

### Teams

- `listMembers(projectId)` -- List project members
- `addMember(projectId, email, role?)` -- Invite a member
- `updateMember(projectId, memberId, role)` -- Change member role
- `removeMember(projectId, memberId)` -- Remove a member

```typescript
// Requires a user JWT. Roles: 'viewer' (default) or 'editor'
const { data: member } = await client.addMember(project.id, 'dev@example.com', 'editor');
await client.updateMember(project.id, member.id, 'viewer');
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
- `restrictProcessing(password)` -- Request processing restriction (requires your password)
- `liftRestriction()` -- Lift processing restriction
- `objectToProcessing()` -- Object to data processing
- `restoreConsent()` -- Withdraw objection

```typescript
// Requires a user JWT (see Authentication)
await client.acceptConsent('analytics');
const myData = await client.exportMyData();
```

### Health

- `health()` / `status()` -- Check platform health (`GET /health`)

```typescript
const status = await client.health();
```

### Retention & Purge

- `getRetentionPolicy()` -- Current retention policy
- `updateRetentionPolicy(policy)` -- Update it (sent as `{ retention_policy: policy }`)
- `previewPurge(params)` -- Count the records a purge would delete
- `purgeData(params)` -- Delete records older than `older_than` (YYYY-MM-DD, required)

```typescript
await client.updateRetentionPolicy({ events_days: 30, deliveries_days: 30, audit_logs_days: 90 });
const preview = await client.previewPurge({ type: 'events', older_than: '2026-01-01' });
```

## Retries

The client retries requests that fail during a brief outage (for example while the
platform is being deployed):

- network errors (connection refused or reset, DNS, TLS), timeouts and HTTP `429`, `502`, `503`, `504`
- up to 6 retries with exponential backoff (1 s, 2 s, 4 s, 8 s, 16 s, 30 s, about 60 s in total, with jitter);
  a `Retry-After` header is honoured (capped at 60 s)
- a `POST` without an idempotency key is retried only on `429` and `503` (the server did not act on it);
  after a network error, timeout, `502` or `504` it may have, so it is not retried and a retry never
  creates a resource twice. `sendEvent` sends an `X-Idempotency-Key` header (your `idempotency_key`, or a
  generated UUID) and `sendEvents` adds an `idempotency_key` to every event that has none, so retried events are
  never duplicated.

Other errors (`400`, `401`, `404`, `500`, ...) are raised at once; after the last retry the error is the same
one you would get without retries. A request that exceeds `timeout` (ms, default 30000; `0` disables it)
raises a `JobcelisError` with `status` 0.

```typescript
// Change the number of retries
const client = new JobcelisClient({ apiKey: 'your_api_key', maxRetries: 3 });

// Disable retries
const noRetries = new JobcelisClient({ apiKey: 'your_api_key', maxRetries: 0 });
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

BSL-1.1 (Business Source License)
