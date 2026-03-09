import Config

# ============================================
# RUNTIME CONFIGURATION
# ============================================
# This file is executed at runtime, including releases.
# It is executed after compile-time config and before starting the application.
# All sensitive configuration should be here using environment variables.

# ============================================
# COMMON RUNTIME CONFIG (All Environments)
# ============================================

# LiveView signing salt
if signing_salt = System.get_env("LIVE_VIEW_SIGNING_SALT") do
  config :streamflix_web, StreamflixWebWeb.Endpoint, live_view: [signing_salt: signing_salt]
end

# Resend API (email delivery) — all environments
if resend_key = System.get_env("RESEND_API_KEY") do
  config :streamflix_web, StreamflixWebWeb.Mailer,
    api_key: resend_key,
    from_email: System.get_env("MAILER_FROM_EMAIL") || "noreply@jobcelis.com",
    from_name: System.get_env("MAILER_FROM_NAME") || "Jobcelis"
end

# ============================================
# PRODUCTION RUNTIME CONFIG
# ============================================

if config_env() == :prod do
  # Database Configuration
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  # prepare: :unnamed required for connection pooler (PgBouncer)
  # SSL: verify_none for pooler compatibility on Alpine
  config :streamflix_core, StreamflixCore.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("DB_POOL_SIZE") || "20"),
    socket_options: maybe_ipv6,
    ssl: [verify: :verify_none],
    prepare: :unnamed,
    after_connect: {Postgrex, :query!, ["SET search_path TO public", []]}

  # Secret Key Base
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "jobcelis.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  # CDN for static assets (optional — set CDN_HOST to enable)
  static_url =
    if cdn_host = System.get_env("CDN_HOST") do
      [scheme: "https", host: cdn_host, port: 443]
    end

  endpoint_config =
    [
      url: [host: host, port: 443, scheme: "https"],
      http: [
        # Bind 0.0.0.0 for health check access (avoid IPv6-only)
        ip: {0, 0, 0, 0},
        port: port
      ],
      secret_key_base: secret_key_base,
      server: true
    ]
    |> then(fn config ->
      if static_url, do: Keyword.put(config, :static_url, static_url), else: config
    end)

  config :streamflix_web, StreamflixWebWeb.Endpoint, endpoint_config

  # Guardian Secret Key
  guardian_secret =
    System.get_env("GUARDIAN_SECRET_KEY") ||
      raise """
      environment variable GUARDIAN_SECRET_KEY is missing.
      You can generate one by calling: mix guardian.gen.secret
      """

  config :streamflix_accounts, StreamflixAccounts.Guardian,
    issuer: "streamflix",
    secret_key: guardian_secret

  # Cloak Vault Key (At-Rest Encryption for webhook secrets)
  if cloak_key = System.get_env("CLOAK_KEY") do
    config :streamflix_core, StreamflixCore.Vault,
      ciphers: [
        default: {
          Cloak.Ciphers.AES.GCM,
          tag: "AES.GCM.V1", key: Base.decode64!(cloak_key), iv_length: 12
        }
      ]
  end

  # HMAC secret for deterministic hashing (email lookups)
  hmac_secret =
    System.get_env("HMAC_SECRET") || System.get_env("CLOAK_KEY") ||
      raise "environment variable HMAC_SECRET is missing."

  config :streamflix_core, StreamflixCore.Hashed.HMAC,
    algorithm: :sha512,
    secret: hmac_secret

  # Backup configuration (production overrides)
  if backup_path = System.get_env("BACKUP_PATH") do
    config :streamflix_core, :backup,
      enabled: System.get_env("BACKUP_ENABLED", "true") == "true",
      backup_path: backup_path,
      retention_days: String.to_integer(System.get_env("BACKUP_RETENTION_DAYS") || "30"),
      pg_dump_path: System.get_env("PG_DUMP_PATH") || "pg_dump"
  end

  # Azure Blob Storage for backups (uses existing AZURE_STORAGE_* vars)
  if azure_account = System.get_env("AZURE_STORAGE_ACCOUNT") do
    config :streamflix_core, :azure_storage,
      account: azure_account,
      key: System.get_env("AZURE_STORAGE_KEY"),
      container_backups: System.get_env("AZURE_CONTAINER_BACKUPS") || "backups"
  end

  # Erlang Distribution Cookie
  if cookie = System.get_env("NODE_COOKIE") do
    Node.set_cookie(String.to_atom(cookie))
  end

  # Legal branding overrides (defaults from config.exs)
  env_legal =
    Enum.filter(
      [
        product_name: System.get_env("LEGAL_PRODUCT_NAME"),
        owner: System.get_env("LEGAL_OWNER"),
        contact_email: System.get_env("LEGAL_CONTACT_EMAIL"),
        donation_paypal_url: System.get_env("DONATION_PAYPAL_URL"),
        donation_payoneer_url: System.get_env("DONATION_PAYONEER_URL"),
        donation_payphone_url: System.get_env("DONATION_PAYPHONE_URL")
      ],
      fn {_, v} -> is_binary(v) and v != "" end
    )

  legal =
    Application.get_env(:streamflix_web, :legal,
      product_name: "Jobcelis",
      owner: "Jobcelis",
      contact_email: "",
      donation_paypal_url: "",
      donation_payoneer_url: "",
      donation_payphone_url: ""
    )
    |> Keyword.merge(env_legal)

  config :streamflix_web, :legal, legal
end
