# Data Classification Policy — Jobcelis / Streamflix

## 1. Classification Levels

| Level | Label | Description | Examples |
|-------|-------|-------------|----------|
| **L1** | **Public** | Non-sensitive, can be shared freely | Documentation pages, public API specs |
| **L2** | **Internal** | For internal use; no direct PII | Project names, webhook URLs, event types, job schedules |
| **L3** | **Confidential** | Contains PII or sensitive business data | User email, user name, IP addresses, user agents, consent records |
| **L4** | **Restricted** | Secrets, credentials, encryption keys | Password hashes, API key hashes, MFA secrets, JWT tokens, CLOAK_KEY, HMAC_SECRET |

---

## 2. Data Inventory

### Users (`users`)

| Field | Classification | Encrypted | Notes |
|-------|---------------|-----------|-------|
| `id` | L2 Internal | No | UUID, non-PII |
| `email` | L3 Confidential | AES-256-GCM | Encrypted via Cloak.Ecto |
| `email_hash` | L3 Confidential | HMAC-SHA512 | Deterministic hash for lookups |
| `name` | L3 Confidential | AES-256-GCM | Encrypted via Cloak.Ecto |
| `password_hash` | L4 Restricted | Argon2id (memory-hard) | One-way hash |
| `role` | L2 Internal | No | |
| `status` | L2 Internal | No | |
| `mfa_secret` | L4 Restricted | AES-256-GCM | Encrypted via Cloak.Ecto |
| `mfa_backup_codes` | L4 Restricted | No (hashed values) | |
| `locked_at` | L2 Internal | No | |

### Audit Logs (`audit_logs`)

| Field | Classification | Encrypted | Notes |
|-------|---------------|-----------|-------|
| `id` | L2 Internal | No | UUID |
| `action` | L2 Internal | No | |
| `ip_address` | L3 Confidential | AES-256-GCM | Encrypted via Cloak.Ecto |
| `user_agent` | L3 Confidential | AES-256-GCM | Encrypted via Cloak.Ecto |
| `metadata` | L2 Internal | No | May contain operational data |
| `user_id` | L2 Internal | No | UUID reference |

### Consents (`consents`)

| Field | Classification | Encrypted | Notes |
|-------|---------------|-----------|-------|
| `ip_address` | L3 Confidential | AES-256-GCM | Encrypted via Cloak.Ecto |
| `purpose` | L2 Internal | No | |
| `granted_at` / `revoked_at` | L2 Internal | No | |

### User Sessions (`user_sessions`)

| Field | Classification | Encrypted | Notes |
|-------|---------------|-----------|-------|
| `token_jti` | L4 Restricted | No | JWT identifier |
| `ip_address` | L3 Confidential | No | Stored at session level |
| `user_agent` | L3 Confidential | No | |
| `device_info` | L2 Internal | No | Derived from UA |

### Sandbox Requests (`sandbox_requests`)

| Field | Classification | Encrypted | Notes |
|-------|---------------|-----------|-------|
| `ip` | L3 Confidential | AES-256-GCM | Encrypted via Cloak.Ecto |
| `headers` | L3 Confidential | No | May contain auth headers |
| `body` | L2 Internal | No | |

### API Keys (`api_keys`)

| Field | Classification | Encrypted | Notes |
|-------|---------------|-----------|-------|
| `key_hash` | L4 Restricted | SHA-256 | One-way hash |
| `key_prefix` | L2 Internal | No | First 8 chars for identification |

### Webhooks (`webhooks`)

| Field | Classification | Encrypted | Notes |
|-------|---------------|-----------|-------|
| `secret` | L4 Restricted | AES-256-GCM | Encrypted via Cloak.Ecto |
| `url` | L2 Internal | No | Target endpoint |

### Password History (`password_history`)

| Field | Classification | Encrypted | Notes |
|-------|---------------|-----------|-------|
| `password_hash` | L4 Restricted | Argon2id | One-way hash |

---

## 3. Handling Requirements by Level

| Requirement | L1 Public | L2 Internal | L3 Confidential | L4 Restricted |
|-------------|----------|-------------|------------------|---------------|
| Encryption at rest | No | No | **Required** (AES-256-GCM) | **Required** (AES-256-GCM or one-way hash) |
| Encryption in transit | TLS | TLS | TLS | TLS |
| Access control | Public | Authenticated users | Owner + Admin | System only |
| Audit logging | No | Optional | **Required** | **Required** |
| Data export (GDPR) | N/A | Included | **Included** | Excluded (secrets) |
| Retention limit | None | 90 days (logs) | 90 days (logs) | Per policy |
| Backup encryption | N/A | Recommended | **Required** | **Required** |

---

## 4. Encryption Standards

| Standard | Algorithm | Usage |
|----------|-----------|-------|
| At-rest encryption | AES-256-GCM | All L3/L4 fields via Cloak.Ecto |
| Deterministic hash | HMAC-SHA512 | Email lookups (`email_hash`) |
| Password hashing | Argon2id | Memory-hard, RFC 9106 (OWASP #1) |
| Transit encryption | TLS 1.2+ | Database (Supabase pooler), HTTPS |
| Token signing | HS512 | JWT via Guardian |

---

## 5. Key Management

| Key | Purpose | Storage | Rotation |
|-----|---------|---------|----------|
| `CLOAK_KEY` | AES-256-GCM encryption/decryption | Environment variable | Annual or on compromise |
| `HMAC_SECRET` | Deterministic email hashing | Environment variable | Annual (requires re-hash) |
| `GUARDIAN_SECRET_KEY` | JWT signing | Environment variable | Annual |
| `SECRET_KEY_BASE` | Phoenix session signing | Environment variable | Annual |

### Key Rotation Procedure
1. Generate new key
2. Add new key as primary cipher in Vault config (keep old as secondary)
3. Run `mix cloak.migrate` to re-encrypt all records
4. Remove old cipher after verification

---

## 6. Data Retention

| Data Type | Retention | Purge Mechanism |
|-----------|-----------|-----------------|
| Audit logs | 90 days | `ObanPurgeWorker` (weekly Sunday 3am) |
| Deliveries | 90 days | `ObanPurgeWorker` |
| Dead letters | 30 days | `ObanPurgeWorker` |
| Job runs | 90 days | `ObanPurgeWorker` |
| User sessions | 7 days (active), 7 days (revoked) | `ObanSessionCleanupWorker` (daily 4am) |
| Password history | 5 most recent | Per user, checked on change |
| Consents | Indefinite | Required for GDPR compliance |
| User data | Until account deletion | GDPR erasure on request |

---

## 7. GDPR Compliance

- **Right to Access (Art. 15)**: `/export/my-data` endpoint exports all user PII
- **Right to Erasure (Art. 17)**: Account deletion erases all PII via `GDPR.erase_user/1`
- **Right to Rectification (Art. 16)**: Users can update email and name via `/account`
- **Consent Management**: Granular consent tracking with revocation support
- **Data Minimization**: Only essential PII collected; encrypted at rest

---

*Last updated: 2026-03-07*
*Classification: L2 Internal*
