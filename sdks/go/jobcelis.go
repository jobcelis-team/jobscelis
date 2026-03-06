// Package jobcelis provides a Go client for the Jobcelis Event Infrastructure Platform.
//
// Usage:
//
//	client := jobcelis.NewClient("your_api_key")
//	resp, err := client.SendEvent(ctx, jobcelis.EventRequest{
//	    Topic:   "order.created",
//	    Payload: map[string]interface{}{"order_id": "123", "amount": 99.99},
//	})
package jobcelis

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"
)

const (
	DefaultBaseURL = "https://jobcelis.com"
	DefaultTimeout = 30 * time.Second
)

// Client is the Jobcelis API client.
type Client struct {
	APIKey     string
	BaseURL    string
	HTTPClient *http.Client
}

// NewClient creates a new Jobcelis client with the given API key.
func NewClient(apiKey string) *Client {
	return &Client{
		APIKey:  apiKey,
		BaseURL: DefaultBaseURL,
		HTTPClient: &http.Client{
			Timeout: DefaultTimeout,
		},
	}
}

// WithBaseURL sets a custom base URL (useful for staging/self-hosted).
func (c *Client) WithBaseURL(baseURL string) *Client {
	c.BaseURL = baseURL
	return c
}

// WithTimeout sets a custom HTTP timeout.
func (c *Client) WithTimeout(timeout time.Duration) *Client {
	c.HTTPClient.Timeout = timeout
	return c
}

// EventRequest is the request body for sending an event.
type EventRequest struct {
	Topic          string                 `json:"topic"`
	Payload        map[string]interface{} `json:"payload"`
	IdempotencyKey string                 `json:"idempotency_key,omitempty"`
}

// EventResponse is the response from sending an event.
type EventResponse struct {
	EventID     string `json:"event_id"`
	PayloadHash string `json:"payload_hash"`
}

// Event represents a full event object.
type Event struct {
	ID             string                 `json:"id"`
	Topic          string                 `json:"topic"`
	Payload        map[string]interface{} `json:"payload"`
	Status         string                 `json:"status"`
	PayloadHash    string                 `json:"payload_hash"`
	IdempotencyKey string                 `json:"idempotency_key,omitempty"`
	OccurredAt     string                 `json:"occurred_at"`
	InsertedAt     string                 `json:"inserted_at"`
}

// Webhook represents a webhook configuration.
type Webhook struct {
	ID          string            `json:"id"`
	URL         string            `json:"url"`
	Status      string            `json:"status"`
	Topics      []string          `json:"topics"`
	Headers     map[string]string `json:"headers,omitempty"`
	RetryConfig map[string]interface{} `json:"retry_config,omitempty"`
	InsertedAt  string            `json:"inserted_at"`
}

// WebhookRequest is the request body for creating a webhook.
type WebhookRequest struct {
	URL     string            `json:"url"`
	Secret  string            `json:"secret,omitempty"`
	Topics  []string          `json:"topics,omitempty"`
	Headers map[string]string `json:"headers,omitempty"`
}

// PaginatedResponse wraps paginated API responses.
type PaginatedResponse[T any] struct {
	Data       []T    `json:"data"`
	HasNext    bool   `json:"has_next"`
	NextCursor string `json:"next_cursor,omitempty"`
}

// APIError represents an error response from the API.
type APIError struct {
	StatusCode int
	Message    string `json:"error"`
}

func (e *APIError) Error() string {
	return fmt.Sprintf("jobcelis: HTTP %d: %s", e.StatusCode, e.Message)
}

// SendEvent sends a single event.
func (c *Client) SendEvent(ctx context.Context, req EventRequest) (*EventResponse, error) {
	var resp EventResponse
	err := c.doRequest(ctx, http.MethodPost, "/api/v1/events", req, &resp)
	return &resp, err
}

// GetEvent retrieves an event by ID.
func (c *Client) GetEvent(ctx context.Context, id string) (*Event, error) {
	var resp Event
	err := c.doRequest(ctx, http.MethodGet, "/api/v1/events/"+id, nil, &resp)
	return &resp, err
}

// ListEvents lists events with optional query parameters.
func (c *Client) ListEvents(ctx context.Context, params url.Values) (*PaginatedResponse[Event], error) {
	path := "/api/v1/events"
	if len(params) > 0 {
		path += "?" + params.Encode()
	}
	var resp PaginatedResponse[Event]
	err := c.doRequest(ctx, http.MethodGet, path, nil, &resp)
	return &resp, err
}

// CreateWebhook creates a new webhook.
func (c *Client) CreateWebhook(ctx context.Context, req WebhookRequest) (*Webhook, error) {
	var resp Webhook
	err := c.doRequest(ctx, http.MethodPost, "/api/v1/webhooks", req, &resp)
	return &resp, err
}

// ListWebhooks lists all webhooks.
func (c *Client) ListWebhooks(ctx context.Context) ([]Webhook, error) {
	var resp struct {
		Data []Webhook `json:"data"`
	}
	err := c.doRequest(ctx, http.MethodGet, "/api/v1/webhooks", nil, &resp)
	return resp.Data, err
}

// GetWebhook retrieves a webhook by ID.
func (c *Client) GetWebhook(ctx context.Context, id string) (*Webhook, error) {
	var resp Webhook
	err := c.doRequest(ctx, http.MethodGet, "/api/v1/webhooks/"+id, nil, &resp)
	return &resp, err
}

// Health checks the platform health.
func (c *Client) Health(ctx context.Context) (map[string]interface{}, error) {
	var resp map[string]interface{}
	err := c.doRequest(ctx, http.MethodGet, "/health", nil, &resp)
	return resp, err
}

func (c *Client) doRequest(ctx context.Context, method, path string, body interface{}, result interface{}) error {
	var reqBody io.Reader
	if body != nil {
		data, err := json.Marshal(body)
		if err != nil {
			return fmt.Errorf("jobcelis: failed to marshal request: %w", err)
		}
		reqBody = bytes.NewReader(data)
	}

	req, err := http.NewRequestWithContext(ctx, method, c.BaseURL+path, reqBody)
	if err != nil {
		return fmt.Errorf("jobcelis: failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Api-Key", c.APIKey)

	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return fmt.Errorf("jobcelis: request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("jobcelis: failed to read response: %w", err)
	}

	if resp.StatusCode >= 400 {
		apiErr := &APIError{StatusCode: resp.StatusCode}
		_ = json.Unmarshal(respBody, apiErr)
		if apiErr.Message == "" {
			apiErr.Message = string(respBody)
		}
		return apiErr
	}

	if result != nil && len(respBody) > 0 {
		if err := json.Unmarshal(respBody, result); err != nil {
			return fmt.Errorf("jobcelis: failed to decode response: %w", err)
		}
	}

	return nil
}
