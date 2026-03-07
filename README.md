# Jobcelis

**Plataforma de eventos, webhooks y jobs programados** — todo en una sola API. Publica eventos con cualquier payload, configura webhooks con filtros avanzados, recibe POST en tiempo real, y programa tareas recurrentes con cron. Incluye dashboard en tiempo real, sistema de equipos, cifrado de datos, cumplimiento GDPR, backups automatizados y más.

Construido con **Elixir/OTP**, **Phoenix 1.8**, **LiveView 1.1** y **PostgreSQL**.

---

## Tabla de contenidos

- [Características principales](#características-principales)
- [Arquitectura](#arquitectura)
- [Requisitos](#requisitos)
- [Configuración rápida](#configuración-rápida)
- [Variables de entorno](#variables-de-entorno)
- [Estructura del proyecto](#estructura-del-proyecto)
- [API](#api)
- [Dashboard](#dashboard)
- [Seguridad](#seguridad)
- [GDPR](#gdpr)
- [Webhooks](#webhooks)
- [Jobs programados](#jobs-programados)
- [Sistema de replay](#sistema-de-replay)
- [Sandbox](#sandbox-testing-de-webhooks)
- [Equipos y colaboración](#equipos-y-colaboración)
- [Analytics](#analytics)
- [Exportación de datos](#exportación-de-datos)
- [Streaming en tiempo real](#streaming-en-tiempo-real)
- [OpenAPI / Swagger](#openapi--swagger)
- [Backups](#backups)
- [Uptime y monitoreo](#uptime-y-monitoreo)
- [Workers en background](#workers-en-background)
- [Internacionalización](#internacionalización-i18n)
- [CI/CD](#cicd)
- [Docker](#docker)
- [Tecnologías](#tecnologías)
- [SDKs y herramientas](#sdks-y-herramientas)
- [Licencia](#licencia)

---

## Características principales

| Categoría | Descripción |
|-----------|-------------|
| **Eventos** | Publica eventos con `topic` y payload JSON vía API. Sin esquemas fijos, o con validación JSON Schema opcional por topic. Soporte para entrega diferida (`deliver_at`). |
| **Webhooks** | URLs de destino con filtros por topic o campos del payload. POST en tiempo real con reintentos configurables, circuit breaker, entregas en batch, y 5 templates integrados (Slack, Discord, Telegram, JSON genérico, custom). |
| **Jobs programados** | Tareas recurrentes: diario, semanal, mensual o expresión cron. Acción: emitir evento o POST a URL con payload configurable. Historial de ejecuciones. |
| **Dashboard LiveView** | Dashboard en tiempo real con KPIs, analytics, gestión de webhooks/jobs/eventos, dead letter queue, sandbox, esquemas, equipo y más. |
| **Multi-proyecto** | Múltiples proyectos por usuario. Selector de proyecto con persistencia en URL. Invitación de miembros con roles (owner/editor/viewer). |
| **Seguridad** | Cifrado AES-256-GCM en reposo, MFA/TOTP, gestión de sesiones, rate limiting, IP allowlist, circuit breaker, detección de anomalías, headers de seguridad. |
| **GDPR** | Derecho al olvido (Art. 17), restricción de procesamiento (Art. 18), derecho de oposición (Art. 21), exportación de datos personales (Art. 15/20), gestión de consentimientos. |
| **API completa** | 90+ endpoints REST con autenticación JWT y API Key. OpenAPI 3.0 con Swagger UI interactivo. SSE y WebSocket para streaming. |
| **Backups** | `pg_dump` automatizado diario con compresión gzip. Almacenamiento local o Azure Blob Storage. Política de retención configurable. |
| **Observabilidad** | Uptime monitoring cada 5 min, health checks (DB/Oban/cache/backup), audit log inmutable, logs JSON estructurados en producción. |
| **Admin** | Panel de superadmin: usuarios, proyectos, métricas de Oban, configuración de plataforma. |

---

## Arquitectura

Aplicación umbrella con 3 apps:

```
streamflix/
├── apps/
│   ├── streamflix_core/       # Dominio: proyectos, API keys, eventos, webhooks,
│   │                          # deliveries, jobs, dead letters, replays, sandbox,
│   │                          # schemas, analytics, audit, equipos, notificaciones,
│   │                          # uptime, GDPR, backups, circuit breaker, cifrado
│   ├── streamflix_accounts/   # Usuarios, autenticación (Guardian/JWT), MFA, sesiones
│   └── streamflix_web/        # Web (LiveView), API REST, plugs, docs, admin
├── config/                    # Configuración por entorno
├── docker-compose.yml
├── Dockerfile
├── .env.example
└── mix.exs
```

---

## Requisitos

- **Elixir** 1.17+
- **Erlang/OTP** 26+
- **PostgreSQL** 15+
- **Node.js** 20+ (para compilar assets)

---

## Configuración rápida

### 1. Clonar y dependencias

```bash
git clone <repo>
cd streamflix
mix deps.get
```

### 2. Variables de entorno

```bash
cp .env.example .env
```

Edita `.env` y configura al menos:

```bash
# Seguridad (generar con los comandos indicados)
SECRET_KEY_BASE=          # mix phx.gen.secret
GUARDIAN_SECRET_KEY=      # mix guardian.gen.secret
LIVE_VIEW_SIGNING_SALT=   # 32+ caracteres

# Base de datos
DB_USERNAME=postgres
DB_PASSWORD=tu_password
DB_HOSTNAME=localhost
DB_DATABASE=jobscelis_dev
```

Generar secretos:

```bash
mix phx.gen.secret        # SECRET_KEY_BASE
mix guardian.gen.secret    # GUARDIAN_SECRET_KEY
```

### 3. Base de datos

```bash
mix ecto.create
mix ecto.migrate
mix run apps/streamflix_core/priv/repo/seeds.exs
```

### 4. Arrancar

```bash
# Cargar .env (Linux/macOS)
export $(grep -v '^#' .env | xargs)

# O en PowerShell (Windows):
# Get-Content .env | ForEach-Object { if ($_ -match '^([^#=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), 'Process') } }

mix phx.server
```

Abre **http://localhost:4000**

### 5. Crear superadmin

```bash
mix run scripts/create_superadmin.exs
```

---

## Variables de entorno

| Variable | Requerida | Descripción |
|----------|-----------|-------------|
| `SECRET_KEY_BASE` | Si | Clave de cifrado de sesiones Phoenix |
| `GUARDIAN_SECRET_KEY` | Si | Clave de firma JWT |
| `LIVE_VIEW_SIGNING_SALT` | Si | Salt para tokens LiveView |
| `DATABASE_URL` | Si* | Cadena de conexión PostgreSQL (alternativa a `DB_*`) |
| `DB_USERNAME` / `DB_PASSWORD` / `DB_HOSTNAME` / `DB_DATABASE` | Si* | Conexión a PostgreSQL (alternativa a `DATABASE_URL`) |
| `CLOAK_KEY` | Producción | Clave AES-256-GCM para cifrado en reposo (Base64) |
| `HMAC_SECRET` | Producción | Secreto HMAC-SHA512 para hashing de emails |
| `RESEND_API_KEY` | Opcional | API key de Resend para emails transaccionales |
| `AZURE_STORAGE_ACCOUNT` / `AZURE_STORAGE_KEY` | Opcional | Azure Blob Storage para backups |
| `AZURE_CONTAINER_BACKUPS` | Opcional | Nombre del container en Azure |
| `BACKUP_ENABLED` / `BACKUP_PATH` / `BACKUP_RETENTION_DAYS` | Opcional | Configuración de backups |
| `DB_POOL_SIZE` | Opcional | Tamaño del pool de conexiones (default: 10) |

---

## Estructura del proyecto

```
streamflix/
├── apps/
│   ├── streamflix_core/
│   │   ├── lib/
│   │   │   ├── platform.ex           # Contexto principal (~55KB)
│   │   │   ├── audit.ex              # Audit log inmutable
│   │   │   ├── notifications.ex      # Notificaciones in-app + PubSub
│   │   │   ├── teams.ex              # Equipos y colaboración
│   │   │   ├── gdpr.ex               # Cumplimiento GDPR
│   │   │   ├── uptime.ex             # Monitoreo de salud
│   │   │   ├── circuit_breaker.ex    # Circuit breaker para webhooks
│   │   │   ├── vault.ex              # Cloak vault AES-256-GCM
│   │   │   └── workers/              # 11 Oban workers
│   │   └── priv/repo/migrations/
│   ├── streamflix_accounts/
│   │   └── lib/
│   │       └── accounts.ex           # Auth, MFA, sesiones, password history
│   └── streamflix_web/
│       └── lib/
│           ├── controllers/           # API REST controllers
│           ├── live/                   # LiveView (dashboard, account, admin)
│           ├── plugs/                 # Auth, rate limit, CORS, security headers
│           └── channels/             # WebSocket channels
├── config/
│   ├── config.exs                     # Base
│   ├── dev.exs / test.exs / prod.exs
│   └── runtime.exs                    # Variables de entorno
├── docs/
│   └── DATA_CLASSIFICATION.md         # Clasificación de datos (4 niveles)
├── docker-compose.yml
├── Dockerfile                         # Multi-stage (dev + prod)
└── .github/workflows/
    ├── ci.yml                         # Tests, format, Credo, Sobelow, Dialyzer
    └── deploy-azure.yml               # Deploy a Azure Container Apps
```

---

## API

### Autenticación (público)

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/api/v1/auth/register` | Registro (email, password, name) |
| POST | `/api/v1/auth/login` | Login → JWT + MFA si habilitado |
| POST | `/api/v1/auth/refresh` | Refrescar JWT |
| POST | `/api/v1/auth/mfa/verify` | Verificar código TOTP |

### Eventos (API Key)

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/api/v1/events` | Crear evento (topic + payload). Soporta `deliver_at` |
| POST | `/api/v1/send` | Alias para crear evento |
| GET | `/api/v1/events` | Listar eventos (paginación por cursor) |
| GET | `/api/v1/events/:id` | Detalle de evento |
| DELETE | `/api/v1/events/:id` | Soft-delete evento |
| POST | `/api/v1/simulate` | Simular evento (sin entregas reales) |
| GET | `/api/v1/topics` | Listar todos los topics del proyecto |

### Webhooks (API Key)

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/v1/webhooks` | Listar webhooks |
| POST | `/api/v1/webhooks` | Crear webhook (URL, topics, filtros, retry, batch, template) |
| GET | `/api/v1/webhooks/:id` | Detalle de webhook |
| PATCH | `/api/v1/webhooks/:id` | Actualizar webhook |
| DELETE | `/api/v1/webhooks/:id` | Desactivar webhook |
| GET | `/api/v1/webhooks/:id/health` | Salud: tasa de éxito, latencia promedio, última entrega |
| GET | `/api/v1/webhooks/templates` | Templates disponibles (Slack, Discord, Telegram, etc.) |

### Entregas (API Key)

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/v1/deliveries` | Listar entregas (status, intentos, response) |
| POST | `/api/v1/deliveries/:id/retry` | Reintentar entrega fallida |

### Dead Letter Queue (API Key)

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/v1/dead-letters` | Listar dead letters |
| GET | `/api/v1/dead-letters/:id` | Detalle de dead letter |
| POST | `/api/v1/dead-letters/:id/retry` | Reintentar dead letter |
| PATCH | `/api/v1/dead-letters/:id/resolve` | Marcar como resuelto |

### Replays (API Key)

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/api/v1/replays` | Iniciar replay (filtro por topic, fechas, webhook) |
| GET | `/api/v1/replays` | Listar replays |
| GET | `/api/v1/replays/:id` | Estado del replay |
| DELETE | `/api/v1/replays/:id` | Cancelar replay |

### Jobs programados (API Key)

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/v1/jobs` | Listar jobs |
| POST | `/api/v1/jobs` | Crear job (schedule + action) |
| GET | `/api/v1/jobs/:id` | Detalle de job |
| PATCH | `/api/v1/jobs/:id` | Actualizar job |
| DELETE | `/api/v1/jobs/:id` | Desactivar job |
| GET | `/api/v1/jobs/:id/runs` | Historial de ejecuciones |
| GET | `/api/v1/jobs/cron-preview` | Preview de próximas ejecuciones cron |

### Sandbox (API Key)

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/v1/sandbox-endpoints` | Listar endpoints de sandbox |
| POST | `/api/v1/sandbox-endpoints` | Crear endpoint temporal |
| DELETE | `/api/v1/sandbox-endpoints/:id` | Eliminar endpoint |
| GET | `/api/v1/sandbox-endpoints/:id/requests` | Ver requests capturados |

### Event Schemas (API Key)

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/v1/event-schemas` | Listar schemas |
| POST | `/api/v1/event-schemas` | Crear schema (JSON Schema por topic) |
| GET | `/api/v1/event-schemas/:id` | Detalle de schema |
| PATCH | `/api/v1/event-schemas/:id` | Actualizar schema |
| DELETE | `/api/v1/event-schemas/:id` | Eliminar schema |
| POST | `/api/v1/event-schemas/validate` | Validar payload contra schema |

### Analytics (API Key)

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/v1/analytics/events-per-day` | Eventos por día (hasta 90 días) |
| GET | `/api/v1/analytics/deliveries-per-day` | Entregas por día |
| GET | `/api/v1/analytics/top-topics` | Topics con más volumen |
| GET | `/api/v1/analytics/webhook-stats` | Stats por webhook (éxito, fallo, latencia) |

### Audit Log (API Key)

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/v1/audit-log` | Consultar audit log del proyecto |

### Exportación (API Key)

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/v1/export/events` | Exportar eventos (CSV/JSON, hasta 10K registros) |
| GET | `/api/v1/export/deliveries` | Exportar entregas |
| GET | `/api/v1/export/jobs` | Exportar jobs |
| GET | `/api/v1/export/audit-log` | Exportar audit log |

### Proyectos y equipos (JWT)

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/v1/projects` | Listar proyectos |
| POST | `/api/v1/projects` | Crear proyecto |
| GET | `/api/v1/projects/:id` | Detalle de proyecto |
| PATCH | `/api/v1/projects/:id` | Actualizar proyecto |
| DELETE | `/api/v1/projects/:id` | Eliminar proyecto |
| PATCH | `/api/v1/projects/:id/default` | Establecer como proyecto default |
| GET | `/api/v1/projects/:id/members` | Listar miembros |
| POST | `/api/v1/projects/:id/members` | Invitar miembro |
| PATCH | `/api/v1/projects/:id/members/:mid` | Cambiar rol |
| DELETE | `/api/v1/projects/:id/members/:mid` | Remover miembro |
| GET | `/api/v1/invitations/pending` | Invitaciones pendientes |
| POST | `/api/v1/invitations/:id/accept` | Aceptar invitación |
| POST | `/api/v1/invitations/:id/reject` | Rechazar invitación |

### GDPR (JWT)

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/v1/me/data` | Exportar datos personales (DSAR Art. 15/20) |
| POST | `/api/v1/me/restrict` | Restringir procesamiento (Art. 18) |
| DELETE | `/api/v1/me/restrict` | Levantar restricción |
| POST | `/api/v1/me/object` | Derecho de oposición (Art. 21) |
| DELETE | `/api/v1/me/object` | Restaurar consentimiento |

### Token y proyecto (API Key)

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/v1/project` | Ver proyecto actual |
| PATCH | `/api/v1/project` | Actualizar proyecto |
| GET | `/api/v1/token` | Ver prefijo del API Key |
| POST | `/api/v1/token/regenerate` | Regenerar API Key (se muestra una sola vez) |

### Streaming (API Key)

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/api/v1/stream` | Server-Sent Events en tiempo real |

### Health check (público)

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET | `/health` | Estado del sistema (DB, Oban, cache, backup) |

Header de autenticación: `Authorization: Bearer <token>` o `X-Api-Key: <token>`

Documentación interactiva: **http://localhost:4000/docs** | Swagger UI: **http://localhost:4000/api/swaggerui**

---

## Dashboard

Dashboard LiveView en tiempo real (`/platform`) con las siguientes secciones:

| Tab | Funcionalidades |
|-----|-----------------|
| **Overview** | KPIs (eventos hoy, tasa de éxito), uptime (24h/7d/30d), gráficos de analytics, eventos recientes, entregas recientes, dead letters, sandbox |
| **Events** | Lista completa con paginación, simulación de eventos, modal de replay, actualizaciones en tiempo real vía PubSub |
| **Webhooks** | Crear/editar/desactivar webhooks, salud por webhook, estado del circuit breaker, configuración de batch |
| **Jobs** | Crear/editar/desactivar jobs (daily/weekly/monthly/cron), preview de expresiones cron, historial de ejecuciones |
| **Settings** | Renombrar proyecto, API key (mostrar/regenerar), schemas de eventos, gestión de equipo (invitar/roles/remover), invitaciones pendientes |

Funcionalidades transversales:
- **Selector de proyecto** con persistencia en URL (`?project=ID`)
- **Campana de notificaciones** en tiempo real con badge de no leídas
- **Overlay de carga** al cambiar de proyecto
- Totalmente **responsive** (mobile-first)

### Cuenta de usuario (`/account`)

- Cambiar email, contraseña, nombre
- **MFA/TOTP**: activar con QR, verificar, códigos de respaldo, desactivar
- **Sesiones**: listar dispositivos activos, revocar sesiones individuales o todas
- **Consentimientos GDPR**: ver, revocar, restringir procesamiento
- Eliminar cuenta
- Reenviar verificación de email

### Panel admin (`/admin`)

- Dashboard: total usuarios, proyectos, eventos, stats de Oban
- Gestión de usuarios: activar/desactivar cuentas
- Gestión de proyectos: ver detalles por proyecto
- Configuración de plataforma

---

## Seguridad

| Característica | Implementación |
|----------------|----------------|
| **Hashing de contraseñas** | Argon2id memory-hard (RFC 9106, OWASP #1). Rehash automático de hashes legacy al login |
| **Cifrado en reposo** | Cloak Ecto AES-256-GCM (email, nombre, secreto MFA) |
| **HMAC determinístico** | HMAC-SHA512 para búsqueda de emails cifrados |
| **JWT** | Guardian, TTL 7 días, tracking por JTI, revocación de sesiones |
| **MFA/TOTP** | NimbleTOTP, QR code, 10 códigos de respaldo (SHA-256), tolerancia ±30s |
| **Bloqueo de cuenta** | Tras 5 intentos fallidos: bloqueo 15 minutos, auto-desbloqueo |
| **Rate limiting** | ETS por IP (login: 5/min, registro: 3/min, API: 15/min, MFA: 10/min) |
| **Scopes de API Key** | Granulares: `events:read`, `events:write`, `webhooks:*`, `jobs:*`, `deliveries:*`, `analytics:read` |
| **IP allowlist** | Por API Key, verificado contra X-Forwarded-For |
| **Circuit breaker** | Por webhook: se abre tras 5 fallos consecutivos, reset tras 5 min |
| **Detección de anomalías** | Cada 5 min: fuerza bruta por IP, ataque coordinado, exfiltración, lockouts |
| **Headers de seguridad** | CSP, X-Frame-Options: DENY, X-Content-Type-Options, Referrer-Policy, Permissions-Policy |
| **Firma de webhooks** | HMAC-SHA256 con secreto cifrado por webhook |
| **Historial de contraseñas** | Previene reutilización de contraseñas recientes |
| **Blacklist de contraseñas** | 200+ contraseñas comunes (MapSet O(1)) |
| **Timeout de sesión** | 30 minutos de inactividad |
| **Force SSL** | Habilitado en producción |

---

## GDPR

| Artículo | Funcionalidad |
|----------|---------------|
| **Art. 15/20** | Exportación completa de datos personales (perfil, proyectos, webhooks, eventos, entregas, jobs, sesiones, consentimientos, audit) |
| **Art. 17** | Derecho al olvido: eliminación atómica en cascada con pseudonimización de audit logs |
| **Art. 18** | Restricción de procesamiento con motivo |
| **Art. 21** | Derecho de oposición al procesamiento |
| **Consentimientos** | Por propósito (terms, privacy, data_processing, marketing) con versión, IP y timestamps. Auto-registro al signup |

Clasificación de datos documentada en `docs/DATA_CLASSIFICATION.md` (4 niveles: Public, Internal, Confidential, Restricted).

---

## Webhooks

- **Routing por topic**: suscribe webhooks a topics específicos
- **Filtros avanzados**: por campos del payload (tipo Ecto custom `WebhookFilters`)
- **5 templates integrados**: Slack (Block Kit), Discord (embeds), Telegram Bot API, JSON genérico, Custom
- **Body personalizado**: template tipo Mustache con `{{topic}}`, `{{payload}}`
- **Headers custom** por webhook
- **Reintentos configurables**: backoff personalizado y máximo de intentos por webhook
- **Batch delivery**: acumulación de eventos por ventana de tiempo o tamaño máximo
- **Circuit breaker**: se abre automáticamente tras fallos consecutivos, test en half-open tras 5 min
- **Health metrics**: tasa de éxito, latencia promedio, última entrega
- **Firma HMAC**: cada payload firmado con el secreto del webhook

---

## Jobs programados

- **Tipos de schedule**: `daily`, `weekly`, `monthly`, `cron` (cualquier expresión cron)
- **Tipos de acción**: `emit_event` (inyectar evento en la plataforma) o `post_url` (HTTP POST a URL externa)
- **Payload configurable** por job
- **Historial de ejecuciones**: tabla `job_runs` con status y output
- **Preview de cron**: endpoint que muestra las próximas N ejecuciones
- **Notificaciones** automáticas en caso de fallo

---

## Sistema de replay

- Replay de eventos filtrado por: topic, rango de fechas (`from_date` / `to_date`), webhook específico
- Tracking de progreso: `processed_events / total_events`
- Broadcast en tiempo real al dashboard vía PubSub
- Cancelable en cualquier momento
- Notificación in-app al completar
- Estados: `pending → running → completed / cancelled`

---

## Sandbox (testing de webhooks)

- Crea endpoints HTTP temporales con slugs únicos
- Acepta cualquier método HTTP (GET, POST, PUT, PATCH, DELETE, etc.)
- Captura request completo: método, path, headers, body, query params, IP
- Expiración automática configurable
- Visualización de requests capturados en el dashboard
- Limpieza automática por `ObanPurgeWorker`

---

## Equipos y colaboración

- **Roles**: `owner`, `editor`, `viewer`
- **Invitación por email** con notificación in-app al invitado
- **Aceptar/rechazar** invitaciones pendientes
- **Gestión de miembros**: cambiar roles, remover (el owner no puede ser removido)
- **Control de acceso**: `viewer` (lectura), `editor` (lectura + escritura), `owner` (todo + admin del proyecto)
- **Multi-proyecto**: un usuario puede ser dueño o miembro de múltiples proyectos

---

## Analytics

- **Eventos por día**: hasta 90 días de lookback
- **Entregas por día**: hasta 90 días de lookback
- **Top topics**: topics con más volumen (configurable, hasta 50)
- **Stats por webhook**: total, éxito, fallo, tasa de éxito, latencia promedio
- **KPIs en dashboard**: eventos hoy, tasa de éxito global

---

## Exportación de datos

| Tipo | Formatos | Máx. registros | Acceso |
|------|----------|-----------------|--------|
| Eventos | CSV, JSON | 10,000 | API Key (`events:read`) o sesión |
| Entregas | CSV, JSON | 10,000 | API Key (`deliveries:read`) o sesión |
| Jobs | CSV, JSON | 10,000 | API Key (`jobs:read`) o sesión |
| Audit log | CSV, JSON | 10,000 | API Key o sesión |
| Datos personales (GDPR) | JSON | Completo | JWT o sesión |

Parámetro `?format=csv|json&days=N` en todos los endpoints de exportación.

---

## Streaming en tiempo real

| Canal | Descripción |
|-------|-------------|
| **SSE** | `GET /api/v1/stream` — push de `event.created` y `delivery.updated`, keepalive 30s |
| **WebSocket** | Phoenix Channel `events:<project_id>` — broadcast de eventos y entregas |
| **PubSub** | Interno para dashboard LiveView: actualizaciones en tiempo real, notificaciones, progreso de replay |

---

## OpenAPI / Swagger

- Spec OpenAPI 3.0 generada con `OpenApiSpex` desde anotaciones de controllers
- **Swagger UI interactivo**: `/api/swaggerui`
- **Spec JSON**: `/api/openapi`
- Dos esquemas de seguridad: `api_key` (X-Api-Key o Bearer) y `bearer` (JWT)
- Tags: Events, Webhooks, Deliveries, Dead Letters, Replays, Analytics, Jobs, Sandbox, Audit, Auth, GDPR, System

---

## Backups

- **`pg_dump` automatizado** diario a las 2am vía `ObanBackupWorker`
- **Compresión gzip** (`--compress=6`, `--format=custom`)
- **Dual storage**: local o Azure Blob Storage (auto-upload si configurado)
- **Retención configurable** (default: 30 días)
- **Limpieza automática** de backups antiguos (local y Azure)
- Estado visible en `/health` y dashboard de uptime
- Auditado en `audit_logs`

---

## Uptime y monitoreo

- **Health checks cada 5 minutos** vía `ObanUptimeWorker`
- Verifica: PostgreSQL, Oban, Cachex, estado de backups
- **Historial de uptime**: porcentaje calculado para 24h, 7d y 30d
- **Notificación a admins** si el estado es degradado o unhealthy
- **Endpoint público**: `GET /health` con estado actual y checks detallados
- **Detección de brechas** cada 5 min: fuerza bruta, ataques coordinados, exfiltración de datos

---

## Workers en background

| Worker | Schedule | Descripción |
|--------|----------|-------------|
| `ObanDeliveryWorker` | On demand | Entrega payloads a webhooks via HTTP POST. Retry con backoff, circuit breaker, batch |
| `ObanScheduledJobWorker` | On demand | Ejecuta jobs programados (emit_event o post_url) |
| `ObanReplayWorker` | On demand | Procesa replays de eventos con broadcast de progreso |
| `ObanDelayedEventsWorker` | Cada minuto | Procesa eventos con `deliver_at` pasado |
| `ObanBatchWorker` | Cada minuto | Flush de batch items cuando se cumple ventana o tamaño máximo |
| `ObanPurgeWorker` | Domingos 3am | Limpia: deliveries >90d, job_runs >90d, sandbox expirados, dead letters resueltos >30d |
| `ObanBackupWorker` | Diario 2am | `pg_dump` + upload a Azure (opcional) + limpieza de retención |
| `ObanUptimeWorker` | Cada 5 min | Health check del sistema, almacena resultado, notifica si degradado |
| `ObanBreachDetectionWorker` | Cada 5 min | Detecta anomalías de seguridad en audit logs |
| `ObanSessionCleanupWorker` | Diario 4am | Purga sesiones revocadas/inactivas >7 días |
| `ObanEmailWorker` | On demand | Envío de emails transaccionales via Resend API |

Colas configuradas: `delivery` (10 concurrent), `scheduled_job` (1), `replay` (3), `default` (5)

---

## Internacionalización (i18n)

- **Bilingüe completo**: Español (default) e Inglés
- Todo texto visible usa `gettext()` — sin strings hardcodeados
- Cubre: flash messages, labels, headers, botones, placeholders, notificaciones, emails, errores
- **Selector de idioma**: `GET /locale/:locale` (almacena en sesión)
- Backend: notificaciones en español en BD, traducción por tipo al renderizar en dashboard

---

## CI/CD

### GitHub Actions CI

Se ejecuta en push a `main`/`develop` y PRs a `main`:

1. `mix compile --warnings-as-errors`
2. `mix format --check-formatted`
3. **Credo** — análisis estático (prioridad mínima: high)
4. **Sobelow** — scanner de seguridad
5. `mix deps.audit` — CVE scanning
6. `mix hex.audit` — paquetes retirados
7. Migraciones + `mix test`
8. **Dialyzer** — type checking

### Deploy a Azure

Push a `main` dispara:
1. Build de imagen Docker
2. Push a Azure Container Registry
3. Restart de Azure Web App

---

## Docker

### Desarrollo

```bash
cp .env.example .env
# Editar .env con los secretos necesarios

docker compose up --build
```

App en **http://localhost:4000**, PostgreSQL en `localhost:5432`.

```bash
# Migraciones (primera vez)
docker compose exec jobscelis mix ecto.migrate
docker compose exec jobscelis mix run apps/streamflix_core/priv/repo/seeds.exs
```

### Producción

Dockerfile multi-stage:
- **Build stage**: compila assets (`mix assets.deploy`) y crea release (`mix release`)
- **Runtime stage**: imagen mínima Alpine, usuario non-root, healthcheck integrado

---

## Tecnologías

| Tecnología | Uso |
|------------|-----|
| **Elixir / OTP** | Lenguaje y runtime |
| **Phoenix 1.8** | Framework web y API |
| **Phoenix LiveView 1.1** | Dashboard y pantallas en tiempo real |
| **Ecto** | ORM y migraciones (PostgreSQL) |
| **Oban 2.20** | Jobs en background (entregas, replays, cron, purge, backups, uptime, emails) |
| **Guardian** | Autenticación JWT |
| **NimbleTOTP** | MFA / TOTP |
| **Cloak Ecto** | Cifrado AES-256-GCM en reposo |
| **Cachex 4.1** | Cache en memoria con TTL |
| **Bandit 1.10.2** | Servidor HTTP |
| **Finch** | Cliente HTTP (pool de conexiones) |
| **OpenApiSpex** | Generación de spec OpenAPI 3.0 + Swagger UI |
| **LoggerJSON** | Logs JSON estructurados (producción) |
| **Tailwind CSS v4** | Estilos (utility-first, responsive) |
| **Resend** | Emails transaccionales |
| **Azure Blob Storage** | Almacenamiento de backups (opcional) |

---

## Usuarios y roles

- **Usuario normal**: se registra, tiene proyectos y API Keys. Gestiona eventos, webhooks y jobs desde el dashboard.
- **Admin / Superadmin**: acceso a `/admin` para gestionar usuarios, proyectos y métricas de la plataforma.
- **Roles de equipo**: `owner` (todo), `editor` (lectura + escritura), `viewer` (solo lectura).

---

## Páginas públicas

La plataforma incluye páginas informativas bilingües y responsive:

`/` (landing) · `/pricing` · `/about` · `/faq` · `/contact` · `/changelog` · `/docs` · `/terms` · `/privacy` · `/cookies` · `/sitemap.xml`

---

## SDKs y herramientas

Todos los SDKs cubren el **100% de la API** (84+ endpoints) con documentación completa.

### Paquetes publicados

| Paquete | Registry | Instalación | Versión |
|---------|----------|-------------|---------|
| **Node.js/TypeScript SDK** | [npmjs.com/@jobcelis/sdk](https://www.npmjs.com/package/@jobcelis/sdk) | `npm install @jobcelis/sdk` | v1.5.0 |
| **CLI** | [npmjs.com/@jobcelis/cli](https://www.npmjs.com/package/@jobcelis/cli) | `npm install -g @jobcelis/cli` | v2.0.2 |
| **Python SDK** | [pypi.org/project/jobcelis](https://pypi.org/project/jobcelis/) | `pip install jobcelis` | v1.4.0 |
| **Go SDK** | [github.com/vladimirCeli/go-jobcelis](https://github.com/vladimirCeli/go-jobcelis) | `go get github.com/vladimirCeli/go-jobcelis` | v1.1.0 |
| **PHP SDK** | [github.com/vladimirCeli/jobcelis-php](https://github.com/vladimirCeli/jobcelis-php) | `composer require jobcelis/sdk` | v1.0.0 |
| **Ruby SDK** | [github.com/vladimirCeli/jobcelis-ruby](https://github.com/vladimirCeli/jobcelis-ruby) | `gem install jobcelis` | v1.0.0 |
| **Terraform Provider** | [registry.terraform.io/vladimirCeli/jobcelis](https://registry.terraform.io/providers/vladimirCeli/jobcelis/) | Ver bloque `required_providers` | v1.0.0 |
| **GitHub Action** | Este monorepo (`sdks/github-action`) | `uses: vladimirCeli/jobscelis/sdks/github-action@main` | - |

### Repositorios externos

Los siguientes SDKs viven en repositorios separados (requerido por sus registros):

| Repo | URL | Motivo |
|------|-----|--------|
| **Go SDK** | [github.com/vladimirCeli/go-jobcelis](https://github.com/vladimirCeli/go-jobcelis) | `pkg.go.dev` requiere repo propio con `go.mod` en raíz |
| **PHP SDK** | [github.com/vladimirCeli/jobcelis-php](https://github.com/vladimirCeli/jobcelis-php) | Packagist requiere `composer.json` en raíz del repo |
| **Ruby SDK** | [github.com/vladimirCeli/jobcelis-ruby](https://github.com/vladimirCeli/jobcelis-ruby) | Repo público para RubyGems y visibilidad del código |
| **Terraform Provider** | [github.com/vladimirCeli/terraform-provider-jobcelis](https://github.com/vladimirCeli/terraform-provider-jobcelis) | Terraform Registry requiere repo `terraform-provider-*` |

> El código fuente canónico de todos los SDKs está en `sdks/` de este monorepo. Los repos externos se sincronizan manualmente.

### Quick Start por SDK

Todos los SDKs se conectan a `https://jobcelis.com` automáticamente — solo necesitas tu API key.

**Node.js / TypeScript:**

```typescript
import { JobcelisClient } from '@jobcelis/sdk';

const client = new JobcelisClient({ apiKey: 'your_api_key' });
const event = await client.sendEvent({ topic: 'order.created', payload: { order_id: '123' } });
const webhooks = await client.listWebhooks();
```

**Python:**

```python
from jobcelis import JobcelisClient

client = JobcelisClient(api_key="your_api_key")
event = client.send_event("order.created", {"order_id": "123"})
webhooks = client.list_webhooks()
```

**Go:**

```go
import jobcelis "github.com/vladimirCeli/go-jobcelis"

client := jobcelis.NewClient("your_api_key")
event, err := client.SendEvent(ctx, jobcelis.EventCreate{
    Topic:   "order.created",
    Payload: map[string]interface{}{"order_id": "123"},
})
```

**CLI:**

```bash
export JOBCELIS_API_KEY=your_api_key

jobcelis events send --topic order.created --payload '{"order_id":"123"}'
jobcelis webhooks list
jobcelis jobs create --name daily-report --queue default --cron "0 9 * * *"
jobcelis status
```

**PHP:**

```php
use Jobcelis\Client;

$client = new Client(apiKey: 'your_api_key');
$event = $client->sendEvent('order.created', ['order_id' => '123']);
$webhooks = $client->listWebhooks();
```

**Ruby:**

```ruby
require "jobcelis"

client = Jobcelis::Client.new(api_key: "your_api_key")
event = client.send_event("order.created", { order_id: "123" })
webhooks = client.list_webhooks
```

**GitHub Action:**

```yaml
- uses: vladimirCeli/jobscelis/sdks/github-action@main
  with:
    api-key: ${{ secrets.JOBCELIS_API_KEY }}
    topic: deploy.completed
    payload: '{"environment": "production", "version": "${{ github.sha }}"}'
```

**Terraform:**

```hcl
terraform {
  required_providers {
    jobcelis = {
      source = "vladimirCeli/jobcelis"
    }
  }
}

provider "jobcelis" {
  api_key = var.jobcelis_api_key
  # Connects to https://jobcelis.com by default
}

resource "jobcelis_webhook" "slack" {
  url    = "https://hooks.slack.com/services/..."
  topics = ["order.created", "payment.failed"]
}

resource "jobcelis_job" "daily_report" {
  name            = "daily-report"
  queue           = "default"
  cron_expression = "0 9 * * *"
}
```

### Cobertura de la API por SDK

Todos los SDKs (Node, Python, Go, PHP, Ruby) cubren las 84 rutas de la API:

- **Auth**: register, login, refresh, MFA verify
- **Events**: send, batch, list, get, delete, simulate
- **Webhooks**: CRUD, health, templates
- **Deliveries**: list, retry
- **Dead Letters**: list, get, retry, resolve
- **Replays**: create, list, get, cancel
- **Jobs**: CRUD, runs, cron preview
- **Pipelines**: CRUD, test
- **Event Schemas**: CRUD, validate
- **Sandbox**: CRUD, requests
- **Analytics**: events/day, deliveries/day, top topics, webhook stats
- **Project**: get, update, topics, token, regenerate
- **Projects (multi)**: CRUD, set default
- **Teams**: list, add, update, remove members
- **Invitations**: pending, accept, reject
- **Audit**: list logs
- **Export**: events, deliveries, jobs, audit log
- **GDPR**: consents, data export, restrict, object
- **Health**: status check

El **CLI** cubre todas las rutas. El **Terraform Provider** cubre 5 recursos con CRUD completo (webhooks, pipelines, jobs, event schemas, projects). El **GitHub Action** permite enviar eventos desde workflows de CI/CD.

### Publicación de SDKs

Los SDKs de npm, PyPI, Packagist y RubyGems se publican via GitHub Actions:

```bash
# Publicar todos los paquetes
gh workflow run publish-sdks.yml -f package=all

# Publicar individualmente
gh workflow run publish-sdks.yml -f package=npm-sdk
gh workflow run publish-sdks.yml -f package=npm-cli
gh workflow run publish-sdks.yml -f package=pypi
gh workflow run publish-sdks.yml -f package=packagist
gh workflow run publish-sdks.yml -f package=rubygems
```

**Secrets requeridos en GitHub:**
- `NPM_TOKEN` — Token granular de npm con scope `@jobcelis` y bypass 2FA
- `PYPI_TOKEN` — Token de API de PyPI
- `RUBYGEMS_API_KEY` — API key de rubygems.org
- Packagist: auto-sync via webhook desde GitHub (no requiere secret)

**Go SDK:** Se publica automáticamente al crear un tag (`git tag v1.x.0 && git push origin v1.x.0`) en el repo `go-jobcelis`.

**Terraform:** Se publica via GoReleaser al crear un tag en el repo `terraform-provider-jobcelis`. Requiere secret `GPG_PRIVATE_KEY` para firmado.

**GitHub Action:** No requiere publicación — se usa directamente desde este repo con `uses: vladimirCeli/jobscelis/sdks/github-action@main`.

---

## Licencia

MIT
