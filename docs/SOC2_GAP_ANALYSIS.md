# SOC 2 Gap Analysis — Jobcelis

## Overview

This document maps Jobcelis controls against SOC 2 Trust Service Criteria (TSC) to identify compliance gaps and remediation plans.

**Assessment date:** 2026-03-06
**Framework:** SOC 2 Type II (Security, Availability, Confidentiality)

## Trust Service Criteria: Security (Common Criteria)

### CC1 — Control Environment

| Control | Status | Evidence |
|---------|--------|----------|
| CC1.1 Management oversight | IN PLACE | CLAUDE.md defines CI rules, code review via PRs |
| CC1.2 Board oversight | GAP | No formal board/governance structure documented |
| CC1.3 Organizational structure | PARTIAL | Umbrella app separation, but no org chart |
| CC1.4 Competency requirements | PARTIAL | CI enforces code quality, no formal training program |

**Remediation:**
- Document organizational structure and roles
- Create a formal code of conduct

### CC2 — Communication and Information

| Control | Status | Evidence |
|---------|--------|----------|
| CC2.1 Internal communication | IN PLACE | CLAUDE.md, MEMORY.md, commit conventions |
| CC2.2 External communication | IN PLACE | SECURITY.md, public docs page, status page |
| CC2.3 Security policies communicated | IN PLACE | SECURITY.md in repository root |

### CC3 — Risk Assessment

| Control | Status | Evidence |
|---------|--------|----------|
| CC3.1 Risk identification | IN PLACE | docs/RISK_ASSESSMENT.md |
| CC3.2 Risk analysis | IN PLACE | Likelihood/impact matrix in risk assessment |
| CC3.3 Fraud risk assessment | GAP | No formal fraud risk analysis |
| CC3.4 Change impact analysis | PARTIAL | CI pipeline catches regressions, no formal change management |

**Remediation:**
- Add fraud risk section to RISK_ASSESSMENT.md
- Document change management process

### CC4 — Monitoring Activities

| Control | Status | Evidence |
|---------|--------|----------|
| CC4.1 Ongoing monitoring | IN PLACE | PromEx metrics, structured logging, health endpoint |
| CC4.2 Deficiency evaluation | IN PLACE | CI pipeline (credo, sobelow, tests, deps.audit) |

### CC5 — Control Activities

| Control | Status | Evidence |
|---------|--------|----------|
| CC5.1 Risk mitigation controls | IN PLACE | Rate limiting, encryption, auth, audit logging |
| CC5.2 Technology general controls | IN PLACE | CI/CD pipeline, automated testing |
| CC5.3 Security policies | IN PLACE | SECURITY.md, CLAUDE.md conventions |

### CC6 — Logical and Physical Access

| Control | Status | Evidence |
|---------|--------|----------|
| CC6.1 Logical access security | IN PLACE | API keys, JWT, session auth, MFA support |
| CC6.2 User authentication | IN PLACE | Memory-hard hashing, lockout, MFA |
| CC6.3 Authorization enforcement | IN PLACE | API key scopes, project isolation, admin checks |
| CC6.4 Access restrictions to data | IN PLACE | PII encryption, email hashing, project scoping |
| CC6.5 Access revocation | IN PLACE | JWT revocation, session management, API key rotation |
| CC6.6 System boundary protection | IN PLACE | Cloudflare, rate limiting, CORS, CSP |
| CC6.7 Access to sensitive data | IN PLACE | Encrypted fields, secrets in env vars |
| CC6.8 Prevention of unauthorized software | IN PLACE | Container-based deploy, Trivy scanning |

### CC7 — System Operations

| Control | Status | Evidence |
|---------|--------|----------|
| CC7.1 Infrastructure monitoring | IN PLACE | Health endpoint, PromEx, status page |
| CC7.2 Anomaly detection | IN PLACE | Breach detection worker, audit logging |
| CC7.3 Security event evaluation | PARTIAL | Logging in place, no formal incident response runbook |
| CC7.4 Incident response | PARTIAL | SECURITY.md defines response times, no runbook |
| CC7.5 Recovery procedures | PARTIAL | Backups verified, no documented disaster recovery plan |

**Remediation:**
- Create incident response runbook
- Document disaster recovery plan with RTO/RPO targets

### CC8 — Change Management

| Control | Status | Evidence |
|---------|--------|----------|
| CC8.1 Change authorization | PARTIAL | PR-based workflow, no formal approval process |
| CC8.2 Change testing | IN PLACE | CI pipeline: compile, format, credo, sobelow, tests |
| CC8.3 Change deployment | IN PLACE | Automated deployment via GitHub Actions |

**Remediation:**
- Require PR approvals before merge (GitHub branch protection)
- Document change management policy

### CC9 — Risk Mitigation

| Control | Status | Evidence |
|---------|--------|----------|
| CC9.1 Vendor risk management | PARTIAL | Using established providers (Azure, Supabase, Cloudflare) |
| CC9.2 Business continuity | PARTIAL | Backups in place, no formal BCP |

**Remediation:**
- Document vendor risk assessments
- Create business continuity plan

## Trust Service Criteria: Availability

| Control | Status | Evidence |
|---------|--------|----------|
| A1.1 Capacity planning | PARTIAL | Load tested with k6, single Azure B1 instance |
| A1.2 Environmental protections | IN PLACE | Cloud-hosted (Azure), managed by provider |
| A1.3 Recovery procedures | PARTIAL | Daily backups, no documented RTO/RPO |

**Remediation:**
- Document RTO/RPO targets in SLA
- Plan scaling strategy (B1 -> B2/S1 based on load test results)

## Trust Service Criteria: Confidentiality

| Control | Status | Evidence |
|---------|--------|----------|
| C1.1 Confidential information identified | IN PLACE | PII fields identified and encrypted |
| C1.2 Confidential information protected | IN PLACE | Encryption at rest, TLS in transit |
| C1.3 Confidential information disposed | IN PLACE | GDPR erasure, event retention policies |

## Gap Summary

| Priority | Gap | Remediation |
|----------|-----|-------------|
| High | No incident response runbook | Create docs/INCIDENT_RESPONSE.md |
| High | No disaster recovery plan | Create docs/DISASTER_RECOVERY.md |
| Medium | No formal change management policy | Add PR approval requirements, document process |
| Medium | No fraud risk analysis | Add section to RISK_ASSESSMENT.md |
| Low | No organizational chart | Document when team grows |
| Low | No vendor risk assessments | Document for Azure, Supabase, Cloudflare |
| Low | No business continuity plan | Create when approaching enterprise customers |

## Compliance Score

| Category | Controls | In Place | Partial | Gap |
|----------|----------|----------|---------|-----|
| Security (CC1-CC9) | 28 | 20 | 6 | 2 |
| Availability (A1) | 3 | 1 | 2 | 0 |
| Confidentiality (C1) | 3 | 3 | 0 | 0 |
| **Total** | **34** | **24 (71%)** | **8 (23%)** | **2 (6%)** |

## Next Steps

1. Create incident response runbook (High priority)
2. Create disaster recovery plan (High priority)
3. Enable GitHub branch protection rules (Medium priority)
4. Schedule next review: Q3 2026
