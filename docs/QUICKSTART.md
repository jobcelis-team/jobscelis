# Quickstart — From zero to first event in 5 minutes

## 1. Get your API key

Sign up at [jobcelis.com/signup](https://jobcelis.com/signup), create a project, and copy your API key from the dashboard.

## 2. Send your first event

```bash
curl -X POST https://jobcelis.com/api/v1/events \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: YOUR_API_KEY" \
  -d '{
    "topic": "order.created",
    "payload": {
      "order_id": "12345",
      "customer": "john@example.com",
      "amount": 99.99
    }
  }'
```

Response:
```json
{
  "event_id": "550e8400-e29b-41d4-a716-446655440000",
  "payload_hash": "a1b2c3..."
}
```

## 3. Create a webhook

```bash
curl -X POST https://jobcelis.com/api/v1/webhooks \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: YOUR_API_KEY" \
  -d '{
    "url": "https://your-server.com/webhook",
    "topics": ["order.*"],
    "secret": "my_webhook_secret"
  }'
```

Now every event with topic `order.*` will be POSTed to your URL.

## 4. Receive webhooks

Your endpoint will receive:

```http
POST /webhook HTTP/1.1
Content-Type: application/json
X-Signature: sha256=<base64_hmac>

{
  "topic": "order.created",
  "payload": {
    "order_id": "12345",
    "customer": "john@example.com",
    "amount": 99.99
  }
}
```

Verify the signature (see [Webhook Verification](WEBHOOK_VERIFICATION.md)) and return `200 OK`.

## 5. Use an SDK (optional)

### Node.js

```bash
npm install @jobcelis/sdk
```

```javascript
const { JobcelisClient } = require('@jobcelis/sdk');

const client = new JobcelisClient({ apiKey: 'YOUR_API_KEY' });

await client.sendEvent({
  topic: 'order.created',
  payload: { order_id: '12345', amount: 99.99 },
});
```

### Python

```bash
pip install jobcelis
```

```python
from jobcelis import JobcelisClient

client = JobcelisClient(api_key="YOUR_API_KEY")

client.send_event("order.created", {"order_id": "12345", "amount": 99.99})
```

### CLI

```bash
npm install -g @jobcelis/cli
export JOBCELIS_API_KEY="YOUR_API_KEY"

jobcelis events send --topic order.created --payload '{"order_id":"12345"}'
```

## Next steps

- [API Documentation](https://jobcelis.com/docs) — Full API reference
- [Webhook Verification](WEBHOOK_VERIFICATION.md) — Secure your endpoints
- [Architecture](ARCHITECTURE.md) — How Jobcelis works internally
- [SDK Node.js](../sdks/node/README.md) — Full Node.js SDK reference
- [SDK Python](../sdks/python/README.md) — Full Python SDK reference
