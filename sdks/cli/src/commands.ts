import * as fs from "node:fs";
import * as path from "node:path";
import * as api from "./api.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function getFlag(args: string[], flag: string): string | undefined {
  const idx = args.indexOf(flag);
  if (idx === -1 || idx + 1 >= args.length) return undefined;
  return args[idx + 1];
}

function requireFlag(args: string[], flag: string, description: string): string {
  const value = getFlag(args, flag);
  if (!value) {
    process.stderr.write(`Error: ${flag} <${description}> is required.\n`);
    process.exit(1);
  }
  return value;
}

function getPositional(args: string[], position: number): string | undefined {
  const positionals = args.filter((a) => !a.startsWith("--"));
  return positionals[position];
}

function requirePositional(
  args: string[],
  position: number,
  description: string
): string {
  const value = getPositional(args, position);
  if (!value) {
    process.stderr.write(`Error: <${description}> argument is required.\n`);
    process.exit(1);
  }
  return value;
}

function printJson(data: unknown): void {
  process.stdout.write(JSON.stringify(data, null, 2) + "\n");
}

function hasFlag(args: string[], flag: string): boolean {
  return args.includes(flag);
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

export async function eventsSend(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis events send --topic <topic> --payload '<json>'\n\n" +
        "Send a single event to the platform.\n"
    );
    return;
  }
  const topic = requireFlag(args, "--topic", "topic");
  const payload = requireFlag(args, "--payload", "json");
  let parsed: unknown;
  try {
    parsed = JSON.parse(payload);
  } catch {
    process.stderr.write("Error: --payload must be valid JSON.\n");
    process.exit(1);
  }
  const result = await api.post("/api/v1/events", { topic, payload: parsed });
  printJson(result);
}

export async function eventsList(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis events list [--limit N] [--cursor C]\n\n" +
        "List events with optional pagination.\n"
    );
    return;
  }
  const params: Record<string, string> = {};
  const limit = getFlag(args, "--limit");
  const cursor = getFlag(args, "--cursor");
  if (limit) params.limit = limit;
  if (cursor) params.cursor = cursor;
  const result = await api.get("/api/v1/events", params);
  printJson(result);
}

export async function eventsGet(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis events get <id>\n\nGet a single event by ID.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "event id");
  const result = await api.get(`/api/v1/events/${id}`);
  printJson(result);
}

export async function eventsBatch(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis events batch --file <path>\n\n" +
        "Send a batch of events from a JSON file (array of event objects).\n"
    );
    return;
  }
  const filePath = requireFlag(args, "--file", "path");
  const resolved = path.resolve(filePath);
  if (!fs.existsSync(resolved)) {
    process.stderr.write(`Error: file not found: ${resolved}\n`);
    process.exit(1);
  }
  const content = fs.readFileSync(resolved, "utf-8");
  let events: unknown;
  try {
    events = JSON.parse(content);
  } catch {
    process.stderr.write("Error: file must contain valid JSON.\n");
    process.exit(1);
  }
  if (!Array.isArray(events)) {
    process.stderr.write("Error: file must contain a JSON array of events.\n");
    process.exit(1);
  }
  const result = await api.post("/api/v1/events/batch", { events });
  printJson(result);
}

// ---------------------------------------------------------------------------
// Webhooks
// ---------------------------------------------------------------------------

export async function webhooksList(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write("Usage: jobcelis webhooks list\n\nList all webhooks.\n");
    return;
  }
  const result = await api.get("/api/v1/webhooks");
  printJson(result);
}

export async function webhooksCreate(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis webhooks create --url <url> --topics <t1,t2>\n\n" +
        "Create a new webhook subscription.\n"
    );
    return;
  }
  const url = requireFlag(args, "--url", "url");
  const topicsRaw = requireFlag(args, "--topics", "topics");
  const topics = topicsRaw.split(",").map((t) => t.trim());
  const result = await api.post("/api/v1/webhooks", { url, topics });
  printJson(result);
}

export async function webhooksGet(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis webhooks get <id>\n\nGet a webhook by ID.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "webhook id");
  const result = await api.get(`/api/v1/webhooks/${id}`);
  printJson(result);
}

export async function webhooksDelete(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis webhooks delete <id>\n\nDelete a webhook by ID.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "webhook id");
  const result = await api.del(`/api/v1/webhooks/${id}`);
  printJson(result);
}

// ---------------------------------------------------------------------------
// Deliveries
// ---------------------------------------------------------------------------

export async function deliveriesList(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis deliveries list [--limit N]\n\nList deliveries.\n"
    );
    return;
  }
  const params: Record<string, string> = {};
  const limit = getFlag(args, "--limit");
  if (limit) params.limit = limit;
  const result = await api.get("/api/v1/deliveries", params);
  printJson(result);
}

export async function deliveriesRetry(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis deliveries retry <id>\n\nRetry a failed delivery.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "delivery id");
  const result = await api.post(`/api/v1/deliveries/${id}/retry`);
  printJson(result);
}

// ---------------------------------------------------------------------------
// Jobs
// ---------------------------------------------------------------------------

export async function jobsList(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write("Usage: jobcelis jobs list\n\nList scheduled jobs.\n");
    return;
  }
  const result = await api.get("/api/v1/jobs");
  printJson(result);
}

export async function jobsCreate(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis jobs create --name <n> --queue <q> --cron <expr>\n\n" +
        "Create a scheduled job.\n"
    );
    return;
  }
  const name = requireFlag(args, "--name", "name");
  const queue = requireFlag(args, "--queue", "queue");
  const cron = requireFlag(args, "--cron", "cron expression");
  const result = await api.post("/api/v1/jobs", { name, queue, cron });
  printJson(result);
}

export async function jobsDelete(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis jobs delete <id>\n\nDelete a scheduled job.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "job id");
  const result = await api.del(`/api/v1/jobs/${id}`);
  printJson(result);
}

// ---------------------------------------------------------------------------
// Pipelines
// ---------------------------------------------------------------------------

export async function pipelinesList(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis pipelines list\n\nList transformation pipelines.\n"
    );
    return;
  }
  const result = await api.get("/api/v1/pipelines");
  printJson(result);
}

export async function pipelinesCreate(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis pipelines create --name <n> --topics <t1,t2> --steps '<json>'\n\n" +
        "Create a transformation pipeline.\n"
    );
    return;
  }
  const name = requireFlag(args, "--name", "name");
  const topicsRaw = requireFlag(args, "--topics", "topics");
  const topics = topicsRaw.split(",").map((t) => t.trim());
  const stepsRaw = requireFlag(args, "--steps", "steps json");
  let steps: unknown;
  try {
    steps = JSON.parse(stepsRaw);
  } catch {
    process.stderr.write("Error: --steps must be valid JSON.\n");
    process.exit(1);
  }
  const result = await api.post("/api/v1/pipelines", { name, topics, steps });
  printJson(result);
}

// ---------------------------------------------------------------------------
// Dead Letters
// ---------------------------------------------------------------------------

export async function deadLettersList(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis dead-letters list\n\nList dead-letter queue entries.\n"
    );
    return;
  }
  const result = await api.get("/api/v1/dead-letters");
  printJson(result);
}

export async function deadLettersRetry(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis dead-letters retry <id>\n\nRetry a dead-letter entry.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "dead-letter id");
  const result = await api.post(`/api/v1/dead-letters/${id}/retry`);
  printJson(result);
}

// ---------------------------------------------------------------------------
// Replays
// ---------------------------------------------------------------------------

export async function replaysList(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write("Usage: jobcelis replays list\n\nList event replays.\n");
    return;
  }
  const result = await api.get("/api/v1/replays");
  printJson(result);
}

export async function replaysCreate(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis replays create --topic <t> --from <date> --to <date>\n\n" +
        "Create an event replay.\n"
    );
    return;
  }
  const topic = requireFlag(args, "--topic", "topic");
  const from = requireFlag(args, "--from", "start date");
  const to = requireFlag(args, "--to", "end date");
  const result = await api.post("/api/v1/replays", { topic, from, to });
  printJson(result);
}

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

export async function schemasList(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis schemas list\n\nList event schemas.\n"
    );
    return;
  }
  const result = await api.get("/api/v1/event-schemas");
  printJson(result);
}

// ---------------------------------------------------------------------------
// Sandbox
// ---------------------------------------------------------------------------

export async function sandboxList(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis sandbox list\n\nList sandbox endpoints.\n"
    );
    return;
  }
  const result = await api.get("/api/v1/sandbox-endpoints");
  printJson(result);
}

export async function sandboxCreate(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis sandbox create [--name <n>]\n\nCreate a sandbox endpoint.\n"
    );
    return;
  }
  const body: Record<string, string> = {};
  const name = getFlag(args, "--name");
  if (name) body.name = name;
  const result = await api.post("/api/v1/sandbox-endpoints", body);
  printJson(result);
}

// ---------------------------------------------------------------------------
// Analytics
// ---------------------------------------------------------------------------

export async function analyticsEvents(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis analytics events [--days N]\n\n" +
        "Get events-per-day analytics.\n"
    );
    return;
  }
  const params: Record<string, string> = {};
  const days = getFlag(args, "--days");
  if (days) params.days = days;
  const result = await api.get("/api/v1/analytics/events-per-day", params);
  printJson(result);
}

export async function analyticsTopics(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis analytics topics [--limit N]\n\n" +
        "Get top topics analytics.\n"
    );
    return;
  }
  const params: Record<string, string> = {};
  const limit = getFlag(args, "--limit");
  if (limit) params.limit = limit;
  const result = await api.get("/api/v1/analytics/top-topics", params);
  printJson(result);
}

// ---------------------------------------------------------------------------
// Export
// ---------------------------------------------------------------------------

export async function exportEvents(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis export events\n\nExport all events to a file.\n"
    );
    return;
  }
  const result = await api.get("/api/v1/export/events");
  const filename = `events-export-${new Date().toISOString().slice(0, 10)}.json`;
  fs.writeFileSync(filename, JSON.stringify(result, null, 2), "utf-8");
  process.stdout.write(`Exported events to ${filename}\n`);
}

export async function exportDeliveries(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis export deliveries\n\nExport all deliveries to a file.\n"
    );
    return;
  }
  const result = await api.get("/api/v1/export/deliveries");
  const filename = `deliveries-export-${new Date().toISOString().slice(0, 10)}.json`;
  fs.writeFileSync(filename, JSON.stringify(result, null, 2), "utf-8");
  process.stdout.write(`Exported deliveries to ${filename}\n`);
}

// ---------------------------------------------------------------------------
// Status
// ---------------------------------------------------------------------------

export async function status(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis status\n\nCheck platform health status.\n"
    );
    return;
  }
  const result = await api.get("/health");
  printJson(result);
}
