# @jobcelis/cli

Command-line interface for the Jobcelis Event Infrastructure Platform.

## Installation

```bash
npm install -g @jobcelis/cli
```

Or run directly with npx:

```bash
npx @jobcelis/cli status
```

## Configuration

Set the following environment variables:

| Variable | Required | Default | Description |
|---|---|---|---|
| `JOBCELIS_API_KEY` | Yes | - | Your API key |
| `JOBCELIS_BASE_URL` | No | `https://jobcelis.com` | Platform base URL |

```bash
export JOBCELIS_API_KEY=your_api_key_here
```

## Commands

### Events

```bash
# Send an event
jobcelis events send --topic user.signup --payload '{"user_id": "abc123", "email": "user@example.com"}'

# List events
jobcelis events list
jobcelis events list --limit 20 --cursor eyJpZCI6MTAwfQ==

# Get a single event
jobcelis events get 550e8400-e29b-41d4-a716-446655440000

# Send a batch of events from a JSON file
jobcelis events batch --file ./events.json
```

### Webhooks

```bash
# List all webhooks
jobcelis webhooks list

# Create a webhook
jobcelis webhooks create --url https://example.com/webhook --topics user.signup,order.created

# Get a webhook
jobcelis webhooks get 550e8400-e29b-41d4-a716-446655440000

# Delete a webhook
jobcelis webhooks delete 550e8400-e29b-41d4-a716-446655440000
```

### Deliveries

```bash
# List deliveries
jobcelis deliveries list
jobcelis deliveries list --limit 50

# Retry a failed delivery
jobcelis deliveries retry 550e8400-e29b-41d4-a716-446655440000
```

### Scheduled Jobs

```bash
# List jobs
jobcelis jobs list

# Create a job
jobcelis jobs create --name daily-report --queue default --cron "0 9 * * *"

# Delete a job
jobcelis jobs delete 550e8400-e29b-41d4-a716-446655440000
```

### Pipelines

```bash
# List pipelines
jobcelis pipelines list

# Create a pipeline
jobcelis pipelines create --name enrich-users --topics user.signup,user.updated --steps '[{"type":"transform","config":{}}]'
```

### Dead Letters

```bash
# List dead-letter entries
jobcelis dead-letters list

# Retry a dead-letter entry
jobcelis dead-letters retry 550e8400-e29b-41d4-a716-446655440000
```

### Replays

```bash
# List replays
jobcelis replays list

# Create a replay
jobcelis replays create --topic user.signup --from 2026-01-01T00:00:00Z --to 2026-01-02T00:00:00Z
```

### Schemas

```bash
# List event schemas
jobcelis schemas list
```

### Sandbox

```bash
# List sandbox endpoints
jobcelis sandbox list

# Create a sandbox endpoint
jobcelis sandbox create
jobcelis sandbox create --name my-test-endpoint
```

### Analytics

```bash
# Events per day
jobcelis analytics events
jobcelis analytics events --days 30

# Top topics
jobcelis analytics topics
jobcelis analytics topics --limit 10
```

### Export

```bash
# Export events to a JSON file
jobcelis export events

# Export deliveries to a JSON file
jobcelis export deliveries
```

### Other

```bash
# Check platform health
jobcelis status

# Show version
jobcelis version

# Show help
jobcelis help
```

## Output

All data commands output JSON to stdout. Status messages and errors are written to stderr.

- Exit code `0`: success
- Exit code `1`: error

## Development

```bash
# Build
npm run build

# Run locally
node dist/index.js help
```

## License

MIT
