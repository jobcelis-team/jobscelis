import type {
  JobcelisConfig,
  Event,
  EventCreate,
  BatchResult,
  Webhook,
  WebhookCreate,
  Delivery,
  DeadLetter,
  Replay,
  ReplayCreate,
  PaginatedResponse,
  ListOptions,
  Job,
  JobCreate,
  JobRun,
  Pipeline,
  PipelineCreate,
  EventSchema,
  EventSchemaCreate,
  SandboxEndpoint,
  SandboxRequest,
  Project,
  Member,
  AuditLog,
  AnalyticsPoint,
  TopicCount,
  WebhookStat,
  WebhookTemplate,
  Consent,
  NotificationChannel,
  NotificationChannelCreate,
  EmbedToken,
  EmbedTokenCreate,
  EmbedTokenResponse,
  SendEventResponse,
  AuthResponse,
  LoginResponse,
  RegisterParams,
  CronPreview,
  PipelineTestResult,
  RetentionPolicy,
  RetentionPolicyResponse,
  PurgeParams,
} from './types';
import { randomUUID } from 'crypto';

export class JobcelisClient {
  private apiKey: string | undefined;
  private authToken: string | undefined;
  private baseUrl: string;
  private timeout: number;
  private maxRetries: number;
  private retryBaseDelay: number;

  constructor(config: JobcelisConfig) {
    this.apiKey = config.apiKey || undefined;
    this.authToken = config.authToken || undefined;
    this.baseUrl = (config.baseUrl || 'https://jobcelis.com').replace(/\/+$/, '');
    // 0 disables the timeout (with `||` it silently became 30000)
    this.timeout = config.timeout ?? 30000;
    this.maxRetries = Math.max(0, Math.floor(config.maxRetries ?? DEFAULT_MAX_RETRIES));
    this.retryBaseDelay = config.retryBaseDelay ?? DEFAULT_RETRY_BASE_DELAY_MS;
  }

  /**
   * Sets (or clears, with null) the user JWT sent as `Authorization: Bearer <token>`.
   * Needed for the account routes: projects, members, invitations and `/me/*`.
   */
  setAuthToken(token: string | null | undefined): void {
    this.authToken = token || undefined;
  }

  // --- Auth (no API key needed) ---

  /** POST /api/v1/auth/register. Stores the returned JWT for the account routes. */
  async register(params: RegisterParams): Promise<AuthResponse> {
    return this.storeToken(await this.post('/api/v1/auth/register', params));
  }

  /**
   * POST /api/v1/auth/login. Returns `{ user, token }` and stores the token, or
   * `{ mfa_required: true, mfa_token }` when the account has MFA: then call verifyMfa().
   */
  async login(email: string, password: string): Promise<LoginResponse> {
    return this.storeToken(await this.post('/api/v1/auth/login', { email, password }));
  }

  /** POST /api/v1/auth/refresh. Defaults to the stored JWT and stores the new one. */
  async refreshToken(token?: string): Promise<{ token: string }> {
    const current = token ?? this.authToken;
    if (!current) throw new JobcelisError(0, 'No token to refresh: pass one or call setAuthToken()');
    return this.storeToken(await this.post('/api/v1/auth/refresh', { token: current }));
  }

  /** POST /api/v1/auth/mfa/verify with the `mfa_token` from login() and a TOTP code. */
  async verifyMfa(mfaToken: string, code: string): Promise<AuthResponse> {
    return this.storeToken(await this.post('/api/v1/auth/mfa/verify', { mfa_token: mfaToken, code }));
  }

  private storeToken<T>(res: T): T {
    const token = (res as { token?: unknown } | undefined)?.token;
    if (typeof token === 'string' && token) this.authToken = token;
    return res;
  }

  // --- Events ---

  /**
   * Sends one event. The request carries an `X-Idempotency-Key` header (the event's
   * `idempotency_key`, or a generated UUID) so retries never duplicate the event.
   */
  async sendEvent(event: EventCreate): Promise<SendEventResponse> {
    return this.post('/api/v1/events', event, { idempotencyKey: event.idempotency_key || randomUUID() });
  }

  /**
   * Sends a batch of events. Items without an `idempotency_key` get a generated
   * UUID, so retries never duplicate an event.
   */
  async sendEvents(events: EventCreate[]): Promise<BatchResult> {
    const items = events.map((e) => (e.idempotency_key ? e : { ...e, idempotency_key: randomUUID() }));
    // every item carries a key, so a retry after a network error is safe
    return this.post('/api/v1/events/batch', { events: items }, { idempotent: true });
  }

  async getEvent(id: string): Promise<Event> {
    return this.get(`/api/v1/events/${id}`);
  }

  async listEvents(opts?: ListOptions): Promise<PaginatedResponse<Event>> {
    return this.get('/api/v1/events', opts);
  }

  async deleteEvent(id: string): Promise<void> {
    await this.delete(`/api/v1/events/${id}`);
  }

  // --- Webhooks ---

  async createWebhook(webhook: WebhookCreate): Promise<Webhook> {
    return this.post('/api/v1/webhooks', webhook);
  }

  async getWebhook(id: string): Promise<Webhook> {
    return this.get(`/api/v1/webhooks/${id}`);
  }

  async listWebhooks(opts?: ListOptions): Promise<PaginatedResponse<Webhook>> {
    return this.get('/api/v1/webhooks', opts);
  }

  async updateWebhook(id: string, updates: Partial<WebhookCreate>): Promise<Webhook> {
    return this.patch(`/api/v1/webhooks/${id}`, updates);
  }

  async deleteWebhook(id: string): Promise<void> {
    await this.delete(`/api/v1/webhooks/${id}`);
  }

  async webhookHealth(id: string): Promise<{ status: string; success_rate: number }> {
    return this.get(`/api/v1/webhooks/${id}/health`);
  }

  async webhookTemplates(): Promise<{ data: WebhookTemplate[] }> {
    return this.get('/api/v1/webhooks/templates');
  }

  async testWebhook(webhookId: string): Promise<any> {
    return this.post(`/api/v1/webhooks/${webhookId}/test`, {});
  }

  // --- Deliveries ---

  async listDeliveries(opts?: ListOptions & { event_id?: string; webhook_id?: string; status?: string }): Promise<PaginatedResponse<Delivery>> {
    return this.get('/api/v1/deliveries', opts);
  }

  async retryDelivery(id: string): Promise<void> {
    await this.post(`/api/v1/deliveries/${id}/retry`, {});
  }

  // --- Dead Letters ---

  async listDeadLetters(opts?: ListOptions): Promise<PaginatedResponse<DeadLetter>> {
    return this.get('/api/v1/dead-letters', opts);
  }

  async getDeadLetter(id: string): Promise<DeadLetter> {
    return this.get(`/api/v1/dead-letters/${id}`);
  }

  async retryDeadLetter(id: string): Promise<void> {
    await this.post(`/api/v1/dead-letters/${id}/retry`, {});
  }

  async resolveDeadLetter(id: string): Promise<void> {
    await this.patch(`/api/v1/dead-letters/${id}/resolve`, {});
  }

  // --- Replays ---

  async createReplay(replay: ReplayCreate): Promise<Replay> {
    return this.post('/api/v1/replays', replay);
  }

  async listReplays(opts?: ListOptions): Promise<PaginatedResponse<Replay>> {
    return this.get('/api/v1/replays', opts);
  }

  async getReplay(id: string): Promise<Replay> {
    return this.get(`/api/v1/replays/${id}`);
  }

  async cancelReplay(id: string): Promise<void> {
    await this.delete(`/api/v1/replays/${id}`);
  }

  // --- Jobs ---

  async createJob(data: JobCreate): Promise<Job> {
    return this.post('/api/v1/jobs', data);
  }

  async listJobs(opts?: ListOptions): Promise<PaginatedResponse<Job>> {
    return this.get('/api/v1/jobs', opts);
  }

  async getJob(id: string): Promise<Job> {
    return this.get(`/api/v1/jobs/${id}`);
  }

  async updateJob(id: string, updates: Partial<JobCreate>): Promise<Job> {
    return this.patch(`/api/v1/jobs/${id}`, updates);
  }

  async deleteJob(id: string): Promise<void> {
    await this.delete(`/api/v1/jobs/${id}`);
  }

  async listJobRuns(jobId: string, opts?: ListOptions): Promise<PaginatedResponse<JobRun>> {
    return this.get(`/api/v1/jobs/${jobId}/runs`, opts);
  }

  async cronPreview(expression: string, count?: number): Promise<CronPreview> {
    return this.get('/api/v1/jobs/cron-preview', { expression, count });
  }

  // --- Pipelines ---

  async createPipeline(data: PipelineCreate): Promise<{ data: Pipeline }> {
    return this.post('/api/v1/pipelines', data);
  }

  async listPipelines(opts?: ListOptions): Promise<{ data: Pipeline[] }> {
    return this.get('/api/v1/pipelines', opts);
  }

  async getPipeline(id: string): Promise<{ data: Pipeline }> {
    return this.get(`/api/v1/pipelines/${id}`);
  }

  async updatePipeline(
    id: string,
    updates: Partial<PipelineCreate> & { status?: 'active' | 'inactive' },
  ): Promise<{ data: Pipeline }> {
    return this.patch(`/api/v1/pipelines/${id}`, updates);
  }

  async deletePipeline(id: string): Promise<void> {
    await this.delete(`/api/v1/pipelines/${id}`);
  }

  /** Runs the pipeline's steps on a sample payload (sent as `{ payload }`). */
  async testPipeline(id: string, payload: Record<string, unknown>): Promise<PipelineTestResult> {
    return this.post(`/api/v1/pipelines/${id}/test`, { payload });
  }

  // --- Event Schemas ---

  async createEventSchema(data: EventSchemaCreate): Promise<{ data: EventSchema }> {
    return this.post('/api/v1/event-schemas', data);
  }

  async listEventSchemas(opts?: ListOptions): Promise<{ data: EventSchema[] }> {
    return this.get('/api/v1/event-schemas', opts);
  }

  async getEventSchema(id: string): Promise<{ data: EventSchema }> {
    return this.get(`/api/v1/event-schemas/${id}`);
  }

  async updateEventSchema(id: string, updates: Partial<EventSchemaCreate>): Promise<{ data: EventSchema }> {
    return this.patch(`/api/v1/event-schemas/${id}`, updates);
  }

  async deleteEventSchema(id: string): Promise<void> {
    await this.delete(`/api/v1/event-schemas/${id}`);
  }

  async validatePayload(topic: string, payload: Record<string, unknown>): Promise<{ valid: boolean; errors?: string[] }> {
    return this.post('/api/v1/event-schemas/validate', { topic, payload });
  }

  // --- Sandbox ---

  async listSandboxEndpoints(): Promise<{ data: SandboxEndpoint[] }> {
    return this.get('/api/v1/sandbox-endpoints');
  }

  async createSandboxEndpoint(name?: string): Promise<SandboxEndpoint> {
    return this.post('/api/v1/sandbox-endpoints', name ? { name } : {});
  }

  async deleteSandboxEndpoint(id: string): Promise<void> {
    await this.delete(`/api/v1/sandbox-endpoints/${id}`);
  }

  async listSandboxRequests(endpointId: string, opts?: ListOptions): Promise<PaginatedResponse<SandboxRequest>> {
    return this.get(`/api/v1/sandbox-endpoints/${endpointId}/requests`, opts);
  }

  // --- Analytics ---

  async eventsPerDay(days?: number): Promise<{ data: AnalyticsPoint[] }> {
    return this.get('/api/v1/analytics/events-per-day', days !== undefined ? { days } : undefined);
  }

  async deliveriesPerDay(days?: number): Promise<{ data: AnalyticsPoint[] }> {
    return this.get('/api/v1/analytics/deliveries-per-day', days !== undefined ? { days } : undefined);
  }

  async topTopics(limit?: number): Promise<{ data: TopicCount[] }> {
    return this.get('/api/v1/analytics/top-topics', limit !== undefined ? { limit } : undefined);
  }

  async webhookStats(): Promise<{ data: WebhookStat[] }> {
    return this.get('/api/v1/analytics/webhook-stats');
  }

  // --- Project (single / current) ---

  async getProject(): Promise<Project> {
    return this.get('/api/v1/project');
  }

  async updateProject(updates: Partial<{ name: string }>): Promise<Project> {
    return this.patch('/api/v1/project', updates);
  }

  async listTopics(): Promise<{ topics: string[] }> {
    return this.get('/api/v1/topics');
  }

  async getToken(): Promise<{ token: string; prefix: string }> {
    return this.get('/api/v1/token');
  }

  async regenerateToken(): Promise<{ token: string; prefix: string }> {
    return this.post('/api/v1/token/regenerate', {});
  }

  /**
   * Limit the API token to scopes and client IPs. Omitted fields are left unchanged;
   * an empty allowed_ips list means any IP.
   */
  async updateTokenRestrictions(restrictions: {
    scopes?: string[];
    allowed_ips?: string[];
  }): Promise<{ prefix: string; scopes: string[]; allowed_ips: string[] }> {
    return this.patch('/api/v1/token', restrictions);
  }

  // --- Projects (multi) ---

  async listProjects(): Promise<{ data: Project[] }> {
    return this.get('/api/v1/projects');
  }

  async createProject(name: string): Promise<{ data: Project }> {
    return this.post('/api/v1/projects', { name });
  }

  async getProjectById(id: string): Promise<{ data: Project }> {
    return this.get(`/api/v1/projects/${id}`);
  }

  async updateProjectById(id: string, updates: Partial<{ name: string }>): Promise<{ data: Project }> {
    return this.patch(`/api/v1/projects/${id}`, updates);
  }

  async deleteProject(id: string): Promise<void> {
    await this.delete(`/api/v1/projects/${id}`);
  }

  async setDefaultProject(id: string): Promise<{ data: Project }> {
    return this.patch(`/api/v1/projects/${id}/default`, {});
  }

  // --- Teams ---

  async listMembers(projectId: string): Promise<{ data: Member[] }> {
    return this.get(`/api/v1/projects/${projectId}/members`);
  }

  /** Invites a user by email. Role: "viewer" (default) or "editor". */
  async addMember(projectId: string, email: string, role: string = 'viewer'): Promise<{ data: Member }> {
    return this.post(`/api/v1/projects/${projectId}/members`, { email, role });
  }

  async updateMember(projectId: string, memberId: string, role: string): Promise<{ data: Member }> {
    return this.patch(`/api/v1/projects/${projectId}/members/${memberId}`, { role });
  }

  async removeMember(projectId: string, memberId: string): Promise<void> {
    await this.delete(`/api/v1/projects/${projectId}/members/${memberId}`);
  }

  // --- Invitations ---

  async listPendingInvitations(): Promise<{ data: any[] }> {
    return this.get('/api/v1/invitations/pending');
  }

  async acceptInvitation(id: string): Promise<any> {
    return this.post(`/api/v1/invitations/${id}/accept`, {});
  }

  async rejectInvitation(id: string): Promise<any> {
    return this.post(`/api/v1/invitations/${id}/reject`, {});
  }

  // --- Audit ---

  async listAuditLogs(opts?: ListOptions): Promise<PaginatedResponse<AuditLog>> {
    return this.get('/api/v1/audit-log', opts);
  }

  // --- Export ---

  async exportEvents(): Promise<string> {
    return this.requestText('GET', '/api/v1/export/events');
  }

  async exportDeliveries(): Promise<string> {
    return this.requestText('GET', '/api/v1/export/deliveries');
  }

  async exportJobs(): Promise<string> {
    return this.requestText('GET', '/api/v1/export/jobs');
  }

  async exportAuditLog(): Promise<string> {
    return this.requestText('GET', '/api/v1/export/audit-log');
  }

  // --- Simulate ---

  async simulateEvent(topic: string, payload: Record<string, unknown>): Promise<Event> {
    return this.post('/api/v1/simulate', { topic, payload });
  }

  // --- Notification Channels ---

  async getNotificationChannel(): Promise<{ data: NotificationChannel | null }> {
    return this.get('/api/v1/notification-channels');
  }

  async upsertNotificationChannel(config: NotificationChannelCreate): Promise<{ data: NotificationChannel }> {
    return this.put('/api/v1/notification-channels', config);
  }

  async deleteNotificationChannel(): Promise<void> {
    await this.delete('/api/v1/notification-channels');
  }

  async testNotificationChannel(): Promise<{ status: string; channels: string[] }> {
    return this.post('/api/v1/notification-channels/test', {});
  }

  // --- Embed Tokens ---

  async listEmbedTokens(): Promise<{ data: EmbedToken[] }> {
    return this.get('/api/v1/embed/tokens');
  }

  async createEmbedToken(config: EmbedTokenCreate): Promise<EmbedTokenResponse> {
    return this.post('/api/v1/embed/tokens', config);
  }

  async revokeEmbedToken(id: string): Promise<{ status: string }> {
    return this.delete(`/api/v1/embed/tokens/${id}`);
  }

  // --- GDPR ---

  async getConsents(): Promise<{ data: Consent[] }> {
    return this.get('/api/v1/me/consents');
  }

  async acceptConsent(purpose: string): Promise<Consent> {
    return this.post(`/api/v1/me/consents/${purpose}/accept`, {});
  }

  async exportMyData(): Promise<Record<string, unknown>> {
    return this.get('/api/v1/me/data');
  }

  /** Restricts processing of your data (GDPR Art. 18). The server requires your password. */
  async restrictProcessing(password: string): Promise<{ status: string; restricted_at: string }> {
    return this.post('/api/v1/me/restrict', { password });
  }

  async liftRestriction(): Promise<void> {
    await this.delete('/api/v1/me/restrict');
  }

  async objectToProcessing(): Promise<void> {
    await this.post('/api/v1/me/object', {});
  }

  async restoreConsent(): Promise<void> {
    await this.delete('/api/v1/me/object');
  }

  // --- Retention & Purge ---

  async getRetentionPolicy(): Promise<{ retention_days: number | null; retention_policy: RetentionPolicy }> {
    return this.get('/api/v1/retention');
  }

  /** Sent as `{ retention_policy: policy }`. */
  async updateRetentionPolicy(policy: RetentionPolicy): Promise<RetentionPolicyResponse> {
    return this.patch('/api/v1/retention', { retention_policy: policy });
  }

  async previewPurge(params: PurgeParams): Promise<any> {
    return this.post('/api/v1/purge/preview', params);
  }

  async purgeData(params: PurgeParams): Promise<any> {
    return this.post('/api/v1/purge', params);
  }

  // --- Health ---

  async health(): Promise<Record<string, unknown>> {
    return this.get('/health');
  }

  /** Alias of health(): `/status` is an HTML page, so this reads `/health`. */
  async status(): Promise<Record<string, unknown>> {
    return this.health();
  }

  // --- HTTP helpers ---

  /**
   * Sends a request, retrying on network errors, timeouts and HTTP 429/502/503/504
   * with exponential backoff. A POST without an idempotency key is retried only on
   * 429 and 503 (the server did not act on it): after a network error, timeout, 502
   * or 504 it may have, and a retry could create the resource twice.
   */
  private async send(
    method: string,
    path: string,
    opts: RetryOptions & { body?: unknown; query?: Record<string, any>; json?: boolean },
  ): Promise<Response> {
    const url = new URL(this.baseUrl + path);
    if (opts.query) {
      for (const [k, v] of Object.entries(opts.query)) {
        if (v !== undefined && v !== null) url.searchParams.set(k, String(v));
      }
    }

    const headers: Record<string, string> = {};
    if (this.apiKey) headers['X-Api-Key'] = this.apiKey;
    if (this.authToken) headers['Authorization'] = `Bearer ${this.authToken}`;
    if (opts.json !== false) headers['Content-Type'] = 'application/json';
    if (opts.idempotencyKey) headers['X-Idempotency-Key'] = opts.idempotencyKey;
    const body = opts.body ? JSON.stringify(opts.body) : undefined;
    const idempotent = method !== 'POST' || !!opts.idempotencyKey || !!opts.idempotent;
    const retryable = idempotent ? RETRYABLE_STATUSES : NON_IDEMPOTENT_RETRYABLE_STATUSES;

    for (let attempt = 0; ; attempt++) {
      const controller = new AbortController();
      let timedOut = false;
      const timer =
        this.timeout > 0
          ? setTimeout(() => {
              timedOut = true;
              controller.abort();
            }, this.timeout)
          : undefined;
      let res: Response;
      try {
        res = await fetch(url.toString(), { method, headers, body, signal: controller.signal });
      } catch (err) {
        clearTimeout(timer);
        if (!idempotent || attempt >= this.maxRetries) {
          if (timedOut) throw new JobcelisError(0, `Request timed out after ${this.timeout} ms`);
          throw err;
        }
        await sleep(this.retryDelay(attempt + 1, null));
        continue;
      }
      clearTimeout(timer);

      if (retryable.has(res.status) && attempt < this.maxRetries) {
        const retryAfter = res.headers.get('retry-after');
        await res.body?.cancel().catch(() => undefined);
        await sleep(this.retryDelay(attempt + 1, retryAfter));
        continue;
      }
      return res;
    }
  }

  /** Delay in ms before retry number n (1-based). */
  private retryDelay(n: number, retryAfter: string | null): number {
    if (retryAfter !== null) {
      const seconds = Number(retryAfter);
      let ms: number | undefined;
      if (retryAfter.trim() !== '' && Number.isFinite(seconds)) {
        ms = seconds * 1000;
      } else {
        const date = Date.parse(retryAfter);
        if (!Number.isNaN(date)) ms = date - Date.now();
      }
      if (ms !== undefined) return Math.min(MAX_RETRY_AFTER_MS, Math.max(0, ms));
    }
    const base = Math.min(MAX_BACKOFF_MS, this.retryBaseDelay * 2 ** (n - 1));
    return base * (0.8 + Math.random() * 0.4);
  }

  private async request(
    method: string,
    path: string,
    body?: unknown,
    query?: Record<string, any>,
    retry: RetryOptions = {},
  ): Promise<unknown> {
    const res = await this.send(method, path, { ...retry, body, query });

    if (!res.ok) {
      const errBody: any = await res.json().catch(() => ({ error: res.statusText }));
      throw new JobcelisError(res.status, errBody.error || errBody.errors || res.statusText);
    }

    if (res.status === 204) return undefined;
    return res.json();
  }

  private async requestText(method: string, path: string): Promise<string> {
    const res = await this.send(method, path, { json: false });

    if (!res.ok) {
      const error = await res.text().catch(() => res.statusText);
      throw new JobcelisError(res.status, error);
    }

    return res.text();
  }

  private async get(path: string, query?: Record<string, any>): Promise<any> {
    return this.request('GET', path, undefined, query);
  }

  private async post(path: string, body: unknown, retry?: RetryOptions): Promise<any> {
    return this.request('POST', path, body, undefined, retry);
  }

  private async put(path: string, body: unknown): Promise<any> {
    return this.request('PUT', path, body);
  }

  private async patch(path: string, body: unknown): Promise<any> {
    return this.request('PATCH', path, body);
  }

  private async delete(path: string): Promise<any> {
    return this.request('DELETE', path);
  }
}

interface RetryOptions {
  /** Sent as X-Idempotency-Key; makes the request safe to retry after a network error. */
  idempotencyKey?: string;
  /** The body carries its own idempotency keys (batch): safe to retry after a network error. */
  idempotent?: boolean;
}

const RETRYABLE_STATUSES = new Set([429, 502, 503, 504]);
/** Statuses where the server surely did not act: safe to retry any POST. */
const NON_IDEMPOTENT_RETRYABLE_STATUSES = new Set([429, 503]);
const DEFAULT_MAX_RETRIES = 6;
const DEFAULT_RETRY_BASE_DELAY_MS = 1000;
const MAX_BACKOFF_MS = 30_000;
const MAX_RETRY_AFTER_MS = 60_000;

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export class JobcelisError extends Error {
  status: number;
  detail: unknown;

  constructor(status: number, detail: unknown) {
    super(typeof detail === 'string' ? detail : JSON.stringify(detail));
    this.name = 'JobcelisError';
    this.status = status;
    this.detail = detail;
  }
}
