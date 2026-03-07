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

```text
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
- Timestamps: always `timestamps(type: :utc_datetime_usec)`
- Migrations: timestamp-based filenames (`20260304100000_description.exs`)

## i18n — Bilingual (Spanish + English)

- Default locale: `"en"` (configured in `config/config.exs`)
- Supported locales: `"es"`, `"en"` — hardcoded in 3 places:
  - `plugs/set_locale.ex` (cookie/session plug)
  - `page_controller.ex` (`set_locale` action)
  - `live/live_locale.ex` (LiveView mount hook)
- Gettext is ONLY in `streamflix_web` — no i18n in core or accounts
- When adding/changing user-facing strings: run `mix gettext.extract --merge`
- Always update both `en/LC_MESSAGES/default.po` and `es/LC_MESSAGES/default.po`
- Translation files are in `apps/streamflix_web/priv/gettext/`

## Security Conventions

- Password hashing: Argon2id only (no PBKDF2), params: t_cost=3, m_cost=16, parallelism=4
- Encryption at rest: Cloak.Ecto AES-256-GCM for PII (email, name, mfa_secret)
- Email lookups: HMAC-SHA512 deterministic hash via `email_hash` field
- JWT auth: Guardian, 7-day TTL, JTI-based revocation
- Rate limiting: ETS-based, path-specific (login=5/min, signup=3/min, MFA=10/min)
- CSP: nonce-based for scripts, per-request random nonce via `SecurityHeaders` plug
- CSRF: Phoenix built-in `protect_from_forgery`
- Session: encrypted cookie, 30-min inactivity timeout, SameSite=Lax
- Failed logins: 5 attempts then 15-min lockout, `Argon2.no_user_verify()` for timing safety
- MFA: TOTP (nimble_totp) + 10 backup codes (SHA-256 hashed, one-time use)
- CORS: strict origin whitelist for browser, wildcard for API (API key protected)
- Force SSL in production via `force_ssl: [rewrite_on: [:x_forwarded_proto]]`

## Public Documentation Security (/docs page — CRITICAL)

The `/docs` page (`docs.html.heex`) is publicly accessible. NEVER expose:

- **Exact thresholds**: lockout attempts, rate limits, detection windows, circuit breaker counts
- **Exact timeouts**: session expiry, MFA token TTL, JWT TTL, monitoring intervals
- **Algorithm/library names**: AES-256-GCM, HMAC-SHA512, SHA-256, Argon2id params, Cloak, Oban, Cachex
- **Infrastructure details**: backup schedules, pg_dump format, env var names, internal ports
- **Internal references**: audit log event names (e.g. `security.anomaly_detected`), internal doc paths (`docs/*.md`)
- **Breach detection specifics**: thresholds, scan intervals, severity classification rules

Use generic language instead: "multiple attempts", "short period", "industry-standard encryption", "automated periodic backups", "continuous monitoring".

**What IS safe to document**: API endpoints, curl examples, user-facing features, general security posture (encrypted at rest, memory-hard hashing), GDPR rights.

## Structured Logging

- All Logger calls in workers must use keyword metadata, not string interpolation
- Every metadata key used must be registered in `config :logger, :console, metadata: [...]` in `config/config.exs`
- Common keys: `:worker`, `:delivery_id`, `:webhook_id`, `:event_id`, `:project_id`, `:error`, `:duration_ms`, `:status`

## Production Environment Variables (required)

- `DATABASE_URL` — Ecto connection string (Supabase pooler port 6543)
- `SECRET_KEY_BASE` — Phoenix endpoint secret
- `GUARDIAN_SECRET_KEY` — JWT signing secret
- `CLOAK_KEY` — AES-256-GCM encryption key (Base64-encoded, 32 bytes decoded)
- `HMAC_SECRET` — SHA-512 secret for email hash lookups
- `LIVE_VIEW_SIGNING_SALT` — LiveView signing salt
- `PHX_HOST` — Production domain (default: jobcelis.com)
- `RESEND_API_KEY` — Email service API key

## Elixir/Phoenix Code Conventions

- Contexts: large modules like `Platform` with grouped functions
- Schemas: in `schemas/` subdirectory, with `@required_fields` and `@optional_fields` module attributes
- Workers: in `platform/` subdirectory (Oban workers)
- Services: in `services/` subdirectory
- Custom types: in `types/`, `encrypted/`, `hashed/` subdirectories
- All modules must have `@moduledoc`
- Background jobs: Oban (queues: delivery, scheduled_job, replay, default)
- Test factories: ExMachina in `test/support/factory.ex` with `_factory()` suffix functions
- Test cases: DataCase for data tests, ConnCase for controller/API tests
- Test async: use `async: true` when safe (no shared DB state)

## Git Rules

- Never include `Co-Authored-By: Claude` or any Claude mention in commits
- Run `mix compile --warnings-as-errors && mix format --check-formatted` before committing

### Branch workflow (CRITICAL)
- **Application changes** (Elixir/Phoenix code, migrations, templates, configs): ALWAYS push to `develop` first, test in staging, then merge to `main` for production
- **Documentation-only changes** (README, CLAUDE.md, SDK docs): can go directly to `main`
- **SDK changes** (sdks/ folder): can go directly to `main` (published via workflow, not deployed)
- **Flow:** `develop` (staging) → verify at staging URL → `main` (production)
- **NEVER push untested application changes directly to `main`**

## Shell

- Use single quotes for passwords/secrets in shell commands (avoid `!` history expansion)
- Always `set -a && source .env && set +a` before `mix` commands locally
- devbox psql path: `.devbox/nix/profile/default/bin/psql`

## SDKs and External Repos

### Monorepo SDK sources (canonical code lives here)
- `sdks/node/` — Node.js/TypeScript SDK (`@jobcelis/sdk` on npm)
- `sdks/cli/` — CLI tool (`@jobcelis/cli` on npm)
- `sdks/python/` — Python SDK (`jobcelis` on PyPI)
- `sdks/go/` — Go SDK (synced to external repo)
- `sdks/php/` — PHP SDK (`jobcelis/sdk` on Packagist)
- `sdks/ruby/` — Ruby SDK (`jobcelis` on RubyGems)
- `sdks/elixir/` — Elixir SDK (`jobcelis` on Hex.pm)
- `sdks/github-action/` — GitHub Action (used directly from this repo)

### External repos (required by their registries)
- **Go SDK**: `github.com/vladimirCeli/go-jobcelis` — pkg.go.dev requires own repo with `go.mod` at root
- **PHP SDK**: `github.com/vladimirCeli/jobcelis-php` — Packagist requires `composer.json` at repo root
- **Ruby SDK**: `github.com/vladimirCeli/jobcelis-ruby` — public repo for RubyGems + code visibility
- **Elixir SDK**: `github.com/vladimirCeli/jobcelis-elixir` — Hex.pm requires own repo for publishing
- **Terraform Provider**: `github.com/vladimirCeli/terraform-provider-jobcelis` — Terraform Registry requires `terraform-provider-*` naming

### SDK publishing rules
- **npm**: Requires granular token with `@jobcelis` scope + "bypass 2FA" enabled. GitHub secret: `NPM_TOKEN`
- **PyPI**: Uses `__token__` auth. GitHub secret: `PYPI_TOKEN`. `setup.py` must include `long_description` from README
- **Go**: Tag-based (`git tag v1.x.0 && git push origin v1.x.0`). No token needed for public repos
- **Terraform**: GoReleaser on tag push. Requires `GPG_PRIVATE_KEY` secret for signing
- **RubyGems**: GitHub secret: `RUBYGEMS_API_KEY`. Version in `lib/jobcelis.rb` and `jobcelis.gemspec`
- **Packagist**: Auto-sync via GitHub webhook — register package on packagist.org, no CI secret needed
- **Hex.pm (Elixir)**: Requires `HEX_API_KEY` secret. Publish with `mix hex.publish` from external repo
- **GitHub Action**: No publishing — used directly from repo with `uses: vladimirCeli/jobscelis/sdks/github-action@main`
- **Workflow**: `.github/workflows/publish-sdks.yml` — manual trigger with package choice
- Always bump version in `package.json`/`setup.py`/`gemspec` before publishing — registries reject duplicate versions

### SDK code conventions
- TypeScript SDKs need `@types/node` in devDependencies and `"types": ["node"]` in tsconfig
- TypeScript imports: use `"./module"` not `"./module.js"` with `commonjs` module
- Python `setup.py`: always include `long_description` + `long_description_content_type="text/markdown"` for PyPI README
- Go SDK: three auth modes — `doRequest` (API key), `doAuthenticatedRequest` (Bearer), `doPublicRequest` (no auth)
- PHP SDK: native cURL, PSR-4 autoload, requires PHP 8.1+
- Ruby SDK: net/http, no external dependencies, requires Ruby 3.0+
- Elixir SDK: uses Finch + Jason, OTP application with supervised Finch pool, idiomatic `{:ok, result}` / `{:error, error}` returns
- All SDKs must cover 100% of API routes. When adding a new API route, update ALL SDKs (Node, Python, Go, PHP, Ruby, Elixir, CLI)

### Syncing external repos
When updating Go SDK or Terraform provider:
1. Make changes in `sdks/go/` or local clone of terraform repo
2. Copy files to external repo: `cp sdks/go/* /path/to/go-jobcelis/`
3. Commit, tag, and push the external repo
4. For Go: `git tag v1.x.0 && git push origin v1.x.0`
5. For Terraform: same tag pattern, GoReleaser handles the release

## Migrations

- Supabase has `ensure_rls_on_new_tables` event trigger — always wrap `ALTER EVENT TRIGGER` in `IF EXISTS` check
- Use `DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_event_trigger WHERE evtname = '...') THEN ... END IF; END $$;`
- This ensures migrations work in both CI (plain PostgreSQL) and production (Supabase)

## Deployment

### Environments

| Environment | URL | Branch | Image tag |
|-------------|-----|--------|-----------|
| **Production** | `jobcelis.com` | `main` | `jobscelis:latest` |
| **Staging** | `jobcelis-staging.azurewebsites.net` | `develop` | `jobscelis:staging` |
| **Local** | `localhost:4000` | — | — |

### Deploy flow (local → staging → production)

1. Develop and commit locally
2. `git checkout develop && git merge main && git push origin develop` → deploys to **staging**
3. Verify at `https://jobcelis-staging.azurewebsites.net`
4. `git checkout main && git push origin main` → deploys to **production**

**Never push untested changes directly to main.** Always verify in staging first.

### Infrastructure

- Docker: multi-stage Alpine build (elixir:1.17-otp-27-alpine)
- Release: `streamflix` (all 3 apps as `:permanent`)
- Auto-migrate on startup via `StreamflixCore.Release.migrate()`
- ACR: `jobscelisacr`
- CDN: `cdn.jobcelis.com` via Cloudflare (production only, env `CDN_HOST`)
- CI: Trivy container security scan (CRITICAL/HIGH CVEs block merge)
