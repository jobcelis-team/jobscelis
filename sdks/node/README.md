# @jobcelis/sdk

Official Node.js/TypeScript SDK for the Jobcelis Event Infrastructure Platform.

## Installation

```bash
npm install @jobcelis/sdk
```

## Quick Start

```typescript
import { JobcelisClient } from '@jobcelis/sdk';

const client = new JobcelisClient({
  apiKey: 'your_api_key',
  baseUrl: 'https://jobcelis.com', // optional, defaults to this
});

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
- `sendEvent(event)` — Send a single event
- `sendEvents(events)` — Send up to 1000 events
- `getEvent(id)` — Get event details
- `listEvents(opts?)` — List events (cursor pagination)
- `deleteEvent(id)` — Deactivate an event

### Webhooks
- `createWebhook(webhook)` — Create a webhook
- `getWebhook(id)` — Get webhook details
- `listWebhooks(opts?)` — List webhooks
- `updateWebhook(id, updates)` — Update a webhook
- `deleteWebhook(id)` — Deactivate a webhook

### Deliveries
- `listDeliveries(opts?)` — List deliveries
- `retryDelivery(id)` — Retry a failed delivery

### Dead Letters
- `listDeadLetters(opts?)` — List dead letters
- `getDeadLetter(id)` — Get dead letter details
- `retryDeadLetter(id)` — Retry a dead letter
- `resolveDeadLetter(id)` — Mark as resolved

### Replays
- `createReplay(replay)` — Start an event replay
- `listReplays(opts?)` — List replays
- `getReplay(id)` — Get replay details
- `cancelReplay(id)` — Cancel a replay

## License

MIT
