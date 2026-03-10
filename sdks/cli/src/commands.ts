import * as fs from "fs";
import * as path from "path";
import * as api from "./api";

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

export async function eventsDelete(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis events delete <id>\n\nDelete an event by ID.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "event id");
  const result = await api.del(`/api/v1/events/${id}`);
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

export async function webhooksUpdate(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis webhooks update <id> [--url <url>] [--topics <t1,t2>]\n\n" +
        "Update a webhook subscription.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "webhook id");
  const body: Record<string, unknown> = {};
  const url = getFlag(args, "--url");
  const topicsRaw = getFlag(args, "--topics");
  if (url) body.url = url;
  if (topicsRaw) body.topics = topicsRaw.split(",").map((t) => t.trim());
  const result = await api.patch(`/api/v1/webhooks/${id}`, body);
  printJson(result);
}

export async function webhooksHealth(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis webhooks health <id>\n\nGet webhook health status.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "webhook id");
  const result = await api.get(`/api/v1/webhooks/${id}/health`);
  printJson(result);
}

export async function webhooksTemplates(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis webhooks templates\n\nList webhook templates.\n"
    );
    return;
  }
  const result = await api.get("/api/v1/webhooks/templates");
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

export async function jobsGet(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis jobs get <id>\n\nGet a scheduled job by ID.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "job id");
  const result = await api.get(`/api/v1/jobs/${id}`);
  printJson(result);
}

export async function jobsUpdate(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis jobs update <id> [--name <n>] [--cron <expr>]\n\n" +
        "Update a scheduled job.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "job id");
  const body: Record<string, string> = {};
  const name = getFlag(args, "--name");
  const cron = getFlag(args, "--cron");
  if (name) body.name = name;
  if (cron) body.cron = cron;
  const result = await api.patch(`/api/v1/jobs/${id}`, body);
  printJson(result);
}

export async function jobsRuns(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis jobs runs <id> [--limit N]\n\nList runs for a job.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "job id");
  const params: Record<string, string> = {};
  const limit = getFlag(args, "--limit");
  if (limit) params.limit = limit;
  const result = await api.get(`/api/v1/jobs/${id}/runs`, params);
  printJson(result);
}

export async function jobsCronPreview(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis jobs cron-preview --cron <expr> [--count N]\n\n" +
        "Preview upcoming cron schedule times.\n"
    );
    return;
  }
  const cron = requireFlag(args, "--cron", "cron expression");
  const params: Record<string, string> = { cron };
  const count = getFlag(args, "--count");
  if (count) params.count = count;
  const result = await api.get("/api/v1/jobs/cron-preview", params);
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

export async function pipelinesGet(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis pipelines get <id>\n\nGet a pipeline by ID.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "pipeline id");
  const result = await api.get(`/api/v1/pipelines/${id}`);
  printJson(result);
}

export async function pipelinesUpdate(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis pipelines update <id> [--name <n>]\n\n" +
        "Update a pipeline.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "pipeline id");
  const body: Record<string, string> = {};
  const name = getFlag(args, "--name");
  if (name) body.name = name;
  const result = await api.patch(`/api/v1/pipelines/${id}`, body);
  printJson(result);
}

export async function pipelinesDelete(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis pipelines delete <id>\n\nDelete a pipeline.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "pipeline id");
  const result = await api.del(`/api/v1/pipelines/${id}`);
  printJson(result);
}

export async function pipelinesTest(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis pipelines test <id> --payload '<json>'\n\n" +
        "Test a pipeline with a sample payload.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "pipeline id");
  const payload = requireFlag(args, "--payload", "json");
  let parsed: unknown;
  try {
    parsed = JSON.parse(payload);
  } catch {
    process.stderr.write("Error: --payload must be valid JSON.\n");
    process.exit(1);
  }
  const result = await api.post(`/api/v1/pipelines/${id}/test`, { payload: parsed });
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

export async function deadLettersGet(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis dead-letters get <id>\n\nGet a dead-letter entry by ID.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "dead-letter id");
  const result = await api.get(`/api/v1/dead-letters/${id}`);
  printJson(result);
}

export async function deadLettersResolve(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis dead-letters resolve <id>\n\nResolve a dead-letter entry.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "dead-letter id");
  const result = await api.patch(`/api/v1/dead-letters/${id}/resolve`);
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

export async function replaysGet(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis replays get <id>\n\nGet a replay by ID.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "replay id");
  const result = await api.get(`/api/v1/replays/${id}`);
  printJson(result);
}

export async function replaysCancel(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis replays cancel <id>\n\nCancel a replay.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "replay id");
  const result = await api.del(`/api/v1/replays/${id}`);
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

export async function schemasCreate(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis schemas create --topic <t> --schema '<json>'\n\n" +
        "Create an event schema.\n"
    );
    return;
  }
  const topic = requireFlag(args, "--topic", "topic");
  const schemaRaw = requireFlag(args, "--schema", "json");
  let schema: unknown;
  try {
    schema = JSON.parse(schemaRaw);
  } catch {
    process.stderr.write("Error: --schema must be valid JSON.\n");
    process.exit(1);
  }
  const result = await api.post("/api/v1/event-schemas", { topic, schema });
  printJson(result);
}

export async function schemasGet(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis schemas get <id>\n\nGet an event schema by ID.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "schema id");
  const result = await api.get(`/api/v1/event-schemas/${id}`);
  printJson(result);
}

export async function schemasUpdate(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis schemas update <id> --schema '<json>'\n\n" +
        "Update an event schema.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "schema id");
  const schemaRaw = requireFlag(args, "--schema", "json");
  let schema: unknown;
  try {
    schema = JSON.parse(schemaRaw);
  } catch {
    process.stderr.write("Error: --schema must be valid JSON.\n");
    process.exit(1);
  }
  const result = await api.patch(`/api/v1/event-schemas/${id}`, { schema });
  printJson(result);
}

export async function schemasDelete(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis schemas delete <id>\n\nDelete an event schema.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "schema id");
  const result = await api.del(`/api/v1/event-schemas/${id}`);
  printJson(result);
}

export async function schemasValidate(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis schemas validate --topic <t> --payload '<json>'\n\n" +
        "Validate a payload against a schema.\n"
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
  const result = await api.post("/api/v1/event-schemas/validate", { topic, payload: parsed });
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

export async function sandboxDelete(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis sandbox delete <id>\n\nDelete a sandbox endpoint.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "sandbox endpoint id");
  const result = await api.del(`/api/v1/sandbox-endpoints/${id}`);
  printJson(result);
}

export async function sandboxRequests(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis sandbox requests <id> [--limit N]\n\n" +
        "List requests received by a sandbox endpoint.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "sandbox endpoint id");
  const params: Record<string, string> = {};
  const limit = getFlag(args, "--limit");
  if (limit) params.limit = limit;
  const result = await api.get(`/api/v1/sandbox-endpoints/${id}/requests`, params);
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

export async function analyticsDeliveries(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis analytics deliveries [--days N]\n\n" +
        "Get deliveries-per-day analytics.\n"
    );
    return;
  }
  const params: Record<string, string> = {};
  const days = getFlag(args, "--days");
  if (days) params.days = days;
  const result = await api.get("/api/v1/analytics/deliveries-per-day", params);
  printJson(result);
}

export async function analyticsWebhookStats(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis analytics webhook-stats\n\n" +
        "Get webhook statistics.\n"
    );
    return;
  }
  const result = await api.get("/api/v1/analytics/webhook-stats");
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

export async function exportJobs(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis export jobs\n\nExport all jobs to a file.\n"
    );
    return;
  }
  const result = await api.get("/api/v1/export/jobs");
  const filename = `jobs-export-${new Date().toISOString().slice(0, 10)}.json`;
  fs.writeFileSync(filename, JSON.stringify(result, null, 2), "utf-8");
  process.stdout.write(`Exported jobs to ${filename}\n`);
}

export async function exportAuditLog(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis export audit-log\n\nExport audit log to a file.\n"
    );
    return;
  }
  const result = await api.get("/api/v1/export/audit-log");
  const filename = `audit-log-export-${new Date().toISOString().slice(0, 10)}.json`;
  fs.writeFileSync(filename, JSON.stringify(result, null, 2), "utf-8");
  process.stdout.write(`Exported audit log to ${filename}\n`);
}

// ---------------------------------------------------------------------------
// Audit
// ---------------------------------------------------------------------------

export async function auditList(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis audit list [--limit N]\n\nList audit log entries.\n"
    );
    return;
  }
  const params: Record<string, string> = {};
  const limit = getFlag(args, "--limit");
  if (limit) params.limit = limit;
  const result = await api.get("/api/v1/audit-log", params);
  printJson(result);
}

// ---------------------------------------------------------------------------
// Project (current)
// ---------------------------------------------------------------------------

export async function projectGet(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis project get\n\nGet current project details.\n"
    );
    return;
  }
  const result = await api.get("/api/v1/project");
  printJson(result);
}

export async function projectUpdate(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis project update --name <n>\n\nUpdate current project.\n"
    );
    return;
  }
  const name = requireFlag(args, "--name", "name");
  const result = await api.patch("/api/v1/project", { name });
  printJson(result);
}

export async function projectTopics(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis project topics\n\nList topics for the current project.\n"
    );
    return;
  }
  const result = await api.get("/api/v1/topics");
  printJson(result);
}

export async function projectToken(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis project token\n\nGet current API token info.\n"
    );
    return;
  }
  const result = await api.get("/api/v1/token");
  printJson(result);
}

export async function projectRegenerateToken(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis project regenerate-token\n\nRegenerate the API token.\n"
    );
    return;
  }
  const result = await api.post("/api/v1/token/regenerate");
  printJson(result);
}

// ---------------------------------------------------------------------------
// Projects (multi)
// ---------------------------------------------------------------------------

export async function projectsList(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis projects list\n\nList all projects.\n"
    );
    return;
  }
  const result = await api.get("/api/v1/projects");
  printJson(result);
}

export async function projectsCreate(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis projects create --name <n>\n\nCreate a new project.\n"
    );
    return;
  }
  const name = requireFlag(args, "--name", "name");
  const result = await api.post("/api/v1/projects", { name });
  printJson(result);
}

export async function projectsGet(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis projects get <id>\n\nGet a project by ID.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "project id");
  const result = await api.get(`/api/v1/projects/${id}`);
  printJson(result);
}

export async function projectsUpdate(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis projects update <id> --name <n>\n\nUpdate a project.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "project id");
  const name = requireFlag(args, "--name", "name");
  const result = await api.patch(`/api/v1/projects/${id}`, { name });
  printJson(result);
}

export async function projectsDelete(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis projects delete <id>\n\nDelete a project.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "project id");
  const result = await api.del(`/api/v1/projects/${id}`);
  printJson(result);
}

export async function projectsSetDefault(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis projects set-default <id>\n\nSet a project as default.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "project id");
  const result = await api.patch(`/api/v1/projects/${id}/default`);
  printJson(result);
}

// ---------------------------------------------------------------------------
// Team Members
// ---------------------------------------------------------------------------

export async function membersList(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis members list --project <id>\n\nList project members.\n"
    );
    return;
  }
  const projectId = requireFlag(args, "--project", "project id");
  const result = await api.get(`/api/v1/projects/${projectId}/members`);
  printJson(result);
}

export async function membersAdd(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis members add --project <id> --email <e> [--role <r>]\n\n" +
        "Add a member to a project.\n"
    );
    return;
  }
  const projectId = requireFlag(args, "--project", "project id");
  const email = requireFlag(args, "--email", "email");
  const body: Record<string, string> = { email };
  const role = getFlag(args, "--role");
  if (role) body.role = role;
  const result = await api.post(`/api/v1/projects/${projectId}/members`, body);
  printJson(result);
}

export async function membersUpdate(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis members update --project <id> <member_id> --role <r>\n\n" +
        "Update a member's role.\n"
    );
    return;
  }
  const projectId = requireFlag(args, "--project", "project id");
  const memberId = requirePositional(args, 0, "member id");
  const role = requireFlag(args, "--role", "role");
  const result = await api.patch(`/api/v1/projects/${projectId}/members/${memberId}`, { role });
  printJson(result);
}

export async function membersRemove(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis members remove --project <id> <member_id>\n\n" +
        "Remove a member from a project.\n"
    );
    return;
  }
  const projectId = requireFlag(args, "--project", "project id");
  const memberId = requirePositional(args, 0, "member id");
  const result = await api.del(`/api/v1/projects/${projectId}/members/${memberId}`);
  printJson(result);
}

// ---------------------------------------------------------------------------
// Invitations
// ---------------------------------------------------------------------------

export async function invitationsPending(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis invitations pending\n\nList pending invitations.\n"
    );
    return;
  }
  const result = await api.get("/api/v1/invitations/pending");
  printJson(result);
}

export async function invitationsAccept(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis invitations accept <id>\n\nAccept an invitation.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "invitation id");
  const result = await api.post(`/api/v1/invitations/${id}/accept`);
  printJson(result);
}

export async function invitationsReject(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis invitations reject <id>\n\nReject an invitation.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "invitation id");
  const result = await api.post(`/api/v1/invitations/${id}/reject`);
  printJson(result);
}

// ---------------------------------------------------------------------------
// Simulate
// ---------------------------------------------------------------------------

export async function simulate(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis simulate --topic <t> --payload '<json>'\n\n" +
        "Simulate an event delivery without persisting.\n"
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
  const result = await api.post("/api/v1/simulate", { topic, payload: parsed });
  printJson(result);
}

// ---------------------------------------------------------------------------
// Notification Channels
// ---------------------------------------------------------------------------

export async function channelsShow(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis channels show\n\nShow notification channel configuration.\n"
    );
    return;
  }
  const result = await api.get("/api/v1/notification-channels");
  printJson(result);
}

export async function channelsUpsert(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis channels upsert --config '<json>'\n\n" +
        "Create or update notification channel configuration.\n" +
        "Example: jobcelis channels upsert --config '{\"email_enabled\":true,\"email_address\":\"a@b.com\"}'\n"
    );
    return;
  }
  const config = requireFlag(args, "--config", "json");
  let parsed: unknown;
  try {
    parsed = JSON.parse(config);
  } catch {
    process.stderr.write("Error: --config must be valid JSON.\n");
    process.exit(1);
  }
  const result = await api.put("/api/v1/notification-channels", parsed);
  printJson(result);
}

export async function channelsDelete(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis channels delete\n\nDelete notification channel configuration.\n"
    );
    return;
  }
  const result = await api.del("/api/v1/notification-channels");
  printJson(result);
}

export async function channelsTest(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis channels test\n\nSend a test notification to all enabled channels.\n"
    );
    return;
  }
  const result = await api.post("/api/v1/notification-channels/test");
  printJson(result);
}

// ---------------------------------------------------------------------------
// GDPR
// ---------------------------------------------------------------------------

export async function gdprConsents(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis gdpr consents\n\nList your consent records.\n"
    );
    return;
  }
  const result = await api.get("/api/v1/me/consents");
  printJson(result);
}

export async function gdprAccept(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis gdpr accept <purpose>\n\nAccept a consent purpose.\n"
    );
    return;
  }
  const purpose = requirePositional(args, 0, "purpose");
  const result = await api.post(`/api/v1/me/consents/${purpose}/accept`);
  printJson(result);
}

export async function gdprExport(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis gdpr export\n\nExport your personal data.\n"
    );
    return;
  }
  const result = await api.get("/api/v1/me/data");
  printJson(result);
}

export async function gdprRestrict(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis gdpr restrict\n\nRequest restriction of processing.\n"
    );
    return;
  }
  const result = await api.post("/api/v1/me/restrict");
  printJson(result);
}

export async function gdprLiftRestriction(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis gdpr lift-restriction\n\nLift restriction of processing.\n"
    );
    return;
  }
  const result = await api.del("/api/v1/me/restrict");
  printJson(result);
}

export async function gdprObject(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis gdpr object\n\nObject to data processing.\n"
    );
    return;
  }
  const result = await api.post("/api/v1/me/object");
  printJson(result);
}

export async function gdprRestore(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis gdpr restore\n\nWithdraw objection to data processing.\n"
    );
    return;
  }
  const result = await api.del("/api/v1/me/object");
  printJson(result);
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

export async function authRegister(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis auth register --email <e> --password <p> [--name <n>]\n\n" +
        "Register a new account.\n"
    );
    return;
  }
  const email = requireFlag(args, "--email", "email");
  const password = requireFlag(args, "--password", "password");
  const body: Record<string, string> = { email, password };
  const name = getFlag(args, "--name");
  if (name) body.name = name;
  const result = await api.post("/api/v1/auth/register", body);
  printJson(result);
}

export async function authLogin(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis auth login --email <e> --password <p>\n\n" +
        "Log in and receive a token.\n"
    );
    return;
  }
  const email = requireFlag(args, "--email", "email");
  const password = requireFlag(args, "--password", "password");
  const result = await api.post("/api/v1/auth/login", { email, password });
  printJson(result);
}

export async function authRefresh(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis auth refresh --token <t>\n\nRefresh an auth token.\n"
    );
    return;
  }
  const token = requireFlag(args, "--token", "token");
  const result = await api.post("/api/v1/auth/refresh", { token });
  printJson(result);
}

export async function authMfaVerify(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis auth mfa-verify --token <t> --code <c>\n\n" +
        "Verify an MFA code.\n"
    );
    return;
  }
  const token = requireFlag(args, "--token", "token");
  const code = requireFlag(args, "--code", "code");
  const result = await api.post("/api/v1/auth/mfa/verify", { token, code });
  printJson(result);
}

// ---------------------------------------------------------------------------
// Embed Tokens
// ---------------------------------------------------------------------------

export async function embedTokensList(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis embed tokens-list\n\nList embed tokens.\n"
    );
    return;
  }
  const result = await api.get("/api/v1/embed/tokens");
  printJson((result as Record<string, unknown>).data ?? result);
}

export async function embedTokensCreate(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis embed tokens-create --name <n> --scopes <s1,s2>\n\n" +
        "Create an embed token.\n"
    );
    return;
  }
  const name = requireFlag(args, "--name", "name");
  const scopes = requireFlag(args, "--scopes", "scopes");
  const result = await api.post("/api/v1/embed/tokens", {
    name,
    scopes: scopes.split(","),
  });
  const r = result as Record<string, unknown>;
  if (r.token) {
    process.stdout.write(`Token: ${r.token}\n`);
  }
  printJson(r.data ?? result);
}

export async function embedTokensRevoke(args: string[]): Promise<void> {
  if (hasFlag(args, "--help")) {
    process.stdout.write(
      "Usage: jobcelis embed tokens-revoke <id>\n\nRevoke an embed token.\n"
    );
    return;
  }
  const id = requirePositional(args, 0, "token-id");
  const result = await api.del(`/api/v1/embed/tokens/${id}`);
  printJson(result);
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
