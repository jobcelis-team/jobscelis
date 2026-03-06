# MASTER PLAN — Jobcelis v2.0

> **Fecha:** 2026-03-05
> **Estado:** Plan completo — sin implementar
> **Objetivo:** Transformar Jobcelis de "webhook tool" a "Event Infrastructure Platform" de nivel enterprise

---

## Tabla de contenidos

1. [Auditoría del estado actual](#1-auditoría-del-estado-actual)
2. [Análisis de gaps técnicos](#2-análisis-de-gaps-técnicos)
3. [Fase 1 — Hardening del core](#3-fase-1--hardening-del-core)
4. [Fase 2 — Features de producto](#4-fase-2--features-de-producto)
5. [Fase 3 — Escalabilidad](#5-fase-3--escalabilidad)
6. [Fase 4 — Ecosistema](#6-fase-4--ecosistema)
7. [Fase 5 — Observabilidad profesional](#7-fase-5--observabilidad-profesional)
8. [Fase 6 — Compliance final](#8-fase-6--compliance-final)
9. [Mejoras de UX/Dashboard](#9-mejoras-de-uxdashboard)
10. [Mejoras de API](#10-mejoras-de-api)
11. [Mejoras de testing](#11-mejoras-de-testing)
12. [Mejoras de infraestructura](#12-mejoras-de-infraestructura)
13. [Mejoras de documentación](#13-mejoras-de-documentación)
14. [Posicionamiento de mercado](#14-posicionamiento-de-mercado)
15. [Roadmap priorizado](#15-roadmap-priorizado)

---

## 1. Auditoría del estado actual

### 1.1 Lo que YA existe (inventario completo)

#### Arquitectura
- Umbrella Elixir con 3 apps: `streamflix_core`, `streamflix_accounts`, `streamflix_web`
- Dependencia estricta: `web -> accounts -> core`
- 1,606 líneas en `platform.ex` (contexto principal)
- 35 migraciones en producción
- 18+ tablas propias + tablas Oban

#### Módulos core (streamflix_core)
| Módulo | Líneas aprox | Función |
|--------|-------------|---------|
| `Platform` | 1,606 | Contexto principal: projects, API keys, events, webhooks, deliveries, jobs, dead letters, replays, sandbox, schemas, analytics, batch, pagination |
| `Teams` | ~200 | Equipos: members, roles (owner/editor/viewer), invitaciones |
| `Notifications` | ~150 | Notificaciones in-app + PubSub broadcast |
| `Audit` | ~100 | Audit log inmutable |
| `GDPR` | ~200 | Art. 15/17/18/21, erasure, DSAR |
| `Uptime` | ~100 | Health checks, uptime tracking |
| `CircuitBreaker` | ~80 | Circuit breaker por webhook (open/half-open/closed) |
| `Vault` | ~30 | Cloak vault AES-256-GCM |

#### Schemas (18 tablas)
| Schema | Campos clave |
|--------|-------------|
| `Project` | name, status, user_id, is_default |
| `ApiKey` | key_hash, prefix, scopes, allowed_ips, project_id |
| `Webhook` | url, topics, filters, secret_encrypted, body_config, retry_config, batch_config, circuit_breaker_state |
| `WebhookEvent` | topic, payload, status, occurred_at, deliver_at, payload_hash, idempotency_key |
| `Delivery` | event_id, webhook_id, status, attempt_number, response_status, response_body, next_retry_at |
| `Job` | name, schedule_type, schedule_config, action_type, action_config, project_id |
| `JobRun` | job_id, status, output, executed_at |
| `DeadLetter` | event_id, webhook_id, original_payload, error_message, resolved |
| `Replay` | project_id, filters, status, total_events, processed_events |
| `SandboxEndpoint` | slug, name, expires_at, project_id |
| `SandboxRequest` | method, path, headers, body, ip, endpoint_id |
| `EventSchema` | topic, schema (JSON Schema), version, project_id |
| `BatchItem` | webhook_id, event_id |
| `AuditLog` | action, user_id, ip_address, user_agent, metadata |
| `Notification` | user_id, type, title, body, read |
| `UptimeCheck` | status, checks, project_id |
| `ProjectMember` | project_id, user_id, role, status |
| `Consent` | user_id, purpose, granted_at, revoked_at, ip_address, version |

#### Workers (11 Oban workers)
| Worker | Schedule | Estado |
|--------|----------|--------|
| `ObanDeliveryWorker` | On demand | Funcional |
| `ObanScheduledJobWorker` | On demand | Funcional |
| `ObanReplayWorker` | On demand | Funcional |
| `ObanDelayedEventsWorker` | Cada minuto | Funcional |
| `ObanBatchWorker` | Cada minuto | Funcional |
| `ObanPurgeWorker` | Domingos 3am | Funcional |
| `ObanBackupWorker` | Diario 2am | Funcional |
| `ObanUptimeWorker` | Cada 5 min | Funcional |
| `ObanBreachDetectionWorker` | Cada 5 min | Funcional |
| `ObanSessionCleanupWorker` | Diario 4am | Funcional |
| `ObanEmailWorker` | On demand | Funcional |

#### API (90+ endpoints)
- 4 endpoints auth (registro, login, refresh, MFA)
- 7 endpoints eventos (CRUD + simulate + topics)
- 7 endpoints webhooks (CRUD + health + templates)
- 2 endpoints deliveries (list + retry)
- 4 endpoints dead letters (CRUD + retry + resolve)
- 4 endpoints replays (CRUD + cancel)
- 7 endpoints jobs (CRUD + runs + cron-preview)
- 4 endpoints sandbox (CRUD + requests)
- 6 endpoints schemas (CRUD + validate)
- 4 endpoints analytics
- 4 endpoints export (CSV/JSON)
- 1 endpoint audit log
- 1 endpoint SSE streaming
- 1 endpoint health check
- 10 endpoints projects/teams/invitations
- 5 endpoints GDPR

#### Dashboard LiveView
- Overview con KPIs, gráficos, eventos/entregas recientes
- Tab Events con paginación y simulación
- Tab Webhooks con health y circuit breaker
- Tab Jobs con cron preview e historial
- Tab Settings con API key, schemas, equipo

#### Seguridad implementada
- Argon2id (RFC 9106)
- AES-256-GCM (Cloak.Ecto) para PII
- HMAC-SHA512 para email lookups
- JWT Guardian con JTI tracking
- MFA/TOTP con NimbleTOTP
- Rate limiting ETS por IP
- IP allowlist por API key
- Circuit breaker por webhook
- CSP nonce-based
- CSRF protection
- Session timeout 30 min
- Account lockout (5 intentos, 15 min)
- Password blacklist + history
- Webhook HMAC-SHA256 signing
- Breach detection automática

#### Compliance
- SOC 2: ~95%
- GDPR: ~90%
- HIPAA: ~35%

#### Documentación existente
| Documento | Contenido |
|-----------|-----------|
| `README.md` | Documentación completa del proyecto |
| `CLAUDE.md` | Reglas de desarrollo |
| `DATA_CLASSIFICATION.md` | Clasificación de datos (4 niveles) |
| `COMPLIANCE_ROADMAP.md` | SOC 2 / GDPR / HIPAA roadmap |
| `ROPA.md` | Registro de actividades GDPR Art. 30 |
| `INCIDENT_RESPONSE.md` | Plan de respuesta a incidentes |
| `BREACH_NOTIFICATION.md` | Proceso notificación Art. 33-34 |
| `LEGAL.md` | Marca y páginas legales |
| `WEBHOOKS_EVENTS_SPEC.md` | Especificación del producto |
| `MANUAL-USUARIO.md` | Manual de usuario |
| `INDICE-DOCUMENTACION.md` | Índice de documentación |

#### CI/CD
- GitHub Actions: compile, format, credo, sobelow, deps.audit, hex.audit, test, dialyzer
- Deploy: Docker multi-stage + Azure Container Registry + Azure Web App
- Auto-migrate on startup

#### Tests actuales (gap crítico)
| Archivo | Cobertura |
|---------|-----------|
| `platform_test.exs` | Existe |
| `page_controller_test.exs` | Existe |
| `error_json_test.exs` | Existe |
| `error_html_test.exs` | Existe |
| `health_controller_test.exs` | Existe |
| `streamflix_accounts_test.exs` | Existe |
| `streamflix_core_test.exs` | Existe |
| **Total: 7 archivos de test** | **Cobertura muy baja** |

### 1.2 Métricas del proyecto

| Métrica | Valor |
|---------|-------|
| Archivos `.ex` | ~100+ |
| Líneas de código estimadas | ~15,000-20,000 |
| Migraciones | 35 |
| Endpoints API | 90+ |
| Workers Oban | 11 |
| Schemas DB | 18 |
| Archivos de test | 7 |
| Documentos | 11 |
| Páginas públicas | 12 |

---

## 2. Análisis de gaps técnicos

### 2.1 Gaps CRÍTICOS (afectan producción)

| # | Gap | Impacto | Prioridad |
|---|-----|---------|-----------|
| G1 | **Cobertura de tests ~10%** | No se puede refactorizar con seguridad. Bugs en producción no se detectan. Empresas serias exigen >80% | P0 |
| G2 | **Platform.ex tiene 1,606 líneas** | Demasiado grande para un solo módulo. Difícil de mantener, testear y navegar | P1 |
| G3 | **No hay batch ingestion** (`POST /events/batch`) | Clientes que envían miles de eventos no pueden hacerlo eficientemente | P1 |
| G4 | **No hay rate limit per-project** | Un proyecto puede abusar y afectar a todos | P1 |
| G5 | **No hay event ordering guarantees** | Eventos pueden llegar fuera de orden al webhook destino | P2 |
| G6 | **Cron parser manual** (~80 líneas) | Parser básico que no soporta ranges, steps, lists (`1-5`, `*/2`, `1,3,5`) | P2 |
| G7 | **No hay retry backoff exponencial real** | El retry config existe pero el backoff es lineal en el worker | P2 |
| G8 | **No hay webhook response logging** | Se guarda response_body pero no headers de respuesta | P3 |
| G9 | **Healthcheck en Dockerfile apunta a `/`** no a `/health` | Health check no preciso | P3 |
| G10 | **No hay API versioning strategy** | Solo v1, sin plan para v2 | P3 |

### 2.2 Gaps de PRODUCTO (limitan adopción)

| # | Gap | Lo que falta | Prioridad |
|---|-----|-------------|-----------|
| P1 | **No hay SDKs** | Sin librerías para Node, Python, Go, Java, Ruby, PHP | P1 |
| P2 | **No hay CLI** | Sin herramienta de línea de comandos | P2 |
| P3 | **No hay event pipelines** | No se puede encadenar: event -> filter -> transform -> delay -> deliver | P2 |
| P4 | **No hay transformaciones avanzadas** | Solo pick/rename/extra. Falta JSONPath, JQ, templates Liquid | P2 |
| P5 | **No hay event versioning** | No se puede tener `order.created v1` y `order.created v2` | P2 |
| P6 | **No hay event search** | No se puede buscar por `payload.user_id=123` o `topic=order.*` | P2 |
| P7 | **No hay retry policies configurables por webhook** | Backoff exponential, linear, fixed — no hay opciones | P2 |
| P8 | **No hay webhook signatures verification docs** | El cliente no sabe cómo verificar la firma | P2 |
| P9 | **No hay topic wildcards** | No soporta `order.*` o `payment.#` | P3 |
| P10 | **No hay event retention policies per-project** | Todos los proyectos tienen la misma retención | P3 |

### 2.3 Gaps de INFRAESTRUCTURA

| # | Gap | Impacto |
|---|-----|---------|
| I1 | **Single point of failure** | Una sola instancia en Azure |
| I2 | **No hay métricas Prometheus/Grafana** | Sin observabilidad real de performance |
| I3 | **No hay distributed tracing** | No se puede seguir un evento end-to-end |
| I4 | **No hay connection pooling tuning** | Pool size fijo (10) sin auto-scaling |
| I5 | **No hay caching distribuido** | Cachex es in-memory single-node |
| I6 | **No hay table partitioning** | Tablas grandes (events, deliveries) sin particiones |
| I7 | **No hay read replicas** | Todas las queries van al mismo DB |
| I8 | **No hay CDN para assets** | Assets servidos desde la misma instancia |
| I9 | **No hay staging environment** | Solo dev y prod |
| I10 | **No hay blue-green deployment** | Deploy directo sin zero-downtime garantizado |

---

## 3. Fase 1 — Hardening del core

**Objetivo:** Solidificar lo que ya existe antes de agregar features nuevas.

### 3.1 Refactorizar Platform.ex (1,606 líneas -> 8 módulos)

Dividir `StreamflixCore.Platform` en módulos especializados:

```
lib/streamflix_core/
├── platform.ex                    # Facade: delega a sub-módulos (< 100 líneas)
├── platform/
│   ├── projects.ex                # create_project, list_projects, delete_project, etc.
│   ├── api_keys.ex                # create_api_key, verify_api_key, regenerate, etc.
│   ├── events.ex                  # create_event, list_events, paginate_events, etc.
│   ├── webhooks.ex                # create_webhook, list_webhooks, build_body, matching, etc.
│   ├── deliveries.ex              # list_deliveries, retry_delivery, paginate_deliveries, etc.
│   ├── jobs.ex                    # create_job, list_jobs, cron parsing, scheduling, etc.
│   ├── dead_letters.ex            # create_dead_letter, retry, resolve, etc.
│   ├── replays.ex                 # create_replay, cancel_replay, etc.
│   ├── sandbox.ex                 # endpoints, requests, slug generation
│   ├── event_schemas.ex           # CRUD schemas, validation
│   ├── analytics.ex               # events_per_day, deliveries_per_day, top_topics, etc.
│   └── cache.ex                   # Cache helpers, invalidation
```

**Patrón:** `Platform` se convierte en facade que delega:
```elixir
defmodule StreamflixCore.Platform do
  defdelegate create_project(attrs), to: StreamflixCore.Platform.Projects
  defdelegate create_event(project_id, body), to: StreamflixCore.Platform.Events
  # ... etc
end
```

Esto mantiene compatibilidad con todo el código existente (no hay breaking changes).

### 3.2 Tests comprehensivos

**Meta: 80%+ de cobertura**

#### Tests por módulo (prioridad por riesgo)

| Módulo | Tests necesarios | Prioridad |
|--------|-----------------|-----------|
| **Platform.Events** | create_event, idempotency, schema validation, delayed events, GDPR restriction, pagination | P0 |
| **Platform.Webhooks** | create, matching (topics, filters), body building (pick/rename/custom), circuit breaker interaction | P0 |
| **Platform.Deliveries** | retry, dead letter creation on max attempts, status transitions | P0 |
| **Accounts** | register, login, MFA flow, lockout, password history, session management | P0 |
| **Platform.ApiKeys** | create, verify, regenerate, scopes, IP allowlist | P1 |
| **Platform.Jobs** | CRUD, cron matching, schedule types, job runs | P1 |
| **Platform.DeadLetters** | retry, resolve, listing | P1 |
| **Platform.Replays** | create, cancel, event counting | P1 |
| **Teams** | create member, roles, invitations, permissions | P1 |
| **GDPR** | erasure, DSAR export, restriction, objection | P1 |
| **Audit** | log creation, immutability | P2 |
| **Notifications** | create, broadcast, mark read | P2 |
| **CircuitBreaker** | state transitions, half-open testing | P2 |
| **Platform.Sandbox** | endpoint creation, request recording, expiration | P2 |
| **Platform.Analytics** | events_per_day, deliveries_per_day, top_topics | P2 |
| **Platform.EventSchemas** | CRUD, JSON Schema validation | P2 |

#### Tests de integración API

| Controller | Tests necesarios |
|-----------|-----------------|
| `AuthController` (API) | Register, login, refresh, MFA verify |
| `AuthController` (browser) | Login, logout, register, forgot/reset password |
| `PlatformEventsController` | CRUD, simulate, pagination |
| `PlatformWebhooksController` | CRUD, health, templates |
| `PlatformDeliveriesController` | List, retry |
| `PlatformJobsController` | CRUD, runs, cron preview |
| `PlatformDeadLettersController` | List, show, retry, resolve |
| `PlatformReplaysController` | CRUD, cancel |
| `PlatformSandboxController` | CRUD, requests |
| `PlatformAnalyticsController` | All 4 endpoints |
| `PlatformExportController` | CSV + JSON for all entities |
| `GDPRController` | Export, restrict, object |
| `PlatformMembersController` | CRUD, invitations |
| `PlatformProjectsController` | CRUD, set default |
| `HealthController` | Status response |

#### Tests de workers

| Worker | Tests necesarios |
|--------|-----------------|
| `ObanDeliveryWorker` | Success, failure, retry, dead letter, circuit breaker, batch |
| `ObanScheduledJobWorker` | emit_event, post_url, failure handling |
| `ObanReplayWorker` | Process events, progress broadcast, cancellation |
| `ObanPurgeWorker` | Purge old records, respect retention |
| `ObanBackupWorker` | pg_dump execution, Azure upload |
| `ObanBreachDetectionWorker` | Brute force detection, anomaly alerts |

#### Test infrastructure necesaria

- **Factory completa** en `test/support/factory.ex`: factories para TODAS las 18 schemas
- **Helpers de auth** para tests API: helper que genera JWT y API key válidos
- **Fixtures de JSON Schema** para tests de validación
- **Mock de HTTP** (Bypass o Mox) para tests de delivery worker

### 3.3 Mejorar cron parser

El parser actual solo soporta `*` y valores exactos. No soporta:

```
*/5         → cada 5 minutos
1-5         → rango
1,3,5       → lista
1-5/2       → rango con step
@daily      → shortcuts
@hourly
```

**Opción A:** Usar librería `crontab` de Hex (madura, probada).
**Opción B:** Extender el parser manual (más trabajo, más bugs).

**Recomendación:** Opción A — usar `crontab` o `quantum` parser.

### 3.4 Fix Dockerfile healthcheck

```dockerfile
# Actual (incorrecto):
HEALTHCHECK CMD curl -f http://localhost:4000/ || exit 1

# Corregido:
HEALTHCHECK CMD curl -f http://localhost:4000/health || exit 1
```

### 3.5 Fix retry backoff

Implementar backoff exponencial real en `ObanDeliveryWorker`:

```
Intento 1: 10s
Intento 2: 30s
Intento 3: 90s
Intento 4: 270s (4.5 min)
Intento 5: 810s (13.5 min)
```

Con jitter aleatorio para evitar thundering herd.

Permitir configuración por webhook:
```json
{
  "retry_strategy": "exponential",  // exponential | linear | fixed
  "base_delay_seconds": 10,
  "max_delay_seconds": 3600,
  "max_attempts": 5,
  "jitter": true
}
```

---

## 4. Fase 2 — Features de producto

### 4.1 Batch event ingestion

**Endpoint:** `POST /api/v1/events/batch`

```json
{
  "events": [
    {"topic": "order.created", "payload": {"id": 1}},
    {"topic": "order.created", "payload": {"id": 2}},
    {"topic": "payment.received", "payload": {"amount": 99.99}}
  ]
}
```

**Respuesta:**
```json
{
  "accepted": 3,
  "rejected": 0,
  "events": [
    {"id": "uuid-1", "topic": "order.created", "status": "accepted"},
    {"id": "uuid-2", "topic": "order.created", "status": "accepted"},
    {"id": "uuid-3", "topic": "payment.received", "status": "accepted"}
  ]
}
```

**Implementación:**
- Máximo 1000 eventos por batch
- Insert con `Repo.insert_all` para eficiencia
- Cada evento pasa por validación de schema individualmente
- Deliveries se crean en batch
- Audit log registra `events.batch_created`

### 4.2 Topic wildcards

Soportar patrones en los topics de los webhooks:

```
order.*          → Matches order.created, order.updated, order.deleted
payment.#        → Matches payment.received, payment.refund.initiated
user.signup      → Exact match (actual)
*                → Matches everything (actual con topics=[])
```

**Implementación:** Modificar `topic_matches?/2` para soportar `*` y `#`:
- `*` = un segmento (split por `.`)
- `#` = uno o más segmentos

### 4.3 Event search / query

**Endpoint:** `GET /api/v1/events/search`

```
GET /api/v1/events/search?q=payload.user_id:123&topic=order.*&from=2026-03-01&to=2026-03-05
```

**Implementación:**
- Query sobre JSONB con operadores PostgreSQL (`->`, `->>`, `@>`)
- Índice GIN en `webhook_events.payload` para performance
- Sintaxis de búsqueda simple: `field:value`, `field:>100`, `field:*keyword*`
- Límite de 1000 resultados

**Migración necesaria:**
```sql
CREATE INDEX idx_webhook_events_payload_gin ON webhook_events USING GIN (payload);
```

### 4.4 Retry policies configurables

Extender `retry_config` en webhooks:

```json
{
  "strategy": "exponential",
  "base_delay": 10,
  "max_delay": 3600,
  "max_attempts": 5,
  "jitter": true,
  "retry_on_status": [500, 502, 503, 504],
  "timeout_ms": 30000
}
```

Estrategias soportadas:
| Estrategia | Fórmula | Ejemplo (base=10s) |
|-----------|---------|-------------------|
| `exponential` | `base * 3^attempt + jitter` | 10s, 30s, 90s, 270s, 810s |
| `linear` | `base * attempt + jitter` | 10s, 20s, 30s, 40s, 50s |
| `fixed` | `base + jitter` | 10s, 10s, 10s, 10s, 10s |

### 4.5 Event retention policies per-project

Agregar a `Project`:
```elixir
field :event_retention_days, :integer, default: 90
field :delivery_retention_days, :integer, default: 90
```

El `ObanPurgeWorker` respeta la configuración por proyecto.

### 4.6 Webhook response logging

Agregar a `Delivery`:
```elixir
field :response_headers, :map  # Headers de respuesta del webhook destino
field :latency_ms, :integer    # Tiempo de respuesta en milisegundos
field :request_body, :string   # Body enviado (para debugging)
```

### 4.7 Event versioning

Agregar a `EventSchema`:
```elixir
field :version, :integer  # Ya existe
field :is_latest, :boolean, default: true
field :migration_rules, :map  # Reglas para migrar v1 -> v2
```

Cuando se crea una nueva versión de schema:
1. La versión anterior se marca como `is_latest: false`
2. Los eventos nuevos se validan contra la versión más reciente
3. Opcionalmente, se pueden definir reglas de migración para transformar eventos antiguos

### 4.8 Rate limiting per-project

Agregar a `Project`:
```elixir
field :rate_limit_events_per_minute, :integer, default: 1000
field :rate_limit_api_calls_per_minute, :integer, default: 500
```

Implementar con Cachex counters:
- Key: `{:rate_limit, project_id, :events, minute_bucket}`
- Increment atómico con `Cachex.incr/3`
- TTL de 120 segundos

Respuesta cuando se excede:
```json
{
  "error": "rate_limit_exceeded",
  "retry_after": 42,
  "limit": 1000,
  "remaining": 0
}
```

Con header `Retry-After` y status `429`.

### 4.9 Webhook signature verification guide

Agregar documentación y ejemplos de verificación para cada lenguaje:

```javascript
// Node.js
const crypto = require('crypto');
const signature = req.headers['x-signature'];
const expected = 'sha256=' + crypto
  .createHmac('sha256', WEBHOOK_SECRET)
  .update(JSON.stringify(req.body))
  .digest('base64');
const valid = crypto.timingSafeEqual(
  Buffer.from(signature), Buffer.from(expected)
);
```

```python
# Python
import hmac, hashlib, base64
expected = 'sha256=' + base64.b64encode(
    hmac.new(WEBHOOK_SECRET.encode(), request.body, hashlib.sha256).digest()
).decode()
valid = hmac.compare_digest(signature, expected)
```

---

## 5. Fase 3 — Escalabilidad

### 5.1 Table partitioning

Las tablas `webhook_events` y `deliveries` crecerán rápido. Particionar por rango de fecha:

```sql
-- Particionar webhook_events por mes
CREATE TABLE webhook_events (
  id uuid PRIMARY KEY,
  ...
  inserted_at timestamptz NOT NULL
) PARTITION BY RANGE (inserted_at);

CREATE TABLE webhook_events_2026_01 PARTITION OF webhook_events
  FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE webhook_events_2026_02 PARTITION OF webhook_events
  FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
-- ...
```

**Worker automático:** `ObanPartitionWorker` que crea particiones para el próximo mes automáticamente.

### 5.2 Read replicas

Configurar Ecto para usar read replicas para queries de lectura:

```elixir
# En Repo
def read_only do
  Ecto.Repo.put_dynamic_repo(__MODULE__.ReadOnly)
end
```

Queries de analytics, listados y exports van a la réplica.
Queries de escritura y transacciones van al primario.

### 5.3 Connection pool tuning

Calcular pool óptimo:
```
pool_size = (cores * 2) + spindle_count
```

Para Azure B1: `pool_size = (1 * 2) + 1 = 3` mínimo, `10` es OK.
Para producción seria: `pool_size = (4 * 2) + 1 = 9` → usar `15-20`.

Agregar `queue_target` y `queue_interval`:
```elixir
config :streamflix_core, StreamflixCore.Repo,
  pool_size: String.to_integer(System.get_env("DB_POOL_SIZE") || "10"),
  queue_target: 5000,
  queue_interval: 1000
```

### 5.4 Caching distribuido

Para multi-nodo, migrar de Cachex (single-node) a Nebulex (distribuido):

```elixir
# Nebulex con adaptador distribuido
defmodule StreamflixCore.Cache do
  use Nebulex.Cache,
    otp_app: :streamflix_core,
    adapter: Nebulex.Adapters.Partitioned
end
```

**Nota:** Solo necesario si se escala a múltiples nodos. Con un solo nodo, Cachex es suficiente.

### 5.5 Async event processing

Para alto throughput, desacoplar ingestion de processing:

```
HTTP Request → Insert event → Return 202 Accepted
                    ↓
              Oban job (async)
                    ↓
         Create deliveries + enqueue
```

Esto ya está parcialmente implementado (Oban workers), pero `create_deliveries_for_event` se ejecuta sincrónicamente dentro de `create_event`. Mover a un worker Oban dedicado.

### 5.6 Database indexes audit

Indexes que podrían faltar o mejorar:

```sql
-- Composite para event search
CREATE INDEX idx_events_project_topic_occurred
  ON webhook_events (project_id, topic, occurred_at DESC);

-- Para delivery worker lookups
CREATE INDEX idx_deliveries_status_webhook
  ON deliveries (status, webhook_id)
  WHERE status IN ('pending', 'retrying');

-- Para batch worker
CREATE INDEX idx_batch_items_webhook
  ON batch_items (webhook_id, inserted_at);

-- GIN para payload search
CREATE INDEX idx_events_payload_gin
  ON webhook_events USING GIN (payload jsonb_path_ops);

-- Para purge worker
CREATE INDEX idx_deliveries_inserted_at
  ON deliveries (inserted_at)
  WHERE inserted_at < NOW() - INTERVAL '90 days';
```

---

## 6. Fase 4 — Ecosistema

### 6.1 SDKs oficiales

#### SDK Node.js / TypeScript

```typescript
import { Jobcelis } from '@jobcelis/sdk';

const client = new Jobcelis({ apiKey: 'wh_...' });

// Enviar evento
await client.events.send({
  topic: 'order.created',
  payload: { order_id: 123, total: 99.99 }
});

// Batch
await client.events.sendBatch([
  { topic: 'order.created', payload: { id: 1 } },
  { topic: 'order.updated', payload: { id: 2 } }
]);

// Listar webhooks
const webhooks = await client.webhooks.list();

// Crear webhook
await client.webhooks.create({
  url: 'https://example.com/hook',
  topics: ['order.*'],
  retryConfig: { strategy: 'exponential', maxAttempts: 5 }
});

// Verificar firma
const isValid = Jobcelis.verifySignature(body, signature, secret);
```

#### SDK Python

```python
from jobcelis import Jobcelis

client = Jobcelis(api_key="wh_...")

# Enviar evento
client.events.send(topic="order.created", payload={"order_id": 123})

# Batch
client.events.send_batch([
    {"topic": "order.created", "payload": {"id": 1}},
    {"topic": "order.updated", "payload": {"id": 2}}
])

# Verificar firma
is_valid = Jobcelis.verify_signature(body, signature, secret)
```

#### SDK Go

```go
client := jobcelis.New("wh_...")

// Enviar evento
client.Events.Send(ctx, &jobcelis.Event{
    Topic:   "order.created",
    Payload: map[string]any{"order_id": 123},
})

// Verificar firma
valid := jobcelis.VerifySignature(body, signature, secret)
```

### 6.2 CLI

```bash
# Instalación
npm install -g @jobcelis/cli
# o
brew install jobcelis

# Configuración
jobcelis config set api-key wh_xxx

# Eventos
jobcelis events send --topic order.created --payload '{"id": 123}'
jobcelis events list --limit 10
jobcelis events search --topic "order.*" --from 2026-03-01

# Webhooks
jobcelis webhooks list
jobcelis webhooks create --url https://example.com/hook --topics "order.*"
jobcelis webhooks health wh-id-123

# Jobs
jobcelis jobs list
jobcelis jobs create --name "Daily report" --schedule "0 8 * * *" --action emit_event

# Sandbox
jobcelis sandbox create
jobcelis sandbox requests sb-slug-123

# Stream
jobcelis stream --topic "order.*"  # SSE en terminal

# Export
jobcelis export events --format csv --days 30 > events.csv
```

### 6.3 Terraform provider

```hcl
provider "jobcelis" {
  api_key = var.jobcelis_api_key
  base_url = "https://jobcelis.com/api/v1"
}

resource "jobcelis_project" "main" {
  name = "My Project"
}

resource "jobcelis_webhook" "slack" {
  project_id = jobcelis_project.main.id
  url        = "https://hooks.slack.com/..."
  topics     = ["order.created", "payment.received"]

  retry_config {
    strategy     = "exponential"
    max_attempts = 5
  }
}

resource "jobcelis_job" "daily_report" {
  project_id    = jobcelis_project.main.id
  name          = "Daily Report"
  schedule_type = "cron"

  schedule_config {
    expression = "0 8 * * *"
  }

  action_type = "post_url"
  action_config {
    url     = "https://example.com/report"
    payload = jsonencode({ type = "daily" })
  }
}
```

### 6.4 Integraciones nativas

| Integración | Tipo | Descripción |
|-------------|------|-------------|
| **Slack** | Webhook template (ya existe) | Mejorar: app OAuth, rich formatting, thread replies |
| **Discord** | Webhook template (ya existe) | Mejorar: embeds con colores por severidad |
| **GitHub** | Nueva | Trigger webhooks en push, PR, issues |
| **Linear** | Nueva | Crear issues desde eventos |
| **PagerDuty** | Nueva | Alertas cuando delivery falla |
| **Datadog** | Nueva | Enviar métricas de eventos/deliveries |
| **Zapier** | Nueva | Trigger Zapier desde cualquier evento |
| **n8n** | Nueva | Self-hosted workflow automation |

---

## 7. Fase 5 — Observabilidad profesional

### 7.1 Métricas Prometheus

Agregar `PromEx` o `TelemetryMetricsPrometheus`:

```elixir
# Métricas clave a exponer
# Counters
events_created_total{project_id, topic}
deliveries_total{project_id, webhook_id, status}
dead_letters_total{project_id}
api_requests_total{method, path, status_code}

# Histograms
delivery_latency_seconds{webhook_id}
event_processing_duration_seconds
api_request_duration_seconds{method, path}

# Gauges
active_webhooks{project_id}
circuit_breaker_state{webhook_id}  # 0=closed, 1=half_open, 2=open
oban_queue_length{queue}
db_pool_size
db_pool_available
```

**Endpoint:** `GET /metrics` (protegido con API key o IP allowlist)

### 7.2 Structured logging mejorado

Agregar metadata contextual a todos los logs:

```elixir
Logger.info("Event created",
  project_id: project_id,
  event_id: event.id,
  topic: event.topic,
  delivery_count: length(matching_webhooks)
)

Logger.warning("Delivery failed",
  delivery_id: delivery.id,
  webhook_id: webhook.id,
  attempt: attempt_number,
  status_code: response_status,
  latency_ms: latency
)
```

### 7.3 Distributed tracing

Agregar `OpenTelemetry` con traces:

```
Trace: event.lifecycle
├── Span: event.ingest (API layer)
├── Span: event.validate (schema validation)
├── Span: event.store (DB insert)
├── Span: event.match (webhook matching)
└── Span: event.deliver (per webhook)
    ├── Span: delivery.prepare (build body)
    ├── Span: delivery.send (HTTP POST)
    └── Span: delivery.record (save result)
```

### 7.4 Dashboard de métricas interno

LiveView page `/admin/metrics` con:
- Eventos por segundo (real-time)
- Latencia de entregas (p50, p95, p99)
- Cola de Oban (pending, executing, completed, failed)
- Health de todos los webhooks en un vistazo
- Top 10 topics por volumen
- Circuit breakers abiertos
- Error rate por webhook

---

## 8. Fase 6 — Compliance final

### 8.1 GDPR completar al 100%

| Item | Estado | Acción |
|------|--------|--------|
| Art. 15 — Acceso | 95% | Agregar timestamps de último acceso a DSAR |
| Art. 16 — Rectificación | 100% | Completo |
| Art. 17 — Supresión | 95% | Verificar cascade completa en todos los edge cases |
| Art. 18 — Limitación | 100% | Completo |
| Art. 20 — Portabilidad | 90% | Agregar formato CSV al DSAR (además de JSON) |
| Art. 21 — Oposición | 100% | Completo |
| Art. 25 — Privacy by design | 80% | Documentar data minimization practices |
| Art. 30 — ROPA | 100% | Completo |
| Art. 33-34 — Breach notification | 100% | Completo |
| Consent management | 90% | Agregar consent versioning y re-consent flow |

### 8.2 SOC 2 completar al 100%

| Control | Estado | Acción |
|---------|--------|--------|
| Seguridad | 95% | Agregar vulnerability scanning automatizado (Trivy en CI) |
| Disponibilidad | 90% | Documentar SLA targets, agregar status page |
| Integridad | 95% | Agregar checksums en exports |
| Confidencialidad | 95% | Auditar que no hay PII en logs |
| Privacidad | 90% | Se solapa con GDPR |

### 8.3 HIPAA (si aplica)

| Control | Estado | Acción |
|---------|--------|--------|
| Access logging (reads) | 0% | Implementar logging de lecturas de PHI |
| Minimum necessary | 0% | Field-level access control por rol |
| BAA con Supabase | 0% | Negociar Business Associate Agreement |
| Emergency access | 0% | Break-glass procedure |
| Auto-logoff PHI | 50% | Ya existe timeout 30min, reducir a 15min para HIPAA |

### 8.4 Nuevos documentos de compliance

| Documento | Contenido |
|-----------|-----------|
| `SECURITY_POLICY.md` | Políticas de seguridad formales |
| `RISK_ASSESSMENT.md` | Análisis de riesgos (activos, amenazas, vulnerabilidades) |
| `SLA.md` | Service Level Agreement (uptime targets) |
| `CHANGE_MANAGEMENT.md` | Proceso de cambios en producción |
| `ACCESS_CONTROL_POLICY.md` | Políticas de acceso y roles |
| `BACKUP_RESTORE.md` | Procedimiento de backup y restauración verificado |
| `PENETRATION_TEST.md` | Resultados de pen testing (pendiente ejecutar) |
| `VULNERABILITY_MANAGEMENT.md` | Proceso de gestión de vulnerabilidades |

---

## 9. Mejoras de UX/Dashboard

### 9.1 Dashboard — Mejoras prioritarias

| Mejora | Descripción | Impacto |
|--------|-------------|---------|
| **Dark mode** | Toggle dark/light mode con persistencia en localStorage | Alto (preferencia de devs) |
| **Keyboard shortcuts** | `k` = navegar arriba, `j` = abajo, `e` = events, `w` = webhooks, `/` = search | Medio |
| **Event detail modal** | Click en evento muestra: payload, deliveries asociadas, timeline completa | Alto |
| **Delivery timeline** | Visualización tipo timeline de cada intento: request, response, latency, status | Alto |
| **Webhook test button** | Botón "Test" en cada webhook que envía un evento de prueba | Alto |
| **Live tail** | Tab "Live" que muestra eventos en tiempo real tipo terminal (SSE en LiveView) | Medio |
| **Search bar global** | Buscar eventos, webhooks, jobs, dead letters desde una sola barra | Alto |
| **Bulk actions** | Seleccionar múltiples dead letters y retry/resolve en batch | Medio |
| **Status indicators** | Badges de color en webhooks: verde (healthy), amarillo (degraded), rojo (critical) | Alto |
| **Onboarding wizard** | Al crear cuenta: guiar paso a paso (crear proyecto → copiar API key → enviar primer evento) | Alto |

### 9.2 Admin panel — Mejoras

| Mejora | Descripción |
|--------|-------------|
| **Impersonation** | Admin puede "ver como" un usuario específico |
| **System metrics** | CPU, memoria, DB connections, Oban queues en tiempo real |
| **User activity log** | Timeline de actividad por usuario |
| **Project analytics** | Stats detallados por proyecto (eventos, deliveries, storage) |
| **Audit log viewer** | Filtrado avanzado del audit log (por usuario, acción, fecha) |
| **Config editor** | Editar configuración de plataforma desde el dashboard (rate limits, retention) |

### 9.3 Páginas públicas — Mejoras

| Página | Mejora |
|--------|--------|
| `/` (landing) | Agregar demo interactiva: "Send your first event in 30 seconds" con código copiable |
| `/docs` | Documentación técnica completa con ejemplos en 5+ lenguajes |
| `/pricing` | Agregar comparación con competidores (Hookdeck, Svix, Convoy) |
| `/changelog` | Agregar RSS feed y notificaciones por email |
| `/status` | **NUEVA** — Status page pública con uptime history |

---

## 10. Mejoras de API

### 10.1 Nuevos endpoints

| Endpoint | Descripción |
|----------|-------------|
| `POST /api/v1/events/batch` | Batch ingestion (hasta 1000 eventos) |
| `GET /api/v1/events/search` | Búsqueda por payload fields |
| `GET /api/v1/events/:id/deliveries` | Deliveries de un evento específico |
| `POST /api/v1/webhooks/:id/test` | Enviar evento de prueba a un webhook |
| `GET /api/v1/webhooks/:id/logs` | Últimas N entregas de un webhook |
| `GET /api/v1/stats` | Stats globales del proyecto (eventos, webhooks, success rate) |
| `GET /api/v1/me` | Info del usuario autenticado (JWT) |
| `PATCH /api/v1/me` | Actualizar perfil (JWT) |
| `GET /api/v1/status` | Status público del sistema |

### 10.2 Mejoras a endpoints existentes

| Endpoint | Mejora |
|----------|--------|
| `GET /api/v1/events` | Agregar filtros: `status`, `from`, `to`, `payload_contains` |
| `GET /api/v1/deliveries` | Agregar filtros: `from`, `to`, `status`, `webhook_id` |
| `GET /api/v1/dead-letters` | Agregar filtro: `webhook_id`, `topic` |
| `GET /api/v1/jobs` | Agregar filtro: `schedule_type`, `status` |
| Todos los list endpoints | Agregar header `X-Total-Count` con total de registros |
| Todos los endpoints | Agregar header `X-Request-Id` para tracing |
| Todos los endpoints | Agregar header `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` |

### 10.3 API versioning strategy

Preparar para v2 sin romper v1:

```
/api/v1/* → Versión actual (mantener indefinidamente)
/api/v2/* → Versión futura (cuando haya breaking changes)
```

Usar header `X-API-Version` como alternativa al path.

Deprecation policy:
1. Anunciar deprecación con 6 meses de anticipación
2. Agregar header `Sunset: <date>` en responses de v1
3. Documentar guía de migración v1 → v2
4. v1 sigue funcionando pero no recibe features nuevas

---

## 11. Mejoras de testing

### 11.1 Test coverage targets

| Módulo | Coverage actual | Target |
|--------|----------------|--------|
| `StreamflixCore.Platform.*` | ~10% | 90% |
| `StreamflixAccounts` | ~5% | 85% |
| `Controllers (API)` | ~5% | 80% |
| `Controllers (browser)` | ~5% | 70% |
| `Workers` | 0% | 80% |
| `LiveView` | 0% | 50% |
| `Plugs` | 0% | 80% |
| **Total** | **~10%** | **80%** |

### 11.2 Test infrastructure

```elixir
# test/support/factory.ex — Agregar factories faltantes
def project_factory do
  %StreamflixCore.Schemas.Project{
    id: Ecto.UUID.generate(),
    name: sequence(:project_name, &"Project #{&1}"),
    status: "active",
    user_id: nil  # set in test
  }
end

def api_key_factory do
  # ...
end

def webhook_factory do
  # ...
end

# ... factories para todas las 18 schemas
```

```elixir
# test/support/auth_helpers.ex
defmodule StreamflixWeb.AuthHelpers do
  def auth_headers_jwt(user) do
    {:ok, token, _claims} = StreamflixAccounts.Guardian.encode_and_sign(user)
    [{"authorization", "Bearer #{token}"}]
  end

  def auth_headers_api_key(project) do
    {:ok, _key, raw} = StreamflixCore.Platform.create_api_key(project.id)
    [{"x-api-key", raw}]
  end
end
```

### 11.3 Property-based testing

Usar `StreamData` para tests basados en propiedades:

```elixir
# Test: cualquier JSON válido se acepta como payload
property "accepts any valid JSON payload" do
  check all payload <- map_of(string(:alphanumeric), one_of([integer(), string(:alphanumeric)])) do
    assert {:ok, _event} = Platform.Events.create_event(project.id, %{"topic" => "test", "payload" => payload})
  end
end

# Test: idempotency key siempre devuelve el mismo evento
property "idempotency key returns same event" do
  check all key <- string(:alphanumeric, min_length: 1) do
    {:ok, e1} = create_event(%{"topic" => "t", "idempotency_key" => key})
    {:ok, e2} = create_event(%{"topic" => "t", "idempotency_key" => key})
    assert e1.id == e2.id
  end
end
```

### 11.4 Load testing

Agregar scripts de load testing con `k6` o `vegeta`:

```javascript
// k6/events_load.js
import http from 'k6/http';

export const options = {
  stages: [
    { duration: '30s', target: 50 },   // ramp up
    { duration: '1m', target: 100 },   // sustained
    { duration: '30s', target: 200 },  // peak
    { duration: '30s', target: 0 },    // ramp down
  ],
};

export default function() {
  http.post('https://jobcelis.com/api/v1/events', JSON.stringify({
    topic: 'load_test.event',
    payload: { timestamp: Date.now(), iteration: __VU }
  }), {
    headers: { 'X-Api-Key': __ENV.API_KEY, 'Content-Type': 'application/json' }
  });
}
```

---

## 12. Mejoras de infraestructura

### 12.1 Staging environment

Agregar un entorno de staging en Azure:

```
Production: jobcelis.com        → Azure Web App (jobcelis)
Staging:    staging.jobcelis.com → Azure Web App (jobcelis-staging)
```

GitHub Actions workflow:
- Push a `develop` → deploy a staging
- Push a `main` → deploy a production

### 12.2 Zero-downtime deployments

Implementar blue-green o rolling deploy:

1. **Health check en /health** (ya existe)
2. **Graceful shutdown** en Phoenix (ya incluido en OTP)
3. **Azure slots** para swap sin downtime
4. **Migration safety**: solo migraciones forward-compatible (no DROP columnas hasta que el nuevo código esté activo)

### 12.3 Container security

Agregar al Dockerfile:
```dockerfile
# Scan de vulnerabilidades en CI
# .github/workflows/ci.yml
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'jobscelisacr.azurecr.io/jobscelis:latest'
    format: 'table'
    exit-code: '1'
    severity: 'CRITICAL,HIGH'
```

### 12.4 Database backups mejorados

| Mejora | Descripción |
|--------|-------------|
| **Point-in-time recovery** | Configurar WAL archiving en Supabase |
| **Backup verification** | Worker mensual que restaura backup en DB temporal y verifica |
| **Cross-region backup** | Copiar backups a segunda región (Azure paired region) |
| **Backup encryption** | Cifrar backups con GPG antes de upload |
| **Backup monitoring** | Alerta si el último backup tiene >26h |

### 12.5 CDN para assets

```elixir
# config/prod.exs
config :streamflix_web, StreamflixWebWeb.Endpoint,
  static_url: [
    scheme: "https",
    host: "cdn.jobcelis.com",
    port: 443
  ]
```

Usar Azure CDN o Cloudflare para servir assets estáticos.

### 12.6 Secret management

Migrar de variables de entorno a Azure Key Vault:

```yaml
# docker-compose.yml (dev) → .env
# Azure Web App → Azure Key Vault references
# Formato: @Microsoft.KeyVault(SecretUri=https://vault.azure.net/secrets/KEY)
```

---

## 13. Mejoras de documentación

### 13.1 Documentación técnica (para desarrolladores)

| Documento | Contenido |
|-----------|-----------|
| `docs/API_REFERENCE.md` | Referencia completa de API con ejemplos curl + respuestas |
| `docs/ARCHITECTURE.md` | Diagrama de arquitectura, flujo de datos, decisiones técnicas |
| `docs/CONTRIBUTING.md` | Guía para contribuidores (setup, coding style, PR process) |
| `docs/DEPLOYMENT.md` | Guía completa de deployment (Azure, Docker, self-hosted) |
| `docs/TROUBLESHOOTING.md` | Problemas comunes y soluciones |
| `docs/WEBHOOK_VERIFICATION.md` | Guía de verificación de firmas (Node, Python, Go, Ruby, PHP, Java) |
| `docs/SDK_DEVELOPMENT.md` | Guía para desarrollar SDKs |
| `docs/MIGRATION_GUIDE.md` | Guía de migración entre versiones |

### 13.2 Documentación de usuario

| Documento | Contenido |
|-----------|-----------|
| `docs/QUICKSTART.md` | De 0 a primer evento en 5 minutos |
| `docs/TUTORIALS.md` | Tutoriales paso a paso: Slack, Discord, custom webhook |
| `docs/EXAMPLES.md` | Ejemplos reales: e-commerce, SaaS billing, monitoring |
| `docs/FAQ_EXTENDED.md` | FAQ técnico extendido |

### 13.3 Documentación interactiva

- **Swagger UI** (ya existe en `/api/swaggerui`)
- **Agregar:** Ejemplos en OpenAPI spec para cada endpoint
- **Agregar:** Try-it-out funcional (ya soportado por SwaggerUI)
- **Agregar:** Documentación de webhook payloads (qué recibe el destino)

---

## 14. Posicionamiento de mercado

### 14.1 Competidores directos

| Competidor | Pricing | Diferenciador |
|-----------|---------|--------------|
| **Hookdeck** | Desde $0 (free tier) | Event gateway, transformations, CLI |
| **Svix** | Desde $0 (open source) | Webhook sending for SaaS |
| **Convoy** | Open source | Webhooks + event mesh |
| **Inngest** | Desde $0 | Event-driven functions |
| **Trigger.dev** | Desde $0 | Background jobs for developers |

### 14.2 Diferenciadores de Jobcelis

| Feature | Jobcelis | Hookdeck | Svix | Convoy |
|---------|---------|----------|------|--------|
| Event ingestion | Si | Si | No (solo sending) | Si |
| Webhook delivery | Si | Si | Si | Si |
| Scheduled jobs | Si | No | No | No |
| Event replay | Si | Si | Si | Si |
| Dead letter queue | Si | Si | No | Si |
| Sandbox testing | Si | No | No | No |
| Circuit breaker | Si | No | Si | Si |
| MFA/TOTP | Si | No | No | No |
| GDPR compliance | Si | Parcial | No | No |
| Self-hosted | Si | No | Si | Si |
| Batch delivery | Si | No | Si | No |
| Event schemas | Si | No | No | No |
| Audit log | Si | No | No | Parcial |
| Cron jobs | Si | No | No | No |
| Dashboard LiveView | Si (real-time) | Si | Si | Si |

### 14.3 Posicionamiento recomendado

**NO posicionar como:** "Webhook tool" (commodity, muchos competidores)

**Posicionar como:** "Event Infrastructure Platform for Developers"

**Tagline:** "Send events, deliver webhooks, schedule jobs — one API, zero infrastructure"

**Value props:**
1. **All-in-one:** Events + webhooks + jobs + replay + sandbox en un solo lugar
2. **Self-hosted:** 100% de los datos bajo tu control
3. **Enterprise-ready:** GDPR, SOC 2, MFA, audit log, encryption
4. **Developer-first:** API-first, SDKs, CLI, Swagger, sandbox
5. **Real-time:** Dashboard LiveView, SSE, WebSocket

### 14.4 Target audience

| Segmento | Caso de uso |
|----------|------------|
| **SaaS startups** | Enviar webhooks a sus clientes (como Stripe Events) |
| **E-commerce** | Notificar sistemas de order lifecycle events |
| **DevOps teams** | Alertas y automatización event-driven |
| **Agencies** | Herramienta interna para conectar servicios de clientes |
| **Indie developers** | Reemplazo de Zapier para developers que prefieren APIs |

---

## 15. Roadmap priorizado

### Sprint 1 (Semana 1-2): Foundation

| # | Tarea | Tipo | Esfuerzo |
|---|-------|------|----------|
| 1 | Refactorizar Platform.ex en sub-módulos | Refactor | 2-3 días |
| 2 | Agregar factories para todas las schemas | Test | 1 día |
| 3 | Tests para Platform.Events (create, idempotency, delayed, GDPR) | Test | 2 días |
| 4 | Tests para Platform.Webhooks (matching, body building) | Test | 1.5 días |
| 5 | Tests para Platform.Deliveries (retry, dead letter) | Test | 1 día |
| 6 | Fix Dockerfile healthcheck | Fix | 5 min |
| 7 | Fix retry backoff exponencial | Fix | 0.5 días |

### Sprint 2 (Semana 3-4): Core tests + quick features

| # | Tarea | Tipo | Esfuerzo |
|---|-------|------|----------|
| 8 | Tests para Accounts (login, MFA, lockout) | Test | 2 días |
| 9 | Tests para API controllers (events, webhooks, deliveries) | Test | 3 días |
| 10 | Tests para Workers (delivery, scheduled job, replay) | Test | 2 días |
| 11 | Batch event ingestion endpoint | Feature | 1.5 días |
| 12 | Topic wildcards | Feature | 1 día |
| 13 | Rate limiting per-project | Feature | 1 día |

### Sprint 3 (Semana 5-6): Product features

| # | Tarea | Tipo | Esfuerzo |
|---|-------|------|----------|
| 14 | Retry policies configurables | Feature | 1.5 días |
| 15 | Event search con GIN index | Feature | 2 días |
| 16 | Webhook response logging (headers, latency) | Feature | 1 día |
| 17 | Event retention policies per-project | Feature | 1 día |
| 18 | Cron parser mejorado (usar librería) | Fix | 0.5 días |
| 19 | Webhook test button (API + dashboard) | Feature | 1 día |
| 20 | Tests para Teams, GDPR, Notifications | Test | 2 días |

### Sprint 4 (Semana 7-8): Dashboard + UX

| # | Tarea | Tipo | Esfuerzo |
|---|-------|------|----------|
| 21 | Event detail modal con timeline de deliveries | UX | 2 días |
| 22 | Delivery timeline visualization | UX | 1.5 días |
| 23 | Status indicators en webhooks (badges de color) | UX | 0.5 días |
| 24 | Search bar global | UX | 1.5 días |
| 25 | Bulk actions en dead letters | UX | 1 día |
| 26 | Onboarding wizard para nuevos usuarios | UX | 2 días |
| 27 | Dark mode | UX | 1.5 días |

### Sprint 5 (Semana 9-10): Observabilidad

| # | Tarea | Tipo | Esfuerzo |
|---|-------|------|----------|
| 28 | Prometheus metrics (PromEx) | Infra | 2 días |
| 29 | API response headers (X-Request-Id, rate limit headers) | API | 1 día |
| 30 | Structured logging mejorado | Infra | 1 día |
| 31 | Admin metrics dashboard (LiveView) | UX | 2 días |
| 32 | Status page pública | Feature | 1.5 días |
| 33 | Database indexes audit + creation | Infra | 1 día |

### Sprint 6 (Semana 11-12): Infraestructura

| # | Tarea | Tipo | Esfuerzo |
|---|-------|------|----------|
| 34 | Staging environment en Azure | Infra | 1 día |
| 35 | Trivy vulnerability scanning en CI | Infra | 0.5 días |
| 36 | CDN para assets estáticos | Infra | 1 día |
| 37 | Backup verification worker | Infra | 1 día |
| 38 | Load testing scripts (k6) | Test | 1 día |
| 39 | API versioning headers (Sunset, X-API-Version) | API | 0.5 días |

### Sprint 7 (Semana 13-16): Ecosistema

| # | Tarea | Tipo | Esfuerzo |
|---|-------|------|----------|
| 40 | SDK Node.js/TypeScript | Ecosystem | 3-4 días |
| 41 | SDK Python | Ecosystem | 2-3 días |
| 42 | CLI (Node.js) | Ecosystem | 3-4 días |
| 43 | Webhook signature verification docs (5 lenguajes) | Docs | 1 día |
| 44 | Architecture documentation | Docs | 1 día |
| 45 | Quickstart guide | Docs | 0.5 días |
| 46 | API examples in OpenAPI spec | Docs | 1 día |

### Sprint 8 (Semana 17-18): Compliance + Polish

| # | Tarea | Tipo | Esfuerzo |
|---|-------|------|----------|
| 47 | Security policy document | Compliance | 1 día |
| 48 | Risk assessment document | Compliance | 1 día |
| 49 | SLA document | Compliance | 0.5 días |
| 50 | Penetration testing (self-service) | Compliance | 2 días |
| 51 | GDPR consent versioning | Compliance | 1 día |
| 52 | SOC 2 gap remediation final | Compliance | 1 día |

### Futuro (Backlog)

| # | Tarea | Tipo |
|---|-------|------|
| F1 | Event pipelines (filter -> transform -> delay -> deliver) | Feature |
| F2 | Transformaciones avanzadas (JSONPath, Liquid templates) | Feature |
| F3 | SDK Go | Ecosystem |
| F4 | Terraform provider | Ecosystem |
| F5 | Integraciones nativas (GitHub, PagerDuty, Datadog) | Feature |
| F6 | Table partitioning para events/deliveries | Infra |
| F7 | Read replicas | Infra |
| F8 | Distributed caching (Nebulex) | Infra |
| F9 | Multi-region deployment | Infra |
| F10 | OpenTelemetry distributed tracing | Infra |
| F11 | HIPAA compliance (if needed) | Compliance |
| F12 | Property-based testing con StreamData | Test |
| F13 | Async event processing (decouple ingestion from delivery) | Infra |

---

## Resumen ejecutivo

### Estado actual
Jobcelis es una plataforma de eventos y webhooks **sorprendentemente completa** para un proyecto personal. Con 90+ endpoints API, 11 workers, 18 schemas, seguridad robusta (Argon2id, AES-256, MFA, GDPR), y un dashboard LiveView funcional, el core del producto está sólido.

### Los 3 gaps más críticos
1. **Cobertura de tests (~10%)** — Sin tests no se puede refactorizar ni escalar con confianza
2. **Platform.ex monolítico (1,606 líneas)** — Difícil de mantener y testear
3. **Sin SDKs ni CLI** — La barrera de entrada para desarrolladores es alta

### La inversión con mayor ROI
1. **Tests** (Sprints 1-2) → Permite todo lo demás con confianza
2. **Batch ingestion + rate limiting** (Sprint 2) → Features que clientes enterprise exigen
3. **SDK Node.js + CLI** (Sprint 7) → Reduce friction de adopción 10x

### Valor potencial

| Estado | Valor estimado |
|--------|---------------|
| Actual (side project) | $5,000-$10,000 |
| Con tests + batch + SDKs | $25,000-$50,000 |
| Como SaaS con clientes | $100,000-$500,000 |
| Con enterprise features + team | $500,000+ |

---

*Plan generado: 2026-03-05*
*Próxima revisión: al completar cada sprint*
