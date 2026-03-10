export interface JobcelisConfig {
  apiKey: string;
  baseUrl?: string;
  timeout?: number;
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
  inserted_at: string;
}

export interface WebhookCreate {
  url: string;
  secret?: string;
  topics?: string[];
  filters?: string[];
  headers?: Record<string, string>;
  retry_config?: Partial<RetryConfig>;
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
  schedule: string;
  topic: string;
  payload: Record<string, unknown>;
  status: string;
  timezone?: string;
  next_run_at?: string;
  last_run_at?: string;
  inserted_at: string;
  updated_at: string;
}

export interface JobCreate {
  name: string;
  schedule: string;
  topic: string;
  payload: Record<string, unknown>;
  timezone?: string;
}

export interface JobRun {
  id: string;
  job_id: string;
  status: string;
  started_at: string;
  finished_at?: string;
  error?: string;
  inserted_at: string;
}

// --- Pipelines ---

export interface Pipeline {
  id: string;
  name: string;
  source_topic: string;
  steps: PipelineStep[];
  status: string;
  inserted_at: string;
  updated_at: string;
}

export interface PipelineCreate {
  name: string;
  source_topic: string;
  steps: PipelineStep[];
}

export interface PipelineStep {
  type: 'filter' | 'transform' | 'delay' | 'deliver';
  config: Record<string, unknown>;
}

// --- Event Schemas ---

export interface EventSchema {
  id: string;
  topic: string;
  version: string;
  schema: Record<string, unknown>;
  inserted_at: string;
  updated_at: string;
}

export interface EventSchemaCreate {
  topic: string;
  version: string;
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
  is_default?: boolean;
  inserted_at: string;
  updated_at: string;
}

// --- Members ---

export interface Member {
  id: string;
  email: string;
  role: string;
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
