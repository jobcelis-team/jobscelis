#!/usr/bin/env node

import * as commands from "./commands";

const VERSION = "2.0.1";

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
    events delete <id>                                Delete event by ID
    events batch --file <path>                        Send batch from file

  Webhooks:
    webhooks list                                     List webhooks
    webhooks create --url <url> --topics <t1,t2>      Create webhook
    webhooks get <id>                                 Get webhook by ID
    webhooks update <id> [--url <u>] [--topics <t>]   Update webhook
    webhooks delete <id>                              Delete webhook
    webhooks health <id>                              Get webhook health
    webhooks templates                                List webhook templates

  Deliveries:
    deliveries list [--limit N]                       List deliveries
    deliveries retry <id>                             Retry a delivery

  Jobs:
    jobs list                                         List scheduled jobs
    jobs create --name <n> --queue <q> --cron <expr>  Create job
    jobs get <id>                                     Get job by ID
    jobs update <id> [--name <n>] [--cron <expr>]     Update job
    jobs delete <id>                                  Delete job
    jobs runs <id> [--limit N]                        List job runs
    jobs cron-preview --cron <expr> [--count N]       Preview cron schedule

  Pipelines:
    pipelines list                                    List pipelines
    pipelines create --name <n> --topics <t> --steps '<json>'
                                                      Create pipeline
    pipelines get <id>                                Get pipeline by ID
    pipelines update <id> [--name <n>]                Update pipeline
    pipelines delete <id>                             Delete pipeline
    pipelines test <id> --payload '<json>'            Test pipeline

  Dead Letters:
    dead-letters list                                 List dead-letter entries
    dead-letters get <id>                             Get dead-letter by ID
    dead-letters retry <id>                           Retry dead-letter
    dead-letters resolve <id>                         Resolve dead-letter

  Replays:
    replays list                                      List replays
    replays create --topic <t> --from <date> --to <date>
                                                      Create replay
    replays get <id>                                  Get replay by ID
    replays cancel <id>                               Cancel a replay

  Schemas:
    schemas list                                      List event schemas
    schemas create --topic <t> --schema '<json>'      Create schema
    schemas get <id>                                  Get schema by ID
    schemas update <id> --schema '<json>'             Update schema
    schemas delete <id>                               Delete schema
    schemas validate --topic <t> --payload '<json>'   Validate payload

  Sandbox:
    sandbox list                                      List sandbox endpoints
    sandbox create [--name <n>]                       Create sandbox endpoint
    sandbox delete <id>                               Delete sandbox endpoint
    sandbox requests <id> [--limit N]                 List endpoint requests

  Analytics:
    analytics events [--days N]                       Events per day
    analytics topics [--limit N]                      Top topics
    analytics deliveries [--days N]                   Deliveries per day
    analytics webhook-stats                           Webhook statistics

  Audit:
    audit list [--limit N]                            List audit log entries

  Export:
    export events                                     Export events to file
    export deliveries                                 Export deliveries to file
    export jobs                                       Export jobs to file
    export audit-log                                  Export audit log to file

  Project (current):
    project get                                       Get current project
    project update --name <n>                         Update current project
    project topics                                    List project topics
    project token                                     Get API token info
    project regenerate-token                          Regenerate API token

  Projects (multi):
    projects list                                     List all projects
    projects create --name <n>                        Create a project
    projects get <id>                                 Get project by ID
    projects update <id> --name <n>                   Update a project
    projects delete <id>                              Delete a project
    projects set-default <id>                         Set default project

  Team Members:
    members list --project <id>                       List project members
    members add --project <id> --email <e> [--role <r>]
                                                      Add member to project
    members update --project <id> <member_id> --role <r>
                                                      Update member role
    members remove --project <id> <member_id>         Remove member

  Invitations:
    invitations pending                               List pending invitations
    invitations accept <id>                           Accept invitation
    invitations reject <id>                           Reject invitation

  Notification Channels:
    channels show                                     Show channel configuration
    channels upsert --config '<json>'                 Create/update channels
    channels delete                                   Delete channel configuration
    channels test                                     Send test notification

  Simulate:
    simulate --topic <t> --payload '<json>'           Simulate event delivery

  GDPR:
    gdpr consents                                     List consent records
    gdpr accept <purpose>                             Accept consent purpose
    gdpr export                                       Export personal data
    gdpr restrict                                     Restrict processing
    gdpr lift-restriction                             Lift restriction
    gdpr object                                       Object to processing
    gdpr restore                                      Withdraw objection

  Auth:
    auth register --email <e> --password <p> [--name <n>]
                                                      Register account
    auth login --email <e> --password <p>             Log in
    auth refresh --token <t>                          Refresh token
    auth mfa-verify --token <t> --code <c>            Verify MFA code

  Other:
    status                                            Check platform health
    version                                           Show CLI version
    help                                              Show this help message

Examples:
  jobcelis events send --topic user.signup --payload '{"user_id":"123"}'
  jobcelis webhooks create --url https://example.com/hook --topics user.signup,order.created
  jobcelis deliveries list --limit 10
  jobcelis jobs runs 550e8400-... --limit 5
  jobcelis schemas validate --topic user.signup --payload '{"user_id":"abc"}'
  jobcelis projects list
  jobcelis gdpr export
  jobcelis auth login --email user@example.com --password secret
  jobcelis status
`.trim();

type CommandHandler = (args: string[]) => Promise<void>;

const COMMAND_MAP: Record<string, Record<string, CommandHandler>> = {
  events: {
    send: commands.eventsSend,
    list: commands.eventsList,
    get: commands.eventsGet,
    delete: commands.eventsDelete,
    batch: commands.eventsBatch,
  },
  webhooks: {
    list: commands.webhooksList,
    create: commands.webhooksCreate,
    get: commands.webhooksGet,
    update: commands.webhooksUpdate,
    delete: commands.webhooksDelete,
    health: commands.webhooksHealth,
    templates: commands.webhooksTemplates,
  },
  deliveries: {
    list: commands.deliveriesList,
    retry: commands.deliveriesRetry,
  },
  jobs: {
    list: commands.jobsList,
    create: commands.jobsCreate,
    get: commands.jobsGet,
    update: commands.jobsUpdate,
    delete: commands.jobsDelete,
    runs: commands.jobsRuns,
    "cron-preview": commands.jobsCronPreview,
  },
  pipelines: {
    list: commands.pipelinesList,
    create: commands.pipelinesCreate,
    get: commands.pipelinesGet,
    update: commands.pipelinesUpdate,
    delete: commands.pipelinesDelete,
    test: commands.pipelinesTest,
  },
  "dead-letters": {
    list: commands.deadLettersList,
    get: commands.deadLettersGet,
    retry: commands.deadLettersRetry,
    resolve: commands.deadLettersResolve,
  },
  replays: {
    list: commands.replaysList,
    create: commands.replaysCreate,
    get: commands.replaysGet,
    cancel: commands.replaysCancel,
  },
  schemas: {
    list: commands.schemasList,
    create: commands.schemasCreate,
    get: commands.schemasGet,
    update: commands.schemasUpdate,
    delete: commands.schemasDelete,
    validate: commands.schemasValidate,
  },
  sandbox: {
    list: commands.sandboxList,
    create: commands.sandboxCreate,
    delete: commands.sandboxDelete,
    requests: commands.sandboxRequests,
  },
  analytics: {
    events: commands.analyticsEvents,
    topics: commands.analyticsTopics,
    deliveries: commands.analyticsDeliveries,
    "webhook-stats": commands.analyticsWebhookStats,
  },
  audit: {
    list: commands.auditList,
  },
  export: {
    events: commands.exportEvents,
    deliveries: commands.exportDeliveries,
    jobs: commands.exportJobs,
    "audit-log": commands.exportAuditLog,
  },
  project: {
    get: commands.projectGet,
    update: commands.projectUpdate,
    topics: commands.projectTopics,
    token: commands.projectToken,
    "regenerate-token": commands.projectRegenerateToken,
  },
  projects: {
    list: commands.projectsList,
    create: commands.projectsCreate,
    get: commands.projectsGet,
    update: commands.projectsUpdate,
    delete: commands.projectsDelete,
    "set-default": commands.projectsSetDefault,
  },
  members: {
    list: commands.membersList,
    add: commands.membersAdd,
    update: commands.membersUpdate,
    remove: commands.membersRemove,
  },
  invitations: {
    pending: commands.invitationsPending,
    accept: commands.invitationsAccept,
    reject: commands.invitationsReject,
  },
  channels: {
    show: commands.channelsShow,
    upsert: commands.channelsUpsert,
    delete: commands.channelsDelete,
    test: commands.channelsTest,
  },
  gdpr: {
    consents: commands.gdprConsents,
    accept: commands.gdprAccept,
    export: commands.gdprExport,
    restrict: commands.gdprRestrict,
    "lift-restriction": commands.gdprLiftRestriction,
    object: commands.gdprObject,
    restore: commands.gdprRestore,
  },
  auth: {
    register: commands.authRegister,
    login: commands.authLogin,
    refresh: commands.authRefresh,
    "mfa-verify": commands.authMfaVerify,
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

  if (args[0] === "simulate") {
    await commands.simulate(args.slice(1));
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
