export interface JobcelisConfig {
  /** Project API key, sent as `X-Api-Key`. Optional for the `/auth/*` calls. */
  apiKey?: string;
  /**
   * User JWT (from login/register), sent as `Authorization: Bearer <token>`. Needed
   * for the account routes: `/projects*`, `/invitations*` and `/me/*`.
   */
  authToken?: string;
  baseUrl?: string;
  /** Request timeout in ms (default 30000). 0 disables it. */
  timeout?: number;
  /**
   * Retries after a network error, timeout or HTTP 429/502/503/504 (default 6,
   * about 60 s of backoff). 0 disables retries. A POST without an idempotency key
   * is retried only on 429/503.
   */
  maxRetries?: number;
  /** Base delay in ms of the exponential backoff (default 1000). */
  retryBaseDelay?: number;
}

export interface Event {
  id: string;
  topic: string;
  payload: Record<string, unknown>;
  payload_hash: string;
  idempotency_key?: string;
  deliver_at?: string;
  inserted_at: string;
}

/** Response of sendEvent(): `id` and `event_id` carry the same value. */
export interface SendEventResponse {
  id: string;
  event_id: string;
  payload_hash: string;
}

export interface EventCreate {
  topic: string;
  payload: Record<string, unknown>;
  idempotency_key?: string;
  deliver_at?: string;
}

export interface BatchResult {
  accepted: number;
  rejected: number;
  events: Array<{ id: string; topic: string; status: string }>;
}

export interface Webhook {
  id: string;
  url: string;
  status: string;
  topics: string[];
  filters: string[];
  headers: Record<string, string>;
  retry_config: RetryConfig;
  rate_limit?: { max_per_second?: number; max_per_minute?: number };
  inserted_at: string;
}

export interface WebhookCreate {
  url: string;
  secret?: string;
  topics?: string[];
  filters?: string[];
  headers?: Record<string, string>;
  retry_config?: Partial<RetryConfig>;
  rate_limit?: { max_per_second?: number; max_per_minute?: number };
}

export interface RetryConfig {
  strategy: 'exponential' | 'linear' | 'fixed';
  base_delay_seconds: number;
  max_delay_seconds: number;
  max_attempts: number;
  jitter: boolean;
}

export interface Delivery {
  id: string;
  event_id: string;
  webhook_id: string;
  status: string;
  attempt_number: number;
  response_status: number | null;
  response_body: string | null;
  response_headers: Record<string, string> | null;
  response_latency_ms: number | null;
  request_headers: Record<string, string> | null;
  request_body: string | null;
  destination_ip: string | null;
  next_retry_at: string | null;
  inserted_at: string;
}

export interface DeadLetter {
  id: string;
  event_id: string;
  webhook_id: string;
  resolved: boolean;
  error: string;
  inserted_at: string;
}

export interface Replay {
  id: string;
  status: string;
  topic: string;
  from_date: string;
  to_date: string;
  webhook_id?: string;
  total_events: number;
  processed_events: number;
  inserted_at: string;
}

export interface ReplayCreate {
  topic: string;
  from_date: string;
  to_date: string;
  webhook_id?: string;
}

export interface PaginatedResponse<T> {
  data: T[];
  has_next: boolean;
  next_cursor: string | null;
}

export interface ListOptions {
  limit?: number;
  cursor?: string;
}

// --- Jobs ---

export interface Job {
  id: string;
  name: string;
  schedule_type: 'daily' | 'weekly' | 'monthly' | 'cron';
  schedule_config: Record<string, unknown>;
  action_type: 'emit_event' | 'post_url';
  action_config: Record<string, unknown>;
  status: string;
  inserted_at: string;
}

/**
 * Job to create. Give the schedule as `schedule` / `cron_expression` (a cron
 * expression or "daily" | "weekly" | "monthly") or the canonical `schedule_type` +
 * `schedule_config`. Give the action as `topic` (+ `payload`) to emit an event,
 * `url` (+ `method`, `payload`) to POST to a URL, or the canonical `action_type` +
 * `action_config`. Without one of them the job does nothing.
 */
export interface JobCreate {
  name: string;
  schedule?: string;
  cron_expression?: string;
  schedule_type?: 'daily' | 'weekly' | 'monthly' | 'cron';
  schedule_config?: Record<string, unknown>;
  topic?: string;
  url?: string;
  method?: string;
  payload?: Record<string, unknown>;
  action_type?: 'emit_event' | 'post_url';
  action_config?: Record<string, unknown>;
  status?: 'active' | 'inactive';
}

export interface JobRun {
  id: string;
  executed_at: string;
  status: string;
  result: Record<string, unknown> | null;
}

export interface CronPreview {
  expression: string;
  next_executions: string[];
}

// --- Pipelines ---

export interface Pipeline {
  id: string;
  name: string;
  status: string;
  description: string | null;
  topics: string[];
  steps: PipelineStep[];
  webhook_id: string;
  inserted_at: string;
}

export interface PipelineCreate {
  name: string;
  /** Webhook that receives the processed events (required). */
  webhook_id: string;
  /** Topics that trigger the pipeline. */
  topics?: string[];
  description?: string;
  steps?: PipelineStep[];
}

/** Keeps the event only when `field` (dot path in the payload) matches. */
export interface PipelineFilterStep {
  type: 'filter';
  field: string;
  operator?: 'eq' | 'neq' | 'gt' | 'gte' | 'lt' | 'lte' | 'contains' | 'exists' | 'not_exists';
  value?: unknown;
}

/** Rewrites the payload. The fields used depend on `operation`. */
export interface PipelineTransformStep {
  type: 'transform';
  operation: 'pick' | 'remove' | 'rename' | 'set' | 'template' | 'flatten';
  /** pick / remove */
  fields?: string[];
  /** rename: old field => new field */
  mapping?: Record<string, string>;
  /** set */
  values?: Record<string, unknown>;
  /** template */
  template?: Record<string, unknown>;
}

/** Delays delivery (at most 7 days in total). */
export interface PipelineDelayStep {
  type: 'delay';
  seconds: number;
}

export type PipelineStep = PipelineFilterStep | PipelineTransformStep | PipelineDelayStep;

export interface PipelineTestResult {
  input: Record<string, unknown>;
  output: Record<string, unknown> | null;
  steps_count: number;
  status: 'passed' | 'filtered';
  reason?: string;
}

// --- Event Schemas ---

export interface EventSchema {
  id: string;
  project_id: string;
  topic: string;
  version: number;
  status: string;
  schema: Record<string, unknown>;
  inserted_at: string;
  updated_at: string;
}

export interface EventSchemaCreate {
  topic: string;
  version?: number;
  schema: Record<string, unknown>;
}

// --- Sandbox ---

export interface SandboxEndpoint {
  id: string;
  name: string;
  url: string;
  inserted_at: string;
}

export interface SandboxRequest {
  id: string;
  endpoint_id: string;
  method: string;
  headers: Record<string, string>;
  body: string | null;
  received_at: string;
}

// --- Project ---

export interface Project {
  id: string;
  name: string;
  status?: string;
  is_default?: boolean;
  settings?: Record<string, unknown>;
  inserted_at: string;
  updated_at: string;
}

// --- Members ---

export interface Member {
  id: string;
  project_id: string;
  user_id: string;
  role: string;
  status: string;
  invited_by: string | null;
  inserted_at: string;
}

// --- Audit ---

export interface AuditLog {
  id: string;
  action: string;
  actor_id: string;
  actor_email?: string;
  resource_type: string;
  resource_id?: string;
  metadata: Record<string, unknown>;
  inserted_at: string;
}

// --- Analytics ---

export interface AnalyticsPoint {
  date: string;
  count: number;
}

export interface TopicCount {
  topic: string;
  count: number;
}

export interface WebhookStat {
  webhook_id: string;
  url: string;
  total: number;
  success: number;
  failed: number;
  success_rate: number;
}

// --- Webhook extras ---

export interface WebhookTemplate {
  id: string;
  name: string;
  description: string;
  url: string;
  topics: string[];
  headers: Record<string, string>;
}

// --- Notification Channels ---

export interface NotificationChannel {
  id: string;
  project_id: string;
  email_enabled: boolean;
  email_address: string | null;
  slack_enabled: boolean;
  slack_webhook_url: string | null;
  discord_enabled: boolean;
  discord_webhook_url: string | null;
  meta_webhook_enabled: boolean;
  meta_webhook_url: string | null;
  meta_webhook_secret: string | null;
  event_types: string[] | null;
  inserted_at: string;
  updated_at: string;
}

export interface NotificationChannelCreate {
  email_enabled?: boolean;
  email_address?: string;
  slack_enabled?: boolean;
  slack_webhook_url?: string;
  discord_enabled?: boolean;
  discord_webhook_url?: string;
  meta_webhook_enabled?: boolean;
  meta_webhook_url?: string;
  meta_webhook_secret?: string;
  event_types?: string[];
}

// --- Embed Tokens ---

export interface EmbedToken {
  id: string;
  prefix: string;
  name: string;
  status: string;
  scopes: string[];
  allowed_origins: string[];
  metadata: Record<string, unknown>;
  expires_at: string | null;
  inserted_at: string;
}

export interface EmbedTokenCreate {
  name?: string;
  scopes?: string[];
  allowed_origins?: string[];
  metadata?: Record<string, unknown>;
  expires_at?: string;
}

export interface EmbedTokenResponse {
  token: string;
  data: EmbedToken;
}

// --- GDPR ---

export interface Consent {
  purpose: string;
  accepted: boolean;
  accepted_at?: string;
}

// --- Auth ---

export interface RegisterParams {
  email: string;
  password: string;
  name?: string;
}

export interface AuthUser {
  id: string;
  email: string;
  name: string | null;
}

export interface AuthResponse {
  user: AuthUser;
  token: string;
  /** Only on register, when a default project and API key were created. */
  api_key?: string | null;
}

export interface MfaChallenge {
  mfa_required: true;
  /** Short-lived (5 min) token to pass to verifyMfa() with the TOTP code. */
  mfa_token: string;
}

export type LoginResponse = AuthResponse | MfaChallenge;

// --- Retention & purge ---

export interface RetentionPolicy {
  events_days?: number;
  deliveries_days?: number;
  audit_logs_days?: number;
}

export interface RetentionPolicyResponse {
  retention_policy: RetentionPolicy;
}

export interface PurgeParams {
  type: 'events' | 'deliveries' | 'audit_logs' | 'dead_letters';
  /** YYYY-MM-DD (required by the server). */
  older_than: string;
  topic?: string;
  status?: string;
}
