import Config

# ============================================
# PRODUCTION CONFIGURATION
# ============================================
# Note: Most production configuration is handled in runtime.exs
# to support environment variables in releases.

# Do not print debug messages in production
config :logger, level: :info

# Structured JSON logging for production (easier to parse by log aggregators)
config :logger, :default_handler,
  formatter: {LoggerJSON.Formatters.Basic, metadata: [:request_id, :user_id]}

# Disable dev routes in production
config :streamflix_web, dev_routes: false

# Configure static assets for production
config :streamflix_web, StreamflixWebWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

# Force SSL in production
config :streamflix_web, StreamflixWebWeb.Endpoint, force_ssl: [rewrite_on: [:x_forwarded_proto]]

# Runtime production configuration is done in config/runtime.exs
