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
  attempt: number;
  response_status: number | null;
  response_body: string | null;
  latency_ms: number | null;
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
