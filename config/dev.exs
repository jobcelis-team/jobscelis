import Config

# ============================================
# DEVELOPMENT CONFIGURATION
# Using Supabase PostgreSQL (same DB as agent_flow)
# ============================================

# ============================================
# DATABASE CONFIG (Supabase Pooler)
# ============================================

config :streamflix_core, StreamflixCore.Repo,
  username: System.get_env("DB_USERNAME") || "postgres",
  password: System.get_env("DB_PASSWORD") || "postgres",
  hostname: System.get_env("DB_HOSTNAME") || "localhost",
  port: String.to_integer(System.get_env("DB_PORT") || "5432"),
  database: System.get_env("DB_DATABASE") || "postgres",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: String.to_integer(System.get_env("DB_POOL_SIZE") || "5"),
  ssl: [verify: :verify_none],
  prepare: :unnamed,
  log: :debug

# ============================================
# WEB ENDPOINT CONFIG
# ============================================

config :streamflix_web, StreamflixWebWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4000")],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: System.get_env("SECRET_KEY_BASE") || "dev_secret_key_base_minimum_64_bytes_long_for_security_purposes_change_in_production",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:streamflix_web, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:streamflix_web, ~w(--watch)]}
  ]

# Watch static and templates for browser reloading.
config :streamflix_web, StreamflixWebWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/streamflix_web_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# ============================================
# GUARDIAN SECRET KEY (Development)
# ============================================

config :streamflix_accounts, StreamflixAccounts.Guardian,
  issuer: "streamflix",
  secret_key: System.get_env("GUARDIAN_SECRET_KEY") || "dev_guardian_secret_key_change_in_production_minimum_64_bytes"

# ============================================
# AZURE CONFIG (Development)
# ============================================

config :streamflix_cdn,
  azure_account: System.get_env("AZURE_STORAGE_ACCOUNT"),
  azure_key: System.get_env("AZURE_STORAGE_KEY"),
  azure_cdn_endpoint: System.get_env("AZURE_CDN_ENDPOINT"),
  containers: %{
    videos: System.get_env("AZURE_CONTAINER_VIDEOS") || "videos",
    thumbnails: System.get_env("AZURE_CONTAINER_THUMBNAILS") || "thumbnails",
    manifests: System.get_env("AZURE_CONTAINER_MANIFESTS") || "manifests",
    originals: System.get_env("AZURE_CONTAINER_ORIGINALS") || "originals"
  },
  videos_playback_base_url: System.get_env("AZURE_VIDEOS_BASE_URL"),
  videos_playback_sas_token: System.get_env("AZURE_VIDEOS_SAS_TOKEN")

# ============================================
# CLUSTERING (Local Development)
# ============================================

config :libcluster,
  topologies: [
    streamflix: [
      strategy: Cluster.Strategy.Epmd,
      config: [
        hosts: [
          :"node1@127.0.0.1",
          :"node2@127.0.0.1",
          :"node3@127.0.0.1"
        ]
      ]
    ]
  ]

# ============================================
# LOGGER
# ============================================

config :logger, :default_formatter, format: "[$level] $message\n"

# Set a higher stacktrace during development.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  enable_expensive_runtime_checks: true

# Enable dev routes for dashboard
config :streamflix_web, dev_routes: true
