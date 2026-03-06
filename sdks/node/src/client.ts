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

  // --- HTTP helpers ---

  private async request(method: string, path: string, body?: unknown, query?: Record<string, unknown>): Promise<unknown> {
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
        const error = await res.json().catch(() => ({ error: res.statusText }));
        throw new JobcelisError(res.status, error.error || error.errors || res.statusText);
      }

      if (res.status === 204) return undefined;
      return res.json();
    } finally {
      clearTimeout(timer);
    }
  }

  private async get(path: string, query?: Record<string, unknown>): Promise<any> {
    return this.request('GET', path, undefined, query);
  }

  private async post(path: string, body: unknown): Promise<any> {
    return this.request('POST', path, body);
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
