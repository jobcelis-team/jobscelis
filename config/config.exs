# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# having a single place to configure them.
import Config

# ============================================
# STREAMFLIX GLOBAL CONFIGURATION
# ============================================

# ============================================
# STREAMFLIX_CORE CONFIG
# ============================================

config :streamflix_core,
  ecto_repos: [StreamflixCore.Repo],
  generators: [timestamp_type: :utc_datetime]

config :streamflix_core, StreamflixCore.Repo,
  migration_primary_key: [type: :binary_id],
  migration_foreign_key: [type: :binary_id]

# ============================================
# STREAMFLIX_WEB CONFIG
# ============================================

config :streamflix_web, StreamflixWebWeb.Gettext, default_locale: "en"

# Session timeout: 30 minutes of inactivity
config :streamflix_web, :session_timeout_seconds, 1800

# Legal entity and branding
config :streamflix_web, :legal,
  product_name: "Jobcelis",
  owner: "Vladimir Celi",
  contact_url: "https://github.com/vladimirCeli",
  profile_url: "https://vladimirceli.github.io/perfil/",
  contact_email: "vladimir.celi@proton.me",
  # Optional donation links (override via env DONATION_*_URL in production)
  donation_paypal_url: "",
  donation_payoneer_url: "",
  donation_payphone_url: "https://ppls.me/A72iyEwG1gOY5d4TKYfEg"

config :streamflix_web, StreamflixWebWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: StreamflixWebWeb.ErrorHTML, json: StreamflixWebWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: StreamflixCore.PubSub,
  live_view: [signing_salt: "change_this_in_runtime"]

# ============================================
# MAILER CONFIG (Resend API)
# API key configured in runtime.exs
# ============================================

config :streamflix_web, StreamflixWebWeb.Mailer,
  from_email: "noreply@jobcelis.com",
  from_name: "Jobcelis"

# ============================================
# STREAMFLIX_ACCOUNTS CONFIG (Guardian + Password Hashing)
# Secrets configured in runtime.exs
# ============================================

# Revoked sessions: the web app disconnects their live LiveView sockets
config :streamflix_accounts,
  on_sessions_revoked: {StreamflixWebWeb.SessionRevocation, :disconnect}

config :streamflix_accounts, StreamflixAccounts.Guardian,
  issuer: "streamflix",
  secret_key: "configured_in_runtime",
  ttl: {7, :days}

# Argon2id — OWASP #1 recommendation, memory-hard (RFC 9106)
# Default config: t_cost=3, m_cost=16 (64 MiB), parallelism=4, argon2_type=2 (Argon2id)

# ============================================
# CLOAK VAULT CONFIG (At-Rest Encryption)
# Default dev key below; production key in runtime.exs via CLOAK_KEY env var
# ============================================

config :streamflix_core, StreamflixCore.Vault,
  ciphers: [
    default: {
      Cloak.Ciphers.AES.GCM,
      tag: "AES.GCM.V1",
      key: Base.decode64!("aTAO0zb80FzEJB4HnBnhhqEmFd0CJXWdKZBwlGMMT0c="),
      iv_length: 12
    }
  ]

config :streamflix_core, StreamflixCore.Hashed.HMAC,
  algorithm: :sha512,
  secret: "dev_hmac_secret_change_in_production_at_least_32_chars"

# ============================================
# LOGGER CONFIG
# ============================================

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [
    :request_id,
    :user_id,
    :content_id,
    :method,
    :path,
    :worker,
    :delivery_id,
    :webhook_id,
    :event_id,
    :project_id,
    :replay_id,
    :job_id,
    :status,
    :error,
    :url,
    :duration_ms,
    :size_bytes,
    :file,
    :attempts,
    :items_count,
    :anomaly_count,
    :anomalies,
    :severity,
    :backups_deleted,
    :deliveries_purged,
    :events_purged,
    :job_runs_purged,
    :sandbox_endpoints_purged,
    :sandbox_requests_purged,
    :dead_letters_purged,
    :processed_events,
    :total_events,
    :age_hours,
    :storage,
    :threshold_hours,
    :channel_id,
    :event_type,
    :errors,
    :keys_cleared,
    :deleted_count,
    :type,
    :older_than
  ]

# ============================================
# QUOTAS AND LIMITS (abuse protection; change here, no code changes needed)
# ============================================

config :streamflix_core, :quotas,
  webhooks_per_project: 50,
  jobs_per_project: 50,
  pipelines_per_project: 50,
  sandbox_endpoints_per_project: 20,
  embed_tokens_per_project: 50,
  event_schemas_per_project: 100,
  projects_per_user: 10

config :streamflix_core,
  # Max events in one POST /api/v1/events/batch (documented as 1000; every item
  # counts against the project's events/minute limit)
  max_event_batch_size: 1000,
  # Captured requests kept per sandbox endpoint and stored body size
  sandbox_max_requests_per_endpoint: 100,
  sandbox_max_stored_body_bytes: 64_000,
  # Event schema JSON size limit
  max_event_schema_bytes: 64_000

config :streamflix_web, :sse,
  # Max lifetime of one SSE stream; clients reconnect after it
  max_lifetime_ms: 3_600_000,
  # Keepalive interval; the API key is re-validated on every keepalive
  keepalive_ms: 30_000,
  # Concurrent SSE streams per project
  max_connections_per_project: 10

# ============================================
# PROM_EX CONFIG (Prometheus Metrics)
# ============================================

config :streamflix_web, StreamflixWeb.PromEx,
  disabled: false,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: [port: 4021, path: "/metrics"]

# ============================================
# PHOENIX CONFIG
# ============================================

config :phoenix, :json_library, Jason

# ============================================
# AZURE BLOB STORAGE (Backups)
# ============================================

config :streamflix_core, :azure_storage,
  account: nil,
  key: nil,
  container_backups: "backups"

# ============================================
# BACKUP CONFIG (pg_dump automated backups)
# ============================================

config :streamflix_core, :backup,
  enabled: true,
  backup_path: Path.expand("../priv/backups", __DIR__),
  retention_days: 30,
  pg_dump_path: "pg_dump"

# ============================================
# OBAN CONFIG (Background Jobs) - estilo whisper_vtt
# Colas: delivery (POST a webhooks), scheduled_job (jobs programados)
# ============================================

config :streamflix_core, Oban,
  engine: Oban.Engines.Basic,
  repo: StreamflixCore.Repo,
  notifier: Oban.Notifiers.PG,
  queues: [
    delivery: 10,
    scheduled_job: 5,
    replay: 3,
    default: 5
  ],
  plugins: [
    # Completed jobs are kept 1 day: deliveries and job runs keep their outcome
    {Oban.Plugins.Pruner, max_age: 24 * 3600},
    # Jobs left "executing" by a crash or a killed deploy are retried instead
    # of staying stuck (longer than any job's own timeout)
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)},
    {Oban.Plugins.Cron,
     crontab: [
       {"* * * * *", StreamflixCore.Platform.ObanDelayedEventsWorker},
       {"* * * * *", StreamflixCore.Platform.ObanBatchWorker},
       {"0 3 * * 0", StreamflixCore.Platform.ObanPurgeWorker},
       {"0 2 * * *", StreamflixCore.Platform.ObanBackupWorker},
       {"*/5 * * * *", StreamflixCore.Platform.ObanUptimeWorker},
       {"*/5 * * * *", StreamflixCore.Platform.ObanBreachDetectionWorker},
       {"0 4 * * *", StreamflixCore.Platform.ObanSessionCleanupWorker},
       {"0 5 1 * *", StreamflixCore.Platform.ObanBackupVerificationWorker},
       {"0 6 * * *", StreamflixCore.Platform.ObanIdempotencyPurgeWorker},
       {"30 3 * * *", StreamflixCore.Platform.ObanSandboxPurgeWorker}
     ]}
  ]

# ============================================
# ESBUILD CONFIG
# ============================================

config :esbuild,
  version: "0.25.0",
  streamflix_web: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/streamflix_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# ============================================
# TAILWIND CONFIG (v4 - uses CSS-based config)
# ============================================

config :tailwind,
  version: "4.1.12",
  streamflix_web: [
    args: ~w(
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../apps/streamflix_web/assets", __DIR__)
  ]

# Import environment specific config
import_config "#{config_env()}.exs"
