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
  config :streamflix_web, StreamflixWebWeb.Endpoint,
    live_view: [signing_salt: signing_salt]
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

  config :streamflix_core, StreamflixCore.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("DB_POOL_SIZE") || "10"),
    socket_options: maybe_ipv6,
    ssl: true,
    ssl_opts: [verify: :verify_none]

  # Secret Key Base
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :streamflix_web, StreamflixWebWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base,
    server: true

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

  # Erlang Distribution Cookie
  if cookie = System.get_env("NODE_COOKIE") do
    Node.set_cookie(String.to_atom(cookie))
  end
end
