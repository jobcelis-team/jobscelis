# Jobcelis Go SDK

Go client for the [Jobcelis](https://jobcelis.com) Event Infrastructure Platform.

## Installation

```bash
go get github.com/jobcelis/go-sdk
```

## Quick Start

```go
package main

import (
    "context"
    "fmt"
    "log"

    jobcelis "github.com/jobcelis/go-sdk"
)

func main() {
    client := jobcelis.NewClient("your_api_key")

    // Send an event
    resp, err := client.SendEvent(context.Background(), jobcelis.EventRequest{
        Topic:   "order.created",
        Payload: map[string]interface{}{
            "order_id": "12345",
            "amount":   99.99,
        },
    })
    if err != nil {
        log.Fatal(err)
    }
    fmt.Printf("Event sent: %s\n", resp.EventID)

    // List webhooks
    webhooks, err := client.ListWebhooks(context.Background())
    if err != nil {
        log.Fatal(err)
    }
    for _, w := range webhooks {
        fmt.Printf("Webhook: %s -> %s\n", w.ID, w.URL)
    }
}
```

## Webhook Verification

```go
package main

import (
    "io"
    "net/http"

    jobcelis "github.com/jobcelis/go-sdk"
)

func webhookHandler(w http.ResponseWriter, r *http.Request) {
    body, _ := io.ReadAll(r.Body)
    signature := r.Header.Get("X-Signature")

    if !jobcelis.VerifySignature("your_secret", body, signature) {
        http.Error(w, "Invalid signature", http.StatusUnauthorized)
        return
    }

    // Process the webhook...
    w.WriteHeader(http.StatusOK)
}
```

## Configuration

```go
// Custom base URL (staging or self-hosted)
client := jobcelis.NewClient("key").WithBaseURL("https://staging.jobcelis.com")

// Custom timeout
client := jobcelis.NewClient("key").WithTimeout(10 * time.Second)
```

## API Methods

| Method | Description |
|--------|-------------|
| `SendEvent(ctx, req)` | Send a single event |
| `GetEvent(ctx, id)` | Get event by ID |
| `ListEvents(ctx, params)` | List events (paginated) |
| `CreateWebhook(ctx, req)` | Create a webhook |
| `ListWebhooks(ctx)` | List all webhooks |
| `GetWebhook(ctx, id)` | Get webhook by ID |
| `Health(ctx)` | Check platform health |

## License

MIT
