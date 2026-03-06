# Service Level Agreement (SLA) — Jobcelis

## 1. Service Availability

Jobcelis commits to the following uptime targets:

| Metric | Target |
|--------|--------|
| Monthly uptime | 99.9% |
| Maximum scheduled downtime per month | 30 minutes |
| Scheduled maintenance window | Sundays 04:00–06:00 UTC |

### Uptime Calculation

```
Uptime % = ((Total Minutes - Downtime Minutes) / Total Minutes) * 100
```

Downtime is measured from the moment the health endpoint (`/health`) returns non-healthy to when it recovers.

**Exclusions:** Scheduled maintenance, force majeure, third-party outages (DNS, CDN, cloud provider), and customer-caused issues are excluded from uptime calculations.

## 2. API Performance

| Metric | Target |
|--------|--------|
| Event ingestion (POST /api/v1/events) | < 200ms p95 |
| Webhook list/get (GET /api/v1/webhooks) | < 300ms p95 |
| Batch ingestion (POST /api/v1/events/batch) | < 500ms p95 |
| Health check (GET /health) | < 50ms p95 |

Performance targets measured under normal load conditions (< 100 concurrent requests per project).

## 3. Webhook Delivery

| Metric | Target |
|--------|--------|
| First delivery attempt | Within 30 seconds of event ingestion |
| Retry policy | Exponential backoff, configurable max attempts |
| Dead letter queue | Failed deliveries preserved for manual retry |
| Delivery success rate (platform-side) | 99.9% (excluding destination failures) |

**Note:** Delivery success depends on the destination endpoint being available. Jobcelis guarantees the attempt is made, not that the destination accepts it.

## 4. Data Durability

| Metric | Target |
|--------|--------|
| Event data retention | Per project configuration (default: 90 days) |
| Database backups | Daily automated backups |
| Backup verification | Monthly automated verification |
| Point-in-time recovery | Available via database provider |

## 5. Support Response Times

| Severity | Description | Response Time | Resolution Target |
|----------|-------------|---------------|-------------------|
| Critical | Platform down, data loss | 1 hour | 4 hours |
| High | Major feature broken, delivery failures | 4 hours | 24 hours |
| Medium | Minor feature issue, degraded performance | 24 hours | 72 hours |
| Low | Question, feature request | 48 hours | Best effort |

### Support Channels

- **Security issues:** security@jobcelis.com
- **General support:** support@jobcelis.com
- **Status page:** Available at /status on the platform

## 6. Service Credits

If Jobcelis fails to meet the monthly uptime target:

| Monthly Uptime | Credit |
|----------------|--------|
| 99.0% - 99.9% | 10% of monthly fee |
| 95.0% - 99.0% | 25% of monthly fee |
| Below 95.0% | 50% of monthly fee |

### Credit Request Process

1. Submit a credit request within 30 days of the incident
2. Include dates and times of experienced downtime
3. Credits applied to the next billing cycle
4. Credits do not exceed 50% of monthly fee

## 7. Changes to This SLA

Jobcelis reserves the right to modify this SLA with 30 days written notice. Changes do not apply retroactively to incidents that occurred before the change.

## 8. Definitions

- **Downtime:** Period where the platform health endpoint returns non-healthy status for more than 5 consecutive minutes.
- **Scheduled maintenance:** Pre-announced maintenance during the designated window.
- **Platform-side delivery success:** Jobcelis successfully sends the HTTP request to the webhook URL (regardless of destination response).
- **p95:** 95th percentile — 95% of requests complete within this time.
