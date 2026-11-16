// Jobcelis failover proxy (Cloudflare Worker, free plan).
//
// Route: jobcelis.com/*  ·  Secret: PROXY_SECRET (same value as the app's
// TRUSTED_PROXY_SECRET on every host)  ·  Cron trigger: */5 * * * *
//
// Every request goes to the primary host (Azure). It is sent to the backup
// host (Render) instead when the primary did not answer as the app:
//   - the connection failed or timed out, or
//   - it returned an error (status >= 400) without an x-request-id header.
//     Every error the app returns goes through Plug.RequestId, so an error
//     without it is a platform page such as Azure's "This web app is stopped"
//     (403) or a gateway error. Static files skip Plug.RequestId but are only
//     ever 200/304, so they are not mistaken for an outage.
// An error returned by the app itself (it has x-request-id) is passed through:
// the backup runs the same code and would answer the same.
//
// Reads (GET/HEAD/OPTIONS) and WebSocket upgrades are always safe to resend.
// Writes are resent only when the primary never handled them (no app
// response); a write that timed out is not resent, so it cannot run twice.

const PRIMARY = "https://jobcelis.azurewebsites.net";
const BACKUP = "https://jobcelis-backup.onrender.com";
const READ_TIMEOUT_MS = 10_000;
const SAFE_METHODS = ["GET", "HEAD", "OPTIONS"];

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const isWebSocket = (request.headers.get("upgrade") || "").toLowerCase() === "websocket";
    const isRead = SAFE_METHODS.includes(request.method);

    // A write's body can be read once: keep it so it can be sent again
    const body = isRead || isWebSocket ? null : await request.arrayBuffer();

    const headers = new Headers(request.headers);
    headers.set("x-jobcelis-client-ip", request.headers.get("cf-connecting-ip") || "");
    if (env.PROXY_SECRET) headers.set("x-jobcelis-proxy-secret", env.PROXY_SECRET);
    headers.set("x-forwarded-host", url.host);
    headers.set("x-forwarded-proto", "https");

    const send = (origin, signal) =>
      fetch(origin + url.pathname + url.search, {
        method: request.method,
        headers,
        body,
        redirect: "manual",
        signal,
      });

    let primary;
    try {
      const signal = isRead && !isWebSocket ? AbortSignal.timeout(READ_TIMEOUT_MS) : undefined;
      primary = await send(PRIMARY, signal);
    } catch (error) {
      // A write that may have reached the app is not sent twice
      if (!isRead && !isWebSocket && error.name === "TimeoutError") throw error;
      primary = null;
    }

    if (primary && answeredByApp(primary)) return rewrite(primary, url);

    const backup = await send(BACKUP);
    return rewrite(backup, url);
  },

  // Cron trigger (every 5 minutes): Render's free plan sleeps after 15 idle
  // minutes, which would stop its Oban jobs and delay a failover by ~50s
  async scheduled(_event, _env, ctx) {
    ctx.waitUntil(fetch(BACKUP + "/health"));
  },
};

function answeredByApp(response) {
  return response.status < 400 || response.headers.has("x-request-id");
}

// Absolute redirects to a host name are turned back into the public domain
function rewrite(response, url) {
  const location = response.headers.get("location");
  if (!location) return response;

  const fixed = location.replace(PRIMARY, url.origin).replace(BACKUP, url.origin);
  if (fixed === location) return response;

  const copy = new Response(response.body, response);
  copy.headers.set("location", fixed);
  return copy;
}
