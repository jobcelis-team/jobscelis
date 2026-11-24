import { trimTrailing } from "./util";

// Configuration is read from the environment on every request.
//   JOBCELIS_API_KEY     project API key, sent as X-Api-Key
//   JOBCELIS_TOKEN       user JWT, sent as Authorization: Bearer (account routes)
//   JOBCELIS_BASE_URL    base URL, may include a path prefix
//   JOBCELIS_TIMEOUT_MS  request timeout in ms (default 30000; 0 disables it)
//   JOBCELIS_MAX_RETRIES retries (default 6; 0 disables them)

const DEFAULT_BASE_URL = "https://jobcelis.com";
const DEFAULT_TIMEOUT_MS = 30_000;

/** Which credential a route needs. */
export type AuthKind = "none" | "api-key" | "jwt";

/**
 * /auth/* and /health need no credential. Projects, members, invitations and
 * /me/* take the user JWT; everything else takes the project API key.
 */
export function authFor(path: string): AuthKind {
  if (path === "/health" || path.startsWith("/api/v1/auth/")) return "none";
  if (
    /^\/api\/v1\/projects(\/|$)/.test(path) ||
    path.startsWith("/api/v1/invitations/") ||
    path.startsWith("/api/v1/me/")
  ) {
    return "jwt";
  }
  return "api-key";
}

function fail(message: string): never {
  process.stderr.write(message);
  process.exit(1);
}

function getApiKey(): string {
  const key = process.env.JOBCELIS_API_KEY;
  if (!key) {
    fail(
      "Error: JOBCELIS_API_KEY environment variable is required.\n" +
        "Set it with: export JOBCELIS_API_KEY=your_api_key\n"
    );
  }
  return key;
}

function getToken(): string {
  const token = process.env.JOBCELIS_TOKEN;
  if (!token) {
    fail(
      "Error: JOBCELIS_TOKEN environment variable is required for this command.\n" +
        "Projects, members, invitations and GDPR commands use your user token (JWT), not the API key.\n" +
        "Get one with: jobcelis auth login --email <e> --password <p>\n" +
        "then: export JOBCELIS_TOKEN=<token>\n"
    );
  }
  return token;
}

function timeoutMs(): number {
  const raw = process.env.JOBCELIS_TIMEOUT_MS;
  const n = Number(raw);
  return raw !== undefined && raw.trim() !== "" && Number.isFinite(n) && n >= 0
    ? Math.floor(n)
    : DEFAULT_TIMEOUT_MS;
}

/**
 * Joins the base URL and the path. `new URL(path, base)` would drop a path prefix
 * of the base (https://host/prefix + /api/v1/x -> https://host/api/v1/x).
 */
export function buildUrl(path: string, params?: Record<string, string>): string {
  const base = trimTrailing(process.env.JOBCELIS_BASE_URL || DEFAULT_BASE_URL, "/");
  const url = new URL(base + (path.startsWith("/") ? path : `/${path}`));
  if (params) {
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== null) {
        url.searchParams.set(key, value);
      }
    }
  }
  return url.toString();
}

function headers(path: string): Record<string, string> {
  const hdrs: Record<string, string> = {
    "Content-Type": "application/json",
    Accept: "application/json",
  };
  const kind = authFor(path);
  if (kind === "api-key") hdrs["X-Api-Key"] = getApiKey();
  if (kind === "jwt") hdrs.Authorization = `Bearer ${getToken()}`;
  return hdrs;
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
/** A POST without an idempotency key is retried only when the server surely did not act. */
const NON_IDEMPOTENT_RETRYABLE_STATUSES = new Set([429, 503]);
const MAX_BACKOFF_MS = 30_000;
const MAX_RETRY_AFTER_MS = 60_000;

function parseMaxRetries(value: string | undefined): number {
  const n = Number(value);
  return value !== undefined && value.trim() !== "" && Number.isFinite(n) && n >= 0 ? Math.floor(n) : 6;
}

/**
 * Automatic retries on network errors, timeouts and HTTP 429/502/503/504. maxRetries
 * comes from JOBCELIS_MAX_RETRIES (default 6, about 60 s of backoff; 0 disables retries).
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
 * fetch with a timeout and retries. A POST without an idempotency key is retried
 * only on 429/503: after a network error, timeout, 502 or 504 the server may have
 * acted on it, and a retry could create the resource twice.
 */
async function send(
  method: string,
  path: string,
  params: Record<string, string> | undefined,
  body: unknown,
  retry: RetryOptions = {}
): Promise<Response> {
  const url = buildUrl(path, params);
  const hdrs = headers(path);
  if (retry.idempotencyKey) hdrs["X-Idempotency-Key"] = retry.idempotencyKey;
  const payload = body !== undefined ? JSON.stringify(body) : undefined;
  const idempotent = method !== "POST" || !!retry.idempotencyKey || !!retry.idempotent;
  const retryable = idempotent ? RETRYABLE_STATUSES : NON_IDEMPOTENT_RETRYABLE_STATUSES;
  const timeout = timeoutMs();

  for (let attempt = 0; ; attempt++) {
    let res: Response;
    try {
      const signal = timeout > 0 ? AbortSignal.timeout(timeout) : undefined;
      res = await fetch(url, { method, headers: hdrs, body: payload, signal });
    } catch (err) {
      if (!idempotent || attempt >= retryConfig.maxRetries) {
        if ((err as Error)?.name === "TimeoutError") {
          throw new Error(`Request timed out after ${timeout} ms (set JOBCELIS_TIMEOUT_MS to change it)`);
        }
        throw err;
      }
      await sleep(retryDelay(attempt + 1, null));
      continue;
    }
    if (retryable.has(res.status) && attempt < retryConfig.maxRetries) {
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
  return handleResponse(await send("GET", path, params, undefined));
}

export async function post(
  path: string,
  body?: unknown,
  retry?: RetryOptions
): Promise<unknown> {
  return handleResponse(await send("POST", path, undefined, body, retry));
}

export async function patch(
  path: string,
  body?: unknown
): Promise<unknown> {
  return handleResponse(await send("PATCH", path, undefined, body));
}

export async function put(
  path: string,
  body?: unknown
): Promise<unknown> {
  return handleResponse(await send("PUT", path, undefined, body));
}

export async function del(path: string): Promise<unknown> {
  return handleResponse(await send("DELETE", path, undefined, undefined));
}
