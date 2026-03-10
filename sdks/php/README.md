# jobcelis/sdk

Official PHP SDK for the [Jobcelis](https://jobcelis.com) Event Infrastructure Platform.

All API calls go to `https://jobcelis.com` by default -- you only need your API key to get started.

## Installation

```bash
composer require jobcelis/sdk
```

## Quick Start

```php
use Jobcelis\Client;

// Only your API key is required -- connects to https://jobcelis.com automatically
$client = new Client(apiKey: 'your_api_key');
```

> **Custom URL:** If you're self-hosting Jobcelis, you can override the base URL:
> ```php
> $client = new Client(apiKey: 'your_api_key', baseUrl: 'https://your-instance.example.com');
> ```

## Authentication

The auth methods do not require an API key. Use them to register, log in, and manage JWT tokens.

```php
use Jobcelis\Client;

$client = new Client(apiKey: '');

// Register a new account
$user = $client->register('alice@example.com', 'SecurePass123!', name: 'Alice');

// Log in -- returns JWT access token and refresh token
$session = $client->login('alice@example.com', 'SecurePass123!');
$accessToken = $session['token'];
$refreshToken = $session['refresh_token'];

// Set the JWT for subsequent authenticated calls
$client->setAuthToken($accessToken);

// Refresh an expired token
$newSession = $client->refreshToken($refreshToken);
$client->setAuthToken($newSession['token']);

// Verify MFA (requires Bearer token already set)
$result = $client->verifyMfa(token: $accessToken, code: '123456');
```

## Events

```php
// Send a single event
$event = $client->sendEvent('order.created', ['order_id' => '123', 'amount' => 99.99]);

// Send batch events (up to 1000)
$batch = $client->sendEvents([
    ['topic' => 'order.created', 'payload' => ['order_id' => '1']],
    ['topic' => 'order.created', 'payload' => ['order_id' => '2']],
]);

// List events with pagination
$events = $client->listEvents(limit: 25);
$nextPage = $client->listEvents(limit: 25, cursor: $events['cursor']);

// Get / delete a single event
$event = $client->getEvent('evt_abc123');
$client->deleteEvent('evt_abc123');
```

## Webhooks

```php
// Create a webhook
$webhook = $client->createWebhook(
    url: 'https://example.com/webhook',
    extra: ['topics' => ['order.*']],
);

// List, get, update, delete
$webhooks = $client->listWebhooks();
$wh = $client->getWebhook('wh_abc123');
$client->updateWebhook('wh_abc123', ['url' => 'https://new-url.com/hook']);
$client->deleteWebhook('wh_abc123');

// Health and templates
$health = $client->webhookHealth('wh_abc123');
$templates = $client->webhookTemplates();
```

## Deliveries

```php
$deliveries = $client->listDeliveries(limit: 20, filters: ['status' => 'failed']);
$client->retryDelivery('del_abc123');
```

## Dead Letters

```php
$deadLetters = $client->listDeadLetters();
$dl = $client->getDeadLetter('dlq_abc123');
$client->retryDeadLetter('dlq_abc123');
$client->resolveDeadLetter('dlq_abc123');
```

## Replays

```php
$replay = $client->createReplay(
    topic: 'order.created',
    fromDate: '2026-01-01T00:00:00Z',
    toDate: '2026-01-31T23:59:59Z',
    webhookId: 'wh_abc123', // optional
);
$replays = $client->listReplays();
$r = $client->getReplay('rpl_abc123');
$client->cancelReplay('rpl_abc123');
```

## Scheduled Jobs

```php
// Create a job
$job = $client->createJob(
    name: 'daily-report',
    queue: 'default',
    cronExpression: '0 9 * * *',
    extra: ['payload' => ['type' => 'daily']],
);

// CRUD
$jobs = $client->listJobs(limit: 10);
$job = $client->getJob('job_abc123');
$client->updateJob('job_abc123', ['cron_expression' => '0 10 * * *']);
$client->deleteJob('job_abc123');

// List runs for a job
$runs = $client->listJobRuns('job_abc123', limit: 20);

// Preview cron schedule
$preview = $client->cronPreview('0 9 * * *', count: 10);
```

## Pipelines

```php
$pipeline = $client->createPipeline(
    name: 'order-processing',
    topics: ['order.created'],
    steps: [
        ['type' => 'filter', 'config' => ['field' => 'amount', 'gt' => 100]],
        ['type' => 'transform', 'config' => ['add_field' => 'priority', 'value' => 'high']],
    ],
);

$pipelines = $client->listPipelines();
$p = $client->getPipeline('pipe_abc123');
$client->updatePipeline('pipe_abc123', ['name' => 'order-processing-v2']);
$client->deletePipeline('pipe_abc123');

// Test a pipeline with a sample payload
$result = $client->testPipeline('pipe_abc123', [
    'topic' => 'order.created',
    'payload' => ['id' => '1'],
]);
```

## Event Schemas

```php
$schema = $client->createEventSchema(
    topic: 'order.created',
    schema: [
        'type' => 'object',
        'properties' => [
            'order_id' => ['type' => 'string'],
            'amount' => ['type' => 'number'],
        ],
        'required' => ['order_id', 'amount'],
    ],
);

$schemas = $client->listEventSchemas();
$s = $client->getEventSchema('sch_abc123');
$client->updateEventSchema('sch_abc123', ['schema' => ['type' => 'object']]);
$client->deleteEventSchema('sch_abc123');

// Validate a payload against a topic's schema
$result = $client->validatePayload('order.created', ['order_id' => '123', 'amount' => 50]);
```

## Sandbox

```php
// Create a temporary endpoint for testing
$endpoint = $client->createSandboxEndpoint(name: 'my-test');
$endpoints = $client->listSandboxEndpoints();

// Inspect received requests
$requests = $client->listSandboxRequests('sbx_abc123', limit: 20);

$client->deleteSandboxEndpoint('sbx_abc123');
```

## Analytics

```php
$eventsChart = $client->eventsPerDay(days: 30);
$deliveriesChart = $client->deliveriesPerDay(days: 7);
$topics = $client->topTopics(limit: 5);
$stats = $client->webhookStats();
```

## Project and Token Management

```php
// Current project
$project = $client->getProject();
$client->updateProject(['name' => 'My Project v2']);

// Topics
$topics = $client->listTopics();

// API token
$token = $client->getToken();
$newToken = $client->regenerateToken();
```

## Multi-Project Management

```php
$projects = $client->listProjects();
$newProject = $client->createProject('staging-env');
$p = $client->getProjectById('proj_abc123');
$client->updateProjectById('proj_abc123', ['name' => 'production-env']);
$client->setDefaultProject('proj_abc123');
$client->deleteProject('proj_abc123');
```

## Team Members

```php
$members = $client->listMembers('proj_abc123');
$member = $client->addMember('proj_abc123', 'alice@example.com', role: 'admin');
$client->updateMember('proj_abc123', 'mem_abc123', role: 'viewer');
$client->removeMember('proj_abc123', 'mem_abc123');
```

## Invitations

```php
// List pending invitations
$invitations = $client->listPendingInvitations();

// Accept or reject
$client->acceptInvitation('inv_abc123');
$client->rejectInvitation('inv_def456');
```

## Audit Logs

```php
$logs = $client->listAuditLogs(limit: 100);
$nextPage = $client->listAuditLogs(cursor: $logs['cursor']);
```

## Data Export

Export methods return raw strings (CSV or JSON).

```php
// Export as CSV
$csvData = $client->exportEvents(format: 'csv');
file_put_contents('events.csv', $csvData);

// Export as JSON
$jsonData = $client->exportDeliveries(format: 'json');

// Other exports
$client->exportJobs(format: 'csv');
$client->exportAuditLog(format: 'csv');
```

## Simulate

```php
// Dry-run an event to see which webhooks would fire
$result = $client->simulateEvent('order.created', ['order_id' => 'test']);
```

## GDPR / Privacy

```php
// Consent management
$consents = $client->getConsents();
$client->acceptConsent('marketing');

// Data portability
$myData = $client->exportMyData();

// Processing restrictions
$client->restrictProcessing();
$client->liftRestriction();

// Right to object
$client->objectToProcessing();
$client->restoreConsent();
```

## Health Check

```php
$health = $client->health();
$status = $client->status();
```

## Error Handling

```php
use Jobcelis\Client;
use Jobcelis\JobcelisException;

$client = new Client(apiKey: 'your_api_key');

try {
    $event = $client->getEvent('nonexistent');
} catch (JobcelisException $e) {
    echo "Status: " . $e->statusCode . "\n";  // 404
    echo "Detail: " . print_r($e->detail, true) . "\n";
}
```

## Webhook Signature Verification

```php
use Jobcelis\WebhookVerifier;

// In your webhook handler
$body = file_get_contents('php://input');
$signature = $_SERVER['HTTP_X_SIGNATURE'] ?? '';

$isValid = WebhookVerifier::verify(
    secret: 'your_webhook_secret',
    body: $body,
    signature: $signature,
);

if (!$isValid) {
    http_response_code(401);
    echo 'Invalid signature';
    exit;
}

$event = json_decode($body, true);
echo "Received: " . $event['topic'];
http_response_code(200);
```

## License

BSL-1.1 (Business Source License)
