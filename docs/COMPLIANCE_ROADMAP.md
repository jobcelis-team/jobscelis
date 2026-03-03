# Compliance Roadmap: SOC 2, GDPR, HIPAA

> **Fecha:** 2026-03-07
> **Estado:** En progreso — SOC 2 ~95%, GDPR ~90% (Art. 15-21 + cookies + ROPA + notificación 72h)
> **Costo:** $0 — solo tiempo de desarrollo
> **Estimación total:** ~27-30 días de trabajo

---

## Estado actual — Lo que YA tenemos

| Capacidad | Estado | Archivos clave |
|---|---|---|
| Audit log inmutable | **Listo** | `audit.ex`, `audit_log.ex` |
| Cifrado en reposo (AES-256-GCM) | **Listo** | `vault.ex`, `encrypted/binary.ex` |
| RBAC (roles + scopes) | **Listo** | `project_member.ex`, `require_scope.ex` |
| Autenticación segura (PBKDF2 210K) | **Listo** | `user.ex`, `auth_controller.ex` |
| Rate limiting | **Listo** | `rate_limit.ex` |
| IP allowlist | **Listo** | `api_key.ex`, `api_key_auth.ex` |
| Security headers (CSP, HSTS, etc.) | **Listo** | `security_headers.ex` |
| Retención de datos + purga | **Listo** | `oban_purge_worker.ex` |
| Exportación de datos (CSV/JSON) | **Listo** | `platform_export_controller.ex` |
| Soft deletes | **Listo** | Schemas generales |
| Logging estructurado (JSON) | **Listo** | `prod.exs` con LoggerJSON |
| Eliminación de cuenta | **Listo** | `auth_controller.ex` |
| Sesiones firmadas + cifradas | **Listo** | `endpoint.ex` |
| HMAC-SHA256 en webhooks | **Listo** | `delivery_worker.ex` |
| Gestión de sesiones (listar/revocar) | **Listo** | `user_session.ex`, `account_live.ex` |
| Cifrado PII (AES-256-GCM + HMAC) | **Listo** | `encrypted/binary.ex`, `hashed/hmac.ex` |
| Clasificación de datos (4 niveles) | **Listo** | `docs/DATA_CLASSIFICATION.md` |
| TLS en BD (Supabase pooler) | **Listo** | `runtime.exs` |

---

## SOC 2 (Type II)

SOC 2 no es una certificación que "compras" — es una auditoría que evalúa controles a lo largo del tiempo. Los 5 Trust Service Criteria son:

### 1. Seguridad (Common Criteria) — ~95% cubierto

**Ya tenemos:**
- Autenticación con hashing fuerte (PBKDF2-SHA512)
- RBAC con roles granulares y scopes por API key
- Rate limiting y IP allowlist
- Security headers completos
- Cifrado de datos sensibles (webhook secrets)
- Audit trail inmutable
- Gestión de sesiones con revocación individual/masiva

**Gaps:**

| Gap | Solución self-hosted | Esfuerzo |
|---|---|---|
| ~~**MFA/TOTP**~~ | ~~Implementar con `nimble_totp` (librería Elixir gratuita). Genera QR con `eqrcode`, valida códigos 6 dígitos. Sin SMS, sin Twilio.~~ | ~~2-3 días~~ **DONE** |
| ~~**Política de sesiones**~~ | ~~Invalidar sesiones inactivas (timeout 30min), listar sesiones activas, forzar logout remoto. Tabla `user_sessions`, revocación por JTI, cleanup worker~~ | ~~1 día~~ **DONE** |
| ~~**Registro de login fallidos**~~ | ~~Guardar en audit_log cada intento fallido con IP, lockout tras N intentos~~ | ~~0.5 días~~ **DONE** |
| ~~**Vulnerability scanning**~~ | ~~`mix sobelow` (ya lo tenemos), `mix deps.audit` para CVEs en dependencias. Automatizar en CI~~ | ~~~0.5 días~~ **DONE** |
| ~~**Política de contraseñas mejorada**~~ | ~~Bloquear contraseñas comunes (lista top 10K), historial de contraseñas (no reusar últimas 5)~~ | ~~~1 día~~ **DONE** |

### 2. Disponibilidad — ~85% cubierto

**Ya tenemos:**
- Finch connection pooling
- Oban para procesamiento async
- Retry automático en deliveries

**Gaps:**

| Gap | Solución self-hosted | Esfuerzo |
|---|---|---|
| ~~**Health check endpoint**~~ | ~~`GET /health` que verifique DB, Oban, Cachex. Devuelve JSON con estado de cada servicio~~ | ~~0.5 días~~ **DONE** |
| ~~**Uptime monitoring**~~ | ~~Cron job propio que hace ping al health check cada 5 min y registra en DB. Dashboard con uptime %~~ | ~~1-2 días~~ **DONE** |
| ~~**Backup de BD**~~ | ~~Script `pg_dump` automatizado con cron. Guardar en disco local o segundo servidor. Probar restore mensualmente~~ | ~~1 día~~ **DONE** |
| ~~**Incident response plan**~~ | ~~Documento markdown con: severidades, contactos, pasos de respuesta, templates de comunicación~~ | ~~1 día~~ **DONE** |
| ~~**Circuit breaker**~~ | ~~Implementar circuit breaker propio para llamadas a webhooks externos (5 fallos → open 5min)~~ | ~~1 día~~ **DONE** |

### 3. Integridad del procesamiento — ~95% cubierto

**Ya tenemos:**
- Eventos inmutables con timestamps
- Audit log de todas las operaciones
- Validaciones con changesets
- Delivery tracking con estados

**Gaps:**

| Gap | Solución self-hosted | Esfuerzo |
|---|---|---|
| ~~**Checksums de integridad**~~ | ~~Hash SHA256 del payload en cada evento para detectar tampering~~ | ~~~0.5 días~~ **DONE** |
| ~~**Idempotency keys**~~ | ~~Ya tenemos `idempotency_key` en eventos — verificar enforcement completo~~ | ~~~0.5 días~~ **DONE** |

### 4. Confidencialidad — ~90% cubierto

**Ya tenemos:**
- Cifrado AES-256-GCM para secrets
- API keys hasheadas (SHA256)
- Sesiones cifradas
- CORS configurado
- Cifrado PII: emails, nombres, IPs, user-agents (AES-256-GCM via Cloak.Ecto)
- HMAC-SHA512 para lookups de email sin exponer plaintext
- Clasificación de datos documentada (4 niveles: Public, Internal, Confidential, Restricted)
- TLS activo en conexión a BD (Supabase pooler con `ssl: [verify: :verify_none]`)

**Gaps:**

| Gap | Solución self-hosted | Esfuerzo |
|---|---|---|
| ~~**Cifrado de más campos**~~ | ~~Extender `Encrypted.Binary` a: emails, names, IPs en audit log, consents, sandbox requests. HMAC para email lookups~~ | ~~1-2 días~~ **DONE** |
| ~~**Clasificación de datos**~~ | ~~Documentar qué datos son: Public, Internal, Confidential, Restricted. Inventario completo por tabla~~ | ~~1 día~~ **DONE** → `docs/DATA_CLASSIFICATION.md` |
| ~~**TLS en BD**~~ | ~~SSL ya activo: `ssl: [verify: :verify_none]` en runtime.exs. Supabase pooler cifra tráfico~~ | **DONE** |

### 5. Privacidad — ~40% cubierto

**Ya tenemos:**
- Eliminación de cuenta
- Exportación de datos
- Soft deletes

**Gaps:** Se solapan con GDPR (ver sección siguiente).

---

## GDPR (Reglamento General de Protección de Datos)

Aplica si procesamos datos de personas en la UE.

### Derechos del interesado (Artículos 15-22)

| Derecho | Estado actual | Solución self-hosted | Esfuerzo |
|---|---|---|---|
| ~~**Acceso (Art. 15)**~~ | ~~Parcial~~ → DSAR v2 completo: perfil, eventos (500), deliveries (500), sesiones (100), GDPR fields | ~~Endpoint `GET /api/v1/me/data`~~ | ~~1-2 días~~ **DONE** |
| ~~**Rectificación (Art. 16)**~~ | Se puede editar perfil (nombre, email, contraseña). Cambios registrados en audit log | Verificado completo | ~~0.5 días~~ **DONE** |
| ~~**Supresión (Art. 17)**~~ | Erasure completo: anonimiza audit logs, notifications; elimina consents, sessions, password_history, memberships, projects + cascade | ~~Derecho al olvido~~ | ~~2 días~~ **DONE** |
| ~~**Portabilidad (Art. 20)**~~ | DSAR v2 con format/schema_version, eventos y deliveries completos, sesiones | ~~Formato máquina-readable~~ | ~~1 día~~ **DONE** |
| ~~**Oposición (Art. 21)**~~ | `processing_consent` flag + enforcement en create_event y DeliveryWorker | ~~Flag processing_consent~~ | ~~1 día~~ **DONE** |
| ~~**Limitación (Art. 18)**~~ | Estado `restricted` + restricted_at/reason + enforcement en workers | ~~Estado restricted~~ | ~~1 día~~ **DONE** |

### Bases legales y consentimiento

| Requisito | Solución self-hosted | Esfuerzo |
|---|---|---|
| **Registro de consentimiento** | Tabla `consents` (user_id, purpose, granted_at, revoked_at, ip, version). Registrar cada aceptación | ~1-2 días |
| ~~**Banner de cookies**~~ | ~~Componente informativo (solo cookies técnicas: sesión + locale). Dismiss con localStorage. Sin opt-in (ePrivacy exempt)~~ | ~~1 día~~ **DONE** |
| **Política de privacidad** | Página `/privacy` con texto gettext bilingüe. Incluir: datos recopilados, base legal, retención, derechos | ~1 día (documentación) |
| ~~**Registro de actividades (Art. 30)**~~ | ~~ROPA completo en `docs/ROPA.md`: 7 actividades, sub-procesadores, medidas Art. 32, derechos. Sección en /docs~~ | ~~1 día~~ **DONE** |

### Seguridad del tratamiento (Art. 32)

| Requisito | Estado | Nota |
|---|---|---|
| Cifrado | **Listo** | AES-256-GCM para todos los campos PII (email, name, IPs, UAs) |
| Seudonimización | No | Separar identificadores de datos |
| Logs de acceso | Si | Audit log cubre esto |
| Pruebas de seguridad | Parcial | Sobelow + deps.audit |

### Brechas de seguridad (Art. 33-34)

| Requisito | Solución self-hosted | Esfuerzo |
|---|---|---|
| ~~**Detección de brechas**~~ | ~~Monitor que detecte: login masivo fallido, export masivo, acceso desde IP inusual. Alertar vía webhook interno~~ | ~~2-3 días~~ **DONE** |
| ~~**Notificación en 72h**~~ | ~~Proceso documentado en `docs/BREACH_NOTIFICATION.md`: timeline 4 fases, templates Art. 33/34, clasificación de severidad (critical/high/medium) en el worker~~ | ~~1 día~~ **DONE** |

---

## HIPAA (Health Insurance Portability and Accountability Act)

HIPAA es el MAS estricto. Aplica si manejamos PHI (Protected Health Information).

### Salvaguardas Administrativas

| Requisito | Solución self-hosted | Esfuerzo |
|---|---|---|
| **Security Officer designado** | Documentar quién es el responsable. Rol formal | ~0.5 días (documentación) |
| **Análisis de riesgo** | Documento que identifique: activos, amenazas, vulnerabilidades, probabilidad, impacto. Revisión anual | ~2 días (documentación) |
| **Plan de contingencia** | Documento: backup, disaster recovery, modo de emergencia, pruebas | ~1 día (documentación) |
| **Training** | Documentar políticas de seguridad. Aunque sea solo una persona, necesita evidencia escrita | ~1 día |
| **BAA (Business Associate Agreement)** | Contrato con Supabase (DB provider). Verificar que Supabase firma BAA para HIPAA | Solo negociación |

### Salvaguardas Técnicas

| Requisito | Estado | Gap | Esfuerzo |
|---|---|---|---|
| ~~**Control de acceso único**~~ | Si — email+password+MFA | ~~Agregar MFA obligatorio para acceso a PHI~~ | **DONE** |
| **Cifrado en tránsito** | Si — HTTPS/TLS | Forzar TLS 1.2+ mínimo | ~0.5 días |
| **Cifrado en reposo** | Parcial | Cifrar TODOS los campos con PHI (no solo webhook secrets) | ~2-3 días |
| **Audit controls** | Si — audit_log | Agregar: quién accedió qué registro específico (access log, no solo mutations) | ~2-3 días |
| **Integridad** | Parcial | HMAC/checksums en registros PHI para detectar alteración | ~1 día |
| **Auto-logoff** | No | Timeout de sesión a 15 minutos de inactividad para usuarios con acceso a PHI | ~0.5 días |
| **Emergency access** | No | Procedimiento de "break glass" para acceso de emergencia con logging especial | ~1-2 días |

### Salvaguardas Físicas

| Requisito | Nota |
|---|---|
| Control de acceso a servidores | Responsabilidad del hosting (Supabase/Fly.io/etc.) |
| Destrucción de medios | Procedimiento documentado para decomisionar discos |

### Requisitos críticos de HIPAA

| Requisito | Solución self-hosted | Esfuerzo |
|---|---|---|
| **Access logging granular** | Cada `READ` de un registro con PHI debe loguearse: quién, qué, cuándo, desde dónde. No solo escrituras — LECTURAS también | ~3-4 días |
| **Minimum necessary** | Cada endpoint devuelve SOLO los campos que el rol necesita. Field-level filtering basado en scope/rol | ~2-3 días |
| **De-identification** | Capacidad de anonimizar PHI para analytics/reportes (Safe Harbor o Expert Determination) | ~2 días |

---

## Plan de implementación por niveles

### Nivel 1 — Quick wins (beneficia a los 3 frameworks)

| Item | Beneficia | Esfuerzo |
|---|---|---|
| ~~MFA con `nimble_totp` + `eqrcode`~~ | SOC2 + HIPAA + GDPR | ~~2-3 días~~ **DONE** |
| ~~Health check endpoint~~ | SOC2 | ~~0.5 días~~ **DONE** |
| ~~Backup automatizado (pg_dump + cron)~~ | SOC2 + HIPAA | ~~1 día~~ **DONE** |
| ~~Login failed tracking + lockout~~ | SOC2 + HIPAA | ~~0.5 días~~ **DONE** |
| ~~Session timeout configurable~~ | SOC2 + HIPAA | ~~0.5 días~~ **DONE** |
| **Subtotal** | | **~5 días** |

### Nivel 2 — Derechos de datos (principalmente GDPR)

| Item | Beneficia | Esfuerzo |
|---|---|---|
| Tabla de consentimientos | GDPR | ~1-2 días |
| Right to erasure (anonimización) | GDPR + HIPAA | ~2 días |
| Data subject access request (DSAR) | GDPR | ~1-2 días |
| Política de privacidad (página) | GDPR | ~1 día |
| **Subtotal** | | **~6 días** |

### Nivel 3 — Hardening (principalmente HIPAA)

| Item | Beneficia | Esfuerzo |
|---|---|---|
| Access logging (lecturas) | HIPAA + SOC2 | ~3-4 días |
| Cifrado de todos los campos PII | HIPAA + GDPR + SOC2 | ~2-3 días |
| Field-level access control | HIPAA | ~2-3 días |
| Breach detection básico | GDPR + SOC2 | ~2-3 días |
| **Subtotal** | | **~10-13 días** |

### Nivel 4 — Documentación (requerida por los 3)

| Documento | Beneficia | Esfuerzo |
|---|---|---|
| Análisis de riesgo | SOC2 + HIPAA | ~2 días |
| Plan de incident response | SOC2 + HIPAA + GDPR | ~1 día |
| Clasificación de datos | SOC2 + HIPAA + GDPR | ~1 día |
| Registro de actividades (Art. 30) | GDPR | ~1 día |
| Políticas de seguridad | SOC2 + HIPAA | ~1 día |
| **Subtotal** | | **~6 días** |

---

## Librerías necesarias (todas gratuitas/open source)

| Librería | Propósito |
|---|---|
| `nimble_totp` | Generación y validación de códigos TOTP para MFA |
| `eqrcode` | Generar QR codes para configurar authenticator apps |
| `fuse` | Circuit breaker pattern (opcional) |
| Todo lo demás | Elixir/Phoenix puro + PostgreSQL |

## Lo que NO necesitamos pagar

- **No Auth0/Okta** — MFA propio con `nimble_totp`
- **No Datadog/Splunk** — LoggerJSON + queries al audit_log
- **No Vanta/Drata** — documentación propia en markdown + docs page
- **No AWS KMS** — Cloak Vault con key propia (ya implementado)
- **No PagerDuty** — webhook interno al propio sistema de alertas

---

## Resumen ejecutivo

| Framework | Cobertura actual | Después de implementar todo |
|---|---|---|
| **SOC 2** | ~95% | ~95% |
| **GDPR** | ~90% | ~95% |
| **HIPAA** | ~35% | ~85% |

> **Nota:** El 100% en HIPAA y SOC2 requiere auditoría externa y controles organizacionales
> que van más allá del software (políticas de RRHH, seguridad física, etc.).
> El software puede cubrir los controles técnicos casi al 100%.

---

## Seguridad en Supabase (Prioridad URGENTE)

### Problema detectado

La app se conecta a Supabase **directamente por PostgreSQL** vía Ecto (puerto 6543, pooler).
**NO usamos** la REST API de Supabase (PostgREST) para nada.

Sin embargo, Supabase expone automáticamente una REST API en:
```
https://<project-ref>.supabase.co/rest/v1/
```

Con RLS deshabilitado + anon key pública, **cualquier persona puede leer/escribir/borrar TODAS las tablas**
a través de esa API REST, sin necesidad de autenticarse en nuestra app.

### Tablas expuestas (18 propias + Oban)

```
users              projects           api_keys
webhooks           webhook_events     deliveries
jobs               job_runs           dead_letters
notifications      replays            audit_logs
sandbox_endpoints  sandbox_requests   event_schemas
project_members    batch_items        user_tokens
oban_jobs          oban_peers
```

### Arquitectura de conexión actual

```
┌─────────────────┐     PostgreSQL directo (Ecto)     ┌──────────────────┐
│   Phoenix App   │ ──────────────────────────────────>│   Supabase DB    │
│   (puerto 4000) │     puerto 6543 (pooler)           │   (PostgreSQL)   │
└─────────────────┘     TLS activo, verify_none        └──────────────────┘
                                                              │
                                                              │ PostgREST
┌─────────────────┐     REST API (NO la usamos)        ┌──────┴───────────┐
│   Atacante con   │ ──────────────────────────────────>│   REST API       │
│   anon key      │     RLS DESHABILITADO = ABIERTO    │   /rest/v1/*     │
└─────────────────┘                                    └──────────────────┘
```

### Plan de acción — Qué hacer en Supabase (Dashboard web)

#### Paso 1: Regenerar API keys (URGENTE — 2 min)

Las keys fueron expuestas. Ir a:
- **Supabase Dashboard > Settings > API**
- Regenerar anon key y service_role key
- Actualizar `.env` local con las nuevas keys (aunque no las usemos en Ecto,
  Supabase las mantiene activas)

#### Paso 2: Habilitar RLS en TODAS las tablas (10 min)

Ir a **Supabase Dashboard > SQL Editor** y ejecutar:

```sql
-- ============================================
-- HABILITAR RLS EN TODAS LAS TABLAS
-- Sin políticas = nadie accede vía REST API
-- La app Ecto NO se ve afectada (conecta como
-- usuario postgres = superuser, bypasea RLS)
-- ============================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE project_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE webhooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE webhook_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE dead_letters ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE replays ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE sandbox_endpoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE sandbox_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_schemas ENABLE ROW LEVEL SECURITY;
ALTER TABLE batch_items ENABLE ROW LEVEL SECURITY;

-- Oban tables (si aplica)
ALTER TABLE oban_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE oban_peers ENABLE ROW LEVEL SECURITY;
```

**Por qué funciona sin romper nada:**
- RLS habilitado SIN políticas = ningún acceso para roles `anon` y `authenticated`
- Tu app Ecto conecta como usuario `postgres.watjjicqcnbbviwazxqu` que es owner/superuser
- Los superusers **SIEMPRE bypasean RLS** en PostgreSQL
- Resultado: REST API bloqueada, app Ecto sigue funcionando normal

#### Paso 3: Revocar permisos de roles de Supabase (5 min)

Doble barrera — quitar permisos directamente a los roles que usa PostgREST:

```sql
-- ============================================
-- REVOCAR PERMISOS DE ROLES DE SUPABASE
-- Estos roles son usados por la REST API.
-- No afecta a la app Ecto (usa rol postgres).
-- ============================================

-- Revocar permisos del rol anon (key pública)
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon;

-- Revocar permisos del rol authenticated
-- (solo necesario si NO usamos Supabase Auth, que es nuestro caso)
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM authenticated;

-- Revocar USAGE del schema para estos roles
REVOKE USAGE ON SCHEMA public FROM anon;
REVOKE USAGE ON SCHEMA public FROM authenticated;
```

#### Paso 4: Verificar que la app sigue funcionando

Después de ejecutar los pasos 2 y 3:

1. Reiniciar la app Phoenix: `mix phx.server`
2. Verificar que login, dashboard, API endpoints funcionan normal
3. La app conecta como postgres (superuser) — no debe verse afectada

#### Paso 5: Verificar que la REST API está bloqueada

Probar que ya no se puede acceder vía REST API:

```bash
# Esto DEBE devolver error o array vacío (no datos reales)
curl https://<project-ref>.supabase.co/rest/v1/users \
  -H "apikey: <nueva-anon-key>" \
  -H "Authorization: Bearer <nueva-anon-key>"

# Respuesta esperada:
# [] (vacío) o error 403/401
```

### SSL/TLS — Estado actual

| Aspecto | Estado | Detalle |
|---|---|---|
| **TLS activo** | Si | Conexión al pooler es cifrada |
| **Verificación de certificado** | No (`verify_none`) | Normal con el pooler de Supabase |
| **Costo** | $0 | SSL viene incluido en plan gratuito |
| **Puerto** | 6543 | PgBouncer pooler (no conexión directa 5432) |

**Configuración actual en la app:**
```elixir
ssl: [verify: :verify_none],
prepare: :unnamed
```

**Explicación:**
- `verify: :verify_none` = el tráfico SÍ está cifrado con TLS, solo que no verifica
  la identidad del certificado del servidor (aceptable con el pooler de Supabase)
- `prepare: :unnamed` = requerido por PgBouncer para evitar errores de prepared statements
- No hay que pagar nada — SSL ya viene habilitado en Supabase free tier

**Mejora opcional (conexión directa, sin pooler):**
```elixir
# Solo si cambias a puerto 5432 (conexión directa, no pooler)
ssl: [
  verify: :verify_peer,
  cacerts: :public_key.cacerts_get(),
  server_name_indication: ~c"db.<project-ref>.supabase.co"
],
# Nota: sin pooler puedes usar prepared statements normales
# prepare: :unnamed ya no sería necesario
```

### Qué hacer en el CÓDIGO de la app

| Cambio | Dónde | Necesario | Esfuerzo |
|---|---|---|---|
| Nada para RLS/permisos | — | No | 0 min |
| Actualizar anon key en `.env` | `.env` local | Solo si regeneras keys | 1 min |
| Remover `SUPABASE_ANON_KEY` de `.env` | `.env` | Recomendado (no la usamos) | 1 min |
| Mejorar SSL a `verify_peer` | `dev.exs`, `runtime.exs` | Opcional | 15 min |

**Conclusión:** Todos los cambios de seguridad se hacen en el **Dashboard de Supabase** (SQL Editor).
La app Phoenix no necesita cambios de código. La conexión Ecto sigue funcionando igual
porque usa el rol postgres (superuser) que ignora RLS y REVOKE.

### Checklist resumen

- [x] Regenerar API keys en Supabase Dashboard
- [x] Ejecutar SQL: habilitar RLS en las 20 tablas
- [x] Ejecutar SQL: revocar permisos de anon y authenticated
- [x] Deshabilitar legacy JWT keys (anon/service_role)
- [x] Verificar que la app Phoenix sigue funcionando (`mix ecto.migrate` OK)
- [x] Verificar que la REST API ya no expone datos (`permission denied` confirmado)
- [x] Remover SUPABASE_ANON_KEY del `.env` y `.env.example`
- [ ] (Opcional) Click "Create ensure_rls trigger" para auto-RLS en tablas futuras
- [ ] (Opcional) Evaluar deshabilitar la Data API completa si Supabase lo permite

### Verificación por entorno (2026-03-02)

Todos los entornos fueron verificados después de aplicar RLS + REVOKE + disable legacy keys.

#### Cómo conecta cada entorno

| Entorno | BD usada | Config file | Conexión | Afectado por RLS |
|---|---|---|---|---|
| **Local** (`mix phx.server`) | Supabase pooler | `dev.exs` | `DB_*` vars separadas (fallback) | No — superuser ignora RLS |
| **Docker** (`docker-compose`) | PostgreSQL 17 local | `dev.exs` | Servicio `db` local | No — BD diferente |
| **CI** (GitHub Actions) | PostgreSQL 16 local | `test.exs` | `localhost:5432/streamflix_test` | No — BD diferente |
| **Producción** (Azure App Service) | Supabase pooler | `runtime.exs` | `DATABASE_URL` (requerida) | No — superuser ignora RLS |

#### Diferencia crítica: `DATABASE_URL` vs `DB_*` variables

```
dev.exs (desarrollo):
  ¿Existe DATABASE_URL? → usarla
  ¿No existe?           → usar DB_USERNAME, DB_PASSWORD, DB_HOSTNAME, DB_PORT, DB_DATABASE
  Nuestro caso local: NO tenemos DATABASE_URL en .env → usa DB_* variables

runtime.exs (producción):
  ¿Existe DATABASE_URL? → usarla
  ¿No existe?           → raise "missing" (la app NO arranca)
  Nuestro caso Azure: SÍ tiene DATABASE_URL configurada
```

#### Variables de entorno en Azure App Service (verificadas 2026-03-02)

```
az webapp config appsettings list --name jobcelis --resource-group jobscelis-rg

Variables presentes:
  DATABASE_URL           → ecto://postgres.xxx:***@aws-1-us-east-1.pooler.supabase.com:6543/postgres
  SECRET_KEY_BASE        → presente (requerida por runtime.exs)
  GUARDIAN_SECRET_KEY    → presente (requerida por runtime.exs)
  CLOAK_KEY              → presente (cifrado at-rest AES-256-GCM)
  PHX_HOST               → presente (jobcelis.com)
  PORT                   → presente (4000)
  RESEND_API_KEY         → presente (email delivery)
  MAILER_FROM_EMAIL      → presente
  MAILER_FROM_NAME       → presente
  SESSION_SIGNING_SALT   → presente

Variables NO necesarias en Azure (no se usan en producción):
  SUPABASE_ANON_KEY      → no existe (correcto — no se usa)
  SUPABASE_URL           → no existe (correcto — no se usa)
  DB_USERNAME/PASSWORD/etc → no existe (se usa DATABASE_URL en su lugar)
```

#### SSL/TLS por entorno

| Entorno | TLS activo | Verificación cert | Config |
|---|---|---|---|
| **Local** | Si (pooler) | `verify_none` | `dev.exs` — aceptable para desarrollo |
| **Docker** | No (localhost) | N/A | PostgreSQL local sin SSL |
| **CI** | No (localhost) | N/A | PostgreSQL local sin SSL |
| **Producción** | Si (pooler) | `verify_none` | `runtime.exs` — aceptable con Supabase pooler |

**Nota sobre `verify_none`:** La conexión SÍ está cifrada con TLS. `verify_none` solo
significa que no verifica la cadena de certificados CA del servidor. El pooler de Supabase
(PgBouncer) usa certificados que no son verificables con `verify_peer` en Alpine Linux.
Supabase documenta esto como el approach correcto para conexiones al pooler (puerto 6543).

#### Producción: `force_ssl` y seguridad HTTP

```elixir
# prod.exs
config :streamflix_web, StreamflixWebWeb.Endpoint,
  force_ssl: [rewrite_on: [:x_forwarded_proto]]  # Azure pone X-Forwarded-Proto: https
```

- Azure App Service termina TLS en el load balancer
- `force_ssl` redirige HTTP → HTTPS usando el header `X-Forwarded-Proto`
- La app escucha en `0.0.0.0:4000` (IPv4) para health checks de Azure
- URL pública: `https://jobcelis.com:443`
