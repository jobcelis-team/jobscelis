# Deployment Flow — Jobcelis

## Environments

| Environment | URL | Branch | Auto-deploy |
|-------------|-----|--------|-------------|
| **Local** | `http://localhost:4000` | — | — |
| **Production** | `https://jobcelis.com` | `main` | Push to `main` |

There is no staging environment: `develop` runs CI only, and production is
reached through a pull request from `develop` to `main`.

## Deploy Process

```
Local development
    │
    ├── commit on a feature branch
    ├── pull request → develop
    │   └── GitHub Actions: ci.yml (compile, format, Credo, Sobelow, tests, Dialyzer, Trivy)
    │
    ▼
develop (integration, CI only)
    │
    ├── pull request develop → main
    │
    ▼
main (production)
    │
    ├── GitHub Actions: deploy.yml
    │   ├── Build image → container registry (jobscelis:latest)
    │   └── Restart the primary host
    ├── Backup host redeploys from main on its own (only when app code changes)
    │
    └── Live at https://jobcelis.com
```

## Commands

### Normal workflow

```bash
# 1. Work on a branch from develop
git switch -c feat/my-change origin/develop
git add <files>
git commit -m "feat: description"
git push -u origin feat/my-change

# 2. Open a pull request to develop and wait for CI
gh pr create --base develop

# 3. Release: pull request develop → main
gh pr create --base main --head develop
```

### Hotfix (urgent production fix)

Same flow with a `fix/...` branch; merge to `develop` and then `develop → main`
as soon as CI passes.

## Production topology

```
Client → https://jobcelis.com → Cloudflare Worker (edge failover proxy)
                                   ├─ primary host
                                   └─ backup host (used when the primary does not answer)
```

- Both hosts run the same release and share one PostgreSQL database.
- Oban runs on both: cron jobs have a single leader and each job is locked
  by the database, so nothing runs twice.
- The Worker forwards the client IP with a shared secret
  (`TRUSTED_PROXY_SECRET`, see `StreamflixWebWeb.Plugs.ClientIp`); every host
  must have the same value.
- Worker source: `infra/cloudflare/failover-worker.js` (deployed in the
  Cloudflare dashboard, not by CI). A cron trigger keeps the backup host awake.

## CI Pipeline

On every push to `main` or `develop`, and on pull requests:

1. `mix compile --warnings-as-errors` — zero warnings
2. `mix format --check-formatted` — code formatted
3. `mix credo --min-priority=high` — static analysis
4. `mix sobelow --exit low --app-dir apps/streamflix_web` — security
5. `mix deps.audit` — no known CVEs
6. `mix hex.audit` — no retired packages
7. `mix test` — all tests pass
8. `mix dialyzer` — type checking
9. **Trivy** — container vulnerability scan (CRITICAL/HIGH block merge)

## Infrastructure

| Component | Service | Details |
|-----------|---------|---------|
| **Hosting** | Cloud platform | Primary + backup container hosts |
| **Edge** | Cloudflare | DNS, proxy and failover Worker |
| **Container Registry** | Container registry | Image: `latest` |
| **Production DB** | Supabase PostgreSQL | Connection pooler |
| **CDN** | Cloudflare → `cdn.jobcelis.com` | Static assets |
| **CI/CD** | GitHub Actions | CI, deploy, releases |
| **Email** | Resend | `support@jobcelis.com` |
| **Backups** | Cloud object storage | Daily, verified monthly |

## Load Testing

Run against a local or dedicated test instance (never production) using k6:

```bash
# Health endpoint
k6 run --env BASE_URL=http://localhost:4000 k6/health_load.js

# Event creation
k6 run --env API_KEY='your_test_key' --env BASE_URL=http://localhost:4000 k6/events_load.js

# Webhook listing
k6 run --env API_KEY='your_test_key' --env BASE_URL=http://localhost:4000 k6/webhooks_load.js
```
