# Jobcelis Terraform Provider

Manage Jobcelis resources as infrastructure-as-code with Terraform.

## Usage

```hcl
terraform {
  required_providers {
    jobcelis = {
      source = "jobcelis/jobcelis"
    }
  }
}

provider "jobcelis" {
  api_key = var.jobcelis_api_key
  # base_url = "https://jobcelis.com"  # optional, defaults to production
}
```

## Resources

### jobcelis_webhook

Manages webhook endpoints that receive event deliveries.

```hcl
resource "jobcelis_webhook" "orders" {
  url    = "https://api.example.com/webhooks/orders"
  secret = var.webhook_secret
  topics = ["order.*"]
}

resource "jobcelis_webhook" "slack_notifications" {
  url    = "https://hooks.slack.com/services/T00/B00/xxx"
  topics = ["order.created", "user.signup"]
}
```

| Attribute | Type         | Required | Description                              |
|-----------|-------------|----------|------------------------------------------|
| `url`     | string      | yes      | Destination URL for webhook deliveries   |
| `secret`  | string      | no       | HMAC-SHA256 signature verification secret |
| `topics`  | list(string)| no       | Event topic patterns (supports wildcards) |
| `status`  | string      | computed | Current status (active/inactive)         |

### jobcelis_pipeline

Manages event processing pipelines with filter and transform steps.

```hcl
resource "jobcelis_pipeline" "high_value_orders" {
  name        = "High-value order alerts"
  description = "Filter orders above $100 and notify Slack"
  webhook_id  = jobcelis_webhook.slack_notifications.id
  topics      = ["order.created"]

  steps = jsonencode([
    {
      type     = "filter"
      field    = "amount"
      operator = "gt"
      value    = 100
    },
    {
      type      = "transform"
      operation = "template"
      template = {
        text = "New order #{{ order_id }} for ${{ amount }}"
      }
    }
  ])
}
```

| Attribute     | Type         | Required | Description                        |
|---------------|-------------|----------|------------------------------------|
| `name`        | string      | yes      | Name of the pipeline               |
| `description` | string      | no       | Description of the pipeline        |
| `webhook_id`  | string      | yes      | Target webhook ID for delivery     |
| `topics`      | list(string)| no       | Event topics that trigger pipeline |
| `steps`       | string      | no       | JSON-encoded array of steps        |
| `status`      | string      | computed | Current status (active/inactive)   |

### jobcelis_job

Manages scheduled jobs that run on a cron schedule.

```hcl
resource "jobcelis_job" "daily_digest" {
  name            = "Daily order digest"
  queue           = "scheduled_job"
  cron_expression = "0 9 * * *"
  topics          = ["order.created", "order.updated"]
  webhook_id      = jobcelis_webhook.slack_notifications.id
}

resource "jobcelis_job" "cleanup" {
  name            = "Stale event cleanup"
  queue           = "default"
  cron_expression = "0 0 * * 0"
}
```

| Attribute         | Type         | Required | Description                        |
|-------------------|-------------|----------|------------------------------------|
| `name`            | string      | yes      | Name of the scheduled job          |
| `queue`           | string      | yes      | Queue to run on (delivery, scheduled_job, default) |
| `cron_expression` | string      | yes      | Cron expression for the schedule   |
| `topics`          | list(string)| no       | Event topics this job processes    |
| `webhook_id`      | string      | no       | Webhook to deliver results to      |
| `status`          | string      | computed | Current status                     |

### jobcelis_event_schema

Manages event schemas for topic payload validation.

```hcl
resource "jobcelis_event_schema" "order_created" {
  topic   = "order.created"
  version = "1.0"

  schema_body = jsonencode({
    type = "object"
    required = ["order_id", "amount", "currency"]
    properties = {
      order_id = { type = "string", format = "uuid" }
      amount   = { type = "number", minimum = 0 }
      currency = { type = "string", enum = ["USD", "EUR", "GBP"] }
    }
  })
}
```

| Attribute     | Type   | Required | Description                      |
|---------------|--------|----------|----------------------------------|
| `topic`       | string | yes      | Event topic this schema covers   |
| `version`     | string | no       | Schema version identifier        |
| `schema_body` | string | yes      | JSON string defining the schema  |

### jobcelis_project

Manages Jobcelis projects for organizing resources.

```hcl
resource "jobcelis_project" "production" {
  name = "Production Events"
}

resource "jobcelis_project" "staging" {
  name = "Staging Events"
}
```

| Attribute | Type   | Required | Description       |
|-----------|--------|----------|-------------------|
| `name`    | string | yes      | Name of project   |

## Data Sources

All resources have corresponding data sources for reading existing resources by ID.

### jobcelis_webhook

```hcl
data "jobcelis_webhook" "existing" {
  webhook_id = "7c9e6679-7425-40de-944b-e07fc1f90ae7"
}

output "webhook_url" {
  value = data.jobcelis_webhook.existing.url
}
```

### jobcelis_pipeline

```hcl
data "jobcelis_pipeline" "existing" {
  pipeline_id = "b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e"
}
```

### jobcelis_job

```hcl
data "jobcelis_job" "existing" {
  job_id = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
}

output "job_schedule" {
  value = data.jobcelis_job.existing.cron_expression
}
```

### jobcelis_event_schema

```hcl
data "jobcelis_event_schema" "existing" {
  event_schema_id = "f1e2d3c4-b5a6-7890-1234-567890abcdef"
}

output "schema_topic" {
  value = data.jobcelis_event_schema.existing.topic
}
```

### jobcelis_project

```hcl
data "jobcelis_project" "existing" {
  project_id = "12345678-abcd-ef01-2345-6789abcdef01"
}

output "project_name" {
  value = data.jobcelis_project.existing.name
}
```

## Environment Variables

| Variable            | Description                                |
|---------------------|--------------------------------------------|
| `JOBCELIS_API_KEY`  | API key (alternative to provider config)   |
| `JOBCELIS_BASE_URL` | Base URL (alternative to provider config)  |

## Building from Source

```bash
cd terraform
go mod download
go build -o terraform-provider-jobcelis
```

## License

MIT
