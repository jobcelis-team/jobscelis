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
} from './types';

export class JobcelisClient {
  private apiKey: string;
  private baseUrl: string;
  private timeout: number;

  constructor(config: JobcelisConfig) {
    this.apiKey = config.apiKey;
    this.baseUrl = (config.baseUrl || 'https://jobcelis.com').replace(/\/$/, '');
    this.timeout = config.timeout || 30000;
  }

  // --- Events ---

  async sendEvent(event: EventCreate): Promise<Event> {
    return this.post('/api/v1/events', event);
  }

  async sendEvents(events: EventCreate[]): Promise<BatchResult> {
    return this.post('/api/v1/events/batch', { events });
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

  async cronPreview(expression: string, count?: number): Promise<{ executions: string[] }> {
    return this.get('/api/v1/jobs/cron-preview', { expression, count });
  }

  // --- Pipelines ---

  async createPipeline(data: PipelineCreate): Promise<Pipeline> {
    return this.post('/api/v1/pipelines', data);
  }

  async listPipelines(opts?: ListOptions): Promise<PaginatedResponse<Pipeline>> {
    return this.get('/api/v1/pipelines', opts);
  }

  async getPipeline(id: string): Promise<Pipeline> {
    return this.get(`/api/v1/pipelines/${id}`);
  }

  async updatePipeline(id: string, updates: Partial<PipelineCreate>): Promise<Pipeline> {
    return this.patch(`/api/v1/pipelines/${id}`, updates);
  }

  async deletePipeline(id: string): Promise<void> {
    await this.delete(`/api/v1/pipelines/${id}`);
  }

  async testPipeline(id: string, payload: Record<string, unknown>): Promise<any> {
    return this.post(`/api/v1/pipelines/${id}/test`, payload);
  }

  // --- Event Schemas ---

  async createEventSchema(data: EventSchemaCreate): Promise<EventSchema> {
    return this.post('/api/v1/event-schemas', data);
  }

  async listEventSchemas(opts?: ListOptions): Promise<PaginatedResponse<EventSchema>> {
    return this.get('/api/v1/event-schemas', opts);
  }

  async getEventSchema(id: string): Promise<EventSchema> {
    return this.get(`/api/v1/event-schemas/${id}`);
  }

  async updateEventSchema(id: string, updates: Partial<EventSchemaCreate>): Promise<EventSchema> {
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

  async listTopics(): Promise<{ data: string[] }> {
    return this.get('/api/v1/topics');
  }

  async getToken(): Promise<{ token: string; prefix: string }> {
    return this.get('/api/v1/token');
  }

  async regenerateToken(): Promise<{ token: string; prefix: string }> {
    return this.post('/api/v1/token/regenerate', {});
  }

  // --- Projects (multi) ---

  async listProjects(): Promise<{ data: Project[] }> {
    return this.get('/api/v1/projects');
  }

  async createProject(name: string): Promise<Project> {
    return this.post('/api/v1/projects', { name });
  }

  async getProjectById(id: string): Promise<Project> {
    return this.get(`/api/v1/projects/${id}`);
  }

  async updateProjectById(id: string, updates: Partial<{ name: string }>): Promise<Project> {
    return this.patch(`/api/v1/projects/${id}`, updates);
  }

  async deleteProject(id: string): Promise<void> {
    await this.delete(`/api/v1/projects/${id}`);
  }

  async setDefaultProject(id: string): Promise<Project> {
    return this.patch(`/api/v1/projects/${id}/default`, {});
  }

  // --- Teams ---

  async listMembers(projectId: string): Promise<{ data: Member[] }> {
    return this.get(`/api/v1/projects/${projectId}/members`);
  }

  async addMember(projectId: string, email: string, role?: string): Promise<Member> {
    return this.post(`/api/v1/projects/${projectId}/members`, { email, role });
  }

  async updateMember(projectId: string, memberId: string, role: string): Promise<Member> {
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

  async restrictProcessing(): Promise<void> {
    await this.post('/api/v1/me/restrict', {});
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

  // --- Health ---

  async health(): Promise<Record<string, unknown>> {
    return this.get('/health');
  }

  // --- HTTP helpers ---

  private async request(method: string, path: string, body?: unknown, query?: Record<string, any>): Promise<unknown> {
    const url = new URL(this.baseUrl + path);
    if (query) {
      for (const [k, v] of Object.entries(query)) {
        if (v !== undefined && v !== null) url.searchParams.set(k, String(v));
      }
    }

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeout);

    try {
      const res = await fetch(url.toString(), {
        method,
        headers: {
          'Content-Type': 'application/json',
          'X-Api-Key': this.apiKey,
        },
        body: body ? JSON.stringify(body) : undefined,
        signal: controller.signal,
      });

      if (!res.ok) {
        const errBody: any = await res.json().catch(() => ({ error: res.statusText }));
        throw new JobcelisError(res.status, errBody.error || errBody.errors || res.statusText);
      }

      if (res.status === 204) return undefined;
      return res.json();
    } finally {
      clearTimeout(timer);
    }
  }

  private async requestText(method: string, path: string): Promise<string> {
    const url = new URL(this.baseUrl + path);

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeout);

    try {
      const res = await fetch(url.toString(), {
        method,
        headers: {
          'X-Api-Key': this.apiKey,
        },
        signal: controller.signal,
      });

      if (!res.ok) {
        const error = await res.text().catch(() => res.statusText);
        throw new JobcelisError(res.status, error);
      }

      return res.text();
    } finally {
      clearTimeout(timer);
    }
  }

  private async get(path: string, query?: Record<string, any>): Promise<any> {
    return this.request('GET', path, undefined, query);
  }

  private async post(path: string, body: unknown): Promise<any> {
    return this.request('POST', path, body);
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
