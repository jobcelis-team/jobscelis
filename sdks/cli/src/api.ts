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

export async function get(
  path: string,
  params?: Record<string, string>
): Promise<unknown> {
  const res = await fetch(buildUrl(path, params), {
    method: "GET",
    headers: headers(),
  });
  return handleResponse(res);
}

export async function post(
  path: string,
  body?: unknown
): Promise<unknown> {
  const res = await fetch(buildUrl(path), {
    method: "POST",
    headers: headers(),
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  return handleResponse(res);
}

export async function patch(
  path: string,
  body?: unknown
): Promise<unknown> {
  const res = await fetch(buildUrl(path), {
    method: "PATCH",
    headers: headers(),
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  return handleResponse(res);
}

export async function put(
  path: string,
  body?: unknown
): Promise<unknown> {
  const res = await fetch(buildUrl(path), {
    method: "PUT",
    headers: headers(),
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  return handleResponse(res);
}

export async function del(path: string): Promise<unknown> {
  const res = await fetch(buildUrl(path), {
    method: "DELETE",
    headers: headers(),
  });
  return handleResponse(res);
}
