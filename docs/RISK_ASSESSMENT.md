# Risk Assessment — Jobcelis

## Overview

This document identifies key risks to the Jobcelis platform, their likelihood, impact, and the mitigations in place.

## Risk Matrix

| ID | Risk | Likelihood | Impact | Severity | Status |
|----|------|-----------|--------|----------|--------|
| R1 | Database outage | Low | Critical | High | Mitigated |
| R2 | Data breach / unauthorized access | Low | Critical | High | Mitigated |
| R3 | Webhook delivery failure (mass) | Medium | High | High | Mitigated |
| R4 | DDoS attack | Medium | High | High | Mitigated |
| R5 | Dependency vulnerability (CVE) | Medium | Medium | Medium | Mitigated |
| R6 | Secret/key exposure | Low | Critical | High | Mitigated |
| R7 | Account takeover | Low | High | Medium | Mitigated |
| R8 | Data loss (no backup) | Low | Critical | High | Mitigated |
| R9 | Service provider outage (Azure/Supabase) | Low | High | Medium | Accepted |
| R10 | Regulatory non-compliance (GDPR) | Low | High | Medium | Mitigated |

## Detailed Risk Analysis

### R1 — Database Outage

**Description:** PostgreSQL becomes unavailable, blocking all platform operations.

**Mitigations:**
- Managed database with automatic failover (Supabase)
- Connection pooling to handle transient failures
- Health check endpoint monitors database connectivity
- Automated daily backups with verification worker
- Backup restoration tested periodically

**Response plan:** If database is down, health endpoint reports "degraded". Webhook deliveries are queued in Oban and retry automatically when DB recovers.

### R2 — Data Breach / Unauthorized Access

**Description:** Attacker gains access to user data or internal systems.

**Mitigations:**
- PII encrypted at rest with industry-standard encryption
- Email lookups use deterministic hashing (not plaintext)
- API keys hashed before storage
- Fine-grained permission scopes on API keys
- Audit logging for all sensitive operations
- Rate limiting prevents brute-force attacks
- Breach detection worker monitors for anomalies

**Response plan:** Revoke compromised credentials, notify affected users within 72 hours (GDPR), rotate encryption keys, publish incident report.

### R3 — Webhook Delivery Failure (Mass)

**Description:** A bug or downstream outage causes widespread delivery failures.

**Mitigations:**
- Exponential backoff retry with configurable max attempts
- Circuit breaker per webhook URL (prevents hammering failing endpoints)
- Dead letter queue captures permanently failed deliveries
- Event replay allows re-delivery of historical events
- Delivery health monitoring per webhook

**Response plan:** Circuit breaker activates automatically. Failed deliveries land in DLQ. Users can replay events once the issue is resolved.

### R4 — DDoS Attack

**Description:** High-volume traffic overwhelms the platform.

**Mitigations:**
- Cloudflare CDN and DDoS protection in front of application
- Rate limiting at application layer (IP-based and project-based)
- Static assets served via CDN (reduces origin load)
- Azure Web App auto-scaling capabilities

**Response plan:** Cloudflare absorbs volumetric attacks. Application rate limiter blocks abusive IPs. Scale up Azure plan if sustained legitimate traffic.

### R5 — Dependency Vulnerability (CVE)

**Description:** A third-party library has a known security vulnerability.

**Mitigations:**
- `mix deps.audit` and `mix hex.audit` in CI pipeline
- Trivy container scanning for OS-level CVEs
- Dependabot alerts on GitHub repository
- Regular dependency updates

**Response plan:** Update affected dependency immediately. If no patch available, evaluate workarounds or remove dependency.

### R6 — Secret/Key Exposure

**Description:** API keys, database credentials, or encryption keys leaked.

**Mitigations:**
- All secrets in environment variables (never in code)
- `.env` excluded from git via `.gitignore`
- GitHub Secrets for CI/CD pipelines
- API keys show only prefix in dashboard (never full key)
- Webhook secrets never returned in API responses

**Response plan:** Rotate compromised secret immediately. Revoke affected API keys. Audit logs to determine exposure scope.

### R7 — Account Takeover

**Description:** Attacker gains access to a user account.

**Mitigations:**
- Memory-hard password hashing
- Account lockout after multiple failed login attempts
- Multi-factor authentication (TOTP + backup codes)
- Session timeout after inactivity
- Password history prevents reuse

**Response plan:** Lock affected account. Force password reset. Revoke all sessions and API keys. Notify user.

### R8 — Data Loss

**Description:** Critical data permanently lost.

**Mitigations:**
- Automated daily database backups to cloud storage
- Backup verification worker checks backup recency monthly
- Point-in-time recovery available via managed database provider
- Event replay capability for webhook re-delivery

**Response plan:** Restore from most recent backup. Verify data integrity. Identify and fix root cause.

### R9 — Service Provider Outage

**Description:** Azure, Supabase, or Cloudflare experiences an outage.

**Mitigations:**
- Health check endpoint monitors all dependencies
- Status page shows real-time system health
- Multi-region capability planned for future

**Response plan:** Monitor provider status pages. Communicate to users via status page. Evaluate migration if outages are frequent.

### R10 — Regulatory Non-Compliance (GDPR)

**Description:** Platform fails to meet GDPR requirements.

**Mitigations:**
- GDPR data export endpoint (user can download their data)
- GDPR data deletion endpoint (right to be forgotten)
- Consent tracking with timestamps
- Data processing agreement documentation
- Privacy policy accessible from all pages
- PII encryption at rest

**Response plan:** Address compliance gap immediately. Consult legal counsel. Notify supervisory authority if required.

## Review Schedule

This risk assessment is reviewed:
- Quarterly (routine)
- After any security incident
- When significant infrastructure changes are made
- Before major feature releases
