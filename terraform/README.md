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

### jobcelis_pipeline

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

## Data Sources

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

## Environment Variables

| Variable | Description |
|----------|-------------|
| `JOBCELIS_API_KEY` | API key (alternative to provider config) |
| `JOBCELIS_URL` | Base URL (alternative to provider config) |

## Building from Source

```bash
cd terraform
go build -o terraform-provider-jobcelis
```

## License

MIT
