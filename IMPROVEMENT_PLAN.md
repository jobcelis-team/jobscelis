# Plan de Mejoras - Jobcelis Platform

> Documento generado tras un análisis exhaustivo de todo el proyecto.
> **Fecha:** 2026-02-28 | **Estado:** Solo análisis, sin cambios aplicados.

---

## Tabla de Contenidos

1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Seguridad](#2-seguridad)
3. [Rendimiento y Caching](#3-rendimiento-y-caching)
4. [Base de Datos](#4-base-de-datos)
5. [Procesamiento en Segundo Plano](#5-procesamiento-en-segundo-plano)
6. [Observabilidad y Monitoreo](#6-observabilidad-y-monitoreo)
7. [Calidad de Código y Testing](#7-calidad-de-código-y-testing)
8. [API y Documentación](#8-api-y-documentación)
9. [Frontend y Assets](#9-frontend-y-assets)
10. [Infraestructura y Despliegue](#10-infraestructura-y-despliegue)
11. [Actualización de Dependencias](#11-actualización-de-dependencias)
12. [Resiliencia y Tolerancia a Fallos](#12-resiliencia-y-tolerancia-a-fallos)
13. [Prioridades de Implementación](#13-prioridades-de-implementación)

---

## 1. Resumen Ejecutivo

### Estado Actual
El proyecto es una plataforma de webhooks/eventos/jobs construida con:
- **Elixir ~> 1.17** + **Phoenix 1.8** + **LiveView 1.1**
- **PostgreSQL** (Supabase) con **Ecto 3.13**
- **Oban 2.20** para jobs en segundo plano
- **Guardian 2.4** + **Argon2id** para autenticación
- **Bandit** como servidor HTTP
- Arquitectura umbrella: `streamflix_core`, `streamflix_accounts`, `streamflix_web`

### Diagnóstico General
| Área | Estado | Prioridad |
|------|--------|-----------|
| Seguridad | Buena base, faltan encriptación at-rest y mejoras | ALTA |
| Caching | Inexistente | ALTA |
| Base de Datos | Índices básicos, falta optimización | ALTA |
| Testing | Mínimo (solo scaffolding) | ALTA |
| Monitoreo | Solo Telemetry básico | MEDIA |
| API Docs | No existe documentación OpenAPI | MEDIA |
| Compresión | Solo gzip estático | MEDIA |
| Rate Limiting | Custom ETS (funcional pero frágil) | MEDIA |
| Jobs/Oban | Bien configurado, falta dashboard | BAJA |
| Frontend | Bien optimizado tras refactor reciente | BAJA |

---

## 2. Seguridad

### 2.1 Encriptación At-Rest con Cloak Ecto
**Estado actual:** El campo `secret_encrypted` en webhooks almacena el secreto HMAC en texto plano. No hay encriptación de datos sensibles en la base de datos.

**Mejora:** Usar [Cloak Ecto](https://hex.pm/packages/cloak_ecto) `~> 1.3` para encriptar campos sensibles automáticamente.

**Campos a encriptar:**
- `webhooks.secret_encrypted` → AES-256-GCM
- `api_keys.key_hash` → Ya es hash SHA256 (OK, pero considerar doble capa)
- Cualquier dato PII futuro (emails, nombres si se requiere GDPR)

**Implementación:**
```elixir
# deps en streamflix_core/mix.exs
{:cloak, "~> 1.1"},
{:cloak_ecto, "~> 1.3"}

# Nuevo módulo: lib/streamflix_core/vault.ex
defmodule StreamflixCore.Vault do
  use Cloak.Vault, otp_app: :streamflix_core
end

# Tipo encriptado: lib/streamflix_core/encrypted/binary.ex
defmodule StreamflixCore.Encrypted.Binary do
  use Cloak.Ecto.Binary, vault: StreamflixCore.Vault
end

# En el schema de Webhook:
field :secret_encrypted, StreamflixCore.Encrypted.Binary
```

**Beneficios:** Si la BD es comprometida, los secretos permanecen ilegibles sin la clave de encriptación.

---

### 2.2 ~~Migrar de PBKDF2 a Argon2~~ COMPLETADO
**Estado:** Implementado. Todos los hashes usan Argon2id (memory-hard, RFC 9106, OWASP #1).
PBKDF2 eliminado completamente — ambas BDs reseteadas con Argon2id exclusivo.

**Archivos modificados:** `mix.exs`, `user.ex`, `authentication.ex`, `password_policy.ex`

---

### 2.3 Mejorar CORS (Restringir Orígenes)
**Estado actual:** `access-control-allow-origin: *` — permite cualquier origen.

**Mejora:** Usar [Corsica](https://hex.pm/packages/corsica) `~> 2.1` o restringir manualmente.

```elixir
# Opción 1: Corsica
plug Corsica,
  origins: [
    "https://jobcelis.com",
    "https://www.jobcelis.com",
    ~r/^https:\/\/.*\.jobcelis\.com$/
  ],
  allow_headers: ["authorization", "x-api-key", "content-type"],
  allow_methods: ["GET", "POST", "PUT", "PATCH", "DELETE"],
  max_age: 86400

# Opción 2: Mantener CORS abierto solo para rutas /api/*
# y restringir para rutas browser
```

**Nota:** Para APIs públicas, `*` puede ser aceptable, pero separar las políticas por ruta (API pública vs dashboard).

---

### 2.4 Sesión: Encriptar Cookies
**Estado actual:** Las cookies de sesión están **firmadas pero no encriptadas** (`store: :cookie`). El contenido es legible con Base64 decode.

**Mejora:**
```elixir
# En endpoint.ex, agregar encryption_salt:
@session_options [
  store: :cookie,
  key: "_streamflix_web_key",
  signing_salt: "Ig7MA6EW",
  encryption_salt: "encrypted_cookie_salt_min_32_chars",  # NUEVO
  same_site: "Lax",
  max_age: 2_592_000
]
```

**Beneficio:** El JWT almacenado en la cookie será ilegible incluso si se intercepta.

---

### 2.5 Verificación SSL de Base de Datos
**Estado actual:** `ssl: [verify: :verify_none]` en producción — no verifica el certificado del servidor PostgreSQL.

**Mejora:**
```elixir
# En runtime.exs para producción:
ssl: [
  verify: :verify_peer,
  cacerts: :public_key.cacerts_get(),  # Erlang/OTP 25+
  server_name_indication: to_charlist(db_host)
]
```

**Riesgo actual:** Vulnerable a ataques Man-in-the-Middle en la conexión a la base de datos.

---

### 2.6 Email Verification
**Estado actual:** Existe el campo `email_verified_at` pero nunca se utiliza. Los usuarios pueden registrarse con cualquier email sin verificación.

**Mejora:** Implementar flujo de verificación por email:
1. Al registrarse, generar token de verificación (Phoenix.Token o similar)
2. Enviar email con link de verificación (usar [Swoosh](https://hex.pm/packages/swoosh) `~> 1.17`)
3. Marcar `email_verified_at` cuando el usuario haga clic
4. Opcionalmente, restringir funcionalidades hasta verificar

**Librería recomendada:** `{:swoosh, "~> 1.17"}` + adaptador (Mailgun, SendGrid, SES, SMTP)

---

### 2.7 Account Lockout tras Intentos Fallidos
**Estado actual:** Rate limiting por IP (5 intentos/min en login) pero no hay bloqueo de cuenta después de N intentos fallidos.

**Mejora:**
- Agregar campo `failed_login_attempts` y `locked_until` al schema User
- Después de 5 intentos fallidos, bloquear cuenta 15 minutos
- Reset counter en login exitoso
- Notificar al usuario por email (si Swoosh implementado)

---

### 2.8 Escaneo de Seguridad con Sobelow
**Estado actual:** No se usa ningún escáner de seguridad estático.

**Mejora:** Agregar [Sobelow](https://hex.pm/packages/sobelow) `~> 0.14`

```elixir
# En streamflix_web/mix.exs
{:sobelow, "~> 0.14", only: [:dev, :test], runtime: false}

# Ejecutar:
# mix sobelow --config
# mix sobelow
```

**Detecta:** XSS, SQL injection, configuraciones inseguras, directory traversal, secrets hardcodeados, CSRF issues.

---

### 2.9 Content Security Policy Mejorada
**Estado actual:** CSP incluye `style-src 'self' 'unsafe-inline'`.

**Mejora:**
- Generar nonce por request para inline styles
- Eliminar `'unsafe-inline'` una vez que Tailwind compile todo a archivos estáticos
- Agregar `upgrade-insecure-requests` en producción

```elixir
"style-src 'self'",  # Sin unsafe-inline
"upgrade-insecure-requests"  # Forzar HTTPS para recursos
```

---

### 2.10 API Key: Timing-Safe Comparison
**Estado actual:** `verify_api_key/2` hace `where(k.key_hash == ^key_hash)` — la comparación SQL es timing-safe, pero el hash se compara como string.

**Mejora:** Usar `:crypto.hash_equals/2` (Erlang/OTP 25+) para comparación en memoria si se cambia a verificación en Elixir:
```elixir
:crypto.hash_equals(stored_hash, computed_hash)
```

---

## 3. Rendimiento y Caching

### 3.1 Implementar Cachex para Cache en Memoria
**Estado actual:** No existe ningún sistema de caching. Cada request a la BD es una consulta fresca.

**Mejora:** Agregar [Cachex](https://hex.pm/packages/cachex) `~> 4.1`

**Qué cachear:**
| Dato | TTL | Justificación |
|------|-----|---------------|
| `verify_api_key/2` resultado | 60s | Se llama en CADA request API |
| `get_project/1` | 120s | Se consulta frecuentemente |
| `list_active_webhooks/1` | 30s | Se consulta en cada evento |
| Estadísticas del admin dashboard | 300s | Queries agregadas costosas |
| Configuración legal/app | 3600s | Casi nunca cambia |

**Implementación:**
```elixir
# En streamflix_core/mix.exs
{:cachex, "~> 4.1"}

# En application.ex, agregar al supervisor:
{Cachex, name: :platform_cache, limit: 10_000}

# Uso:
def verify_api_key(_prefix, raw_key) do
  key_hash = hash_api_key(raw_key)
  Cachex.fetch(:platform_cache, {:api_key, key_hash}, fn _key ->
    result = # ... query actual a la BD
    {:commit, result, ttl: :timer.seconds(60)}
  end)
end
```

**Impacto estimado:** Reducción de 60-80% de queries a la BD en endpoints API.

---

### 3.2 Cache de Compilación Ecto Queries
**Estado actual:** Las queries Ecto se compilan en cada ejecución.

**Mejora:** Usar `prepare: :named` con queries frecuentes (solo si NO se usa PgBouncer en modo transaction).

**Alternativa con PgBouncer:** Ya usa `prepare: :unnamed` (correcto para Supabase). Para optimizar, considerar:
```elixir
# Reducir overhead de queries repetitivas con Cachex:
def list_events(project_id, opts) do
  cache_key = {:events, project_id, opts[:limit] || 20}
  Cachex.fetch(:platform_cache, cache_key, fn _ ->
    result = # query
    {:commit, result, ttl: :timer.seconds(15)}
  end)
end
```

---

### 3.3 Compresión HTTP: Brotli + Zstandard para Assets
**Estado actual:** Solo gzip habilitado para archivos estáticos (`Plug.Static` con `gzip: true`).

**Mejora:** Agregar [PhoenixBakery](https://github.com/hauleth/phoenix_bakery) `~> 0.1` para pre-comprimir con Brotli.

```elixir
# En streamflix_web/mix.exs
{:phoenix_bakery, "~> 0.1", runtime: false}

# En config/prod.exs
config :streamflix_web, StreamflixWebWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  compressors: [PhoenixBakery.Gzip, PhoenixBakery.Brotli]
```

**Beneficio:** Brotli ofrece ~15-20% mejor compresión que gzip, especialmente para CSS/JS/HTML.

---

### 3.4 Compresión de Respuestas Dinámicas
**Estado actual:** Las respuestas JSON de la API no se comprimen.

**Mejora:** Habilitar compresión en Bandit:
```elixir
# En endpoint.ex o config:
config :streamflix_web, StreamflixWebWeb.Endpoint,
  http: [
    ip: {0, 0, 0, 0},
    port: port,
    compress: true  # Habilita gzip para respuestas dinámicas
  ]
```

**Impacto:** Respuestas JSON grandes (listas de eventos, deliveries) se reducen ~70%.

---

### 3.5 Lazy Loading de Datos en LiveView
**Estado actual:** `PlatformDashboardLive.mount/3` carga TODO en un solo mount: proyecto, api_key, eventos, webhooks, jobs, deliveries (6 queries).

**Mejora:** Cargar datos on-demand por sección:
```elixir
def mount(_params, session, socket) do
  # Solo cargar lo esencial
  socket = assign(socket, :project, Platform.get_project_by_user_id(user.id))
  # Marcar secciones como "no cargadas"
  socket = assign(socket, :events, :not_loaded)
  socket = assign(socket, :webhooks, :not_loaded)
  # etc.

  if connected?(socket), do: send(self(), :load_initial)
  {:ok, socket}
end

def handle_info(:load_initial, socket) do
  # Cargar en paralelo con Task.async
  tasks = [
    Task.async(fn -> {:events, Platform.list_events(project_id, limit: 20)} end),
    Task.async(fn -> {:webhooks, Platform.list_webhooks(project_id)} end),
    Task.async(fn -> {:jobs, Platform.list_jobs(project_id)} end),
    Task.async(fn -> {:deliveries, Platform.list_deliveries(project_id: project_id, limit: 30)} end)
  ]
  results = Task.await_many(tasks, 5000)
  socket = Enum.reduce(results, socket, fn {key, data}, acc -> assign(acc, key, data) end)
  {:noreply, socket}
end
```

**Beneficio:** Mount inicial más rápido, datos cargados en paralelo, no bloquea el render.

---

### 3.6 ETag y Cache-Control Headers
**Estado actual:** No hay headers de cache para respuestas API.

**Mejora:** Agregar ETags para endpoints de lectura:
```elixir
# En un plug para API responses:
def call(conn, _opts) do
  register_before_send(conn, fn conn ->
    if conn.method == "GET" and conn.status == 200 do
      body = conn.resp_body
      etag = :crypto.hash(:md5, body) |> Base.encode16(case: :lower)
      conn
      |> put_resp_header("etag", ~s("#{etag}"))
      |> put_resp_header("cache-control", "private, max-age=0, must-revalidate")
    else
      conn
    end
  end)
end
```

---

### 3.7 Connection Pool de Finch para HTTP Saliente
**Estado actual:** `Req` se usa sin pool de conexiones configurado. Cada delivery crea una nueva conexión TCP.

**Mejora:** Configurar un pool Finch compartido:
```elixir
# En application.ex de streamflix_core:
{Finch, name: StreamflixCore.Finch,
  pools: %{
    :default => [size: 25, count: 1],    # Pool general
    # Pools específicos por host frecuente:
    # "https://api.example.com" => [size: 10, protocol: :http2]
  }}

# En DeliveryWorker:
Req.post(url, json: body, finch: StreamflixCore.Finch)
```

**Beneficio:** Reutilización de conexiones TCP, reducción de latencia en deliveries.

---

## 4. Base de Datos

### 4.1 Índices Compuestos Faltantes
**Estado actual:** Solo índices simples en columnas individuales.

**Mejoras necesarias:**
```sql
-- Deliveries: Query frecuente por project_id + status
CREATE INDEX idx_deliveries_project_status
  ON deliveries (webhook_id, status)
  WHERE status = 'pending';

-- Deliveries: Retry scheduling
CREATE INDEX idx_deliveries_retry
  ON deliveries (next_retry_at)
  WHERE status = 'pending' AND next_retry_at IS NOT NULL;

-- Events: Query frecuente por project + topic + fecha
CREATE INDEX idx_events_project_topic_date
  ON webhook_events (project_id, topic, occurred_at DESC);

-- Jobs: Scheduler query (active jobs only)
CREATE INDEX idx_jobs_active_schedule
  ON jobs (status, schedule_type)
  WHERE status = 'active';

-- API Keys: Lookup optimizado
CREATE INDEX idx_api_keys_hash_active
  ON api_keys (key_hash)
  WHERE status = 'active';

-- Job Runs: History por job
CREATE INDEX idx_job_runs_job_executed
  ON job_runs (job_id, executed_at DESC);
```

**Impacto:** Queries 10-100x más rápidas con datos grandes.

---

### 4.2 Partial Indexes para Soft Deletes
**Estado actual:** Muchas queries filtran `WHERE status = 'active'` pero los índices incluyen todos los registros.

**Mejora:** Crear índices parciales:
```sql
CREATE INDEX idx_projects_user_active
  ON projects (user_id)
  WHERE status = 'active';

CREATE INDEX idx_webhooks_project_active
  ON webhooks (project_id)
  WHERE status = 'active';
```

**Beneficio:** Índices más pequeños y rápidos, solo incluyen filas relevantes.

---

### 4.3 Paginación con Cursores
**Estado actual:** `limit(100)` sin paginación real. Cuando haya miles de eventos, solo se ven los primeros 100.

**Mejora:** Implementar cursor-based pagination:
```elixir
def list_events(project_id, opts) do
  limit = min(opts[:limit] || 20, 100)
  cursor = opts[:after]  # ID del último elemento visto

  query = WebhookEvent
    |> where(project_id: ^project_id)
    |> order_by([e], desc: e.occurred_at, desc: e.id)
    |> limit(^(limit + 1))  # +1 para saber si hay más

  query = if cursor do
    # Filtrar después del cursor
    where(query, [e], e.id < ^cursor)
  else
    query
  end

  results = Repo.all(query)
  has_next = length(results) > limit
  items = Enum.take(results, limit)

  %{items: items, has_next: has_next, next_cursor: List.last(items) && List.last(items).id}
end
```

---

### 4.4 Database Connection Pool Tuning
**Estado actual:** `pool_size: 10` en producción (default).

**Recomendación:**
```elixir
config :streamflix_core, StreamflixCore.Repo,
  pool_size: String.to_integer(System.get_env("DB_POOL_SIZE") || "20"),
  queue_target: 2_000,      # Target checkout time (2s)
  queue_interval: 5_000,    # Check interval (5s)
  timeout: 15_000            # Query timeout (15s)
```

**Regla general:** `pool_size` = (número de cores de la BD * 2) + 1, máximo ~50 para PostgreSQL.

---

### 4.5 Vacuum y Mantenimiento Automático
**Mejora:** Agregar migración para configurar autovacuum en tablas de alto tráfico:
```sql
ALTER TABLE webhook_events SET (
  autovacuum_vacuum_scale_factor = 0.05,  -- Vacuum cuando 5% de filas cambian (default 20%)
  autovacuum_analyze_scale_factor = 0.02
);

ALTER TABLE deliveries SET (
  autovacuum_vacuum_scale_factor = 0.05,
  autovacuum_analyze_scale_factor = 0.02
);
```

---

### 4.6 Archivado/Purga de Datos Antiguos
**Estado actual:** No hay mecanismo de limpieza. Las tablas `webhook_events`, `deliveries` y `job_runs` crecerán indefinidamente.

**Mejora:** Crear un Oban cron job para archivar datos antiguos:
```elixir
# Worker de limpieza mensual
defmodule StreamflixCore.Platform.PurgeWorker do
  use Oban.Worker, queue: :default, max_attempts: 1

  @impl true
  def perform(_job) do
    cutoff = DateTime.utc_now() |> DateTime.add(-90, :day)  # 90 días

    # Eliminar deliveries exitosas antiguas
    Repo.delete_all(
      from d in Delivery,
        where: d.status == "success" and d.inserted_at < ^cutoff
    )

    # Eliminar job_runs antiguos
    Repo.delete_all(
      from jr in JobRun,
        where: jr.executed_at < ^cutoff
    )

    :ok
  end
end
```

---

## 5. Procesamiento en Segundo Plano

### 5.1 Oban Web Dashboard (Ahora Open Source)
**Estado actual:** No hay visibilidad sobre los jobs en Oban. Solo logs.

**Mejora:** Agregar [Oban Web](https://hex.pm/packages/oban_web) `~> 2.11` (gratis desde enero 2025).

```elixir
# En streamflix_web/mix.exs
{:oban_web, "~> 2.11"}

# En router.ex
import ObanWeb.Router

scope "/admin" do
  pipe_through [:browser, :require_admin]
  oban_web("/oban")
end
```

**Beneficios:**
- Dashboard LiveView con estado de todas las colas
- Ver jobs fallidos, reintentar manualmente
- Métricas de throughput y latencia
- Filtros por cola, estado, worker

---

### 5.2 Oban: Migración V13 para Índices Compuestos
**Estado actual:** Usa Oban V12 migrations.

**Mejora:** Ejecutar migración V13 (disponible en Oban 2.20):
```elixir
defmodule StreamflixCore.Repo.Migrations.ObanV13 do
  use Ecto.Migration
  def up, do: Oban.Migration.up(version: 13)
  def down, do: Oban.Migration.down(version: 13)
end
```

**Beneficio:** Índices compuestos que aceleran el Pruner y las queries de scheduling.

---

### 5.3 Circuit Breaker para Deliveries
**Estado actual:** Si un webhook endpoint está caído, se siguen enviando intentos hasta agotar los 5 reintentos por cada delivery.

**Mejora:** Implementar circuit breaker por URL de webhook:
```elixir
# Trackear fallos consecutivos por webhook_id en ETS/Cachex
# Si > 10 fallos consecutivos en 5 minutos:
#   - Marcar webhook como "circuit_open"
#   - No encolar deliveries nuevas
#   - Retry automático después de 5 minutos
#   - Si sigue fallando, notificar al usuario
```

---

### 5.4 Priorización de Colas
**Estado actual:** Cola `delivery` con 10 workers fijos.

**Mejora:** Separar por prioridad:
```elixir
config :streamflix_core, Oban,
  queues: [
    delivery_high: 5,      # Primeros intentos (baja latencia)
    delivery_retry: 3,     # Reintentos (puede esperar)
    scheduled_job: 2,      # Jobs programados
    maintenance: 1,        # Limpieza, archivado
    default: 5
  ]
```

---

### 5.5 Unique Jobs para Evitar Duplicados
**Estado actual:** El Scheduler podría encolar el mismo job dos veces si el tick anterior aún se está procesando.

**Mejora:**
```elixir
defmodule StreamflixCore.Platform.ObanScheduledJobWorker do
  use Oban.Worker,
    queue: :scheduled_job,
    max_attempts: 1,
    unique: [period: 120, keys: [:job_id]]  # Prevenir duplicados en 2 min
end
```

---

## 6. Observabilidad y Monitoreo

### 6.1 PromEx: Métricas Prometheus + Grafana
**Estado actual:** Solo Telemetry básico con `telemetry_poller`. No hay sistema de métricas exportable.

**Mejora:** Agregar [PromEx](https://hex.pm/packages/prom_ex) `~> 1.11`

```elixir
# En streamflix_web/mix.exs
{:prom_ex, "~> 1.11"}

# Crear lib/streamflix_web/prom_ex.ex
defmodule StreamflixWeb.PromEx do
  use PromEx, otp_app: :streamflix_web

  @impl true
  def plugins do
    [
      PromEx.Plugins.Application,
      PromEx.Plugins.Beam,
      {PromEx.Plugins.Phoenix, router: StreamflixWebWeb.Router, endpoint: StreamflixWebWeb.Endpoint},
      {PromEx.Plugins.Ecto, repos: [StreamflixCore.Repo]},
      {PromEx.Plugins.Oban, oban_supervisors: [Oban]},
      PromEx.Plugins.PhoenixLiveView
    ]
  end

  @impl true
  def dashboards do
    [
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"},
      {:prom_ex, "phoenix.json"},
      {:prom_ex, "ecto.json"},
      {:prom_ex, "oban.json"},
      {:prom_ex, "phoenix_live_view.json"}
    ]
  end
end
```

**Métricas que obtienes automáticamente:**
- Request duration por ruta
- Ecto query time por tabla/operación
- Oban job throughput/latencia/fallos por cola
- BEAM memory, process count, scheduler utilization
- LiveView mount/handle_event timing

---

### 6.2 Sentry para Error Tracking
**Estado actual:** Los errores se logean pero no se agregan ni notifican.

**Mejora:** Agregar [Sentry](https://hex.pm/packages/sentry) `~> 11.0`

```elixir
# En streamflix_web/mix.exs
{:sentry, "~> 11.0"}

# En config/prod.exs
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: :prod,
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()],
  integrations: [
    oban: [capture_errors: true]
  ]

# En config/config.exs
config :logger,
  backends: [:console, Sentry.LoggerBackend]
```

**Beneficios:** Alertas en tiempo real por errores, agrupación inteligente, contexto de request.

---

### 6.3 Structured Logging con LoggerJSON
**Estado actual:** Logs en formato texto plano.

**Mejora:** Agregar [LoggerJSON](https://hex.pm/packages/logger_json) `~> 7.0`

```elixir
# En streamflix_web/mix.exs
{:logger_json, "~> 7.0"}

# En config/prod.exs
config :logger, :default_handler,
  formatter: {LoggerJSON.Formatters.Basic, metadata: [:request_id, :user_id]}
```

**Beneficios:** Logs parseables por ELK/Datadog/CloudWatch, búsqueda estructurada, correlación por request_id.

---

### 6.4 Health Check Endpoint
**Estado actual:** No existe endpoint de health check.

**Mejora:** Crear `/health` endpoint:
```elixir
# En router.ex (fuera de pipelines)
get "/health", HealthController, :check

# HealthController:
def check(conn, _params) do
  db_ok = try do
    Repo.query!("SELECT 1")
    true
  rescue
    _ -> false
  end

  status = if db_ok, do: 200, else: 503
  json(conn, %{status: if(db_ok, do: "ok", else: "degraded"), db: db_ok, version: "1.0.0"})
end
```

**Uso:** Load balancers, Kubernetes readiness probes, monitoring.

---

## 7. Calidad de Código y Testing

### 7.1 Test Suite Completa
**Estado actual:** Solo tests de scaffolding (hello world tests, error page tests). **Cobertura estimada: <5%**.

**Mejora:** Implementar tests en 4 niveles:

**Nivel 1: Unit Tests (contextos)**
```elixir
# test/streamflix_core/platform_test.exs
describe "create_event/2" do
  test "creates event and enqueues deliveries" do ...
  test "matches webhooks by topic" do ...
  test "respects webhook filters" do ...
  test "handles empty payload" do ...
end

# test/streamflix_accounts/authentication_test.exs
describe "authenticate/2" do
  test "returns user with valid credentials" do ...
  test "returns error for invalid password" do ...
  test "returns error for inactive user" do ...
  test "timing-safe for non-existent user" do ...
end
```

**Nivel 2: Integration Tests (controllers)**
```elixir
# test/streamflix_web/controllers/api/v1/platform_events_controller_test.exs
describe "POST /api/v1/events" do
  test "creates event with valid API key" do ...
  test "returns 401 without API key" do ...
  test "returns 401 with invalid API key" do ...
  test "returns 429 when rate limited" do ...
end
```

**Nivel 3: LiveView Tests**
```elixir
# test/streamflix_web/live/platform_dashboard_live_test.exs
describe "PlatformDashboardLive" do
  test "renders dashboard for authenticated user" do ...
  test "redirects unauthenticated user" do ...
  test "sends test event" do ...
end
```

**Nivel 4: E2E Tests (opcional, con Wallaby)**

---

### 7.2 Test Factories con ExMachina
**Mejora:** Agregar [ExMachina](https://hex.pm/packages/ex_machina) `~> 2.8`

```elixir
# test/support/factory.ex
defmodule StreamflixCore.Factory do
  use ExMachina.Ecto, repo: StreamflixCore.Repo

  def user_factory do
    %StreamflixAccounts.Schemas.User{
      email: sequence(:email, &"user#{&1}@test.com"),
      name: "Test User",
      password_hash: Argon2.hash_pwd_salt("Password123"),
      status: "active",
      role: "user"
    }
  end

  def project_factory do
    %StreamflixCore.Schemas.Project{
      name: "Test Project",
      status: "active",
      user_id: nil
    }
  end

  # ... factories para cada schema
end
```

---

### 7.3 Mox para Mocking de Servicios Externos
**Mejora:** Agregar [Mox](https://hex.pm/packages/mox) `~> 1.2` para mockear HTTP calls:

```elixir
# Definir behaviour para HTTP client
defmodule StreamflixCore.HTTPClient do
  @callback post(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
end

# En test:
Mox.defmock(StreamflixCore.MockHTTP, for: StreamflixCore.HTTPClient)

# Inyectar en config/test.exs:
config :streamflix_core, :http_client, StreamflixCore.MockHTTP
```

**Beneficio:** Tests determinísticos sin llamadas HTTP reales.

---

### 7.4 Code Coverage con ExCoveralls
**Mejora:** Agregar [ExCoveralls](https://hex.pm/packages/excoveralls) `~> 0.18`

```elixir
# En cada app mix.exs
{:excoveralls, "~> 0.18", only: :test}

# En mix.exs raíz
def project do
  [
    test_coverage: [tool: ExCoveralls],
    preferred_cli_env: [coveralls: :test, "coveralls.html": :test]
  ]
end

# Ejecutar:
# mix coveralls.html --umbrella
```

**Meta:** Alcanzar >80% de cobertura.

---

### 7.5 Credo para Linting
**Estado actual:** `credo` está en deps pero no se ha configurado ni ejecutado.

**Mejora:** Crear `.credo.exs` con reglas estrictas:
```bash
mix credo gen.config
mix credo --strict
```

**Integrar en CI:** `mix credo --strict --format=oneline`

---

### 7.6 Dialyzer para Análisis Estático de Tipos
**Estado actual:** `dialyxir` está en deps pero no se usa.

**Mejora:**
```bash
# Primera ejecución (genera PLT, tarda ~5-10 min):
mix dialyzer

# Agregar @spec a funciones públicas de contextos:
@spec create_event(String.t(), map()) :: {:ok, WebhookEvent.t()} | {:error, Ecto.Changeset.t()}
def create_event(project_id, body) do ...
```

---

## 8. API y Documentación

### 8.1 OpenAPI/Swagger con open_api_spex
**Estado actual:** No existe documentación de la API. Los consumidores deben leer código para entender endpoints.

**Mejora:** Agregar [open_api_spex](https://hex.pm/packages/open_api_spex) `~> 3.22`

```elixir
# En streamflix_web/mix.exs
{:open_api_spex, "~> 3.22"}

# Crear ApiSpec module
defmodule StreamflixWebWeb.ApiSpec do
  alias OpenApiSpex.{Info, OpenApi, Paths, Server}

  @behaviour OpenApi
  @impl OpenApi
  def spec do
    %OpenApi{
      info: %Info{
        title: "Jobcelis API",
        version: "1.0.0",
        description: "Webhook events, jobs, and delivery management API"
      },
      servers: [%Server{url: "https://jobcelis.com"}],
      paths: Paths.from_router(StreamflixWebWeb.Router)
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end

# Servir Swagger UI en /api/docs
scope "/api" do
  get "/docs", OpenApiSpex.Plug.SwaggerUI, path: "/api/openapi"
  get "/openapi", OpenApiSpex.Plug.RenderSpec, []
end
```

**Beneficios:**
- Documentación interactiva auto-generada
- Validación automática de request/response
- Generación de SDKs para clientes
- Especificación compartible (JSON/YAML)

---

### 8.2 Versionamiento de API
**Estado actual:** Solo `/api/v1/`. No hay estrategia para v2.

**Recomendación:** El versionamiento actual es correcto. Documentar política:
- v1 será soportado indefinidamente
- Cambios breaking solo en v2+
- Deprecation headers cuando sea necesario

---

### 8.3 Paginación Estandarizada en API
**Estado actual:** Solo `?limit=N` sin paginación real.

**Mejora:** Implementar cursor-based pagination en todos los endpoints de lista:
```json
// GET /api/v1/events?limit=20&after=uuid-cursor
{
  "data": [...],
  "meta": {
    "has_next": true,
    "next_cursor": "abc123",
    "total": 1543
  }
}
```

---

### 8.4 Rate Limiting Headers en API
**Estado actual:** Solo retorna 429 cuando se excede. No indica cuántos requests quedan.

**Mejora:** Agregar headers estándar:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1709136000
```

---

## 9. Frontend y Assets

### 9.1 Lazy Loading de Imágenes
**Estado actual:** Las imágenes se cargan todas al inicio.

**Mejora:** Agregar `loading="lazy"` a todas las imágenes no críticas:
```html
<img src="/images/feature.png" loading="lazy" alt="..." />
```

---

### 9.2 Preload de Assets Críticos
**Mejora:** En el layout root, agregar preloads:
```html
<link rel="preload" href="/assets/app.css" as="style" />
<link rel="preload" href="/assets/app.js" as="script" />
<link rel="preconnect" href="https://fonts.googleapis.com" />
```

---

### 9.3 Service Worker para Offline
**Mejora futura (baja prioridad):** Crear un service worker básico para cachear assets estáticos y mostrar página offline.

---

### 9.4 Eliminar VideoPlayer Hook
**Estado actual:** `app.js` contiene un hook `VideoPlayer` de ~200 líneas para un reproductor de video completo. El proyecto es una plataforma de webhooks, no de streaming.

**Mejora:** Eliminar el hook VideoPlayer y código relacionado para reducir el bundle JS.

---

## 10. Infraestructura y Despliegue

### 10.1 CDN para Assets Estáticos
**Estado actual:** Assets servidos directamente desde el servidor Phoenix.

**Mejora:** Configurar CDN (Cloudflare, AWS CloudFront):
```elixir
# En config/prod.exs
config :streamflix_web, StreamflixWebWeb.Endpoint,
  static_url: [
    scheme: "https",
    host: "cdn.jobcelis.com",
    port: 443
  ]
```

**Beneficios:** Latencia reducida globalmente, offload del servidor, cache edge.

---

### 10.2 Release con Mix Release
**Estado actual:** Usa `mix phx.server` directamente (parece ser).

**Mejora:** Compilar releases nativos:
```elixir
# En mix.exs raíz
def project do
  [
    releases: [
      streamflix: [
        include_executables_for: [:unix],
        applications: [
          streamflix_core: :permanent,
          streamflix_accounts: :permanent,
          streamflix_web: :permanent
        ]
      ]
    ]
  ]
end
```

```bash
MIX_ENV=prod mix release
_build/prod/rel/streamflix/bin/streamflix start
```

**Beneficios:** Binary optimizado, startup más rápido, sin necesidad de Elixir instalado.

---

### 10.3 Docker Multi-Stage Build Optimizado
**Mejora:** Verificar que el Dockerfile use multi-stage para reducir tamaño:
```dockerfile
# Stage 1: Build
FROM elixir:1.19-otp-27-alpine AS build
# ... compile release

# Stage 2: Runtime (solo ~50MB)
FROM alpine:3.19
# ... copy release only
```

---

### 10.4 Fly.io para Edge Computing
**Estado actual:** Desplegado en Azure.

**Alternativa futura:** [Fly.io](https://fly.io) ofrece:
- Deploy Elixir con clustering BEAM automático
- Réplicas en múltiples regiones (edge)
- PostgreSQL gestionado con read replicas
- Pricing competitivo para startups
- `fly launch` detecta Phoenix automáticamente

---

### 10.5 CI/CD Pipeline
**Mejora:** Crear `.github/workflows/ci.yml`:
```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.19'
          otp-version: '27'
      - run: mix deps.get
      - run: mix compile --warnings-as-errors
      - run: mix format --check-formatted
      - run: mix credo --strict
      - run: mix sobelow --config
      - run: mix coveralls
      - run: mix dialyzer
```

---

## 11. Actualización de Dependencias

### Dependencias a Actualizar/Agregar

| Dependencia | Actual | Recomendada | Acción |
|-------------|--------|-------------|--------|
| `elixir` | ~> 1.17 | 1.19.5 | Actualizar (4x compilación más rápida) |
| `phoenix` | ~> 1.8 | 1.8.3 | Verificar que esté actualizado |
| `oban` | ~> 2.20 | 2.20.3 | Actualizar y ejecutar migration V13 |
| `pbkdf2_elixir` | ~> 2.2 | — | **REMOVIDO.** Reemplazado por `argon2_elixir ~> 4.1` |
| `req` | ~> 0.5 | 0.5.17 | Actualizar |
| `postgrex` | ~> 0.21 | 0.22.0 | Actualizar |
| **NUEVAS** | | | |
| `cachex` | — | ~> 4.1 | **AGREGAR** (caching) |
| `cloak_ecto` | — | ~> 1.3 | **AGREGAR** (encryption at-rest) |
| `oban_web` | — | ~> 2.11 | **AGREGAR** (job dashboard) |
| `prom_ex` | — | ~> 1.11 | **AGREGAR** (métricas) |
| `sentry` | — | ~> 11.0 | **AGREGAR** (error tracking) |
| `logger_json` | — | ~> 7.0 | **AGREGAR** (structured logs) |
| `open_api_spex` | — | ~> 3.22 | **AGREGAR** (API docs) |
| `sobelow` | — | ~> 0.14 | **AGREGAR** (security scan) |
| `excoveralls` | — | ~> 0.18 | **AGREGAR** (code coverage) |
| `ex_machina` | — | ~> 2.8 | **AGREGAR** (test factories) |
| `mox` | — | ~> 1.2 | **AGREGAR** (mocking) |
| `phoenix_bakery` | — | ~> 0.1 | **AGREGAR** (brotli compression) |
| `swoosh` | — | ~> 1.17 | **AGREGAR** (email sending) |
| `hammer` | — | ~> 7.2 | **CONSIDERAR** (reemplazar rate limit custom) |
| `corsica` | — | ~> 2.1 | **CONSIDERAR** (reemplazar CORS custom) |

---

## 12. Resiliencia y Tolerancia a Fallos

### 12.1 Supervisión y Reinicio Automático
**Estado actual:** Supervisor tree básico con `one_for_one`.

**Mejoras:**
- Agregar `max_restarts` y `max_seconds` a supervisores
- Considerar `rest_for_one` para dependencias (si Repo cae, detener Scheduler)
- Agregar `Supervisor.child_spec` con IDs descriptivos

---

### 12.2 Graceful Shutdown
**Estado actual:** No hay manejo de shutdown graceful.

**Mejora:** Configurar Oban para drain en shutdown:
```elixir
# Ya incluido en Oban por defecto, pero verificar:
config :streamflix_core, Oban,
  shutdown_grace_period: 15_000  # 15s para completar jobs en vuelo
```

---

### 12.3 Timeouts Explícitos en Todas las Queries
**Estado actual:** Algunas queries no tienen timeout explícito.

**Mejora:** Configurar timeout global de Repo:
```elixir
config :streamflix_core, StreamflixCore.Repo,
  timeout: 15_000,          # Query timeout
  ownership_timeout: 60_000  # Para tests
```

---

### 12.4 PubSub para Actualizaciones en Tiempo Real
**Estado actual:** Phoenix.PubSub configurado pero no utilizado.

**Mejora:** Usar PubSub para actualizar LiveViews en tiempo real:
```elixir
# Cuando se crea un evento:
Phoenix.PubSub.broadcast(StreamflixCore.PubSub, "project:#{project_id}", {:new_event, event})

# En PlatformDashboardLive:
def mount(...) do
  if connected?(socket) do
    Phoenix.PubSub.subscribe(StreamflixCore.PubSub, "project:#{project.id}")
  end
end

def handle_info({:new_event, event}, socket) do
  events = [event | socket.assigns.events] |> Enum.take(20)
  {:noreply, assign(socket, :events, events)}
end
```

**Beneficio:** Dashboard se actualiza automáticamente cuando llegan eventos, sin polling.

---

### 12.5 Telemetry para Custom Metrics
**Mejora:** Agregar telemetry events a operaciones críticas:
```elixir
# En Platform.create_event/2:
:telemetry.execute(
  [:jobcelis, :event, :created],
  %{count: 1, deliveries: length(deliveries)},
  %{project_id: project_id, topic: topic}
)

# En DeliveryWorker.run/1:
:telemetry.execute(
  [:jobcelis, :delivery, :completed],
  %{duration: duration_ms},
  %{status: status, webhook_url: url}
)
```

---

## 13. Prioridades de Implementación

### Fase 1: Seguridad Crítica (1-2 semanas)
| # | Mejora | Sección | Esfuerzo |
|---|--------|---------|----------|
| 1 | Encriptar cookies de sesión | 2.4 | 30 min |
| 2 | Cloak Ecto para secrets | 2.1 | 2-3 horas |
| 3 | Verificación SSL de BD | 2.5 | 30 min |
| 4 | Sobelow scanner | 2.8 | 1 hora |
| 5 | Restringir CORS | 2.3 | 1 hora |

### Fase 2: Rendimiento (1-2 semanas)
| # | Mejora | Sección | Esfuerzo |
|---|--------|---------|----------|
| 6 | Cachex para API keys y queries | 3.1 | 3-4 horas |
| 7 | Índices compuestos en BD | 4.1, 4.2 | 2-3 horas |
| 8 | Finch connection pool | 3.7 | 1 hora |
| 9 | Compresión Brotli | 3.3 | 1 hora |
| 10 | Compresión dinámica | 3.4 | 30 min |

### Fase 3: Observabilidad (1 semana)
| # | Mejora | Sección | Esfuerzo |
|---|--------|---------|----------|
| 11 | Oban Web dashboard | 5.1 | 1-2 horas |
| 12 | PromEx métricas | 6.1 | 2-3 horas |
| 13 | Sentry error tracking | 6.2 | 1-2 horas |
| 14 | LoggerJSON | 6.3 | 1 hora |
| 15 | Health check endpoint | 6.4 | 30 min |

### Fase 4: Testing (2-3 semanas)
| # | Mejora | Sección | Esfuerzo |
|---|--------|---------|----------|
| 16 | ExMachina factories | 7.2 | 2-3 horas |
| 17 | Mox para HTTP | 7.3 | 2-3 horas |
| 18 | Unit tests (contextos) | 7.1 | 1 semana |
| 19 | Integration tests (API) | 7.1 | 3-5 días |
| 20 | ExCoveralls + CI | 7.4 | 1-2 horas |

### Fase 5: API y Documentación (1 semana)
| # | Mejora | Sección | Esfuerzo |
|---|--------|---------|----------|
| 21 | OpenAPI/Swagger | 8.1 | 3-5 días |
| 22 | Paginación con cursores | 4.3 | 1-2 días |
| 23 | Rate limit headers | 8.4 | 2-3 horas |

### Fase 6: Funcionalidades (2 semanas)
| # | Mejora | Sección | Esfuerzo |
|---|--------|---------|----------|
| 24 | Email verification (Swoosh) | 2.6 | 2-3 días |
| 25 | Account lockout | 2.7 | 3-4 horas |
| 26 | PubSub real-time updates | 12.4 | 3-4 horas |
| 27 | Purge worker (limpieza) | 4.6 | 2-3 horas |
| 28 | Circuit breaker | 5.3 | 1 día |

### Fase 7: Infraestructura (1 semana)
| # | Mejora | Sección | Esfuerzo |
|---|--------|---------|----------|
| 29 | CDN para assets | 10.1 | 2-3 horas |
| 30 | CI/CD pipeline | 10.5 | 3-4 horas |
| 31 | Docker optimizado | 10.3 | 1-2 horas |
| 32 | Mix release | 10.2 | 1-2 horas |

### Fase 8: Largo Plazo
| # | Mejora | Sección | Esfuerzo |
|---|--------|---------|----------|
| 33 | Migrar a Argon2 | 2.2 | 1 día |
| 34 | Actualizar Elixir 1.19 | 11 | 1-2 horas |
| 35 | Oban V13 migration | 5.2 | 30 min |
| 36 | Eliminar VideoPlayer hook | 9.4 | 30 min |
| 37 | Lazy loading LiveView | 3.5 | 3-4 horas |

---

## Resumen de Librerías Nuevas

```elixir
# === SEGURIDAD ===
{:cloak, "~> 1.1"},
{:cloak_ecto, "~> 1.3"},
{:sobelow, "~> 0.14", only: [:dev, :test], runtime: false},

# === RENDIMIENTO ===
{:cachex, "~> 4.1"},
{:phoenix_bakery, "~> 0.1", runtime: false},

# === MONITOREO ===
{:prom_ex, "~> 1.11"},
{:sentry, "~> 11.0"},
{:logger_json, "~> 7.0"},
{:oban_web, "~> 2.11"},

# === API ===
{:open_api_spex, "~> 3.22"},

# === TESTING ===
{:excoveralls, "~> 0.18", only: :test},
{:ex_machina, "~> 2.8", only: :test},
{:mox, "~> 1.2", only: :test},

# === EMAIL ===
{:swoosh, "~> 1.17"},

# === CONSIDERAR (reemplazan código custom) ===
# {:hammer, "~> 7.2"},        # Reemplaza rate_limit.ex custom
# {:corsica, "~> 2.1"},       # Reemplaza cors.ex custom
{:argon2_elixir, "~> 4.1"},  # IMPLEMENTADO — reemplaza pbkdf2 como hashing primario
```

---

> **Total de mejoras identificadas:** 37
> **Librerías nuevas recomendadas:** 13 (+ 3 opcionales)
> **Tiempo estimado total:** 8-12 semanas (implementación progresiva por fases)
