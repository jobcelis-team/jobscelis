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
jobcelis events send --topic user.signup --payload '{"user_id": "abc123"}'

# List events
jobcelis events list
jobcelis events list --limit 20 --cursor eyJpZCI6MTAwfQ==

# Get a single event
jobcelis events get 550e8400-e29b-41d4-a716-446655440000

# Delete an event
jobcelis events delete 550e8400-e29b-41d4-a716-446655440000

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

# Update a webhook
jobcelis webhooks update 550e8400-... --url https://new-url.com --topics user.updated

# Delete a webhook
jobcelis webhooks delete 550e8400-e29b-41d4-a716-446655440000

# Check webhook health
jobcelis webhooks health 550e8400-e29b-41d4-a716-446655440000

# List webhook templates
jobcelis webhooks templates
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

# Get a job
jobcelis jobs get 550e8400-e29b-41d4-a716-446655440000

# Update a job
jobcelis jobs update 550e8400-... --name new-name --cron "0 10 * * *"

# Delete a job
jobcelis jobs delete 550e8400-e29b-41d4-a716-446655440000

# List job runs
jobcelis jobs runs 550e8400-... --limit 10

# Preview cron schedule
jobcelis jobs cron-preview --cron "0 9 * * *" --count 5
```

### Pipelines

```bash
# List pipelines
jobcelis pipelines list

# Create a pipeline
jobcelis pipelines create --name enrich-users --topics user.signup --steps '[{"type":"transform"}]'

# Get a pipeline
jobcelis pipelines get 550e8400-e29b-41d4-a716-446655440000

# Update a pipeline
jobcelis pipelines update 550e8400-... --name new-name

# Delete a pipeline
jobcelis pipelines delete 550e8400-e29b-41d4-a716-446655440000

# Test a pipeline
jobcelis pipelines test 550e8400-... --payload '{"user_id":"123"}'
```

### Dead Letters

```bash
# List dead-letter entries
jobcelis dead-letters list

# Get a dead-letter entry
jobcelis dead-letters get 550e8400-e29b-41d4-a716-446655440000

# Retry a dead-letter entry
jobcelis dead-letters retry 550e8400-e29b-41d4-a716-446655440000

# Resolve a dead-letter entry
jobcelis dead-letters resolve 550e8400-e29b-41d4-a716-446655440000
```

### Replays

```bash
# List replays
jobcelis replays list

# Create a replay
jobcelis replays create --topic user.signup --from 2026-01-01T00:00:00Z --to 2026-01-02T00:00:00Z

# Get a replay
jobcelis replays get 550e8400-e29b-41d4-a716-446655440000

# Cancel a replay
jobcelis replays cancel 550e8400-e29b-41d4-a716-446655440000
```

### Schemas

```bash
# List event schemas
jobcelis schemas list

# Create a schema
jobcelis schemas create --topic user.signup --schema '{"type":"object","properties":{"user_id":{"type":"string"}}}'

# Get a schema
jobcelis schemas get 550e8400-e29b-41d4-a716-446655440000

# Update a schema
jobcelis schemas update 550e8400-... --schema '{"type":"object"}'

# Delete a schema
jobcelis schemas delete 550e8400-e29b-41d4-a716-446655440000

# Validate a payload against a schema
jobcelis schemas validate --topic user.signup --payload '{"user_id":"abc"}'
```

### Sandbox

```bash
# List sandbox endpoints
jobcelis sandbox list

# Create a sandbox endpoint
jobcelis sandbox create
jobcelis sandbox create --name my-test-endpoint

# Delete a sandbox endpoint
jobcelis sandbox delete 550e8400-e29b-41d4-a716-446655440000

# List requests for a sandbox endpoint
jobcelis sandbox requests 550e8400-... --limit 20
```

### Analytics

```bash
# Events per day
jobcelis analytics events
jobcelis analytics events --days 30

# Top topics
jobcelis analytics topics
jobcelis analytics topics --limit 10

# Deliveries per day
jobcelis analytics deliveries
jobcelis analytics deliveries --days 7

# Webhook statistics
jobcelis analytics webhook-stats
```

### Audit

```bash
# List audit log entries
jobcelis audit list
jobcelis audit list --limit 50
```

### Export

```bash
# Export events to a JSON file
jobcelis export events

# Export deliveries to a JSON file
jobcelis export deliveries

# Export jobs to a JSON file
jobcelis export jobs

# Export audit log to a JSON file
jobcelis export audit-log
```

### Project (current)

```bash
# Get current project details
jobcelis project get

# Update current project
jobcelis project update --name "My Project"

# List project topics
jobcelis project topics

# Get API token info
jobcelis project token

# Regenerate API token
jobcelis project regenerate-token
```

### Projects (multi)

```bash
# List all projects
jobcelis projects list

# Create a project
jobcelis projects create --name "New Project"

# Get a project
jobcelis projects get 550e8400-e29b-41d4-a716-446655440000

# Update a project
jobcelis projects update 550e8400-... --name "Updated Name"

# Delete a project
jobcelis projects delete 550e8400-e29b-41d4-a716-446655440000

# Set default project
jobcelis projects set-default 550e8400-e29b-41d4-a716-446655440000
```

### Team Members

```bash
# List project members
jobcelis members list --project 550e8400-...

# Add a member
jobcelis members add --project 550e8400-... --email user@example.com --role editor

# Update member role
jobcelis members update --project 550e8400-... abc123 --role admin

# Remove a member
jobcelis members remove --project 550e8400-... abc123
```

### Invitations

```bash
# List pending invitations
jobcelis invitations pending

# Accept an invitation
jobcelis invitations accept 550e8400-e29b-41d4-a716-446655440000

# Reject an invitation
jobcelis invitations reject 550e8400-e29b-41d4-a716-446655440000
```

### Simulate

```bash
# Simulate an event delivery (dry run)
jobcelis simulate --topic user.signup --payload '{"user_id":"123"}'
```

### GDPR

```bash
# List consent records
jobcelis gdpr consents

# Accept a consent purpose
jobcelis gdpr accept marketing

# Export personal data
jobcelis gdpr export

# Restrict processing
jobcelis gdpr restrict

# Lift restriction
jobcelis gdpr lift-restriction

# Object to processing
jobcelis gdpr object

# Withdraw objection
jobcelis gdpr restore
```

### Auth

```bash
# Register a new account
jobcelis auth register --email user@example.com --password secret123 --name "John Doe"

# Log in
jobcelis auth login --email user@example.com --password secret123

# Refresh a token
jobcelis auth refresh --token eyJhbGci...

# Verify MFA code
jobcelis auth mfa-verify --token eyJhbGci... --code 123456
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
