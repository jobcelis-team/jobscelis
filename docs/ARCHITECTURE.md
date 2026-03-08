# Architecture — Jobcelis

## Overview

Jobcelis is an Event Infrastructure Platform built with Elixir/Phoenix as an umbrella application. It handles event ingestion, webhook delivery, scheduled jobs, and real-time monitoring.

## Umbrella Structure

```
jobscelis/
├── apps/
│   ├── streamflix_core/       # Data layer, schemas, workers, services
│   ├── streamflix_accounts/   # Authentication, users, sessions
│   └── streamflix_web/        # HTTP layer, API, LiveView dashboard
├── config/                    # Configuration (compile-time + runtime)
├── docs/                      # Documentation
├── sdks/                      # Client SDKs (Node.js, Python)
├── cli/                       # Command-line interface
└── k6/                        # Load testing scripts
```

## Dependency Flow (strict)

```
streamflix_web → streamflix_accounts → streamflix_core
```

- `streamflix_core` cannot reference Accounts or Web modules
- `streamflix_accounts` cannot reference Web modules
- `streamflix_web` can reference both

## Data Flow

```
Client                    Jobcelis                         Destination
  │                         │                                 │
  │  POST /api/v1/events    │                                 │
  │────────────────────────>│                                 │
  │                         │  Match topics to webhooks       │
  │                         │  ┌─────────────────────┐        │
  │                         │  │ Oban delivery queue  │        │
  │                         │  └─────────┬───────────┘        │
  │                         │            │                    │
  │                         │            │  POST webhook.url  │
  │                         │            │───────────────────>│
  │                         │            │                    │
  │                         │            │  200 OK            │
  │                         │            │<───────────────────│
  │                         │            │                    │
  │                         │  Record delivery result         │
  │  201 Created            │                                 │
  │<────────────────────────│                                 │
```

## Key Components

### streamflix_core

| Component | Location | Purpose |
|-----------|----------|---------|
| **Platform** | `platform.ex` | Main context — events, webhooks, deliveries, jobs |
| **Schemas** | `schemas/` | Ecto schemas (18+ tables, all binary UUID PKs) |
| **Workers** | `platform/` | Oban background workers (delivery, backup, purge, etc.) |
| **Services** | `services/` | Cloud storage, audit logging |
| **Repo** | `repo.ex` | Database access (PostgreSQL via Supabase) |
| **Vault** | `vault.ex` | Cloak encryption vault (AES-256-GCM) |

### streamflix_accounts

| Component | Purpose |
|-----------|---------|
| **Accounts** | User CRUD, authentication, password hashing (Argon2id) |
| **Guardian** | JWT token management (7-day TTL) |
| **Schemas** | User, UserSession, UserToken, PasswordHistory |

### streamflix_web

| Component | Location | Purpose |
|-----------|----------|---------|
| **API Controllers** | `controllers/api/v1/` | REST API endpoints |
| **LiveView** | `live/` | Real-time dashboard, admin panel, status page |
| **Plugs** | `plugs/` | Auth, rate limiting, CORS, CSP, compression |
| **OpenAPI** | `api_spec.ex`, `schemas.ex` | Auto-generated API documentation |

## Authentication

| Method | Used for | Header |
|--------|----------|--------|
| **API Key** | Platform operations (events, webhooks) | `X-Api-Key: <key>` |
| **JWT** | User operations (projects, teams, GDPR) | `Authorization: Bearer <token>` |
| **Session** | Browser dashboard | Encrypted cookie |

## Background Processing

Oban queues with dedicated workers:

| Queue | Concurrency | Workers |
|-------|-------------|---------|
| `delivery` | 10 | Webhook POST delivery with retry |
| `scheduled_job` | 1 | User-scheduled jobs (cron, interval) |
| `replay` | 3 | Historical event replay |
| `default` | 5 | Backup, purge, uptime, breach detection, batch, delayed events |

## Security Layers

```
Request → Cloudflare (DDoS, CDN)
        → Cloud platform (TLS termination)
        → Phoenix Endpoint (CSP nonce, security headers)
        → Rate Limiter (IP-based + project-based)
        → Authentication (API key or JWT)
        → Scope check (fine-grained permissions)
        → Controller (business logic)
        → Response
```

## Database

- PostgreSQL (Supabase) with connection pooling (PgBouncer port 6543)
- All primary/foreign keys: binary UUIDs
- PII encrypted at rest (Cloak AES-256-GCM)
- Email lookups via HMAC-SHA512 deterministic hash
- Automated daily backups to cloud object storage

## Environments

| Environment | URL | Deploy trigger |
|-------------|-----|----------------|
| Local | `localhost:4000` | `mix phx.server` |
| Staging | Staging environment | Push to `develop` |
| Production | `jobcelis.com` | Push to `main` |
