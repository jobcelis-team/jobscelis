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
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const (
	DefaultBaseURL = "https://jobcelis.com"
	DefaultTimeout = 30 * time.Second
)

// Client is the Jobcelis API client.
type Client struct {
	APIKey     string
	AuthToken  string
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

// SetAuthToken sets a Bearer token for endpoints that require JWT authentication
// (projects, teams, invitations, GDPR). This is obtained via Login or Register.
func (c *Client) SetAuthToken(token string) *Client {
	c.AuthToken = token
	return c
}

// ---------- Types ----------

// AuthRegisterRequest is the request body for user registration.
type AuthRegisterRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
	Name     string `json:"name"`
}

// AuthLoginRequest is the request body for user login.
type AuthLoginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// AuthTokenResponse is the response from login or register.
type AuthTokenResponse struct {
	Token        string `json:"token"`
	RefreshToken string `json:"refresh_token,omitempty"`
	MFARequired  bool   `json:"mfa_required,omitempty"`
	MFAToken     string `json:"mfa_token,omitempty"`
}

// Invitation represents a pending project invitation.
type Invitation struct {
	ID          string `json:"id"`
	ProjectID   string `json:"project_id"`
	ProjectName string `json:"project_name"`
	Email       string `json:"email"`
	Role        string `json:"role"`
	Status      string `json:"status"`
	InsertedAt  string `json:"inserted_at"`
}

// Token represents an API token.
type Token struct {
	Token     string `json:"token"`
	CreatedAt string `json:"created_at,omitempty"`
}

// Topic represents a topic used in the current project.
type Topic struct {
	Name       string `json:"name"`
	EventCount int    `json:"event_count"`
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
	ID          string                 `json:"id"`
	URL         string                 `json:"url"`
	Status      string                 `json:"status"`
	Topics      []string               `json:"topics"`
	Headers     map[string]string      `json:"headers,omitempty"`
	RetryConfig map[string]interface{} `json:"retry_config,omitempty"`
	RateLimit   map[string]interface{} `json:"rate_limit,omitempty"`
	InsertedAt  string                 `json:"inserted_at"`
}

// WebhookRequest is the request body for creating or updating a webhook.
type WebhookRequest struct {
	URL       string                 `json:"url"`
	Secret    string                 `json:"secret,omitempty"`
	Topics    []string               `json:"topics,omitempty"`
	Headers   map[string]string      `json:"headers,omitempty"`
	RateLimit map[string]interface{} `json:"rate_limit,omitempty"`
}

// BatchRequest is the request body for sending multiple events.
type BatchRequest struct {
	Events []EventRequest `json:"events"`
}

// BatchResult is the response from sending a batch of events.
type BatchResult struct {
	Accepted int `json:"accepted"`
	Rejected int `json:"rejected"`
	Events   []struct {
		ID     string `json:"id"`
		Topic  string `json:"topic"`
		Status string `json:"status"`
	} `json:"events"`
}

// Delivery represents a delivery attempt.
type Delivery struct {
	ID                string             `json:"id"`
	EventID           string             `json:"event_id"`
	WebhookID         string             `json:"webhook_id"`
	Status            string             `json:"status"`
	AttemptNumber     int                `json:"attempt_number"`
	ResponseStatus    *int               `json:"response_status,omitempty"`
	ResponseBody      *string            `json:"response_body,omitempty"`
	ResponseHeaders   map[string]string  `json:"response_headers,omitempty"`
	ResponseLatencyMs *int               `json:"response_latency_ms,omitempty"`
	RequestHeaders    map[string]string  `json:"request_headers,omitempty"`
	RequestBody       *string            `json:"request_body,omitempty"`
	DestinationIP     *string            `json:"destination_ip,omitempty"`
	NextRetryAt       *string            `json:"next_retry_at,omitempty"`
	InsertedAt        string             `json:"inserted_at"`
}

// DeadLetter represents a dead-lettered event.
type DeadLetter struct {
	ID         string `json:"id"`
	EventID    string `json:"event_id"`
	WebhookID  string `json:"webhook_id"`
	Error      string `json:"error"`
	Resolved   bool   `json:"resolved"`
	InsertedAt string `json:"inserted_at"`
}

// Replay represents an event replay operation.
type Replay struct {
	ID              string  `json:"id"`
	Status          string  `json:"status"`
	Topic           string  `json:"topic"`
	FromDate        string  `json:"from_date"`
	ToDate          string  `json:"to_date"`
	WebhookID       *string `json:"webhook_id,omitempty"`
	TotalEvents     int     `json:"total_events"`
	ProcessedEvents int     `json:"processed_events"`
	InsertedAt      string  `json:"inserted_at"`
}

// ReplayRequest is the request body for creating a replay.
type ReplayRequest struct {
	Topic     string  `json:"topic"`
	FromDate  string  `json:"from_date"`
	ToDate    string  `json:"to_date"`
	WebhookID *string `json:"webhook_id,omitempty"`
}

// Job represents a scheduled job.
type Job struct {
	ID             string   `json:"id"`
	Name           string   `json:"name"`
	Status         string   `json:"status"`
	Queue          string   `json:"queue"`
	CronExpression string   `json:"cron_expression"`
	Topics         []string `json:"topics"`
	WebhookID      *string  `json:"webhook_id,omitempty"`
	InsertedAt     string   `json:"inserted_at"`
}

// JobRequest is the request body for creating or updating a job.
type JobRequest struct {
	Name           string   `json:"name"`
	Queue          string   `json:"queue"`
	CronExpression string   `json:"cron_expression"`
	Topics         []string `json:"topics"`
	WebhookID      *string  `json:"webhook_id,omitempty"`
}

// JobRun represents a single execution of a job.
type JobRun struct {
	ID         string  `json:"id"`
	JobID      string  `json:"job_id"`
	Status     string  `json:"status"`
	StartedAt  *string `json:"started_at,omitempty"`
	FinishedAt *string `json:"finished_at,omitempty"`
}

// Pipeline represents an event processing pipeline.
type Pipeline struct {
	ID          string                   `json:"id"`
	Name        string                   `json:"name"`
	Status      string                   `json:"status"`
	Description string                   `json:"description"`
	Topics      []string                 `json:"topics"`
	Steps       []map[string]interface{} `json:"steps"`
	WebhookID   *string                  `json:"webhook_id,omitempty"`
	InsertedAt  string                   `json:"inserted_at"`
}

// PipelineRequest is the request body for creating or updating a pipeline.
type PipelineRequest struct {
	Name        string                   `json:"name"`
	Description string                   `json:"description"`
	Topics      []string                 `json:"topics"`
	Steps       []map[string]interface{} `json:"steps"`
	WebhookID   *string                  `json:"webhook_id,omitempty"`
}

// EventSchema represents an event schema definition.
type EventSchema struct {
	ID         string                 `json:"id"`
	Topic      string                 `json:"topic"`
	Version    string                 `json:"version"`
	Status     string                 `json:"status"`
	Schema     map[string]interface{} `json:"schema"`
	InsertedAt string                 `json:"inserted_at"`
}

// EventSchemaRequest is the request body for creating or updating an event schema.
type EventSchemaRequest struct {
	Topic   string                 `json:"topic"`
	Version string                 `json:"version"`
	Schema  map[string]interface{} `json:"schema"`
}

// SandboxEndpoint represents a sandbox testing endpoint.
type SandboxEndpoint struct {
	ID         string `json:"id"`
	Slug       string `json:"slug"`
	Name       string `json:"name"`
	InsertedAt string `json:"inserted_at"`
}

// SandboxRequest represents a captured request to a sandbox endpoint.
type SandboxRequest struct {
	Method     string            `json:"method"`
	Path       string            `json:"path"`
	Headers    map[string]string `json:"headers"`
	Body       string            `json:"body"`
	InsertedAt string            `json:"inserted_at"`
}

// Project represents a project.
type Project struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	Status     string `json:"status"`
	InsertedAt string `json:"inserted_at"`
}

// ProjectRequest is the request body for creating or updating a project.
type ProjectRequest struct {
	Name string `json:"name"`
}

// AuditLog represents an audit log entry.
type AuditLog struct {
	ID         string                 `json:"id"`
	Action     string                 `json:"action"`
	ActorType  string                 `json:"actor_type"`
	ActorID    string                 `json:"actor_id"`
	Metadata   map[string]interface{} `json:"metadata"`
	InsertedAt string                 `json:"inserted_at"`
}

// AnalyticsPoint represents a single data point in a time series.
type AnalyticsPoint struct {
	Date  string `json:"date"`
	Count int    `json:"count"`
}

// TopicCount represents a topic and its event count.
type TopicCount struct {
	Topic string `json:"topic"`
	Count int    `json:"count"`
}

// WebhookStat represents delivery statistics for a webhook.
type WebhookStat struct {
	WebhookID string `json:"webhook_id"`
	Total     int    `json:"total"`
	Success   int    `json:"success"`
	Failed    int    `json:"failed"`
}

// ExportOptions configures export format.
type ExportOptions struct {
	Format string `json:"format"`
}

// Member represents a project team member.
type Member struct {
	ID    string `json:"id"`
	Email string `json:"email"`
	Role  string `json:"role"`
}

// NotificationChannel represents external notification channel config for a project.
type NotificationChannel struct {
	ID                 string   `json:"id"`
	ProjectID          string   `json:"project_id"`
	EmailEnabled       bool     `json:"email_enabled"`
	EmailAddress       *string  `json:"email_address,omitempty"`
	SlackEnabled       bool     `json:"slack_enabled"`
	SlackWebhookURL    *string  `json:"slack_webhook_url,omitempty"`
	DiscordEnabled     bool     `json:"discord_enabled"`
	DiscordWebhookURL  *string  `json:"discord_webhook_url,omitempty"`
	MetaWebhookEnabled bool     `json:"meta_webhook_enabled"`
	MetaWebhookURL     *string  `json:"meta_webhook_url,omitempty"`
	MetaWebhookSecret  *string  `json:"meta_webhook_secret,omitempty"`
	EventTypes         []string `json:"event_types,omitempty"`
	InsertedAt         string   `json:"inserted_at"`
	UpdatedAt          string   `json:"updated_at"`
}

// Consent represents a GDPR consent record.
type Consent struct {
	Purpose   string `json:"purpose"`
	Accepted  bool   `json:"accepted"`
	UpdatedAt string `json:"updated_at,omitempty"`
}

// EmbedToken represents an embed token for client-side integrations.
type EmbedToken struct {
	ID             string                 `json:"id"`
	Prefix         string                 `json:"prefix"`
	Name           string                 `json:"name"`
	Status         string                 `json:"status"`
	Scopes         []string               `json:"scopes"`
	AllowedOrigins []string               `json:"allowed_origins"`
	Metadata       map[string]interface{} `json:"metadata"`
	ExpiresAt      *string                `json:"expires_at"`
	InsertedAt     string                 `json:"inserted_at"`
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

// ---------- Events ----------

// SendEvent sends a single event.
func (c *Client) SendEvent(ctx context.Context, req EventRequest) (*EventResponse, error) {
	var resp EventResponse
	err := c.doRequest(ctx, http.MethodPost, "/api/v1/events", req, &resp)
	return &resp, err
}

// SendEvents sends a batch of events.
func (c *Client) SendEvents(ctx context.Context, req BatchRequest) (*BatchResult, error) {
	var resp BatchResult
	err := c.doRequest(ctx, http.MethodPost, "/api/v1/events/batch", req, &resp)
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

// DeleteEvent deletes an event by ID.
func (c *Client) DeleteEvent(ctx context.Context, id string) error {
	return c.doRequest(ctx, http.MethodDelete, "/api/v1/events/"+id, nil, nil)
}

// ---------- Webhooks ----------

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

// UpdateWebhook updates an existing webhook.
func (c *Client) UpdateWebhook(ctx context.Context, id string, req WebhookRequest) (*Webhook, error) {
	var resp Webhook
	err := c.doRequest(ctx, http.MethodPatch, "/api/v1/webhooks/"+id, req, &resp)
	return &resp, err
}

// DeleteWebhook deletes a webhook by ID.
func (c *Client) DeleteWebhook(ctx context.Context, id string) error {
	return c.doRequest(ctx, http.MethodDelete, "/api/v1/webhooks/"+id, nil, nil)
}

// WebhookHealth retrieves health status for a specific webhook.
func (c *Client) WebhookHealth(ctx context.Context, id string) (map[string]interface{}, error) {
	var resp map[string]interface{}
	err := c.doRequest(ctx, http.MethodGet, "/api/v1/webhooks/"+id+"/health", nil, &resp)
	return resp, err
}

// TestWebhook sends a test delivery to a webhook.
func (c *Client) TestWebhook(ctx context.Context, id string) (map[string]interface{}, error) {
	var resp map[string]interface{}
	err := c.doRequest(ctx, http.MethodPost, "/api/v1/webhooks/"+id+"/test", nil, &resp)
	return resp, err
}

// WebhookTemplates retrieves available webhook templates.
func (c *Client) WebhookTemplates(ctx context.Context) ([]map[string]interface{}, error) {
	var resp struct {
		Data []map[string]interface{} `json:"data"`
	}
	err := c.doRequest(ctx, http.MethodGet, "/api/v1/webhooks/templates", nil, &resp)
	return resp.Data, err
}

// ---------- Deliveries ----------

// ListDeliveries lists deliveries with optional query parameters.
func (c *Client) ListDeliveries(ctx context.Context, params url.Values) (*PaginatedResponse[Delivery], error) {
	path := "/api/v1/deliveries"
	if len(params) > 0 {
		path += "?" + params.Encode()
	}
	var resp PaginatedResponse[Delivery]
	err := c.doRequest(ctx, http.MethodGet, path, nil, &resp)
	return &resp, err
}

// RetryDelivery retries a failed delivery.
func (c *Client) RetryDelivery(ctx context.Context, id string) error {
	return c.doRequest(ctx, http.MethodPost, "/api/v1/deliveries/"+id+"/retry", nil, nil)
}

// ---------- Dead Letters ----------

// ListDeadLetters lists dead-lettered events with optional query parameters.
func (c *Client) ListDeadLetters(ctx context.Context, params url.Values) (*PaginatedResponse[DeadLetter], error) {
	path := "/api/v1/dead-letters"
	if len(params) > 0 {
		path += "?" + params.Encode()
	}
	var resp PaginatedResponse[DeadLetter]
	err := c.doRequest(ctx, http.MethodGet, path, nil, &resp)
	return &resp, err
}

// GetDeadLetter retrieves a dead letter by ID.
func (c *Client) GetDeadLetter(ctx context.Context, id string) (*DeadLetter, error) {
	var resp DeadLetter
	err := c.doRequest(ctx, http.MethodGet, "/api/v1/dead-letters/"+id, nil, &resp)
	return &resp, err
}

// RetryDeadLetter retries a dead-lettered event.
func (c *Client) RetryDeadLetter(ctx context.Context, id string) error {
	return c.doRequest(ctx, http.MethodPost, "/api/v1/dead-letters/"+id+"/retry", nil, nil)
}

// ResolveDeadLetter marks a dead letter as resolved.
func (c *Client) ResolveDeadLetter(ctx context.Context, id string) error {
	return c.doRequest(ctx, http.MethodPatch, "/api/v1/dead-letters/"+id+"/resolve", nil, nil)
}

// ---------- Replays ----------

// CreateReplay creates a new event replay.
func (c *Client) CreateReplay(ctx context.Context, req ReplayRequest) (*Replay, error) {
	var resp Replay
	err := c.doRequest(ctx, http.MethodPost, "/api/v1/replays", req, &resp)
	return &resp, err
}

// ListReplays lists replays with optional query parameters.
func (c *Client) ListReplays(ctx context.Context, params url.Values) (*PaginatedResponse[Replay], error) {
	path := "/api/v1/replays"
	if len(params) > 0 {
		path += "?" + params.Encode()
	}
	var resp PaginatedResponse[Replay]
	err := c.doRequest(ctx, http.MethodGet, path, nil, &resp)
	return &resp, err
}

// GetReplay retrieves a replay by ID.
func (c *Client) GetReplay(ctx context.Context, id string) (*Replay, error) {
	var resp Replay
	err := c.doRequest(ctx, http.MethodGet, "/api/v1/replays/"+id, nil, &resp)
	return &resp, err
}

// CancelReplay cancels an in-progress replay.
func (c *Client) CancelReplay(ctx context.Context, id string) error {
	return c.doRequest(ctx, http.MethodDelete, "/api/v1/replays/"+id, nil, nil)
}

// ---------- Jobs ----------

// CreateJob creates a new scheduled job.
func (c *Client) CreateJob(ctx context.Context, req JobRequest) (*Job, error) {
	var resp Job
	err := c.doRequest(ctx, http.MethodPost, "/api/v1/jobs", req, &resp)
	return &resp, err
}

// ListJobs lists jobs with optional query parameters.
func (c *Client) ListJobs(ctx context.Context, params url.Values) (*PaginatedResponse[Job], error) {
	path := "/api/v1/jobs"
	if len(params) > 0 {
		path += "?" + params.Encode()
	}
	var resp PaginatedResponse[Job]
	err := c.doRequest(ctx, http.MethodGet, path, nil, &resp)
	return &resp, err
}

// GetJob retrieves a job by ID.
func (c *Client) GetJob(ctx context.Context, id string) (*Job, error) {
	var resp Job
	err := c.doRequest(ctx, http.MethodGet, "/api/v1/jobs/"+id, nil, &resp)
	return &resp, err
}

// UpdateJob updates an existing job.
func (c *Client) UpdateJob(ctx context.Context, id string, req JobRequest) (*Job, error) {
	var resp Job
	err := c.doRequest(ctx, http.MethodPatch, "/api/v1/jobs/"+id, req, &resp)
	return &resp, err
}

// DeleteJob deletes a job by ID.
func (c *Client) DeleteJob(ctx context.Context, id string) error {
	return c.doRequest(ctx, http.MethodDelete, "/api/v1/jobs/"+id, nil, nil)
}

// ListJobRuns lists runs for a specific job.
func (c *Client) ListJobRuns(ctx context.Context, jobID string, params url.Values) (*PaginatedResponse[JobRun], error) {
	path := "/api/v1/jobs/" + jobID + "/runs"
	if len(params) > 0 {
		path += "?" + params.Encode()
	}
	var resp PaginatedResponse[JobRun]
	err := c.doRequest(ctx, http.MethodGet, path, nil, &resp)
	return &resp, err
}

// CronPreview returns a preview of upcoming cron execution times.
func (c *Client) CronPreview(ctx context.Context, expression string) ([]string, error) {
	params := url.Values{"expression": {expression}}
	var resp struct {
		Data []string `json:"data"`
	}
	err := c.doRequest(ctx, http.MethodGet, "/api/v1/jobs/cron-preview?"+params.Encode(), nil, &resp)
	return resp.Data, err
}

// ---------- Pipelines ----------

// CreatePipeline creates a new event processing pipeline.
func (c *Client) CreatePipeline(ctx context.Context, req PipelineRequest) (*Pipeline, error) {
	var resp Pipeline
	err := c.doRequest(ctx, http.MethodPost, "/api/v1/pipelines", req, &resp)
	return &resp, err
}

// ListPipelines lists pipelines with optional query parameters.
func (c *Client) ListPipelines(ctx context.Context, params url.Values) (*PaginatedResponse[Pipeline], error) {
	path := "/api/v1/pipelines"
	if len(params) > 0 {
		path += "?" + params.Encode()
	}
	var resp PaginatedResponse[Pipeline]
	err := c.doRequest(ctx, http.MethodGet, path, nil, &resp)
	return &resp, err
}

// GetPipeline retrieves a pipeline by ID.
func (c *Client) GetPipeline(ctx context.Context, id string) (*Pipeline, error) {
	var resp Pipeline
	err := c.doRequest(ctx, http.MethodGet, "/api/v1/pipelines/"+id, nil, &resp)
	return &resp, err
}

// UpdatePipeline updates an existing pipeline.
func (c *Client) UpdatePipeline(ctx context.Context, id string, req PipelineRequest) (*Pipeline, error) {
	var resp Pipeline
	err := c.doRequest(ctx, http.MethodPatch, "/api/v1/pipelines/"+id, req, &resp)
	return &resp, err
}

// DeletePipeline deletes a pipeline by ID.
func (c *Client) DeletePipeline(ctx context.Context, id string) error {
	return c.doRequest(ctx, http.MethodDelete, "/api/v1/pipelines/"+id, nil, nil)
}

// TestPipeline sends a test payload through a pipeline to preview results.
func (c *Client) TestPipeline(ctx context.Context, id string, payload map[string]interface{}) (map[string]interface{}, error) {
	var resp map[string]interface{}
	err := c.doRequest(ctx, http.MethodPost, "/api/v1/pipelines/"+id+"/test", payload, &resp)
	return resp, err
}

// ---------- Event Schemas ----------

// CreateEventSchema creates a new event schema.
func (c *Client) CreateEventSchema(ctx context.Context, req EventSchemaRequest) (*EventSchema, error) {
	var resp EventSchema
	err := c.doRequest(ctx, http.MethodPost, "/api/v1/event-schemas", req, &resp)
	return &resp, err
}

// ListEventSchemas lists event schemas with optional query parameters.
func (c *Client) ListEventSchemas(ctx context.Context, params url.Values) (*PaginatedResponse[EventSchema], error) {
	path := "/api/v1/event-schemas"
	if len(params) > 0 {
		path += "?" + params.Encode()
	}
	var resp PaginatedResponse[EventSchema]
	err := c.doRequest(ctx, http.MethodGet, path, nil, &resp)
	return &resp, err
}

// GetEventSchema retrieves an event schema by ID.
func (c *Client) GetEventSchema(ctx context.Context, id string) (*EventSchema, error) {
	var resp EventSchema
	err := c.doRequest(ctx, http.MethodGet, "/api/v1/event-schemas/"+id, nil, &resp)
	return &resp, err
}

// UpdateEventSchema updates an existing event schema.
func (c *Client) UpdateEventSchema(ctx context.Context, id string, req EventSchemaRequest) (*EventSchema, error) {
	var resp EventSchema
	err := c.doRequest(ctx, http.MethodPatch, "/api/v1/event-schemas/"+id, req, &resp)
	return &resp, err
}

// DeleteEventSchema deletes an event schema by ID.
func (c *Client) DeleteEventSchema(ctx context.Context, id string) error {
	return c.doRequest(ctx, http.MethodDelete, "/api/v1/event-schemas/"+id, nil, nil)
}

// ValidatePayload validates a payload against the schema for a given topic.
func (c *Client) ValidatePayload(ctx context.Context, topic string, payload map[string]interface{}) (map[string]interface{}, error) {
	body := map[string]interface{}{
		"topic":   topic,
		"payload": payload,
	}
	var resp map[string]interface{}
	err := c.doRequest(ctx, http.MethodPost, "/api/v1/event-schemas/validate", body, &resp)
	return resp, err
}

// ---------- Sandbox ----------

// ListSandboxEndpoints lists all sandbox endpoints.
func (c *Client) ListSandboxEndpoints(ctx context.Context) ([]SandboxEndpoint, error) {
	var resp struct {
		Data []SandboxEndpoint `json:"data"`
	}
	err := c.doRequest(ctx, http.MethodGet, "/api/v1/sandbox-endpoints", nil, &resp)
	return resp.Data, err
}

// CreateSandboxEndpoint creates a new sandbox endpoint.
func (c *Client) CreateSandboxEndpoint(ctx context.Context, name string) (*SandboxEndpoint, error) {
	body := map[string]string{"name": name}
	var resp SandboxEndpoint
	err := c.doRequest(ctx, http.MethodPost, "/api/v1/sandbox-endpoints", body, &resp)
	return &resp, err
}

// DeleteSandboxEndpoint deletes a sandbox endpoint by ID.
func (c *Client) DeleteSandboxEndpoint(ctx context.Context, id string) error {
	return c.doRequest(ctx, http.MethodDelete, "/api/v1/sandbox-endpoints/"+id, nil, nil)
}

// ListSandboxRequests lists captured requests for a sandbox endpoint.
func (c *Client) ListSandboxRequests(ctx context.Context, endpointID string, params url.Values) (*PaginatedResponse[SandboxRequest], error) {
	path := "/api/v1/sandbox-endpoints/" + endpointID + "/requests"
	if len(params) > 0 {
		path += "?" + params.Encode()
	}
	var resp PaginatedResponse[SandboxRequest]
	err := c.doRequest(ctx, http.MethodGet, path, nil, &resp)
	return &resp, err
}

// ---------- Analytics ----------

// EventsPerDay returns event counts per day for the given number of days.
func (c *Client) EventsPerDay(ctx context.Context, days int) ([]AnalyticsPoint, error) {
	params := url.Values{"days": {fmt.Sprintf("%d", days)}}
	var resp struct {
		Data []AnalyticsPoint `json:"data"`
	}
	err := c.doRequest(ctx, http.MethodGet, "/api/v1/analytics/events-per-day?"+params.Encode(), nil, &resp)
	return resp.Data, err
}

// DeliveriesPerDay returns delivery counts per day for the given number of days.
func (c *Client) DeliveriesPerDay(ctx context.Context, days int) ([]AnalyticsPoint, error) {
	params := url.Values{"days": {fmt.Sprintf("%d", days)}}
	var resp struct {
		Data []AnalyticsPoint `json:"data"`
	}
	err := c.doRequest(ctx, http.MethodGet, "/api/v1/analytics/deliveries-per-day?"+params.Encode(), nil, &resp)
	return resp.Data, err
}

// TopTopics returns the most active topics.
func (c *Client) TopTopics(ctx context.Context, limit int) ([]TopicCount, error) {
	params := url.Values{"limit": {fmt.Sprintf("%d", limit)}}
	var resp struct {
		Data []TopicCount `json:"data"`
	}
	err := c.doRequest(ctx, http.MethodGet, "/api/v1/analytics/top-topics?"+params.Encode(), nil, &resp)
	return resp.Data, err
}

// WebhookStats returns delivery statistics per webhook.
func (c *Client) WebhookStats(ctx context.Context) ([]WebhookStat, error) {
	var resp struct {
		Data []WebhookStat `json:"data"`
	}
	err := c.doRequest(ctx, http.MethodGet, "/api/v1/analytics/webhook-stats", nil, &resp)
	return resp.Data, err
}

// ---------- Projects (Multi — requires Bearer token) ----------

// ListProjects lists all projects.
// Requires Bearer token auth (SetAuthToken).
func (c *Client) ListProjects(ctx context.Context) ([]Project, error) {
	var resp struct {
		Data []Project `json:"data"`
	}
	err := c.doAuthenticatedRequest(ctx, http.MethodGet, "/api/v1/projects", nil, &resp)
	return resp.Data, err
}

// CreateProject creates a new project.
// Requires Bearer token auth (SetAuthToken).
func (c *Client) CreateProject(ctx context.Context, req ProjectRequest) (*Project, error) {
	var resp Project
	err := c.doAuthenticatedRequest(ctx, http.MethodPost, "/api/v1/projects", req, &resp)
	return &resp, err
}

// GetProjectByID retrieves a project by ID.
// Requires Bearer token auth (SetAuthToken).
func (c *Client) GetProjectByID(ctx context.Context, id string) (*Project, error) {
	var resp Project
	err := c.doAuthenticatedRequest(ctx, http.MethodGet, "/api/v1/projects/"+id, nil, &resp)
	return &resp, err
}

// UpdateProjectByID updates an existing project.
// Requires Bearer token auth (SetAuthToken).
func (c *Client) UpdateProjectByID(ctx context.Context, id string, req ProjectRequest) (*Project, error) {
	var resp Project
	err := c.doAuthenticatedRequest(ctx, http.MethodPatch, "/api/v1/projects/"+id, req, &resp)
	return &resp, err
}

// DeleteProject deletes a project by ID.
// Requires Bearer token auth (SetAuthToken).
func (c *Client) DeleteProject(ctx context.Context, id string) error {
	return c.doAuthenticatedRequest(ctx, http.MethodDelete, "/api/v1/projects/"+id, nil, nil)
}

// SetDefaultProject sets a project as the default.
// Requires Bearer token auth (SetAuthToken).
func (c *Client) SetDefaultProject(ctx context.Context, id string) error {
	return c.doAuthenticatedRequest(ctx, http.MethodPatch, "/api/v1/projects/"+id+"/default", nil, nil)
}

// ---------- Teams (requires Bearer token) ----------

// ListMembers lists team members for a project.
// Requires Bearer token auth (SetAuthToken).
func (c *Client) ListMembers(ctx context.Context, projectID string) ([]Member, error) {
	var resp struct {
		Data []Member `json:"data"`
	}
	err := c.doAuthenticatedRequest(ctx, http.MethodGet, "/api/v1/projects/"+projectID+"/members", nil, &resp)
	return resp.Data, err
}

// AddMember adds a team member to a project.
// Requires Bearer token auth (SetAuthToken).
func (c *Client) AddMember(ctx context.Context, projectID, email, role string) (*Member, error) {
	body := map[string]string{"email": email, "role": role}
	var resp Member
	err := c.doAuthenticatedRequest(ctx, http.MethodPost, "/api/v1/projects/"+projectID+"/members", body, &resp)
	return &resp, err
}

// UpdateMember updates a team member's role.
// Requires Bearer token auth (SetAuthToken).
func (c *Client) UpdateMember(ctx context.Context, projectID, memberID, role string) (*Member, error) {
	body := map[string]string{"role": role}
	var resp Member
	err := c.doAuthenticatedRequest(ctx, http.MethodPatch, "/api/v1/projects/"+projectID+"/members/"+memberID, body, &resp)
	return &resp, err
}

// RemoveMember removes a team member from a project.
// Requires Bearer token auth (SetAuthToken).
func (c *Client) RemoveMember(ctx context.Context, projectID, memberID string) error {
	return c.doAuthenticatedRequest(ctx, http.MethodDelete, "/api/v1/projects/"+projectID+"/members/"+memberID, nil, nil)
}

// ---------- Audit ----------

// ListAuditLogs lists audit log entries with optional query parameters.
func (c *Client) ListAuditLogs(ctx context.Context, params url.Values) (*PaginatedResponse[AuditLog], error) {
	path := "/api/v1/audit-log"
	if len(params) > 0 {
		path += "?" + params.Encode()
	}
	var resp PaginatedResponse[AuditLog]
	err := c.doRequest(ctx, http.MethodGet, path, nil, &resp)
	return &resp, err
}

// ---------- Export ----------

// ExportEvents exports all events as CSV.
func (c *Client) ExportEvents(ctx context.Context) ([]byte, error) {
	return c.doRequestRaw(ctx, http.MethodGet, "/api/v1/export/events")
}

// ExportDeliveries exports all deliveries as CSV.
func (c *Client) ExportDeliveries(ctx context.Context) ([]byte, error) {
	return c.doRequestRaw(ctx, http.MethodGet, "/api/v1/export/deliveries")
}

// ExportJobs exports all jobs as CSV.
func (c *Client) ExportJobs(ctx context.Context) ([]byte, error) {
	return c.doRequestRaw(ctx, http.MethodGet, "/api/v1/export/jobs")
}

// ExportAuditLog exports the audit log as CSV.
func (c *Client) ExportAuditLog(ctx context.Context) ([]byte, error) {
	return c.doRequestRaw(ctx, http.MethodGet, "/api/v1/export/audit-log")
}

// ---------- Simulate ----------

// SimulateEvent simulates sending an event for testing purposes.
func (c *Client) SimulateEvent(ctx context.Context, topic string, payload map[string]interface{}) (map[string]interface{}, error) {
	body := map[string]interface{}{
		"topic":   topic,
		"payload": payload,
	}
	var resp map[string]interface{}
	err := c.doRequest(ctx, http.MethodPost, "/api/v1/simulate", body, &resp)
	return resp, err
}

// ---------- Notification Channels ----------

// GetNotificationChannel retrieves the notification channel config for the current project.
func (c *Client) GetNotificationChannel(ctx context.Context) (*NotificationChannel, error) {
	var resp struct {
		Data *NotificationChannel `json:"data"`
	}
	err := c.doRequest(ctx, http.MethodGet, "/api/v1/notification-channels", nil, &resp)
	return resp.Data, err
}

// UpsertNotificationChannel creates or updates the notification channel config.
func (c *Client) UpsertNotificationChannel(ctx context.Context, config map[string]interface{}) (*NotificationChannel, error) {
	var resp struct {
		Data NotificationChannel `json:"data"`
	}
	err := c.doRequest(ctx, http.MethodPut, "/api/v1/notification-channels", config, &resp)
	return &resp.Data, err
}

// DeleteNotificationChannel removes the notification channel config.
func (c *Client) DeleteNotificationChannel(ctx context.Context) error {
	return c.doRequest(ctx, http.MethodDelete, "/api/v1/notification-channels", nil, nil)
}

// TestNotificationChannel sends a test notification to all enabled channels.
func (c *Client) TestNotificationChannel(ctx context.Context) error {
	return c.doRequest(ctx, http.MethodPost, "/api/v1/notification-channels/test", nil, nil)
}

// ---------- GDPR (requires Bearer token) ----------

// GetConsents retrieves the current user's consent records.
// Requires Bearer token auth (SetAuthToken).
func (c *Client) GetConsents(ctx context.Context) ([]Consent, error) {
	var resp struct {
		Data []Consent `json:"data"`
	}
	err := c.doAuthenticatedRequest(ctx, http.MethodGet, "/api/v1/me/consents", nil, &resp)
	return resp.Data, err
}

// AcceptConsent accepts a specific consent purpose.
// Requires Bearer token auth (SetAuthToken).
func (c *Client) AcceptConsent(ctx context.Context, purpose string) error {
	return c.doAuthenticatedRequest(ctx, http.MethodPost, "/api/v1/me/consents/"+purpose+"/accept", nil, nil)
}

// ExportMyData exports the current user's personal data (GDPR right of access).
// Requires Bearer token auth (SetAuthToken).
func (c *Client) ExportMyData(ctx context.Context) (map[string]interface{}, error) {
	var resp map[string]interface{}
	err := c.doAuthenticatedRequest(ctx, http.MethodGet, "/api/v1/me/data", nil, &resp)
	return resp, err
}

// RestrictProcessing requests restriction of processing (GDPR Article 18).
// Requires Bearer token auth (SetAuthToken).
func (c *Client) RestrictProcessing(ctx context.Context) error {
	return c.doAuthenticatedRequest(ctx, http.MethodPost, "/api/v1/me/restrict", nil, nil)
}

// LiftRestriction lifts a previously requested processing restriction.
// Requires Bearer token auth (SetAuthToken).
func (c *Client) LiftRestriction(ctx context.Context) error {
	return c.doAuthenticatedRequest(ctx, http.MethodDelete, "/api/v1/me/restrict", nil, nil)
}

// ObjectToProcessing registers an objection to data processing (GDPR Article 21).
// Requires Bearer token auth (SetAuthToken).
func (c *Client) ObjectToProcessing(ctx context.Context) error {
	return c.doAuthenticatedRequest(ctx, http.MethodPost, "/api/v1/me/object", nil, nil)
}

// RestoreConsent withdraws a processing objection.
// Requires Bearer token auth (SetAuthToken).
func (c *Client) RestoreConsent(ctx context.Context) error {
	return c.doAuthenticatedRequest(ctx, http.MethodDelete, "/api/v1/me/object", nil, nil)
}

// ---------- Project (Current) ----------

// GetCurrentProject retrieves the current project (scoped by API key).
func (c *Client) GetCurrentProject(ctx context.Context) (*Project, error) {
	var resp Project
	err := c.doRequest(ctx, http.MethodGet, "/api/v1/project", nil, &resp)
	return &resp, err
}

// UpdateCurrentProject updates the current project.
func (c *Client) UpdateCurrentProject(ctx context.Context, updates map[string]interface{}) (*Project, error) {
	var resp Project
	err := c.doRequest(ctx, http.MethodPatch, "/api/v1/project", updates, &resp)
	return &resp, err
}

// ListTopics lists all topics used in the current project.
func (c *Client) ListTopics(ctx context.Context) ([]Topic, error) {
	var resp struct {
		Data []Topic `json:"data"`
	}
	err := c.doRequest(ctx, http.MethodGet, "/api/v1/topics", nil, &resp)
	return resp.Data, err
}

// GetToken retrieves the current API token metadata.
func (c *Client) GetToken(ctx context.Context) (*Token, error) {
	var resp Token
	err := c.doRequest(ctx, http.MethodGet, "/api/v1/token", nil, &resp)
	return &resp, err
}

// RegenerateToken regenerates the project API token.
func (c *Client) RegenerateToken(ctx context.Context) (*Token, error) {
	var resp Token
	err := c.doRequest(ctx, http.MethodPost, "/api/v1/token/regenerate", nil, &resp)
	return &resp, err
}

// ---------- Invitations ----------

// ListPendingInvitations lists pending invitations for the authenticated user.
// Requires Bearer token auth (SetAuthToken).
func (c *Client) ListPendingInvitations(ctx context.Context) ([]Invitation, error) {
	var resp struct {
		Data []Invitation `json:"data"`
	}
	err := c.doAuthenticatedRequest(ctx, http.MethodGet, "/api/v1/invitations/pending", nil, &resp)
	return resp.Data, err
}

// AcceptInvitation accepts a project invitation.
// Requires Bearer token auth (SetAuthToken).
func (c *Client) AcceptInvitation(ctx context.Context, id string) error {
	return c.doAuthenticatedRequest(ctx, http.MethodPost, "/api/v1/invitations/"+id+"/accept", nil, nil)
}

// RejectInvitation rejects a project invitation.
// Requires Bearer token auth (SetAuthToken).
func (c *Client) RejectInvitation(ctx context.Context, id string) error {
	return c.doAuthenticatedRequest(ctx, http.MethodPost, "/api/v1/invitations/"+id+"/reject", nil, nil)
}

// ---------- Auth ----------

// Register creates a new user account.
func (c *Client) Register(ctx context.Context, email, password, name string) (*AuthTokenResponse, error) {
	body := AuthRegisterRequest{Email: email, Password: password, Name: name}
	var resp AuthTokenResponse
	err := c.doPublicRequest(ctx, http.MethodPost, "/api/v1/auth/register", body, &resp)
	return &resp, err
}

// Login authenticates a user and returns a JWT token.
func (c *Client) Login(ctx context.Context, email, password string) (*AuthTokenResponse, error) {
	body := AuthLoginRequest{Email: email, Password: password}
	var resp AuthTokenResponse
	err := c.doPublicRequest(ctx, http.MethodPost, "/api/v1/auth/login", body, &resp)
	return &resp, err
}

// RefreshToken refreshes an expired JWT token.
func (c *Client) RefreshToken(ctx context.Context, refreshToken string) (*AuthTokenResponse, error) {
	body := map[string]string{"refresh_token": refreshToken}
	var resp AuthTokenResponse
	err := c.doPublicRequest(ctx, http.MethodPost, "/api/v1/auth/refresh", body, &resp)
	return &resp, err
}

// VerifyMFA verifies a TOTP code during MFA-required login.
func (c *Client) VerifyMFA(ctx context.Context, mfaToken, code string) (*AuthTokenResponse, error) {
	body := map[string]string{"mfa_token": mfaToken, "code": code}
	var resp AuthTokenResponse
	err := c.doPublicRequest(ctx, http.MethodPost, "/api/v1/auth/mfa/verify", body, &resp)
	return &resp, err
}

// ---------- Embed Tokens ----------

// ListEmbedTokens lists all embed tokens for the current project.
func (c *Client) ListEmbedTokens(ctx context.Context) ([]EmbedToken, error) {
	var resp struct {
		Data []EmbedToken `json:"data"`
	}
	err := c.doRequest(ctx, http.MethodGet, "/api/v1/embed/tokens", nil, &resp)
	return resp.Data, err
}

// CreateEmbedToken creates a new embed token.
// Returns the raw response including the "token" field (only available at creation time).
func (c *Client) CreateEmbedToken(ctx context.Context, config map[string]interface{}) (map[string]interface{}, error) {
	var resp map[string]interface{}
	err := c.doRequest(ctx, http.MethodPost, "/api/v1/embed/tokens", config, &resp)
	return resp, err
}

// RevokeEmbedToken revokes an embed token by ID.
func (c *Client) RevokeEmbedToken(ctx context.Context, id string) error {
	return c.doRequest(ctx, http.MethodDelete, "/api/v1/embed/tokens/"+id, nil, nil)
}

// ---------- Retention & Purge ----------

// RetentionPolicy represents the data retention policy.
type RetentionPolicy struct {
	EventsDays    int `json:"events_days,omitempty"`
	DeliveriesDays int `json:"deliveries_days,omitempty"`
	AuditLogsDays int `json:"audit_logs_days,omitempty"`
}

// PurgeRequest represents the parameters for a purge operation.
type PurgeRequest struct {
	Type     string `json:"type"`
	OlderThan string `json:"older_than,omitempty"`
	Topic    string `json:"topic,omitempty"`
	Status   string `json:"status,omitempty"`
}

// GetRetentionPolicy retrieves the current retention policy.
func (c *Client) GetRetentionPolicy(ctx context.Context) (map[string]interface{}, error) {
	var resp map[string]interface{}
	err := c.doRequest(ctx, http.MethodGet, "/api/v1/retention", nil, &resp)
	return resp, err
}

// UpdateRetentionPolicy updates the retention policy.
func (c *Client) UpdateRetentionPolicy(ctx context.Context, policy RetentionPolicy) (map[string]interface{}, error) {
	var resp map[string]interface{}
	err := c.doRequest(ctx, http.MethodPatch, "/api/v1/retention", policy, &resp)
	return resp, err
}

// PreviewPurge previews a purge operation without executing it.
func (c *Client) PreviewPurge(ctx context.Context, req PurgeRequest) (map[string]interface{}, error) {
	var resp map[string]interface{}
	err := c.doRequest(ctx, http.MethodPost, "/api/v1/purge/preview", req, &resp)
	return resp, err
}

// PurgeData executes a purge operation.
func (c *Client) PurgeData(ctx context.Context, req PurgeRequest) (map[string]interface{}, error) {
	var resp map[string]interface{}
	err := c.doRequest(ctx, http.MethodPost, "/api/v1/purge", req, &resp)
	return resp, err
}

// ---------- Health ----------

// Health checks the platform health.
func (c *Client) Health(ctx context.Context) (map[string]interface{}, error) {
	var resp map[string]interface{}
	err := c.doRequest(ctx, http.MethodGet, "/health", nil, &resp)
	return resp, err
}

// ---------- Webhook Signature Verification ----------

// VerifyWebhookSignature verifies a webhook signature from Jobcelis.
//
// The Jobcelis backend signs webhook payloads with HMAC-SHA256, Base64-encoded
// without padding, and sends the signature in the x-signature header with the
// format "sha256=<base64_no_padding>".
//
// Parameters:
//   - secret: the webhook signing secret
//   - body: the raw request body
//   - signature: the full X-Signature header value (e.g. "sha256=abc123...")
func VerifyWebhookSignature(secret, body, signature string) bool {
	if secret == "" || body == "" || signature == "" {
		return false
	}

	const prefix = "sha256="
	if !strings.HasPrefix(signature, prefix) {
		return false
	}

	receivedSig := signature[len(prefix):]

	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(body))
	expectedSig := base64.RawStdEncoding.EncodeToString(mac.Sum(nil))

	return hmac.Equal([]byte(expectedSig), []byte(receivedSig))
}

// ---------- Internal ----------

func (c *Client) doRequest(ctx context.Context, method, path string, body interface{}, result interface{}) error {
	return c.doRequestWithAuth(ctx, method, path, body, result, "apikey")
}

func (c *Client) doAuthenticatedRequest(ctx context.Context, method, path string, body interface{}, result interface{}) error {
	return c.doRequestWithAuth(ctx, method, path, body, result, "bearer")
}

func (c *Client) doPublicRequest(ctx context.Context, method, path string, body interface{}, result interface{}) error {
	return c.doRequestWithAuth(ctx, method, path, body, result, "none")
}

func (c *Client) doRequestWithAuth(ctx context.Context, method, path string, body interface{}, result interface{}, authMode string) error {
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
	switch authMode {
	case "apikey":
		req.Header.Set("X-Api-Key", c.APIKey)
	case "bearer":
		req.Header.Set("Authorization", "Bearer "+c.AuthToken)
	}

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

func (c *Client) doRequestRaw(ctx context.Context, method, path string) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, method, c.BaseURL+path, nil)
	if err != nil {
		return nil, fmt.Errorf("jobcelis: failed to create request: %w", err)
	}

	req.Header.Set("X-Api-Key", c.APIKey)

	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("jobcelis: request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("jobcelis: failed to read response: %w", err)
	}

	if resp.StatusCode >= 400 {
		apiErr := &APIError{StatusCode: resp.StatusCode}
		_ = json.Unmarshal(respBody, apiErr)
		if apiErr.Message == "" {
			apiErr.Message = string(respBody)
		}
		return nil, apiErr
	}

	return respBody, nil
}
