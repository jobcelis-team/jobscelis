# Deployment Flow — Jobcelis

## Environments

| Environment | URL | Branch | Image | Auto-deploy |
|-------------|-----|--------|-------|-------------|
| **Local** | `http://localhost:4000` | — | — | — |
| **Staging** | `https://jobcelis-staging.azurewebsites.net` | `develop` | `jobscelis:staging` | Push to `develop` |
| **Production** | `https://jobcelis.com` | `main` | `jobscelis:latest` | Push to `main` |

## Deploy Process

```
Local development
    │
    ├── commit changes
    │
    ▼
Staging (develop branch)
    │
    ├── git checkout develop
    ├── git merge main
    ├── git push origin develop
    │   └── GitHub Actions: deploy-staging.yml
    │       ├── Build image → ACR (jobscelis:staging)
    │       └── Restart jobcelis-staging Web App
    │
    ├── Verify at https://jobcelis-staging.azurewebsites.net
    │
    ▼
Production (main branch)
    │
    ├── git checkout main
    ├── git push origin main
    │   └── GitHub Actions: deploy-azure.yml
    │       ├── Build image → ACR (jobscelis:latest)
    │       └── Restart jobcelis Web App
    │
    └── Live at https://jobcelis.com
```

## Commands

### Normal workflow (staging first)

```bash
# 1. Work locally, make changes, commit
git add <files>
git commit -m "feat: description"

# 2. Deploy to staging
git checkout develop
git merge main
git push origin develop

# 3. Verify staging works
# Visit https://jobcelis-staging.azurewebsites.net

# 4. Deploy to production
git checkout main
git push origin main
```

### Quick sync (after pushing to main, keep develop up to date)

```bash
git checkout develop
git merge main
git push origin develop
git checkout main
```

### Hotfix (urgent production fix)

```bash
# Fix and commit on main
git add <files>
git commit -m "fix: urgent fix"
git push origin main

# Then sync develop
git checkout develop
git merge main
git push origin develop
git checkout main
```

## CI Pipeline

On every push to `main` or `develop`, and on PRs to `main`:

1. `mix compile --warnings-as-errors` — zero warnings
2. `mix format --check-formatted` — code formatted
3. `mix credo --min-priority=high` — static analysis
4. `mix sobelow --exit low --app-dir apps/streamflix_web` — security
5. `mix deps.audit` — no known CVEs
6. `mix hex.audit` — no retired packages
7. `mix test` — all tests pass
8. `mix dialyzer` — type checking (non-blocking)
9. **Trivy** — container vulnerability scan (CRITICAL/HIGH block merge)

## Infrastructure

| Component | Service | Details |
|-----------|---------|---------|
| **Hosting** | Azure Web App (B1 Basic) | Canada Central |
| **Container Registry** | Azure ACR (`jobscelisacr`) | Images: `latest`, `staging` |
| **Production DB** | Supabase PostgreSQL | Pooler port 6543 |
| **Staging DB** | Supabase PostgreSQL (us-west-2) | Separate instance |
| **CDN** | Cloudflare → `cdn.jobcelis.com` | Production only |
| **DNS** | Cloudflare | `jobcelis.com`, `cdn.jobcelis.com` |
| **CI/CD** | GitHub Actions | 3 workflows: CI, deploy-azure, deploy-staging |
| **Email** | Resend | `support@jobcelis.com` |
| **Backups** | Azure Blob Storage | Daily at 2am, verified monthly |

## Load Testing

Run against staging (never production) using k6:

```bash
# Health endpoint
k6 run --env BASE_URL=https://jobcelis-staging.azurewebsites.net k6/health_load.js

# Event creation
k6 run --env API_KEY='your_staging_key' --env BASE_URL=https://jobcelis-staging.azurewebsites.net k6/events_load.js

# Webhook listing
k6 run --env API_KEY='your_staging_key' --env BASE_URL=https://jobcelis-staging.azurewebsites.net k6/webhooks_load.js
```
