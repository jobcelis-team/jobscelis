const { test, before, after, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const crypto = require('node:crypto');

// Fake API: each request takes the next scripted response. { delay } holds the
// answer back for that many ms.
let server;
let origin;
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
  origin = `http://127.0.0.1:${server.address().port}`;
  api = require('../dist/api');
  commands = require('../dist/commands');
});

after(() => {
  server.closeAllConnections();
  return new Promise((resolve) => server.close(resolve));
});

let stdout;
let stderr;

beforeEach(() => {
  script = [];
  requests = [];
  process.env.JOBCELIS_API_KEY = 'test-key';
  delete process.env.JOBCELIS_TOKEN;
  delete process.env.JOBCELIS_TIMEOUT_MS;
  process.env.JOBCELIS_BASE_URL = origin;
  api.retryConfig.maxRetries = 6;
  api.retryConfig.baseDelayMs = 1;
  stdout = '';
  stderr = '';
});

afterEach(() => {
  process.exitCode = 0;
});

/**
 * Runs a command with its output captured and process.exit turned into an
 * exception.
 */
async function run(fn) {
  const realExit = process.exit;
  const realWrite = process.stdout.write;
  const realErrWrite = process.stderr.write;
  process.exit = (code) => {
    throw new Error(`exit ${code}`);
  };
  // The test runner reports through stdout with Buffers: let those through
  process.stdout.write = (chunk, ...rest) =>
    typeof chunk === 'string' ? ((stdout += chunk), true) : realWrite.call(process.stdout, chunk, ...rest);
  process.stderr.write = (chunk, ...rest) =>
    typeof chunk === 'string' ? ((stderr += chunk), true) : realErrWrite.call(process.stderr, chunk, ...rest);
  try {
    return await fn();
  } finally {
    process.exit = realExit;
    process.stdout.write = realWrite;
    process.stderr.write = realErrWrite;
  }
}

test('API-key routes send X-Api-Key, never Authorization', async () => {
  process.env.JOBCELIS_TOKEN = 'jwt';
  await api.get('/api/v1/events');
  assert.equal(requests[0].headers['x-api-key'], 'test-key');
  assert.equal(requests[0].headers['authorization'], undefined);
});

test('JWT routes send JOBCELIS_TOKEN as Bearer', async () => {
  process.env.JOBCELIS_TOKEN = 'jwt-1';
  await run(() => commands.projectsList([]));
  await run(() => commands.gdprConsents([]));
  await run(() => commands.invitationsPending([]));
  for (const r of requests) {
    assert.equal(r.headers['authorization'], 'Bearer jwt-1');
    assert.equal(r.headers['x-api-key'], undefined);
  }
  assert.deepEqual(requests.map((r) => r.url), ['/api/v1/projects', '/api/v1/me/consents', '/api/v1/invitations/pending']);
});

test('JWT routes without JOBCELIS_TOKEN exit with an explanation', async () => {
  await assert.rejects(run(() => commands.projectsList([])), /exit 1/);
  assert.match(stderr, /JOBCELIS_TOKEN/);
  assert.equal(requests.length, 0);
});

test('the singular /project route still uses the API key', () => {
  assert.equal(api.authFor('/api/v1/project'), 'api-key');
  assert.equal(api.authFor('/api/v1/projects'), 'jwt');
  assert.equal(api.authFor('/api/v1/projects/p1/members'), 'jwt');
  assert.equal(api.authFor('/api/v1/auth/login'), 'none');
  assert.equal(api.authFor('/health'), 'none');
});

test('auth login works without JOBCELIS_API_KEY', async () => {
  delete process.env.JOBCELIS_API_KEY;
  script = [{ status: 200, body: { token: 'jwt' } }];
  await run(() => commands.authLogin(['--email', 'a@b.c', '--password', 'pw']));
  assert.equal(requests[0].url, '/api/v1/auth/login');
  assert.equal(requests[0].headers['x-api-key'], undefined);
  assert.equal(requests[0].headers['authorization'], undefined);
});

test('auth refresh defaults to JOBCELIS_TOKEN; mfa-verify sends mfa_token', async () => {
  delete process.env.JOBCELIS_API_KEY;
  process.env.JOBCELIS_TOKEN = 'jwt-old';
  await run(() => commands.authRefresh([]));
  assert.deepEqual(requests[0].body, { token: 'jwt-old' });
  await run(() => commands.authMfaVerify(['--token', 'mfa-1', '--code', '123456']));
  assert.deepEqual(requests[1].body, { mfa_token: 'mfa-1', code: '123456' });
});

test('retention set wraps the policy', async () => {
  await run(() => commands.retentionSet(['--events-days', '30', '--audit-logs-days', '90']));
  assert.equal(requests[0].method, 'PATCH');
  assert.deepEqual(requests[0].body, { retention_policy: { events_days: 30, audit_logs_days: 90 } });
});

test('retention set without flags exits', async () => {
  await assert.rejects(run(() => commands.retentionSet([])), /exit 1/);
  assert.equal(requests.length, 0);
});

test('pipelines create sends webhook_id and requires it', async () => {
  await run(() => commands.pipelinesCreate(['--name', 'p', '--topics', 'a,b', '--webhook-id', 'wh_1', '--steps', '[{"type":"delay","seconds":5}]']));
  assert.deepEqual(requests[0].body, { name: 'p', topics: ['a', 'b'], webhook_id: 'wh_1', steps: [{ type: 'delay', seconds: 5 }] });
  await assert.rejects(run(() => commands.pipelinesCreate(['--name', 'p', '--topics', 'a'])), /exit 1/);
  assert.equal(requests.length, 1);
});

test('jobs create sends --topic / --url and requires one of them', async () => {
  await run(() => commands.jobsCreate(['--name', 'j', '--cron', '0 3 * * *', '--topic', 'report.run', '--payload', '{"a":1}']));
  assert.deepEqual(requests[0].body, { name: 'j', cron: '0 3 * * *', topic: 'report.run', payload: { a: 1 } });
  await run(() => commands.jobsCreate(['--name', 'j', '--cron', 'daily', '--url', 'https://example.com/ping']));
  assert.deepEqual(requests[1].body, { name: 'j', cron: 'daily', url: 'https://example.com/ping' });
  await assert.rejects(run(() => commands.jobsCreate(['--name', 'j', '--cron', 'daily'])), /exit 1/);
  assert.equal(requests.length, 2);
});

test('jobs cron-preview sends the expression parameter', async () => {
  await run(() => commands.jobsCronPreview(['--cron', '*/5 * * * *']));
  assert.equal(requests[0].url, '/api/v1/jobs/cron-preview?expression=*%2F5+*+*+*+*');
});

test('purge requires --older-than', async () => {
  await assert.rejects(run(() => commands.purgeExecute(['--type', 'events'])), /exit 1/);
  await assert.rejects(run(() => commands.purgePreview(['--type', 'events'])), /exit 1/);
  assert.equal(requests.length, 0);
  await run(() => commands.purgePreview(['--type', 'events', '--older-than', '2026-01-01']));
  assert.deepEqual(requests[0].body, { type: 'events', older_than: '2026-01-01' });
});

test('gdpr restrict sends the password', async () => {
  process.env.JOBCELIS_TOKEN = 'jwt';
  await run(() => commands.gdprRestrict(['--password', 'secret']));
  assert.deepEqual(requests[0].body, { password: 'secret' });
});

test('base URL with a path prefix keeps the prefix', async () => {
  process.env.JOBCELIS_BASE_URL = `${origin}/prefix/`;
  await api.get('/api/v1/events', { limit: '5' });
  assert.equal(requests[0].url, '/prefix/api/v1/events?limit=5');
});

for (const status of [502, 504]) {
  test(`POST without idempotency key is not retried on ${status}`, async () => {
    script = [{ status, body: { error: 'gateway' } }];
    await assert.rejects(api.post('/api/v1/webhooks', { url: 'https://example.com' }), new RegExp(`HTTP ${status}`));
    assert.equal(requests.length, 1);
  });
}

test('a request slower than JOBCELIS_TIMEOUT_MS fails with a timeout error', async () => {
  process.env.JOBCELIS_TIMEOUT_MS = '50';
  api.retryConfig.maxRetries = 0;
  script = [{ status: 200, body: {}, delay: 500 }];
  await assert.rejects(api.get('/api/v1/events'), /timed out after 50 ms/);
});

// --- verify-signature ---

const secret = 'whsec_test';
const body = '{"topic":"order.created"}';
const sig = 'sha256=' + crypto.createHmac('sha256', secret).update(body).digest('base64').replace(/=+$/, '');

test('verify-signature prints true and keeps exit code 0 for a valid signature', async () => {
  await run(() => commands.verifySignature(['--secret', secret, '--body', body, '--signature', sig]));
  assert.equal(stdout, 'true\n');
  assert.ok(!process.exitCode);
});

test('verify-signature prints false and sets exit code 1 for an invalid signature', async () => {
  await run(() => commands.verifySignature(['--secret', secret, '--body', body + 'x', '--signature', sig]));
  assert.equal(stdout, 'false\n');
  assert.equal(process.exitCode, 1);
});

test('signatures with junk Base64 characters do not match', () => {
  assert.equal(commands.signatureMatches(secret, body, sig), true);
  assert.equal(commands.signatureMatches(secret, body, sig + '!!'), false);
  assert.equal(commands.signatureMatches(secret, body, sig + '='), true);
});
