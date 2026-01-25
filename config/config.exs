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

# Nebulex Cache Config - values from environment or defaults
config :streamflix_core, StreamflixCore.Cache,
  gc_interval: :timer.hours(1),
  max_size: 1_000_000,
  allocated_memory: 500_000_000,
  gc_cleanup_min_timeout: :timer.seconds(10),
  gc_cleanup_max_timeout: :timer.minutes(10)

# ============================================
# STREAMFLIX_WEB CONFIG
# ============================================

# Configure MIME types for file uploads
config :mime, :types, %{
  "video/x-matroska" => ["mkv"]
}

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
# STREAMFLIX_ACCOUNTS CONFIG (Guardian)
# Secrets configured in runtime.exs
# ============================================

config :streamflix_accounts, StreamflixAccounts.Guardian,
  issuer: "streamflix",
  secret_key: "configured_in_runtime",
  ttl: {7, :days}

# ============================================
# STREAMFLIX_CDN CONFIG (Azure)
# All values from environment variables
# ============================================

config :streamflix_cdn,
  azure_account: nil,
  azure_key: nil,
  azure_cdn_endpoint: nil,
  videos_playback_base_url: nil,
  videos_playback_sas_token: nil,
  containers: %{
    videos: "streamflix-videos",
    thumbnails: "streamflix-thumbnails",
    manifests: "streamflix-manifests",
    originals: "streamflix-originals"
  }

# ============================================
# STREAMFLIX_STREAMING CONFIG
# ============================================

config :streamflix_streaming,
  max_concurrent_streams_basic: 1,
  max_concurrent_streams_standard: 2,
  max_concurrent_streams_premium: 4,
  heartbeat_interval: 10_000,
  session_timeout: 300_000

# ============================================
# CLUSTERING CONFIG
# Configured in runtime.exs based on environment
# ============================================

config :libcluster,
  topologies: []

# ============================================
# LOGGER CONFIG
# ============================================

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :user_id, :content_id]

# ============================================
# PHOENIX CONFIG
# ============================================

config :phoenix, :json_library, Jason

# ============================================
# OBAN CONFIG (Background Jobs)
# Uses PG notifier for better Supabase compatibility
# ============================================

config :streamflix_core, Oban,
  engine: Oban.Engines.Basic,
  repo: StreamflixCore.Repo,
  notifier: Oban.Notifiers.PG,
  queues: [
    default: 10,
    transcoding: 2,
    notifications: 5,
    analytics: 3
  ]

# ============================================
# ESBUILD CONFIG
# ============================================

config :esbuild,
  version: "0.25.0",
  streamflix_web: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
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
