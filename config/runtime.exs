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

  # prepare: :unnamed necesario con Supabase pooler (PgBouncer); si no, "prepared statement does not exist"
  # ssl: verify_none suficiente si el canal ya está protegido (túnel, red interna).
  # Para cumplimiento estricto (p. ej. auditoría): usar verify_peer y CA, ej. ssl: [verify: :verify_peer, cacertfile: System.get_env("DB_CA_CERT")], con el certificado CA en ese path.
  config :streamflix_core, StreamflixCore.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("DB_POOL_SIZE") || "10"),
    socket_options: maybe_ipv6,
    ssl: [verify: :verify_none],
    prepare: :unnamed

  # Secret Key Base
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "jobcelis.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  # Session signing salt (recomendado en prod para rotación sin recompilar)
  session_signing_salt = System.get_env("SESSION_SIGNING_SALT")

  config :streamflix_web, StreamflixWebWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # IPv4 0.0.0.0 para que Azure y el health check puedan conectar (evitar solo IPv6)
      ip: {0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base,
    server: true,
    session_signing_salt: session_signing_salt

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

  # Marca y titular legal (por defecto los de config.exs; en producción puedes sobrescribir con env)
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
    Application.get_env(:streamflix_web, :legal, [
      product_name: "Jobcelis",
      owner: "Jobcelis",
      contact_email: "",
      donation_paypal_url: "",
      donation_payoneer_url: "",
      donation_payphone_url: ""
    ])
    |> Keyword.merge(env_legal)

  config :streamflix_web, :legal, legal
end
