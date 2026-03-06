/**
 * Jobcelis CLI — Command-line interface for the Jobcelis platform.
 *
 * Usage:
 *   jobcelis <command> [options]
 *
 * Commands:
 *   events send       Send an event
 *   events list       List events
 *   events get <id>   Get event details
 *   webhooks list     List webhooks
 *   webhooks create   Create a webhook
 *   webhooks get <id> Get webhook details
 *   deliveries list   List deliveries
 *   dead-letters list List dead letters
 *   status            Check platform status
 *
 * Environment:
 *   JOBCELIS_API_KEY  API key (required)
 *   JOBCELIS_URL      Base URL (default: https://jobcelis.com)
 */

const API_KEY = process.env.JOBCELIS_API_KEY;
const BASE_URL = (process.env.JOBCELIS_URL || 'https://jobcelis.com').replace(/\/$/, '');

async function request(method, path, body) {
  if (!API_KEY) {
    console.error('Error: JOBCELIS_API_KEY environment variable is required');
    process.exit(1);
  }

  const url = `${BASE_URL}${path}`;
  const opts = {
    method,
    headers: {
      'Content-Type': 'application/json',
      'X-Api-Key': API_KEY,
    },
  };
  if (body) opts.body = JSON.stringify(body);

  const res = await fetch(url, opts);
  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: res.statusText }));
    console.error(`Error ${res.status}: ${err.error || JSON.stringify(err)}`);
    process.exit(1);
  }
  if (res.status === 204) return null;
  return res.json();
}

function parseFlags(args) {
  const flags = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i].startsWith('--')) {
      const key = args[i].slice(2);
      const val = args[i + 1] && !args[i + 1].startsWith('--') ? args[++i] : true;
      flags[key] = val;
    }
  }
  return flags;
}

const commands = {
  async 'events send'(args) {
    const flags = parseFlags(args);
    if (!flags.topic) {
      console.error('Usage: jobcelis events send --topic <topic> --payload \'{"key":"value"}\'');
      process.exit(1);
    }
    const payload = flags.payload ? JSON.parse(flags.payload) : {};
    const result = await request('POST', '/api/v1/events', { topic: flags.topic, payload });
    console.log(JSON.stringify(result, null, 2));
  },

  async 'events list'(args) {
    const flags = parseFlags(args);
    const params = new URLSearchParams();
    if (flags.limit) params.set('limit', flags.limit);
    if (flags.cursor) params.set('cursor', flags.cursor);
    const qs = params.toString() ? `?${params}` : '';
    const result = await request('GET', `/api/v1/events${qs}`);
    console.log(JSON.stringify(result, null, 2));
  },

  async 'events get'(args) {
    const id = args.find(a => !a.startsWith('--'));
    if (!id) { console.error('Usage: jobcelis events get <id>'); process.exit(1); }
    const result = await request('GET', `/api/v1/events/${id}`);
    console.log(JSON.stringify(result, null, 2));
  },

  async 'webhooks list'(args) {
    const flags = parseFlags(args);
    const params = new URLSearchParams();
    if (flags.limit) params.set('limit', flags.limit);
    const qs = params.toString() ? `?${params}` : '';
    const result = await request('GET', `/api/v1/webhooks${qs}`);
    console.log(JSON.stringify(result, null, 2));
  },

  async 'webhooks create'(args) {
    const flags = parseFlags(args);
    if (!flags.url) {
      console.error('Usage: jobcelis webhooks create --url <url> [--topics "order.*,user.*"]');
      process.exit(1);
    }
    const body = { url: flags.url };
    if (flags.topics) body.topics = flags.topics.split(',');
    if (flags.secret) body.secret = flags.secret;
    const result = await request('POST', '/api/v1/webhooks', body);
    console.log(JSON.stringify(result, null, 2));
  },

  async 'webhooks get'(args) {
    const id = args.find(a => !a.startsWith('--'));
    if (!id) { console.error('Usage: jobcelis webhooks get <id>'); process.exit(1); }
    const result = await request('GET', `/api/v1/webhooks/${id}`);
    console.log(JSON.stringify(result, null, 2));
  },

  async 'deliveries list'(args) {
    const flags = parseFlags(args);
    const params = new URLSearchParams();
    if (flags.limit) params.set('limit', flags.limit);
    if (flags['event-id']) params.set('event_id', flags['event-id']);
    if (flags['webhook-id']) params.set('webhook_id', flags['webhook-id']);
    const qs = params.toString() ? `?${params}` : '';
    const result = await request('GET', `/api/v1/deliveries${qs}`);
    console.log(JSON.stringify(result, null, 2));
  },

  async 'dead-letters list'(args) {
    const flags = parseFlags(args);
    const params = new URLSearchParams();
    if (flags.limit) params.set('limit', flags.limit);
    const qs = params.toString() ? `?${params}` : '';
    const result = await request('GET', `/api/v1/dead-letters${qs}`);
    console.log(JSON.stringify(result, null, 2));
  },

  async 'status'() {
    const result = await fetch(`${BASE_URL}/health`).then(r => r.json());
    console.log(JSON.stringify(result, null, 2));
  },
};

function showHelp() {
  console.log(`
Jobcelis CLI — Event Infrastructure Platform

Usage: jobcelis <command> [options]

Commands:
  events send       Send an event (--topic, --payload)
  events list       List events (--limit, --cursor)
  events get <id>   Get event details
  webhooks list     List webhooks (--limit)
  webhooks create   Create a webhook (--url, --topics, --secret)
  webhooks get <id> Get webhook details
  deliveries list   List deliveries (--limit, --event-id, --webhook-id)
  dead-letters list List dead letters (--limit)
  status            Check platform health

Environment:
  JOBCELIS_API_KEY  Your API key (required for most commands)
  JOBCELIS_URL      Base URL (default: https://jobcelis.com)

Examples:
  jobcelis events send --topic order.created --payload '{"id":"123"}'
  jobcelis events list --limit 10
  jobcelis webhooks create --url https://example.com/hook --topics "order.*"
  jobcelis status
`);
}

async function main(argv) {
  if (argv.length === 0 || argv[0] === '--help' || argv[0] === '-h') {
    showHelp();
    return;
  }

  // Try two-word command first, then one-word
  const twoWord = `${argv[0]} ${argv[1]}`;
  const oneWord = argv[0];

  if (commands[twoWord]) {
    await commands[twoWord](argv.slice(2));
  } else if (commands[oneWord]) {
    await commands[oneWord](argv.slice(1));
  } else {
    console.error(`Unknown command: ${argv.join(' ')}`);
    showHelp();
    process.exit(1);
  }
}

module.exports = { main };
