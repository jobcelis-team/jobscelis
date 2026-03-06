# jobcelis

Official Python SDK for the Jobcelis Event Infrastructure Platform.

## Installation

```bash
pip install jobcelis
```

## Quick Start

```python
from jobcelis import JobcelisClient

client = JobcelisClient(
    api_key="your_api_key",
    base_url="https://jobcelis.com",  # optional
)

# Send an event
event = client.send_event("order.created", {"order_id": "123", "amount": 99.99})

# Send batch events
batch = client.send_events([
    {"topic": "order.created", "payload": {"order_id": "1"}},
    {"topic": "order.created", "payload": {"order_id": "2"}},
])

# List webhooks
webhooks = client.list_webhooks()

# Create a webhook
webhook = client.create_webhook(
    url="https://example.com/webhook",
    topics=["order.*"],
)
```

## Webhook Signature Verification

```python
from jobcelis import verify_webhook_signature

# Flask example
@app.route('/webhook', methods=['POST'])
def handle_webhook():
    is_valid = verify_webhook_signature(
        secret='your_webhook_secret',
        body=request.get_data(as_text=True),
        signature=request.headers.get('X-Signature', '')
    )

    if not is_valid:
        return 'Invalid signature', 401

    event = request.get_json()
    print(f"Received: {event['topic']}")
    return 'OK', 200
```

## License

MIT
