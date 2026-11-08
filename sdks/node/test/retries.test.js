const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { JobcelisClient, JobcelisError } = require('../dist');

// Fake API: each request takes the next scripted response; 'drop' closes the
// connection without answering (a network error).
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
      if (next === 'drop') {
        req.socket.destroy();
        return;
      }
      res.writeHead(next.status, { 'Content-Type': 'application/json', ...(next.headers || {}) });
      res.end(JSON.stringify(next.body ?? {}));
    });
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(() => new Promise((resolve) => server.close(resolve)));

beforeEach(() => {
  script = [];
  requests = [];
});

function client(opts = {}) {
  return new JobcelisClient({ apiKey: 'test', baseUrl, retryBaseDelay: 1, ...opts });
}

test('GET retries 503 twice then succeeds', async () => {
  script = [{ status: 503 }, { status: 503 }, { status: 200, body: { id: 'evt_1' } }];
  const event = await client().getEvent('evt_1');
  assert.equal(event.id, 'evt_1');
  assert.equal(requests.length, 3);
});

test('429 with Retry-After: 0 is retried', async () => {
  script = [{ status: 429, headers: { 'Retry-After': '0' } }, { status: 200, body: { data: [] } }];
  await client().listEvents();
  assert.equal(requests.length, 2);
});

test('sendEvent sends the same X-Idempotency-Key on every attempt', async () => {
  script = ['drop', { status: 502 }, { status: 202, body: { id: 'evt_1' } }];
  await client().sendEvent({ topic: 't', payload: {} });
  assert.equal(requests.length, 3);
  const key = requests[0].headers['x-idempotency-key'];
  assert.match(key, /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  for (const r of requests) assert.equal(r.headers['x-idempotency-key'], key);
});

test('sendEvent keeps a caller-supplied idempotency key', async () => {
  script = [{ status: 503 }, { status: 202, body: {} }];
  await client().sendEvent({ topic: 't', payload: {}, idempotency_key: 'my-key' });
  assert.equal(requests.length, 2);
  for (const r of requests) assert.equal(r.headers['x-idempotency-key'], 'my-key');
});

test('sendEvents adds idempotency_key to items that lack one and keeps existing ones', async () => {
  script = ['drop', { status: 202, body: { accepted: 2 } }];
  const events = [{ topic: 'a', payload: {} }, { topic: 'b', payload: {}, idempotency_key: 'keep-me' }];
  await client().sendEvents(events);
  assert.equal(requests.length, 2);
  const [first, second] = requests.map((r) => r.body.events);
  assert.ok(first[0].idempotency_key);
  assert.equal(first[1].idempotency_key, 'keep-me');
  assert.deepEqual(second, first);
  assert.equal(events[0].idempotency_key, undefined, 'caller objects are not mutated');
});

test('POST of a non-event resource is not retried on a network error', async () => {
  script = ['drop'];
  await assert.rejects(client().createWebhook({ url: 'https://example.com' }));
  assert.equal(requests.length, 1);
  assert.equal(requests[0].headers['x-idempotency-key'], undefined);
});

test('POST of a non-event resource is retried on 503', async () => {
  script = [{ status: 503 }, { status: 201, body: { id: 'wh_1' } }];
  const webhook = await client().createWebhook({ url: 'https://example.com' });
  assert.equal(webhook.id, 'wh_1');
  assert.equal(requests.length, 2);
});

test('maxRetries: 0 makes exactly one request', async () => {
  script = [{ status: 503, body: { error: 'down' } }];
  await assert.rejects(client({ maxRetries: 0 }).getEvent('x'), (err) => err instanceof JobcelisError && err.status === 503);
  assert.equal(requests.length, 1);
});

test('the last error after all retries is a JobcelisError', async () => {
  script = [{ status: 503 }, { status: 503 }, { status: 503 }];
  await assert.rejects(client({ maxRetries: 2 }).getEvent('x'), (err) => err instanceof JobcelisError && err.status === 503);
  assert.equal(requests.length, 3);
});

for (const status of [400, 500]) {
  test(`status ${status} is not retried`, async () => {
    script = [{ status, body: { error: 'nope' } }];
    await assert.rejects(client().getEvent('x'), (err) => err instanceof JobcelisError && err.status === status && err.message === 'nope');
    assert.equal(requests.length, 1);
  });
}

test('GET is retried on a network error', async () => {
  script = ['drop', { status: 200, body: 'csv' }];
  await client().exportEvents();
  assert.equal(requests.length, 2);
});
