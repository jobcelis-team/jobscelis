const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const http = require('node:http');

// Fake API: each request takes the next scripted response; 'drop' closes the
// connection without answering (a network error).
let server;
let script = [];
let requests = [];
let api;
let commands;

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
  // api.ts reads the configuration when it is loaded
  process.env.JOBCELIS_API_KEY = 'test';
  process.env.JOBCELIS_BASE_URL = `http://127.0.0.1:${server.address().port}`;
  api = require('../dist/api');
  commands = require('../dist/commands');
});

after(() => new Promise((resolve) => server.close(resolve)));

beforeEach(() => {
  script = [];
  requests = [];
  api.retryConfig.maxRetries = 6;
  api.retryConfig.baseDelayMs = 1;
});

test('GET retries 503 twice then succeeds', async () => {
  script = [{ status: 503 }, { status: 503 }, { status: 200, body: { id: 'evt_1' } }];
  const event = await api.get('/api/v1/events/evt_1');
  assert.equal(event.id, 'evt_1');
  assert.equal(requests.length, 3);
});

test('429 with Retry-After: 0 is retried', async () => {
  script = [{ status: 429, headers: { 'Retry-After': '0' } }, { status: 200, body: {} }];
  await api.get('/api/v1/events');
  assert.equal(requests.length, 2);
});

test('events send sends the same X-Idempotency-Key on every attempt', async () => {
  script = ['drop', { status: 502 }, { status: 202, body: {} }];
  await commands.eventsSend(['--topic', 't', '--payload', '{}']);
  assert.equal(requests.length, 3);
  const key = requests[0].headers['x-idempotency-key'];
  assert.match(key, /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  for (const r of requests) assert.equal(r.headers['x-idempotency-key'], key);
});

test('events send keeps --idempotency-key', async () => {
  script = [{ status: 503 }, { status: 202, body: {} }];
  await commands.eventsSend(['--topic', 't', '--payload', '{}', '--idempotency-key', 'my-key']);
  assert.equal(requests.length, 2);
  for (const r of requests) assert.equal(r.headers['x-idempotency-key'], 'my-key');
});

test('events batch adds idempotency_key to items that lack one and keeps existing ones', async () => {
  const file = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'jobcelis-cli-')), 'events.json');
  fs.writeFileSync(file, JSON.stringify([{ topic: 'a', payload: {} }, { topic: 'b', payload: {}, idempotency_key: 'keep-me' }]));
  script = ['drop', { status: 202, body: {} }];
  await commands.eventsBatch(['--file', file]);
  assert.equal(requests.length, 2);
  const [first, second] = requests.map((r) => r.body.events);
  assert.ok(first[0].idempotency_key);
  assert.equal(first[1].idempotency_key, 'keep-me');
  assert.deepEqual(second, first);
});

test('POST of a non-event resource is not retried on a network error', async () => {
  script = ['drop'];
  await assert.rejects(api.post('/api/v1/webhooks', { url: 'https://example.com' }));
  assert.equal(requests.length, 1);
});

test('POST of a non-event resource is retried on 503', async () => {
  script = [{ status: 503 }, { status: 201, body: { id: 'wh_1' } }];
  const webhook = await api.post('/api/v1/webhooks', { url: 'https://example.com' });
  assert.equal(webhook.id, 'wh_1');
  assert.equal(requests.length, 2);
});

test('maxRetries 0 makes exactly one request', async () => {
  api.retryConfig.maxRetries = 0;
  script = [{ status: 503, body: { error: 'down' } }];
  await assert.rejects(api.get('/api/v1/events/x'), /HTTP 503: down/);
  assert.equal(requests.length, 1);
});

for (const status of [400, 500]) {
  test(`status ${status} is not retried`, async () => {
    script = [{ status, body: { error: 'nope' } }];
    await assert.rejects(api.get('/api/v1/events/x'), new RegExp(`HTTP ${status}: nope`));
    assert.equal(requests.length, 1);
  });
}
