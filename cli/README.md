# @jobcelis/cli

Command-line interface for the Jobcelis Event Infrastructure Platform.

## Installation

```bash
npm install -g @jobcelis/cli
```

## Setup

```bash
export JOBCELIS_API_KEY="your_api_key"
export JOBCELIS_URL="https://jobcelis.com"  # optional
```

## Usage

```bash
# Send an event
jobcelis events send --topic order.created --payload '{"id":"123","amount":99.99}'

# List events
jobcelis events list --limit 10

# Get event details
jobcelis events get <event-id>

# List webhooks
jobcelis webhooks list

# Create a webhook
jobcelis webhooks create --url https://example.com/hook --topics "order.*,user.*"

# List deliveries
jobcelis deliveries list --event-id <id>

# List dead letters
jobcelis dead-letters list

# Check platform status
jobcelis status
```

## License

MIT
