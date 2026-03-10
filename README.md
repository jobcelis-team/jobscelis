# Jobcelis

**Event infrastructure platform for developers** — publish events with any payload, configure webhooks with advanced filters, receive real-time POST deliveries, and schedule recurring jobs with cron. Includes a real-time dashboard, team collaboration, data encryption, GDPR compliance, automated backups, and more.

Built with **Elixir/OTP**, **Phoenix 1.8**, **LiveView 1.1**, and **PostgreSQL**.

---

## Table of Contents

- [Key Features](#key-features)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Environment Variables](#environment-variables)
- [Project Structure](#project-structure)
- [API Reference](#api-reference)
- [Dashboard](#dashboard)
- [Security](#security)
- [GDPR Compliance](#gdpr-compliance)
- [Webhooks](#webhooks)
- [Scheduled Jobs](#scheduled-jobs)
- [Event Replay](#event-replay)
- [Sandbox](#sandbox)
- [Pipelines](#pipelines)
- [Teams & Collaboration](#teams--collaboration)
- [Analytics](#analytics)
- [Data Export](#data-export)
- [Real-time Streaming](#real-time-streaming)
- [OpenAPI / Swagger](#openapi--swagger)
- [Backups](#backups)
- [Uptime & Monitoring](#uptime--monitoring)
- [Background Workers](#background-workers)
- [Internationalization](#internationalization-i18n)
- [Public Pages & SEO](#public-pages--seo)
- [CI/CD](#cicd)
- [Docker](#docker)
- [Tech Stack](#tech-stack)
- [SDKs & Tools](#sdks--tools)
- [License](#license)

---

## Key Features

| Category | Description |
|----------|-------------|
| **Events** | Publish events with `topic` and JSON payload via API. Schema-free, or with optional JSON Schema validation per topic. Supports deferred delivery (`deliver_at`) and batch events. |
| **Webhooks** | Destination URLs with topic and payload field filters. Real-time POST with configurable retries, circuit breaker, batch delivery, and 5 built-in templates (Slack, Discord, Telegram, generic JSON, custom). |
| **Scheduled Jobs** | Recurring tasks: daily, weekly, monthly, or cron expression. Actions: emit event or POST to external URL with configurable payload. Execution history tracking. |
| **Pipelines** | Multi-step event processing workflows with transformations. Chain events through configurable pipeline stages. |
| **External Alerts** | Receive notifications via email, Slack, Discord, or meta-webhook when webhooks fail, circuit breakers open, jobs fail, or deliveries move to DLQ. Configurable per project with event type filters. |
| **Dashboard** | Real-time LiveView dashboard with KPIs, analytics charts, webhook/job/event management, dead letter queue, sandbox, schemas, team management, alert configuration, and more. |
| **Multi-project** | Multiple projects per user. Project selector with URL persistence. Invite members with roles (owner/editor/viewer). |
| **Security** | Industry-standard encryption at rest, MFA/TOTP, session management, rate limiting, IP allowlist, circuit breaker, anomaly detection, security headers, cookie consent. |
| **GDPR** | Right to erasure (Art. 17), restriction of processing (Art. 18), right to object (Art. 21), personal data export (Art. 15/20), consent management. |
| **API** | 90+ REST endpoints with JWT and API Key authentication. OpenAPI 3.0 with interactive Swagger UI. SSE and WebSocket for streaming. |
| **Backups** | Automated daily database backups with compression. Local or cloud object storage. Configurable retention policy. |
| **Observability** | Periodic uptime monitoring, health checks (database, jobs, cache, backup), immutable audit log, structured JSON logs in production. |
| **Admin Panel** | Superadmin panel: user management with search, project overview, system metrics, platform settings. |

---

## Architecture

Umbrella application with 3 apps and strict dependency flow:

```
streamflix_web → streamflix_accounts → streamflix_core
```

```
jobcelis/
├── apps/
│   ├── streamflix_core/       # Domain: projects, API keys, events, webhooks,
│   │                          # deliveries, jobs, dead letters, replays, sandbox,
│   │                          # schemas, pipelines, analytics, audit, teams,
│   │                          # notifications, uptime, GDPR, backups, circuit breaker
│   ├── streamflix_accounts/   # Users, authentication (JWT), MFA, sessions
│   └── streamflix_web/        # Web (LiveView), REST API, plugs, docs, admin
├── sdks/                      # 13 SDKs + CLI + GitHub Action
├── docs/                      # Public documentation
├── config/                    # Per-environment configuration
├── Dockerfile                 # Multi-stage build (dev + prod)
├── docker-compose.yml
└── .github/workflows/
    ├── ci.yml                 # Tests, format, Credo, Sobelow, Dialyzer, Trivy
    ├── deploy.yml             # Production deploy
    ├── deploy-staging.yml     # Staging deploy
    └── publish-sdks.yml       # SDK publishing
```

---

## Requirements

- **Elixir** 1.17+
- **Erlang/OTP** 27+
- **PostgreSQL** 15+
- **Node.js** 20+ (for asset compilation)

---

## Quick Start

### 1. Clone and install dependencies

```bash
git clone <repo>
cd jobcelis
mix deps.get
```

### 2. Environment variables

```bash
cp .env.example .env
```

Edit `.env` and configure at least:

```bash
# Security (generate with the commands below)
SECRET_KEY_BASE=          # mix phx.gen.secret
GUARDIAN_SECRET_KEY=      # mix guardian.gen.secret
LIVE_VIEW_SIGNING_SALT=   # 32+ characters

# Database
DB_USERNAME=postgres
DB_PASSWORD=your_password
DB_HOSTNAME=localhost
DB_DATABASE=jobcelis_dev
```

Generate secrets:

```bash
mix phx.gen.secret        # SECRET_KEY_BASE
mix guardian.gen.secret    # GUARDIAN_SECRET_KEY
```

### 3. Database

```bash
mix ecto.create
mix ecto.migrate
mix run apps/streamflix_core/priv/repo/seeds.exs
```

### 4. Start the server

```bash
# Load .env (Linux/macOS)
set -a && source .env && set +a

mix phx.server
```

Open **http://localhost:4000**

### 5. Create superadmin

```bash
iex -S mix
# Then call the user creation functions with superadmin role
```

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `SECRET_KEY_BASE` | Yes | Phoenix session encryption key |
| `GUARDIAN_SECRET_KEY` | Yes | JWT signing key |
| `LIVE_VIEW_SIGNING_SALT` | Yes | LiveView token signing salt |
| `DATABASE_URL` | Yes* | PostgreSQL connection string (alternative to `DB_*`) |
| `DB_USERNAME` / `DB_PASSWORD` / `DB_HOSTNAME` / `DB_DATABASE` | Yes* | PostgreSQL connection (alternative to `DATABASE_URL`) |
| `CLOAK_KEY` | Production | Encryption key for data at rest (Base64) |
| `HMAC_SECRET` | Production | Secret for deterministic email hashing |
| `RESEND_API_KEY` | Optional | Resend API key for transactional emails |
| `PHX_HOST` | Production | Production domain |
| `CDN_HOST` | Optional | CDN domain for static assets |
| `AZURE_STORAGE_ACCOUNT` / `AZURE_STORAGE_KEY` | Optional | Cloud storage credentials for backups |
| `AZURE_CONTAINER_BACKUPS` | Optional | Cloud storage container name |
| `BACKUP_ENABLED` / `BACKUP_PATH` / `BACKUP_RETENTION_DAYS` | Optional | Backup configuration |

---

## Project Structure

```
jobcelis/
├── apps/
│   ├── streamflix_core/
│   │   ├── lib/
│   │   │   ├── platform.ex              # Main context module
│   │   │   ├── platform/
│   │   │   │   ├── contexts/            # Business contexts (events, webhooks, jobs, etc.)
│   │   │   │   ├── pipelines.ex         # Pipeline processing engine
│   │   │   │   ├── transformer.ex       # Payload transformations
│   │   │   │   └── ...                  # Background workers
│   │   │   ├── schemas/                 # Ecto schemas (20+ domain entities)
│   │   │   ├── audit.ex                 # Immutable audit log
│   │   │   ├── gdpr.ex                  # GDPR compliance
│   │   │   ├── circuit_breaker.ex       # Webhook circuit breaker
│   │   │   ├── notifications.ex         # In-app notifications + PubSub
│   │   │   └── release.ex              # Auto-migration on startup
│   │   └── priv/repo/migrations/
│   ├── streamflix_accounts/
│   │   └── lib/
│   │       ├── schemas/                 # User, session, token, password history
│   │       └── services/               # Authentication, MFA
│   └── streamflix_web/
│       └── lib/
│           ├── controllers/             # REST API controllers + page controllers
│           ├── live/
│           │   ├── platform_dashboard/  # Modular dashboard (helpers, tabs, modals)
│           │   ├── platform_dashboard_live.ex
│           │   ├── admin/              # Admin LiveViews
│           │   └── account/            # Account settings LiveView
│           ├── plugs/                  # Auth, rate limit, CORS, security headers, locale
│           └── channels/              # WebSocket channels
├── config/
│   ├── config.exs                      # Base configuration
│   ├── dev.exs / test.exs / prod.exs
│   └── runtime.exs                     # Runtime env vars
├── sdks/                               # 13 SDKs + CLI + GitHub Action
├── docs/                               # Public docs (architecture, quickstart, SLA, webhooks)
└── .github/workflows/                  # CI, deploy, SDK publishing
```

---

## API Reference

Authentication header: `Authorization: Bearer <jwt_token>` or `X-Api-Key: <api_key>`

Interactive docs: **https://jobcelis.com/docs** | Swagger UI: **https://jobcelis.com/api/swaggerui**

### Auth (Public)

| Method | Route | Description |
|--------|-------|-------------|
| POST | `/api/v1/auth/register` | Register (email, password, name) |
| POST | `/api/v1/auth/login` | Login → JWT + MFA if enabled |
| POST | `/api/v1/auth/refresh` | Refresh JWT token |
| POST | `/api/v1/auth/mfa/verify` | Verify TOTP code |

### Events (API Key)

| Method | Route | Description |
|--------|-------|-------------|
| POST | `/api/v1/events` | Create event (topic + payload). Supports `deliver_at` |
| POST | `/api/v1/send` | Alias for creating an event |
| POST | `/api/v1/events/batch` | Send multiple events in a single request |
| GET | `/api/v1/events` | List events (cursor pagination) |
| GET | `/api/v1/events/:id` | Event details |
| DELETE | `/api/v1/events/:id` | Soft-delete event |
| POST | `/api/v1/simulate` | Simulate event (no real deliveries) |
| GET | `/api/v1/topics` | List all topics in the project |

### Webhooks (API Key)

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/api/v1/webhooks` | List webhooks |
| POST | `/api/v1/webhooks` | Create webhook (URL, topics, filters, retry, batch, template) |
| GET | `/api/v1/webhooks/:id` | Webhook details |
| PATCH | `/api/v1/webhooks/:id` | Update webhook |
| DELETE | `/api/v1/webhooks/:id` | Deactivate webhook |
| GET | `/api/v1/webhooks/:id/health` | Health: success rate, avg latency, last delivery |
| GET | `/api/v1/webhooks/templates` | Available templates (Slack, Discord, Telegram, etc.) |

### Deliveries (API Key)

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/api/v1/deliveries` | List deliveries with full request/response logs, headers, latency, and destination IP |
| POST | `/api/v1/deliveries/:id/retry` | Retry failed delivery |

### Dead Letter Queue (API Key)

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/api/v1/dead-letters` | List dead letters |
| GET | `/api/v1/dead-letters/:id` | Dead letter details |
| POST | `/api/v1/dead-letters/:id/retry` | Retry dead letter |
| PATCH | `/api/v1/dead-letters/:id/resolve` | Mark as resolved |

### Replays (API Key)

| Method | Route | Description |
|--------|-------|-------------|
| POST | `/api/v1/replays` | Start replay (filter by topic, dates, webhook) |
| GET | `/api/v1/replays` | List replays |
| GET | `/api/v1/replays/:id` | Replay status |
| DELETE | `/api/v1/replays/:id` | Cancel replay |

### Scheduled Jobs (API Key)

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/api/v1/jobs` | List jobs |
| POST | `/api/v1/jobs` | Create job (schedule + action) |
| GET | `/api/v1/jobs/:id` | Job details |
| PATCH | `/api/v1/jobs/:id` | Update job |
| DELETE | `/api/v1/jobs/:id` | Deactivate job |
| GET | `/api/v1/jobs/:id/runs` | Execution history |
| GET | `/api/v1/jobs/cron-preview` | Preview next cron executions |

### Pipelines (API Key)

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/api/v1/pipelines` | List pipelines |
| POST | `/api/v1/pipelines` | Create pipeline |
| GET | `/api/v1/pipelines/:id` | Pipeline details |
| PATCH | `/api/v1/pipelines/:id` | Update pipeline |
| DELETE | `/api/v1/pipelines/:id` | Delete pipeline |
| POST | `/api/v1/pipelines/:id/test` | Test pipeline with sample data |

### Sandbox (API Key)

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/api/v1/sandbox-endpoints` | List sandbox endpoints |
| POST | `/api/v1/sandbox-endpoints` | Create temporary endpoint |
| DELETE | `/api/v1/sandbox-endpoints/:id` | Delete endpoint |
| GET | `/api/v1/sandbox-endpoints/:id/requests` | View captured requests |

### Notification Channels (API Key)

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/api/v1/notification-channels` | Get channel configuration |
| PUT | `/api/v1/notification-channels` | Create or update channels (email, Slack, Discord, meta-webhook) |
| DELETE | `/api/v1/notification-channels` | Delete channel configuration |
| POST | `/api/v1/notification-channels/test` | Send test notification to all enabled channels |

### Event Schemas (API Key)

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/api/v1/event-schemas` | List schemas |
| POST | `/api/v1/event-schemas` | Create schema (JSON Schema per topic) |
| GET | `/api/v1/event-schemas/:id` | Schema details |
| PATCH | `/api/v1/event-schemas/:id` | Update schema |
| DELETE | `/api/v1/event-schemas/:id` | Delete schema |
| POST | `/api/v1/event-schemas/validate` | Validate payload against schema |

### Analytics (API Key)

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/api/v1/analytics/events-per-day` | Events per day (up to 90 days) |
| GET | `/api/v1/analytics/deliveries-per-day` | Deliveries per day |
| GET | `/api/v1/analytics/top-topics` | Topics by volume |
| GET | `/api/v1/analytics/webhook-stats` | Per-webhook stats (success, failure, latency) |

### Audit Log (API Key)

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/api/v1/audit-log` | Query project audit log |

### Export (API Key)

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/api/v1/export/events` | Export events (CSV/JSON) |
| GET | `/api/v1/export/deliveries` | Export deliveries |
| GET | `/api/v1/export/jobs` | Export jobs |
| GET | `/api/v1/export/audit-log` | Export audit log |

### Projects & Teams (JWT)

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/api/v1/projects` | List projects |
| POST | `/api/v1/projects` | Create project |
| GET | `/api/v1/projects/:id` | Project details |
| PATCH | `/api/v1/projects/:id` | Update project |
| DELETE | `/api/v1/projects/:id` | Delete project |
| PATCH | `/api/v1/projects/:id/default` | Set as default project |
| GET | `/api/v1/projects/:id/members` | List members |
| POST | `/api/v1/projects/:id/members` | Invite member |
| PATCH | `/api/v1/projects/:id/members/:mid` | Change role |
| DELETE | `/api/v1/projects/:id/members/:mid` | Remove member |
| GET | `/api/v1/invitations/pending` | Pending invitations |
| POST | `/api/v1/invitations/:id/accept` | Accept invitation |
| POST | `/api/v1/invitations/:id/reject` | Reject invitation |

### GDPR (JWT)

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/api/v1/me/data` | Export personal data (DSAR Art. 15/20) |
| POST | `/api/v1/me/restrict` | Restrict processing (Art. 18) |
| DELETE | `/api/v1/me/restrict` | Lift restriction |
| POST | `/api/v1/me/object` | Right to object (Art. 21) |
| DELETE | `/api/v1/me/object` | Restore consent |
| GET | `/api/v1/consents` | List consents |
| POST | `/api/v1/consents` | Grant consent |
| DELETE | `/api/v1/consents/:id` | Revoke consent |

### Token & Project (API Key)

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/api/v1/project` | View current project |
| PATCH | `/api/v1/project` | Update project |
| GET | `/api/v1/token` | View API Key prefix |
| POST | `/api/v1/token/regenerate` | Regenerate API Key (shown once) |

### Streaming (API Key)

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/api/v1/stream` | Server-Sent Events (real-time) |

### Health (Public)

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/health` | System status (database, jobs, cache, backup) |

---

## Dashboard

Real-time LiveView dashboard at `/platform` with modular architecture:

| Tab | Features |
|-----|----------|
| **Overview** | KPIs (events today, success rate), uptime (24h/7d/30d), analytics charts, recent events, recent deliveries, dead letters, sandbox |
| **Events** | Full list with pagination, event simulation, replay modal, real-time updates via PubSub |
| **Webhooks** | Create/edit/deactivate webhooks, per-webhook health, circuit breaker status, batch configuration |
| **Jobs** | Create/edit/deactivate jobs (daily/weekly/monthly/cron), cron expression preview, execution history |
| **Settings** | Rename project, API key (show/regenerate), event schemas, team management (invite/roles/remove), pending invitations |

Cross-cutting features:
- **Project selector** with URL persistence (`?project=ID`)
- **Notification bell** with real-time unread badge
- **Loading overlay** when switching projects
- Fully **responsive** (mobile-first)
- **Dark mode** support across all pages

### User Account (`/account`)

- Change email, password (with visual strength indicator), name
- **MFA/TOTP**: enable with QR code, verify, backup codes, disable
- **Sessions**: list active devices, revoke individual or all sessions
- **GDPR consents**: view, revoke, restrict processing
- Delete account
- Resend email verification

### Admin Panel (`/admin`)

- Dashboard: total users, projects, events, system metrics
- User management: activate/deactivate accounts, functional search
- Project management: view details per project
- Platform settings

---

## Security

| Feature | Description |
|---------|-------------|
| **Password hashing** | Memory-hard algorithm (OWASP recommended) with automatic legacy rehashing |
| **Encryption at rest** | Industry-standard encryption for sensitive data (email, name, MFA secret) |
| **Secure lookups** | Deterministic hashing for searching encrypted fields |
| **JWT** | Tokens with expiration, unique ID tracking, session revocation |
| **MFA/TOTP** | Two-factor authentication with QR code, single-use backup codes |
| **Account lockout** | Temporary lockout after multiple failed attempts, auto-unlock |
| **Rate limiting** | Per-IP limiting on sensitive routes (login, registration, API, MFA) |
| **API Key scopes** | Granular permissions: `events:read`, `events:write`, `webhooks:*`, `jobs:*`, `deliveries:*`, `analytics:read` |
| **IP allowlist** | Per-API Key IP restriction |
| **Circuit breaker** | Automatic per-webhook protection on consecutive failures |
| **Anomaly detection** | Continuous monitoring for suspicious patterns (brute force, data exfiltration, coordinated attacks) |
| **Security headers** | CSP (nonce-based), X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy |
| **Webhook signatures** | Each delivery signed with a unique per-webhook secret |
| **Password history** | Prevents reuse of recent passwords |
| **Password blocklist** | Common passwords rejected |
| **Password strength** | Visual strength indicator on signup and password reset |
| **Session timeout** | Automatic expiration on inactivity |
| **Cookie consent** | GDPR-compliant cookie consent banner |
| **Force SSL** | Enabled in production |

---

## GDPR Compliance

| Article | Feature |
|---------|---------|
| **Art. 15/20** | Full personal data export (profile, projects, webhooks, events, deliveries, jobs, sessions, consents, audit) |
| **Art. 17** | Right to erasure: atomic cascade deletion with audit log pseudonymization |
| **Art. 18** | Restriction of processing with stated reason |
| **Art. 21** | Right to object to processing |
| **Consents** | Per-purpose (terms, privacy, data_processing, marketing) with version, IP, and timestamps. Auto-registered at signup |

Data is classified into 4 levels (Public, Internal, Confidential, Restricted) with appropriate access controls for each level.

---

## Webhooks

- **Topic routing**: subscribe webhooks to specific topics
- **Advanced filters**: filter by payload fields
- **5 built-in templates**: Slack (Block Kit), Discord (embeds), Telegram Bot API, generic JSON, Custom
- **Custom body**: Mustache-style template with `{{topic}}`, `{{payload}}`
- **Custom headers** per webhook
- **Configurable retries**: custom backoff and max attempts per webhook
- **Batch delivery**: accumulate events by time window or max size
- **Circuit breaker**: automatically opens on consecutive failures, gradual recovery in half-open state
- **Health metrics**: success rate, average latency, last delivery
- **Signature verification**: each payload signed with the webhook's unique secret

---

## Scheduled Jobs

- **Schedule types**: `daily`, `weekly`, `monthly`, `cron` (any cron expression)
- **Action types**: `emit_event` (inject event into the platform) or `post_url` (HTTP POST to external URL)
- **Configurable payload** per job
- **Execution history**: tracked with status and output
- **Cron preview**: endpoint showing next N executions
- **Automatic notifications** on failure

---

## Event Replay

- Replay events filtered by: topic, date range (`from_date` / `to_date`), specific webhook
- Progress tracking: `processed_events / total_events`
- Real-time broadcast to dashboard via PubSub
- Cancelable at any time
- In-app notification on completion
- States: `pending → running → completed / cancelled`

---

## Sandbox

- Create temporary HTTP endpoints with unique slugs
- Accept any HTTP method (GET, POST, PUT, PATCH, DELETE, etc.)
- Capture full request: method, path, headers, body, query params, IP
- Configurable automatic expiration
- View captured requests in the dashboard
- Automatic periodic cleanup

---

## Pipelines

- Create multi-step event processing workflows
- Configure transformation stages for event payloads
- Test pipelines with sample data before activation
- Full CRUD management via API and dashboard

---

## Teams & Collaboration

- **Roles**: `owner`, `editor`, `viewer`
- **Email invitations** with in-app notification to the invitee
- **Accept/reject** pending invitations
- **Member management**: change roles, remove (owner cannot be removed)
- **Access control**: `viewer` (read-only), `editor` (read + write), `owner` (full + project admin)
- **Multi-project**: a user can own or be a member of multiple projects

---

## Analytics

- **Events per day**: up to 90-day lookback
- **Deliveries per day**: up to 90-day lookback
- **Top topics**: topics by volume (configurable)
- **Per-webhook stats**: total, success, failure, success rate, average latency
- **Dashboard KPIs**: events today, global success rate

---

## Data Export

| Type | Formats | Access |
|------|---------|--------|
| Events | CSV, JSON | API Key (`events:read`) or session |
| Deliveries | CSV, JSON | API Key (`deliveries:read`) or session |
| Jobs | CSV, JSON | API Key (`jobs:read`) or session |
| Audit log | CSV, JSON | API Key or session |
| Personal data (GDPR) | JSON | JWT or session |

Parameter `?format=csv|json&days=N` on all export endpoints.

---

## Real-time Streaming

| Channel | Description |
|---------|-------------|
| **SSE** | `GET /api/v1/stream` — push `event.created` and `delivery.updated` events |
| **WebSocket** | Phoenix Channel `events:<project_id>` — broadcast events and deliveries |
| **PubSub** | Internal for LiveView dashboard: real-time updates, notifications, replay progress |

---

## OpenAPI / Swagger

- OpenAPI 3.0 spec generated from controller annotations
- **Interactive Swagger UI**: `/api/swaggerui`
- **JSON spec**: `/api/openapi`
- Two security schemes: `api_key` (X-Api-Key or Bearer) and `bearer` (JWT)
- Tags: Events, Webhooks, Deliveries, Dead Letters, Replays, Analytics, Jobs, Pipelines, Sandbox, Audit, Auth, GDPR, System

---

## Backups

- **Automated daily backups** with compression
- **Dual storage**: local or cloud object storage (auto-upload if configured)
- **Configurable retention** with automatic cleanup of old backups
- Status visible in `/health` and uptime dashboard
- Tracked in audit log

---

## Uptime & Monitoring

- **Periodic automated health checks**
- Verifies: database, background jobs, cache, backup status
- **Uptime history**: percentage calculated for 24h, 7d, and 30d
- **Admin notifications** when status is degraded
- **Public endpoint**: `GET /health` with current status and detailed checks
- **Continuous anomaly detection** with automatic alerts

---

## Background Workers

The system uses Oban for background processing:

| Category | Type | Description |
|----------|------|-------------|
| **Deliveries** | On demand | Deliver payloads to webhooks via HTTP POST with retry, circuit breaker, and batch |
| **Scheduled jobs** | On demand | Execute scheduled jobs (emit event or POST to URL) |
| **Replay** | On demand | Process event replays with progress broadcast |
| **Deferred events** | Periodic | Process events with scheduled delivery (`deliver_at`) |
| **Batch** | Periodic | Flush batch items when window or size threshold is reached |
| **Purge** | Scheduled | Automatic cleanup of old data (deliveries, sandbox, dead letters) |
| **Backups** | Scheduled | Database backup with compression and optional upload |
| **Monitoring** | Periodic | System health checks with notifications |
| **Security** | Periodic | Anomaly detection in access patterns |
| **Sessions** | Scheduled | Cleanup of revoked and inactive sessions |
| **Emails** | On demand | Transactional email delivery |

---

## Internationalization (i18n)

- **Fully bilingual**: English and Spanish (1,769+ translated strings)
- All visible text uses `gettext()` — no hardcoded strings
- Covers: flash messages, labels, headers, buttons, placeholders, notifications, emails, errors, page titles, meta descriptions
- **Language selector**: `GET /locale/:locale` (stored in session and cookie)
- **Bilingual SEO**: page titles and suffixes translated automatically based on locale

---

## Public Pages & SEO

The platform includes bilingual (EN/ES), responsive, SEO-optimized informational pages:

`/` (landing) · `/pricing` · `/about` · `/faq` · `/contact` · `/changelog` · `/docs` · `/status` · `/terms` · `/privacy` · `/cookies` · `/sitemap.xml`

**SEO features:**
- Canonical tags on all pages
- `hreflang` tags (en/es/x-default)
- Unique meta descriptions per page
- Dynamic Open Graph tags per page
- Dynamic XML sitemap
- Preconnect for external CDNs
- Structured bilingual page titles

---

## CI/CD

### GitHub Actions CI

Runs on push to `main`/`develop` and PRs to `main`:

1. `mix compile --warnings-as-errors`
2. `mix format --check-formatted`
3. **Credo** — static analysis
4. **Sobelow** — security scanner
5. `mix deps.audit` — CVE scanning
6. `mix hex.audit` — retired packages
7. Migrations + `mix test`
8. **Dialyzer** — type checking
9. **Trivy** — container security scan (CRITICAL/HIGH CVEs block merge)

### Deploy

| Environment | Branch | Trigger |
|-------------|--------|---------|
| **Staging** | `develop` | Auto push → Container Registry → Cloud platform |
| **Production** | `main` | Auto push → Container Registry → Cloud platform |

Recommended flow: `develop` (staging) → verify → `main` (production).

---

## Docker

### Development

```bash
cp .env.example .env
# Edit .env with the required secrets

docker compose up --build
```

App at **http://localhost:4000**, PostgreSQL at `localhost:5432`.

```bash
# Migrations (first time)
docker compose exec jobscelis mix ecto.migrate
docker compose exec jobscelis mix run apps/streamflix_core/priv/repo/seeds.exs
```

### Production

Multi-stage Dockerfile:
- **Build stage**: compile assets (`mix assets.deploy`) and create release (`mix release`)
- **Runtime stage**: minimal Alpine image, non-root user, built-in healthcheck

---

## Tech Stack

| Technology | Usage |
|------------|-------|
| **Elixir / OTP** | Language and runtime |
| **Phoenix 1.8** | Web framework and API |
| **Phoenix LiveView 1.1** | Real-time dashboard and interactive pages |
| **Ecto** | ORM and migrations (PostgreSQL) |
| **Oban** | Background jobs (deliveries, replays, cron, purge, backups, monitoring, emails) |
| **Guardian** | JWT authentication |
| **Finch** | HTTP client (connection pooling) |
| **OpenApiSpex** | OpenAPI 3.0 spec generation + Swagger UI |
| **Tailwind CSS v4** | Styles (utility-first, responsive, dark mode) |
| **Resend** | Transactional emails |
| **Cloud Object Storage** | Backup storage (optional) |

---

## Users & Roles

- **Regular user**: registers, creates projects and API Keys. Manages events, webhooks, and jobs from the dashboard.
- **Admin / Superadmin**: access to `/admin` for managing users, projects, and platform metrics.
- **Team roles**: `owner` (full access), `editor` (read + write), `viewer` (read-only).

---

## SDKs & Tools

All SDKs cover **100% of the API** (84+ endpoints) with full documentation.

### Published Packages

| Package | Registry | Install | Version |
|---------|----------|---------|---------|
| **Node.js/TypeScript** | [npm](https://www.npmjs.com/package/@jobcelis/sdk) | `npm install @jobcelis/sdk` | v1.5.0 |
| **CLI** | [npm](https://www.npmjs.com/package/@jobcelis/cli) | `npm install -g @jobcelis/cli` | v2.0.2 |
| **Python** | [PyPI](https://pypi.org/project/jobcelis/) | `pip install jobcelis` | v1.4.0 |
| **Go** | [GitHub](https://github.com/vladimirCeli/go-jobcelis) | `go get github.com/vladimirCeli/go-jobcelis` | v1.1.0 |
| **PHP** | [Packagist](https://packagist.org/packages/jobcelis/sdk) | `composer require jobcelis/sdk` | v1.0.0 |
| **Ruby** | [RubyGems](https://rubygems.org/gems/jobcelis) | `gem install jobcelis` | v1.0.0 |
| **Elixir** | [Hex](https://hex.pm/packages/jobcelis) · [Docs](https://hexdocs.pm/jobcelis) | `{:jobcelis, "~> 1.0"}` | v1.0.0 |
| **C# / .NET** | [NuGet](https://www.nuget.org/packages/Jobcelis) | `dotnet add package Jobcelis` | v1.0.0 |
| **Rust** | [crates.io](https://crates.io/crates/jobcelis) · [Docs](https://docs.rs/jobcelis) | `cargo add jobcelis` | v1.0.0 |
| **Swift** | [GitHub](https://github.com/vladimirCeli/jobcelis-swift) | `.package(url: "...jobcelis-swift", from: "1.0.0")` | v1.0.0 |
| **Java** | [Maven Central](https://repo1.maven.org/maven2/com/jobcelis/jobcelis/1.0.0/) | `com.jobcelis:jobcelis:1.0.0` | v1.0.0 |
| **Dart/Flutter** | [pub.dev](https://pub.dev/packages/jobcelis) | `dart pub add jobcelis` | v1.0.0 |
| **Kotlin** | [Maven Central](https://repo1.maven.org/maven2/com/jobcelis/jobcelis-kotlin/1.0.0/) | `com.jobcelis:jobcelis-kotlin:1.0.0` | v1.0.0 |
| **Terraform** | [Registry](https://registry.terraform.io/providers/vladimirCeli/jobcelis/) | See `required_providers` block | v1.0.0 |
| **GitHub Action** | This monorepo | `uses: vladimirCeli/jobscelis/sdks/github-action@main` | — |

### Quick Start Examples

All SDKs connect to `https://jobcelis.com` by default — you only need your API key.

**Node.js / TypeScript:**

```typescript
import { JobcelisClient } from '@jobcelis/sdk';

const client = new JobcelisClient({ apiKey: 'your_api_key' });
const event = await client.sendEvent({ topic: 'order.created', payload: { order_id: '123' } });
const webhooks = await client.listWebhooks();
```

**Python:**

```python
from jobcelis import JobcelisClient

client = JobcelisClient(api_key="your_api_key")
event = client.send_event("order.created", {"order_id": "123"})
webhooks = client.list_webhooks()
```

**Go:**

```go
import jobcelis "github.com/vladimirCeli/go-jobcelis"

client := jobcelis.NewClient("your_api_key")
event, err := client.SendEvent(ctx, jobcelis.EventCreate{
    Topic:   "order.created",
    Payload: map[string]interface{}{"order_id": "123"},
})
```

**CLI:**

```bash
export JOBCELIS_API_KEY=your_api_key

jobcelis events send --topic order.created --payload '{"order_id":"123"}'
jobcelis webhooks list
jobcelis jobs create --name daily-report --queue default --cron "0 9 * * *"
jobcelis status
```

**PHP:**

```php
use Jobcelis\Client;

$client = new Client(apiKey: 'your_api_key');
$event = $client->sendEvent('order.created', ['order_id' => '123']);
$webhooks = $client->listWebhooks();
```

**Ruby:**

```ruby
require "jobcelis"

client = Jobcelis::Client.new(api_key: "your_api_key")
event = client.send_event("order.created", { order_id: "123" })
webhooks = client.list_webhooks
```

**Elixir:**

```elixir
client = Jobcelis.client("your_api_key")
{:ok, event} = Jobcelis.send_event(client, "order.created", %{order_id: "123"})
{:ok, webhooks} = Jobcelis.list_webhooks(client)
```

**C# / .NET:**

```csharp
using Jobcelis;

var client = new JobcelisClient("your_api_key");
var evt = await client.SendEventAsync("order.created", new { order_id = "123" });
var webhooks = await client.ListWebhooksAsync();
```

**Rust:**

```rust
use jobcelis::JobcelisClient;
use serde_json::json;

let client = JobcelisClient::new("your_api_key");
let event = client.send_event("order.created", json!({"order_id": "123"})).await?;
let webhooks = client.list_webhooks(50, None).await?;
```

**Swift:**

```swift
import Jobcelis

let client = JobcelisClient(apiKey: "your_api_key")
let event = try await client.sendEvent(topic: "order.created", payload: ["order_id": "123"])
let webhooks = try await client.listWebhooks()
```

**Java:**

```java
import com.jobcelis.JobcelisClient;
import java.util.Map;

var client = new JobcelisClient("your_api_key");
var event = client.sendEvent("order.created", Map.of("order_id", "123"));
var webhooks = client.listWebhooks(50, null);
```

**Dart/Flutter:**

```dart
import 'package:jobcelis/jobcelis.dart';

final client = JobcelisClient(apiKey: 'your_api_key');
final event = await client.sendEvent('order.created', {'order_id': '123'});
final webhooks = await client.listWebhooks();
```

**Kotlin:**

```kotlin
import com.jobcelis.JobcelisClient
import kotlinx.coroutines.runBlocking

fun main() = runBlocking {
    val client = JobcelisClient("your_api_key")
    val event = client.sendEvent("order.created", mapOf("order_id" to "123"))
    val webhooks = client.listWebhooks()
    client.close()
}
```

**GitHub Action:**

```yaml
- uses: vladimirCeli/jobscelis/sdks/github-action@main
  with:
    api-key: ${{ secrets.JOBCELIS_API_KEY }}
    topic: deploy.completed
    payload: '{"environment": "production", "version": "${{ github.sha }}"}'
```

**Terraform:**

```hcl
terraform {
  required_providers {
    jobcelis = {
      source = "vladimirCeli/jobcelis"
    }
  }
}

provider "jobcelis" {
  api_key = var.jobcelis_api_key
}

resource "jobcelis_webhook" "slack" {
  url    = "https://hooks.slack.com/services/..."
  topics = ["order.created", "payment.failed"]
}

resource "jobcelis_job" "daily_report" {
  name            = "daily-report"
  queue           = "default"
  cron_expression = "0 9 * * *"
}
```

### API Coverage per SDK

All SDKs (Node, Python, Go, PHP, Ruby, Elixir, C#/.NET, Rust, Swift, Java, Dart, Kotlin) cover all 84 API routes:

- **Auth**: register, login, refresh, MFA verify
- **Events**: send, batch, list, get, delete, simulate
- **Webhooks**: CRUD, health, templates
- **Deliveries**: list, retry
- **Dead Letters**: list, get, retry, resolve
- **Replays**: create, list, get, cancel
- **Jobs**: CRUD, runs, cron preview
- **Pipelines**: CRUD, test
- **Event Schemas**: CRUD, validate
- **Sandbox**: CRUD, requests
- **Analytics**: events/day, deliveries/day, top topics, webhook stats
- **Project**: get, update, topics, token, regenerate
- **Projects (multi)**: CRUD, set default
- **Teams**: list, add, update, remove members
- **Invitations**: pending, accept, reject
- **Audit**: list logs
- **Export**: events, deliveries, jobs, audit log
- **GDPR**: consents, data export, restrict, object
- **Health**: status check

The **CLI** covers all routes. The **Terraform Provider** covers 5 resources with full CRUD (webhooks, pipelines, jobs, event schemas, projects). The **GitHub Action** enables sending events from CI/CD workflows.

### External Repositories

The following SDKs live in separate repositories (required by their registries):

| Repo | URL | Reason |
|------|-----|--------|
| **Go** | [go-jobcelis](https://github.com/vladimirCeli/go-jobcelis) | `pkg.go.dev` requires own repo with `go.mod` at root |
| **PHP** | [jobcelis-php](https://github.com/vladimirCeli/jobcelis-php) | Packagist requires `composer.json` at repo root |
| **Ruby** | [jobcelis-ruby](https://github.com/vladimirCeli/jobcelis-ruby) | Public repo for RubyGems and code visibility |
| **Elixir** | [jobcelis-elixir](https://github.com/vladimirCeli/jobcelis-elixir) | Hex.pm requires own repo for publishing |
| **C# / .NET** | [jobcelis-dotnet](https://github.com/vladimirCeli/jobcelis-dotnet) | NuGet requires own repo for publishing |
| **Rust** | [jobcelis-rust](https://github.com/vladimirCeli/jobcelis-rust) | crates.io requires own repo for publishing |
| **Swift** | [jobcelis-swift](https://github.com/vladimirCeli/jobcelis-swift) | Swift Package Manager uses GitHub repo URL directly |
| **Java** | [jobcelis-java](https://github.com/vladimirCeli/jobcelis-java) | Maven Central requires own repo for publishing |
| **Dart/Flutter** | [jobcelis-dart](https://github.com/vladimirCeli/jobcelis-dart) | pub.dev requires own repo for publishing |
| **Kotlin** | [jobcelis-kotlin](https://github.com/vladimirCeli/jobcelis-kotlin) | Maven Central requires own repo for publishing |
| **Terraform** | [terraform-provider-jobcelis](https://github.com/vladimirCeli/terraform-provider-jobcelis) | Terraform Registry requires `terraform-provider-*` naming |

> Canonical source code for all SDKs is in `sdks/` of this monorepo. External repos are synced manually.

---

## License

Business Source License 1.1 (BUSL-1.1) — see [LICENSE](LICENSE) for full terms.

**What this means:**
- You can view, fork, modify, and contribute to the code
- You can use it for your own projects and internal tools
- You **cannot** offer Jobcelis as a hosted/managed service to third parties
- On 2030-03-08, the license automatically converts to Apache 2.0
