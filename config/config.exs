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

config :streamflix_web, StreamflixWebWeb.Gettext, default_locale: "es"

# Marca y titular legal (copyright, términos, contacto, donaciones). Servicio de Vladimir Celi.
config :streamflix_web, :legal,
  product_name: "Jobcelis",
  owner: "Vladimir Celi",
  contact_url: "https://github.com/vladimirCeli",
  profile_url: "https://vladimirceli.github.io/perfil/",
  contact_email: "vladimir.celi@proton.me",
  # Opcional: enlaces para donaciones. Dejar "" si no usas; en producción puedes usar env DONATION_PAYPAL_URL, DONATION_PAYONEER_URL
  donation_paypal_url: "",
  donation_payoneer_url: ""

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
    default: 5
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
