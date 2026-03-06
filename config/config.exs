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

# Marca y titular legal (copyright, términos, contacto, donaciones). Servicio de Vladimir Celi.
config :streamflix_web, :legal,
  product_name: "Jobcelis",
  owner: "Vladimir Celi",
  contact_url: "https://github.com/vladimirCeli",
  profile_url: "https://vladimirceli.github.io/perfil/",
  contact_email: "vladimir.celi@proton.me",
  # Opcional: enlaces para donaciones. Dejar "" si no usas; en producción puedes usar env DONATION_*_URL
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
    :threshold_hours
  ]

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
    scheduled_job: 1,
    replay: 3,
    default: 5
  ],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 7 * 24 * 3600},
    {Oban.Plugins.Cron,
     crontab: [
       {"* * * * *", StreamflixCore.Platform.ObanDelayedEventsWorker},
       {"* * * * *", StreamflixCore.Platform.ObanBatchWorker},
       {"0 3 * * 0", StreamflixCore.Platform.ObanPurgeWorker},
       {"0 2 * * *", StreamflixCore.Platform.ObanBackupWorker},
       {"*/5 * * * *", StreamflixCore.Platform.ObanUptimeWorker},
       {"*/5 * * * *", StreamflixCore.Platform.ObanBreachDetectionWorker},
       {"0 4 * * *", StreamflixCore.Platform.ObanSessionCleanupWorker},
       {"0 5 1 * *", StreamflixCore.Platform.ObanBackupVerificationWorker}
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
