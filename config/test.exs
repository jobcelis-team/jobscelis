import Config

# ============================================
# TEST CONFIGURATION
# Uses test defaults, no real credentials needed
# ============================================

# Configure your database for testing
config :streamflix_core, StreamflixCore.Repo,
  username: System.get_env("TEST_DB_USERNAME") || "postgres",
  password: System.get_env("TEST_DB_PASSWORD") || "postgres",
  hostname: System.get_env("TEST_DB_HOSTNAME") || "localhost",
  port: String.to_integer(System.get_env("TEST_DB_PORT") || "5432"),
  database: "streamflix_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test.
config :streamflix_web, StreamflixWebWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base:
    "test_secret_key_base_that_is_at_least_64_bytes_long_for_security_purposes_here",
  server: false

# Guardian test config - uses test-only secret
config :streamflix_accounts, StreamflixAccounts.Guardian,
  issuer: "streamflix_test",
  secret_key: "test_guardian_secret_key_for_testing_purposes_only_minimum_64_bytes"

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Oban inline mode for tests
config :streamflix_core, Oban, testing: :inline

# Disable PromEx in test
config :streamflix_web, StreamflixWeb.PromEx, disabled: true
