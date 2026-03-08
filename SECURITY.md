# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest (main branch) | Yes |
| Staging (develop branch) | Best-effort |

## Reporting a Vulnerability

If you discover a security vulnerability in Jobcelis, please report it responsibly.

**Email:** security@jobcelis.com

### What to include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response timeline

| Stage | Timeframe |
|-------|-----------|
| Acknowledgment | Within 24 hours |
| Initial assessment | Within 48 hours |
| Fix development | Within 7 days (critical), 30 days (non-critical) |
| Public disclosure | After fix is deployed |

### What we ask

- Do NOT publicly disclose the vulnerability before we have addressed it
- Do NOT access, modify, or delete data belonging to other users
- Do NOT perform denial-of-service attacks
- Do NOT use automated scanning tools against production without prior approval

### What we commit to

- We will acknowledge your report promptly
- We will keep you informed of our progress
- We will credit you in our changelog (unless you prefer anonymity)
- We will not take legal action against researchers acting in good faith

## Security Measures

### Data Protection

- All data encrypted in transit (TLS 1.2+)
- Sensitive data encrypted at rest using industry-standard encryption
- Database credentials rotated periodically
- PII fields use deterministic hashing for lookups

### Authentication

- Memory-hard password hashing algorithm
- Multi-factor authentication (TOTP) support
- JWT tokens with limited lifetime
- Session timeout after period of inactivity
- Account lockout after multiple failed attempts

### Infrastructure

- Automated vulnerability scanning in CI pipeline
- Dependency auditing for known CVEs
- Static analysis security testing (SAST)
- Rate limiting on all public endpoints
- Content Security Policy (CSP) with nonce-based script execution
- CORS with strict origin whitelist

### Webhook Security

- All webhook deliveries signed with HMAC-SHA256
- Signature verification documented for multiple languages
- Webhook secrets never logged or exposed in API responses

## Scope

The following are in scope for security reports:

- jobcelis.com (production)
- API endpoints (`/api/v1/*`)
- Dashboard and authentication flows
- Webhook delivery and signature verification
- SDKs and CLI tools

The following are out of scope:

- Third-party services (Cloudflare, Supabase, cloud hosting provider)
- Social engineering attacks
- Physical security
- Denial-of-service attacks
