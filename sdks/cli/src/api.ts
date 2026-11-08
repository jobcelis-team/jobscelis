const BASE_URL = process.env.JOBCELIS_BASE_URL || "https://jobcelis.com";
const API_KEY = process.env.JOBCELIS_API_KEY;

function getApiKey(): string {
  if (!API_KEY) {
    process.stderr.write(
      "Error: JOBCELIS_API_KEY environment variable is required.\n" +
        "Set it with: export JOBCELIS_API_KEY=your_api_key\n"
    );
    process.exit(1);
  }
  return API_KEY;
}

function buildUrl(path: string, params?: Record<string, string>): string {
  const url = new URL(path, BASE_URL);
  if (params) {
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== null) {
        url.searchParams.set(key, value);
      }
    }
  }
  return url.toString();
}

function headers(): Record<string, string> {
  return {
    Authorization: `Bearer ${getApiKey()}`,
    "Content-Type": "application/json",
    Accept: "application/json",
  };
}

async function handleResponse(res: Response): Promise<unknown> {
  const text = await res.text();
  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch {
    body = text;
  }

  if (!res.ok) {
    const msg =
      typeof body === "object" && body !== null && "error" in body
        ? (body as Record<string, unknown>).error
        : typeof body === "object" && body !== null && "message" in body
          ? (body as Record<string, unknown>).message
          : text || res.statusText;
    throw new Error(`HTTP ${res.status}: ${msg}`);
  }

  return body;
}

const RETRYABLE_STATUSES = new Set([429, 502, 503, 504]);
const MAX_BACKOFF_MS = 30_000;
const MAX_RETRY_AFTER_MS = 60_000;

function parseMaxRetries(value: string | undefined): number {
  const n = Number(value);
  return value !== undefined && value.trim() !== "" && Number.isFinite(n) && n >= 0 ? Math.floor(n) : 6;
}

/**
 * Automatic retries on network errors and HTTP 429/502/503/504. maxRetries comes
 * from JOBCELIS_MAX_RETRIES (default 6, about 60 s of backoff; 0 disables retries).
 */
export const retryConfig = {
  maxRetries: parseMaxRetries(process.env.JOBCELIS_MAX_RETRIES),
  baseDelayMs: 1000,
};

export interface RetryOptions {
  /** Sent as X-Idempotency-Key; makes a POST safe to retry after a network error. */
  idempotencyKey?: string;
  /** The body carries its own idempotency keys (batch): safe to retry after a network error. */
  idempotent?: boolean;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Delay in ms before retry number n (1-based). */
function retryDelay(n: number, retryAfter: string | null): number {
  if (retryAfter !== null) {
    const seconds = Number(retryAfter);
    let ms: number | undefined;
    if (retryAfter.trim() !== "" && Number.isFinite(seconds)) {
      ms = seconds * 1000;
    } else {
      const date = Date.parse(retryAfter);
      if (!Number.isNaN(date)) ms = date - Date.now();
    }
    if (ms !== undefined) return Math.min(MAX_RETRY_AFTER_MS, Math.max(0, ms));
  }
  const base = Math.min(MAX_BACKOFF_MS, retryConfig.baseDelayMs * 2 ** (n - 1));
  return base * (0.8 + Math.random() * 0.4);
}

/**
 * fetch with retries. POSTs are retried on network errors only when they carry
 * an idempotency key, so a retry can never create a resource twice.
 */
async function send(
  method: string,
  url: string,
  body: unknown,
  retry: RetryOptions = {}
): Promise<Response> {
  const hdrs = headers();
  if (retry.idempotencyKey) hdrs["X-Idempotency-Key"] = retry.idempotencyKey;
  const payload = body !== undefined ? JSON.stringify(body) : undefined;
  const retryOnNetworkError =
    method !== "POST" || !!retry.idempotencyKey || !!retry.idempotent;

  for (let attempt = 0; ; attempt++) {
    let res: Response;
    try {
      res = await fetch(url, { method, headers: hdrs, body: payload });
    } catch (err) {
      if (!retryOnNetworkError || attempt >= retryConfig.maxRetries) throw err;
      await sleep(retryDelay(attempt + 1, null));
      continue;
    }
    if (RETRYABLE_STATUSES.has(res.status) && attempt < retryConfig.maxRetries) {
      const retryAfter = res.headers.get("retry-after");
      await res.body?.cancel().catch(() => undefined);
      await sleep(retryDelay(attempt + 1, retryAfter));
      continue;
    }
    return res;
  }
}

export async function get(
  path: string,
  params?: Record<string, string>
): Promise<unknown> {
  return handleResponse(await send("GET", buildUrl(path, params), undefined));
}

export async function post(
  path: string,
  body?: unknown,
  retry?: RetryOptions
): Promise<unknown> {
  return handleResponse(await send("POST", buildUrl(path), body, retry));
}

export async function patch(
  path: string,
  body?: unknown
): Promise<unknown> {
  return handleResponse(await send("PATCH", buildUrl(path), body));
}

export async function put(
  path: string,
  body?: unknown
): Promise<unknown> {
  return handleResponse(await send("PUT", buildUrl(path), body));
}

export async function del(path: string): Promise<unknown> {
  return handleResponse(await send("DELETE", buildUrl(path), undefined));
}
