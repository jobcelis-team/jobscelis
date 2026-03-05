# CLAUDE.md — Jobcelis Project Rules

## CI Pipeline (all must pass before merge)

1. `mix compile --warnings-as-errors` — zero warnings allowed
2. `mix format --check-formatted` — code must be formatted
3. `mix credo --min-priority=high` — static analysis
4. `mix sobelow --exit low --app-dir apps/streamflix_web` — security scan
5. `mix deps.audit` — no known CVEs in dependencies
6. `mix hex.audit` — no retired packages
7. `mix test` — all tests must pass
8. `mix dialyzer` — runs but non-blocking (continue-on-error)

**Before committing, always run:** `mix compile --warnings-as-errors && mix format --check-formatted`

## Umbrella Architecture (CRITICAL)

Strict dependency flow — never reference modules upstream:

```
streamflix_web -> streamflix_accounts -> streamflix_core
```

- `streamflix_core` CANNOT reference `StreamflixAccounts.*` or `StreamflixWebWeb.*`
- `streamflix_accounts` CANNOT reference `StreamflixWebWeb.*`
- `streamflix_web` CAN reference both `StreamflixCore.*` and `StreamflixAccounts.*`

When querying tables owned by another app from `streamflix_core`, use raw table queries
(`from(s in "table_name")`) and cast binary IDs explicitly: `type(s.id, :string)`.

## Database

- All primary/foreign keys are binary UUIDs (`:binary_id`)
- Raw table queries return UUIDs as raw bytes — always cast with `type(field, :string)` before JSON encoding
- Cloak-encrypted fields (`*_encrypted`) contain raw binary — never include in JSON responses

## Git Rules

- Never include `Co-Authored-By: Claude` or any Claude mention in commits
- Run `mix format` before committing to avoid CI format failures

## Elixir/Phoenix Conventions

- Password hashing: Argon2id only (no PBKDF2)
- Encryption: Cloak.Ecto AES-256-GCM for PII, HMAC-SHA512 for email lookups
- i18n: Spanish (default) + English — update .pot/.po files for user-facing strings
- Background jobs: Oban (queues: delivery, scheduled_job, replay, default)

## Shell

- Use single quotes for passwords/secrets in shell commands (avoid `!` history expansion)
- Always `set -a && source .env && set +a` before `mix` commands locally
