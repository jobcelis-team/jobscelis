#!/usr/bin/env node

import * as commands from "./commands";

const VERSION = "1.0.0";

const HELP_TEXT = `
jobcelis - CLI for the Jobcelis Event Infrastructure Platform (v${VERSION})

Usage: jobcelis <resource> <action> [options]

Configuration:
  JOBCELIS_API_KEY     API key (required)
  JOBCELIS_BASE_URL    Base URL (default: https://jobcelis.com)

Commands:

  Events:
    events send --topic <topic> --payload '<json>'    Send an event
    events list [--limit N] [--cursor C]              List events
    events get <id>                                   Get event by ID
    events batch --file <path>                        Send batch from file

  Webhooks:
    webhooks list                                     List webhooks
    webhooks create --url <url> --topics <t1,t2>      Create webhook
    webhooks get <id>                                 Get webhook by ID
    webhooks delete <id>                              Delete webhook

  Deliveries:
    deliveries list [--limit N]                       List deliveries
    deliveries retry <id>                             Retry a delivery

  Jobs:
    jobs list                                         List scheduled jobs
    jobs create --name <n> --queue <q> --cron <expr>  Create job
    jobs delete <id>                                  Delete job

  Pipelines:
    pipelines list                                    List pipelines
    pipelines create --name <n> --topics <t1,t2> --steps '<json>'
                                                      Create pipeline

  Dead Letters:
    dead-letters list                                 List dead-letter entries
    dead-letters retry <id>                           Retry dead-letter

  Replays:
    replays list                                      List replays
    replays create --topic <t> --from <date> --to <date>
                                                      Create replay

  Schemas:
    schemas list                                      List event schemas

  Sandbox:
    sandbox list                                      List sandbox endpoints
    sandbox create [--name <n>]                       Create sandbox endpoint

  Analytics:
    analytics events [--days N]                       Events per day
    analytics topics [--limit N]                      Top topics

  Export:
    export events                                     Export events to file
    export deliveries                                 Export deliveries to file

  Other:
    status                                            Check platform health
    version                                           Show CLI version
    help                                              Show this help message

Examples:
  jobcelis events send --topic user.signup --payload '{"user_id":"123"}'
  jobcelis webhooks create --url https://example.com/hook --topics user.signup,order.created
  jobcelis deliveries list --limit 10
  jobcelis status
`.trim();

type CommandHandler = (args: string[]) => Promise<void>;

const COMMAND_MAP: Record<string, Record<string, CommandHandler>> = {
  events: {
    send: commands.eventsSend,
    list: commands.eventsList,
    get: commands.eventsGet,
    batch: commands.eventsBatch,
  },
  webhooks: {
    list: commands.webhooksList,
    create: commands.webhooksCreate,
    get: commands.webhooksGet,
    delete: commands.webhooksDelete,
  },
  deliveries: {
    list: commands.deliveriesList,
    retry: commands.deliveriesRetry,
  },
  jobs: {
    list: commands.jobsList,
    create: commands.jobsCreate,
    delete: commands.jobsDelete,
  },
  pipelines: {
    list: commands.pipelinesList,
    create: commands.pipelinesCreate,
  },
  "dead-letters": {
    list: commands.deadLettersList,
    retry: commands.deadLettersRetry,
  },
  replays: {
    list: commands.replaysList,
    create: commands.replaysCreate,
  },
  schemas: {
    list: commands.schemasList,
  },
  sandbox: {
    list: commands.sandboxList,
    create: commands.sandboxCreate,
  },
  analytics: {
    events: commands.analyticsEvents,
    topics: commands.analyticsTopics,
  },
  export: {
    events: commands.exportEvents,
    deliveries: commands.exportDeliveries,
  },
};

async function main(): Promise<void> {
  const args = process.argv.slice(2);

  if (args.length === 0 || args[0] === "help" || args[0] === "--help") {
    process.stdout.write(HELP_TEXT + "\n");
    return;
  }

  if (args[0] === "version" || args[0] === "--version") {
    process.stdout.write(`jobcelis v${VERSION}\n`);
    return;
  }

  if (args[0] === "status") {
    await commands.status(args.slice(1));
    return;
  }

  const resource = args[0];
  const action = args[1];

  if (!action || action === "--help") {
    const group = COMMAND_MAP[resource];
    if (group) {
      process.stdout.write(`Available ${resource} commands:\n`);
      for (const cmd of Object.keys(group)) {
        process.stdout.write(`  jobcelis ${resource} ${cmd}\n`);
      }
      process.stdout.write(`\nRun 'jobcelis ${resource} <command> --help' for details.\n`);
      return;
    }
    process.stderr.write(`Unknown command: ${resource}\n`);
    process.stderr.write("Run 'jobcelis help' for available commands.\n");
    process.exit(1);
  }

  const group = COMMAND_MAP[resource];
  if (!group) {
    process.stderr.write(`Unknown resource: ${resource}\n`);
    process.stderr.write("Run 'jobcelis help' for available commands.\n");
    process.exit(1);
  }

  const handler = group[action];
  if (!handler) {
    process.stderr.write(`Unknown command: ${resource} ${action}\n`);
    process.stderr.write(`Run 'jobcelis ${resource} --help' for available commands.\n`);
    process.exit(1);
  }

  await handler(args.slice(2));
}

main().catch((err: Error) => {
  process.stderr.write(`Error: ${err.message}\n`);
  process.exit(1);
});
