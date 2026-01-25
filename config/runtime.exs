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

# Streaming configuration from env
config :streamflix_streaming,
  max_concurrent_streams_basic: String.to_integer(System.get_env("MAX_STREAMS_BASIC") || "1"),
  max_concurrent_streams_standard: String.to_integer(System.get_env("MAX_STREAMS_STANDARD") || "2"),
  max_concurrent_streams_premium: String.to_integer(System.get_env("MAX_STREAMS_PREMIUM") || "4"),
  heartbeat_interval: String.to_integer(System.get_env("HEARTBEAT_INTERVAL") || "10000"),
  session_timeout: String.to_integer(System.get_env("SESSION_TIMEOUT") || "300000")

# Video playback: SAS URL for reading videos (all environments)
config :streamflix_cdn,
  videos_playback_base_url: System.get_env("AZURE_VIDEOS_BASE_URL"),
  videos_playback_sas_token: System.get_env("AZURE_VIDEOS_SAS_TOKEN")

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

  # Azure Configuration
  azure_account = System.get_env("AZURE_STORAGE_ACCOUNT")
  azure_key = System.get_env("AZURE_STORAGE_KEY")

  if azure_account && azure_key do
    config :streamflix_cdn,
      azure_account: azure_account,
      azure_key: azure_key,
      azure_cdn_endpoint: System.get_env("AZURE_CDN_ENDPOINT"),
      containers: %{
        videos: System.get_env("AZURE_CONTAINER_VIDEOS") || "videos",
        thumbnails: System.get_env("AZURE_CONTAINER_THUMBNAILS") || "thumbnails",
        manifests: System.get_env("AZURE_CONTAINER_MANIFESTS") || "manifests",
        originals: System.get_env("AZURE_CONTAINER_ORIGINALS") || "originals"
      }
  end

  # Clustering Configuration
  cluster_strategy = System.get_env("CLUSTER_STRATEGY") || "kubernetes"

  cluster_config =
    case cluster_strategy do
      "kubernetes" ->
        [
          streamflix: [
            strategy: Cluster.Strategy.Kubernetes,
            config: [
              mode: :dns,
              kubernetes_node_basename: System.get_env("KUBERNETES_NODE_BASENAME") || "streamflix",
              kubernetes_selector: System.get_env("KUBERNETES_SELECTOR") || "app=streamflix",
              kubernetes_namespace: System.get_env("KUBERNETES_NAMESPACE") || "production",
              polling_interval: 5_000
            ]
          ]
        ]

      "dns" ->
        [
          streamflix: [
            strategy: Cluster.Strategy.DNSPoll,
            config: [
              polling_interval: 5_000,
              query: System.get_env("DNS_QUERY") || "streamflix.local",
              node_basename: System.get_env("NODE_NAME") || "streamflix"
            ]
          ]
        ]

      _ ->
        []
    end

  config :libcluster, topologies: cluster_config

  # Erlang Distribution Cookie
  if cookie = System.get_env("NODE_COOKIE") do
    Node.set_cookie(String.to_atom(cookie))
  end
end
