const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { createHmac } = require('node:crypto');
const { JobcelisClient, JobcelisError, verifyWebhookSignature } = require('../dist');

// Fake API: each request takes the next scripted response. { delay } holds the
// answer back for that many ms.
let server;
let baseUrl;
let script = [];
let requests = [];

before(async () => {
  server = http.createServer((req, res) => {
    let raw = '';
    req.on('data', (c) => (raw += c));
    req.on('end', () => {
      requests.push({ method: req.method, url: req.url, headers: req.headers, body: raw ? JSON.parse(raw) : undefined });
      const next = script.shift() || { status: 200, body: {} };
      const answer = () => {
        if (res.destroyed) return;
        res.writeHead(next.status, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(next.body ?? {}));
      };
      if (next.delay) setTimeout(answer, next.delay);
      else answer();
    });
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(() => {
  server.closeAllConnections();
  return new Promise((resolve) => server.close(resolve));
});

beforeEach(() => {
  script = [];
  requests = [];
});

function client(opts = {}) {
  return new JobcelisClient({ apiKey: 'test', baseUrl, retryBaseDelay: 1, ...opts });
}

test('sends X-Api-Key and no Authorization without an auth token', async () => {
  await client().listEvents();
  assert.equal(requests[0].headers['x-api-key'], 'test');
  assert.equal(requests[0].headers['authorization'], undefined);
});

test('authToken option and setAuthToken send Authorization: Bearer', async () => {
  const c = client({ authToken: 'jwt-1' });
  await c.listProjects();
  assert.equal(requests[0].headers['authorization'], 'Bearer jwt-1');
  assert.equal(requests[0].headers['x-api-key'], 'test');
  c.setAuthToken('jwt-2');
  await c.listProjects();
  assert.equal(requests[1].headers['authorization'], 'Bearer jwt-2');
  c.setAuthToken(null);
  await c.listProjects();
  assert.equal(requests[2].headers['authorization'], undefined);
});

test('login works without an API key and stores the returned token', async () => {
  script = [{ status: 200, body: { user: { id: 'u1' }, token: 'jwt-login' } }, { status: 200, body: { data: [] } }];
  const c = new JobcelisClient({ baseUrl, retryBaseDelay: 1 });
  await c.login('a@b.c', 'pw');
  assert.equal(requests[0].url, '/api/v1/auth/login');
  assert.deepEqual(requests[0].body, { email: 'a@b.c', password: 'pw' });
  assert.equal(requests[0].headers['x-api-key'], undefined);
  await c.listProjects();
  assert.equal(requests[1].headers['authorization'], 'Bearer jwt-login');
});

test('login with MFA returns the challenge and verifyMfa sends mfa_token + code', async () => {
  script = [
    { status: 200, body: { mfa_required: true, mfa_token: 'mfa-1' } },
    { status: 200, body: { user: { id: 'u1' }, token: 'jwt-mfa' } },
  ];
  const c = client();
  const res = await c.login('a@b.c', 'pw');
  assert.equal(res.mfa_required, true);
  await c.verifyMfa(res.mfa_token, '123456');
  assert.equal(requests[1].url, '/api/v1/auth/mfa/verify');
  assert.deepEqual(requests[1].body, { mfa_token: 'mfa-1', code: '123456' });
  await c.listProjects();
  assert.equal(requests[2].headers['authorization'], 'Bearer jwt-mfa');
});

test('register and refreshToken hit the auth routes', async () => {
  script = [{ status: 201, body: { user: { id: 'u1' }, token: 'jwt-reg' } }, { status: 200, body: { token: 'jwt-new' } }];
  const c = client();
  await c.register({ email: 'a@b.c', password: 'pw', name: 'A' });
  assert.equal(requests[0].url, '/api/v1/auth/register');
  assert.deepEqual(requests[0].body, { email: 'a@b.c', password: 'pw', name: 'A' });
  await c.refreshToken();
  assert.equal(requests[1].url, '/api/v1/auth/refresh');
  assert.deepEqual(requests[1].body, { token: 'jwt-reg' });
});

test('updateRetentionPolicy wraps the policy in retention_policy', async () => {
  await client().updateRetentionPolicy({ events_days: 30 });
  assert.equal(requests[0].method, 'PATCH');
  assert.deepEqual(requests[0].body, { retention_policy: { events_days: 30 } });
});

test('testPipeline sends { payload }', async () => {
  await client().testPipeline('p1', { amount: 5 });
  assert.equal(requests[0].url, '/api/v1/pipelines/p1/test');
  assert.deepEqual(requests[0].body, { payload: { amount: 5 } });
});

test('restrictProcessing sends the password', async () => {
  await client({ authToken: 'jwt' }).restrictProcessing('secret');
  assert.deepEqual(requests[0].body, { password: 'secret' });
});

test('addMember defaults the role to viewer', async () => {
  await client({ authToken: 'jwt' }).addMember('p1', 'x@y.z');
  assert.deepEqual(requests[0].body, { email: 'x@y.z', role: 'viewer' });
});

test('status() reads /health', async () => {
  await client().status();
  assert.equal(requests[0].url, '/health');
});

for (const status of [502, 504]) {
  test(`POST without idempotency key is not retried on ${status}`, async () => {
    script = [{ status, body: { error: 'bad gateway' } }];
    await assert.rejects(client().createWebhook({ url: 'https://example.com' }), (err) => err.status === status);
    assert.equal(requests.length, 1);
  });

  test(`GET is still retried on ${status}`, async () => {
    script = [{ status }, { status: 200, body: { id: 'x' } }];
    await client().getEvent('x');
    assert.equal(requests.length, 2);
  });
}

test('a timeout raises JobcelisError, not AbortError', async () => {
  script = [{ status: 200, body: {}, delay: 500 }];
  await assert.rejects(
    client({ timeout: 50, maxRetries: 0 }).getEvent('x'),
    (err) => err instanceof JobcelisError && err.status === 0 && /timed out/.test(err.message),
  );
});

test('timeout: 0 disables the timeout instead of using the default', async () => {
  script = [{ status: 200, body: { id: 'slow' }, delay: 100 }];
  const event = await client({ timeout: 0 }).getEvent('x');
  assert.equal(event.id, 'slow');
});

test('base URL with a path prefix keeps the prefix', async () => {
  const c = new JobcelisClient({ apiKey: 'test', baseUrl: `${baseUrl}/prefix/`, retryBaseDelay: 1 });
  await c.listEvents();
  assert.equal(requests[0].url, '/prefix/api/v1/events');
});

// --- Webhook signatures ---

const secret = 'whsec_test';
const body = '{"topic":"order.created","payload":{"id":1}}';
const sig = (b) => 'sha256=' + createHmac('sha256', secret).update(b).digest('base64').replace(/=+$/, '');

test('verifyWebhookSignature accepts a valid signature for string and Buffer bodies', () => {
  assert.equal(verifyWebhookSignature(secret, body, sig(body)), true);
  assert.equal(verifyWebhookSignature(secret, Buffer.from(body), sig(body)), true);
});

test('verifyWebhookSignature accepts padded Base64', () => {
  const padded = 'sha256=' + createHmac('sha256', secret).update(body).digest('base64');
  assert.equal(verifyWebhookSignature(secret, body, padded), true);
});

test('verifyWebhookSignature rejects signatures with extra invalid characters', () => {
  const good = sig(body);
  // Buffer.from(x, 'base64') silently drops these, so a decode-and-compare would accept them
  assert.equal(verifyWebhookSignature(secret, body, good + '!!'), false);
  assert.equal(verifyWebhookSignature(secret, body, good.slice(0, 10) + '*' + good.slice(10)), false);
});

test('verifyWebhookSignature rejects a wrong body, secret or prefix', () => {
  assert.equal(verifyWebhookSignature(secret, body + ' ', sig(body)), false);
  assert.equal(verifyWebhookSignature('other', body, sig(body)), false);
  assert.equal(verifyWebhookSignature(secret, body, sig(body).replace('sha256=', 'sha1=')), false);
  assert.equal(verifyWebhookSignature(secret, '', sig('')), false);
});
