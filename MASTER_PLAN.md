# PLAN MAESTRO - Jobcelis Platform
# Mejoras Técnicas + Nuevas Funcionalidades

> Análisis exhaustivo de todo el proyecto. **Sin cambios aplicados.**
> Fecha: 2026-02-28

---

## PARTE A: MEJORAS TÉCNICAS (Infraestructura y Calidad)

Estas mejoras NO agregan funcionalidades visibles al usuario, pero hacen el software robusto, seguro y rápido.

---

### A1. Encriptar Cookies de Sesión
**Problema:** Las cookies están firmadas pero NO encriptadas. El JWT guardado en la cookie se puede leer con Base64 decode.
**Solución:** Agregar `encryption_salt` en `endpoint.ex`.
**Archivos:** `endpoint.ex`
**Esfuerzo:** 30 minutos
**Impacto:** ALTO (seguridad)

---

### A2. Encriptación At-Rest (Cloak Ecto)
**Problema:** `webhooks.secret_encrypted` guarda el secreto HMAC en texto plano en PostgreSQL. Si la BD se compromete, todos los secretos quedan expuestos.
**Solución:** Librería `cloak_ecto ~> 1.3` para encriptar con AES-256-GCM automáticamente al guardar y desencriptar al leer.
**Archivos nuevos:** `vault.ex`, `encrypted/binary.ex`
**Archivos modificados:** `webhook.ex` (cambiar tipo del campo), `mix.exs`, `config.exs`, migración
**Esfuerzo:** 2-3 horas
**Impacto:** ALTO (seguridad)

---

### A3. Verificación SSL de Base de Datos
**Problema:** `ssl: [verify: :verify_none]` en producción. No verifica certificado del servidor PostgreSQL. Vulnerable a Man-in-the-Middle.
**Solución:** Cambiar a `verify: :verify_peer` con `cacerts: :public_key.cacerts_get()`.
**Archivos:** `runtime.exs`
**Esfuerzo:** 30 minutos
**Impacto:** ALTO (seguridad)

---

### A4. Restringir CORS
**Problema:** `access-control-allow-origin: *` permite cualquier origen.
**Solución:** Restringir a `jobcelis.com` y subdominios para rutas browser. Mantener abierto solo para `/api/*`.
**Archivos:** `cors.ex`
**Esfuerzo:** 1 hora
**Impacto:** MEDIO (seguridad)

---

### A5. Sobelow - Scanner de Seguridad
**Problema:** No hay análisis estático de seguridad.
**Solución:** Agregar `sobelow ~> 0.14` y ejecutar `mix sobelow`. Detecta XSS, SQL injection, secrets hardcodeados, configs inseguras.
**Archivos:** `mix.exs` (web)
**Esfuerzo:** 1 hora
**Impacto:** MEDIO (seguridad)

---

### A6. Cachex - Cache en Memoria
**Problema:** Cero caching. Cada request API consulta la BD (verify_api_key se ejecuta en CADA request).
**Solución:** `cachex ~> 4.1`. Cachear: verificación de API key (60s TTL), proyecto (120s), webhooks activos (30s), stats admin (300s).
**Archivos nuevos:** Ninguno (se agrega al supervisor)
**Archivos modificados:** `application.ex`, `platform.ex`, `mix.exs`
**Esfuerzo:** 3-4 horas
**Impacto:** MUY ALTO (rendimiento, reduce 60-80% queries)

---

### A7. Índices Compuestos en PostgreSQL
**Problema:** Solo índices simples. Con datos grandes, queries se vuelven lentas.
**Solución:** Migración con índices compuestos y parciales:
- `deliveries(webhook_id, status) WHERE status = 'pending'`
- `deliveries(next_retry_at) WHERE status = 'pending'`
- `webhook_events(project_id, topic, occurred_at DESC)`
- `jobs(status, schedule_type) WHERE status = 'active'`
- `api_keys(key_hash) WHERE status = 'active'`
**Archivos:** Nueva migración
**Esfuerzo:** 2-3 horas
**Impacto:** ALTO (rendimiento, queries 10-100x más rápidas)

---

### A8. Finch Connection Pool
**Problema:** Cada delivery HTTP crea conexión TCP nueva. Lento y desperdicia recursos.
**Solución:** Configurar pool Finch compartido con 25 conexiones reutilizables. Pasar `finch: StreamflixCore.Finch` a Req.
**Archivos:** `application.ex`, `delivery_worker.ex`, `scheduled_job_runner.ex`
**Esfuerzo:** 1 hora
**Impacto:** ALTO (rendimiento deliveries)

---

### A9. Compresión Dinámica (Bandit)
**Problema:** Respuestas JSON de la API no se comprimen.
**Solución:** `compress: true` en config del Endpoint HTTP.
**Archivos:** `runtime.exs`, `dev.exs`
**Esfuerzo:** 30 minutos
**Impacto:** MEDIO (reduce ~70% tamaño de respuestas JSON grandes)

---

### A10. Compresión Brotli para Assets
**Problema:** Solo gzip para archivos estáticos.
**Solución:** `phoenix_bakery ~> 0.1` para pre-comprimir con Brotli al deploy. ~15-20% mejor que gzip.
**Archivos:** `mix.exs` (web), `prod.exs`
**Esfuerzo:** 1 hora
**Impacto:** MEDIO (frontend más rápido)

---

### A11. Oban Web Dashboard (Gratis)
**Problema:** No hay visibilidad sobre los jobs de Oban. Solo logs.
**Solución:** `oban_web ~> 2.11` (open source desde enero 2025). Dashboard LiveView en `/admin/oban`.
**Archivos:** `mix.exs` (web), `router.ex`
**Esfuerzo:** 1-2 horas
**Impacto:** ALTO (operaciones, debugging)

---

### A12. Oban Migración V13
**Problema:** Usa V12. V13 tiene índices compuestos que aceleran Pruner y scheduling.
**Solución:** Nueva migración con `Oban.Migration.up(version: 13)`.
**Archivos:** Nueva migración
**Esfuerzo:** 30 minutos
**Impacto:** MEDIO (rendimiento Oban)

---

### A13. Unique Jobs en Oban
**Problema:** El Scheduler podría encolar el mismo job dos veces si el tick anterior no terminó.
**Solución:** `unique: [period: 120, keys: [:job_id]]` en ObanScheduledJobWorker.
**Archivos:** `oban_scheduled_job_worker.ex`
**Esfuerzo:** 15 minutos
**Impacto:** MEDIO (evita duplicados)

---

### A14. Health Check Endpoint
**Problema:** No existe. Load balancers y monitoring no pueden verificar estado.
**Solución:** `GET /health` que verifica BD y retorna status JSON.
**Archivos nuevos:** `health_controller.ex`
**Archivos modificados:** `router.ex`
**Esfuerzo:** 30 minutos
**Impacto:** ALTO (operaciones)

---

### A15. Structured Logging (LoggerJSON)
**Problema:** Logs en texto plano, imposible parsear automáticamente.
**Solución:** `logger_json ~> 7.0` para JSON estructurado con request_id, user_id.
**Archivos:** `mix.exs`, `prod.exs`
**Esfuerzo:** 1 hora
**Impacto:** MEDIO (operaciones)

---

### A16. Paginación con Cursores
**Problema:** `limit(100)` sin paginación real. Con miles de registros, solo se ven los primeros 100.
**Solución:** Cursor-based pagination en Platform context y API controllers. Retornar `{data, has_next, next_cursor}`.
**Archivos:** `platform.ex`, todos los controllers API que listen
**Esfuerzo:** 1-2 días
**Impacto:** ALTO (escalabilidad)

---

### A17. PubSub Real-Time
**Problema:** PubSub configurado pero no utilizado. El dashboard no se actualiza en tiempo real.
**Solución:** Broadcast en `create_event/2`, subscribe en `PlatformDashboardLive.mount/3`. Dashboard se actualiza solo.
**Archivos:** `platform.ex`, `platform_dashboard_live.ex`
**Esfuerzo:** 3-4 horas
**Impacto:** ALTO (UX)

---

### A18. Purge Worker (Limpieza Automática)
**Problema:** Las tablas `webhook_events`, `deliveries`, `job_runs` crecen indefinidamente.
**Solución:** Oban cron job que cada semana elimina deliveries exitosas y job_runs > 90 días.
**Archivos nuevos:** `purge_worker.ex`
**Archivos modificados:** `config.exs` (Oban crontab)
**Esfuerzo:** 2-3 horas
**Impacto:** ALTO (mantenimiento BD)

---

### A19. Tests + ExMachina + Mox + ExCoveralls
**Problema:** Cobertura de tests <5%. Solo scaffolding.
**Solución:** Agregar factories (ExMachina), mocks HTTP (Mox), coverage (ExCoveralls). Escribir tests para Platform context, Authentication, API controllers, LiveViews.
**Archivos nuevos:** `factory.ex`, `mock_http.ex`, tests/
**Archivos modificados:** Todos los `mix.exs`, `test_helper.exs`
**Esfuerzo:** 2-3 semanas
**Impacto:** MUY ALTO (calidad, confianza en deploys)

---

### A20. Credo + Dialyzer (Ejecutar)
**Problema:** Están en deps pero nunca se ejecutaron.
**Solución:** `mix credo gen.config`, `mix credo --strict`, `mix dialyzer`. Agregar `@spec` a funciones públicas.
**Esfuerzo:** 1-2 días
**Impacto:** MEDIO (calidad de código)

---

### A21. OpenAPI/Swagger
**Problema:** La API no tiene documentación. Los clientes deben leer código.
**Solución:** `open_api_spex ~> 3.22`. Auto-genera spec OpenAPI 3.x desde controllers. Sirve Swagger UI en `/api/docs`.
**Archivos nuevos:** `api_spec.ex`, schemas por endpoint
**Archivos modificados:** Todos los API controllers (agregar operation specs), `router.ex`
**Esfuerzo:** 3-5 días
**Impacto:** ALTO (developer experience)

---

### A22. CI/CD Pipeline
**Problema:** No hay pipeline automatizado.
**Solución:** `.github/workflows/ci.yml` con: compile, format check, credo, sobelow, tests, coverage, dialyzer.
**Archivos nuevos:** `.github/workflows/ci.yml`
**Esfuerzo:** 3-4 horas
**Impacto:** ALTO (calidad)

---

### A23. Eliminar VideoPlayer Hook
**Problema:** `app.js` tiene ~200 líneas de un reproductor de video que no tiene nada que ver con webhooks.
**Solución:** Eliminar el hook y código relacionado.
**Archivos:** `app.js`
**Esfuerzo:** 30 minutos
**Impacto:** BAJO (limpieza, reduce bundle JS)

---

### A24. Migrar PBKDF2 a Argon2
**Problema:** PBKDF2 es vulnerable a ataques GPU paralelos. OWASP recomienda Argon2.
**Solución:** `argon2_elixir ~> 4.1`. Migración gradual: al login con PBKDF2, re-hashear con Argon2.
**Nota:** Requiere compilador C en Windows.
**Archivos:** `mix.exs` (accounts), `user.ex`, `authentication.ex`
**Esfuerzo:** 1 día
**Impacto:** MEDIO (seguridad largo plazo)

---

## PARTE B: NUEVAS FUNCIONALIDADES (Valor para el Usuario)

Estas funcionalidades amplían lo que Jobcelis ofrece como servicio. Todo construible con Elixir + PostgreSQL, sin servicios externos.

---

### B1. Dead Letter Queue (DLQ)

**Qué es:** Cuando un delivery falla todos sus reintentos (5), en vez de solo marcarlo "failed" y olvidarlo, moverlo a una cola especial donde el usuario puede inspeccionarlo, editarlo y reintentarlo.

**Tablas nuevas:**
```sql
CREATE TABLE dead_letters (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  delivery_id UUID REFERENCES deliveries(id),
  event_id UUID REFERENCES webhook_events(id),
  webhook_id UUID REFERENCES webhooks(id),
  original_payload JSONB NOT NULL,
  last_error TEXT,
  last_response_status INTEGER,
  attempts_exhausted INTEGER DEFAULT 5,
  resolved BOOLEAN DEFAULT FALSE,
  resolved_at TIMESTAMPTZ,
  inserted_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_dead_letters_project ON dead_letters(project_id, resolved, inserted_at DESC);
```

**Lógica:**
- En `delivery_worker.ex`: cuando `attempt_number >= max_attempts` y status es "failed", insertar en `dead_letters`
- En dashboard: nueva sección "Dead Letter Queue" con tabla de items no resueltos
- Acciones: "Ver payload", "Editar payload", "Reintentar", "Descartar"
- Al reintentar: crear nueva Delivery con el payload (original o editado), encolar ObanDeliveryWorker

**API endpoints nuevos:**
```
GET    /api/v1/dead-letters              # Listar (filtros: resolved, webhook_id)
GET    /api/v1/dead-letters/:id          # Ver detalle con payload completo
POST   /api/v1/dead-letters/:id/retry    # Reintentar (opcionalmente con payload modificado)
PATCH  /api/v1/dead-letters/:id/resolve  # Marcar como resuelto
```

**Archivos nuevos:** `dead_letter.ex` (schema), migración, `platform_dead_letters_controller.ex`
**Archivos modificados:** `platform.ex` (funciones DLQ), `delivery_worker.ex` (insertar en DLQ), `platform_dashboard_live.ex` (UI), `router.ex`
**Esfuerzo:** 2-3 días
**Impacto:** ALTO (ningún competidor open-source lo hace bien)

---

### B2. Event Replay

**Qué es:** Re-enviar todos los eventos de un rango de fechas a un webhook específico o a todos. El usuario selecciona "desde fecha X hasta fecha Y, topic Z" y el sistema re-crea deliveries para todos esos eventos.

**Lógica:**
- Query eventos por `project_id + topic (opcional) + rango de fechas`
- Para cada evento, crear nuevas Deliveries para los webhooks activos que matcheen
- Encolar como Oban jobs en una cola separada `replay` para no afectar deliveries normales
- Tracking: tabla `replays` con status, progress, total_events, delivered_count

**Tablas nuevas:**
```sql
CREATE TABLE replays (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  status VARCHAR(20) DEFAULT 'pending', -- pending, running, completed, failed
  filters JSONB, -- {topic, from_date, to_date, webhook_id}
  total_events INTEGER DEFAULT 0,
  processed_events INTEGER DEFAULT 0,
  created_by UUID REFERENCES users(id),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  inserted_at TIMESTAMPTZ DEFAULT NOW()
);
```

**API endpoints nuevos:**
```
POST   /api/v1/replays                   # Crear replay (body: {topic?, from, to, webhook_id?})
GET    /api/v1/replays                   # Listar replays con status
GET    /api/v1/replays/:id              # Ver progreso
DELETE /api/v1/replays/:id              # Cancelar replay en curso
```

**Dashboard:** Botón "Replay Events" con modal para seleccionar filtros. Barra de progreso en tiempo real con PubSub.

**Archivos nuevos:** `replay.ex` (schema), `replay_worker.ex` (Oban), migración, controller
**Archivos modificados:** `platform.ex`, `platform_dashboard_live.ex`, `router.ex`, Oban config (nueva cola `replay`)
**Esfuerzo:** 3-4 días
**Impacto:** MUY ALTO (feature #1 más pedida en el mercado)

---

### B3. Webhook Health Score

**Qué es:** Calcular automáticamente la "salud" de cada webhook basado en datos reales de deliveries.

**Métricas calculadas (sin tablas nuevas, todo desde `deliveries`):**
```elixir
def webhook_health(webhook_id) do
  # Últimas 24 horas
  since = DateTime.utc_now() |> DateTime.add(-24, :hour)

  stats = Repo.one(
    from d in Delivery,
    where: d.webhook_id == ^webhook_id and d.inserted_at >= ^since,
    select: %{
      total: count(d.id),
      success: count(fragment("CASE WHEN ? = 'success' THEN 1 END", d.status)),
      failed: count(fragment("CASE WHEN ? = 'failed' THEN 1 END", d.status)),
      avg_latency: avg(fragment("EXTRACT(EPOCH FROM ? - ?)", d.updated_at, d.inserted_at))
    }
  )

  success_rate = if stats.total > 0, do: stats.success / stats.total * 100, else: 100
  score = cond do
    success_rate >= 98 -> :healthy      # Verde
    success_rate >= 90 -> :degraded     # Amarillo
    true -> :critical                    # Rojo
  end

  Map.put(stats, :score, score)
  |> Map.put(:success_rate, success_rate)
end
```

**Dashboard:** Semáforo verde/amarillo/rojo junto a cada webhook. Tooltip con % éxito y latencia promedio.

**API endpoint nuevo:**
```
GET /api/v1/webhooks/:id/health   # {score, success_rate, avg_latency, total_24h, failed_24h}
```

**Archivos modificados:** `platform.ex` (función health), `platform_dashboard_live.ex` (UI), `platform_webhooks_controller.ex` (endpoint), `router.ex`
**Esfuerzo:** 1 día
**Impacto:** ALTO (diferenciador vs competencia)

---

### B4. Alertas Internas (Sistema de Notificaciones)

**Qué es:** Sistema de notificaciones dentro de la plataforma. Campana en el navbar con contador. Sin servicios externos.

**Tabla nueva:**
```sql
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  type VARCHAR(50) NOT NULL, -- webhook_failing, job_failed, key_used, replay_complete, etc.
  title VARCHAR(255) NOT NULL,
  message TEXT,
  metadata JSONB DEFAULT '{}',
  read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMPTZ,
  inserted_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_notifications_user ON notifications(user_id, read, inserted_at DESC);
```

**Triggers automáticos (creados en `platform.ex` y workers):**
- Webhook falla 5+ veces consecutivas → notificación "Webhook X está fallando"
- Job scheduled falla → notificación "Job X falló"
- API key usada por primera vez → notificación "Tu API key fue utilizada"
- Replay completado → notificación "Replay completado: X eventos re-enviados"
- Delivery en DLQ → notificación "Delivery movida a Dead Letter Queue"

**Dashboard:**
- Campana con badge en el navbar (LiveView PubSub, actualización real-time)
- Dropdown con últimas 10 notificaciones
- Página `/notifications` con historial completo
- Botón "Marcar todas como leídas"

**API endpoints:**
```
GET    /api/v1/notifications              # Listar (filtro: unread)
PATCH  /api/v1/notifications/:id/read     # Marcar como leída
POST   /api/v1/notifications/read-all     # Marcar todas como leídas
```

**Archivos nuevos:** `notification.ex` (schema), migración, `notifications_live.ex`, controller
**Archivos modificados:** `platform.ex`, `delivery_worker.ex`, `scheduled_job_runner.ex`, `layouts.ex` (campana), `router.ex`
**Esfuerzo:** 2-3 días
**Impacto:** ALTO

---

### B5. Webhook Simulator (Dry Run)

**Qué es:** Botón "Simular" que muestra QUÉ PASARÍA si se enviara un evento, SIN ejecutar el POST real.

**Lógica (todo ya existe, solo falta exponerlo):**
```elixir
def simulate_event(project_id, body) do
  {topic, payload} = extract_topic_and_payload(body)
  webhooks = list_active_webhooks_for_project(project_id)

  matching = Enum.filter(webhooks, &webhook_matches_event?(&1, %{topic: topic, payload: payload}))

  Enum.map(matching, fn webhook ->
    body = build_webhook_body(webhook, %{topic: topic, payload: payload, id: "simulated"})
    body_json = Jason.encode!(body)
    signature = if webhook.secret_encrypted do
      :crypto.mac(:hmac, :sha256, webhook.secret_encrypted, body_json) |> Base.encode64(padding: false)
    end

    %{
      webhook_id: webhook.id,
      webhook_url: webhook.url,
      would_send_body: body,
      would_send_headers: %{
        "content-type" => "application/json",
        "x-signature" => if(signature, do: "sha256=#{signature}", else: nil)
      },
      matched_by_topic: topic in (webhook.topics || []) or webhook.topics == [],
      matched_by_filters: filters_match?(webhook.filters, payload)
    }
  end)
end
```

**Dashboard:** Botón "Simular" en la sección "Enviar evento de prueba". Muestra modal con resultado: qué webhooks matchearían, qué body se enviaría, qué headers, qué firma HMAC.

**API endpoint:**
```
POST /api/v1/simulate   # Body: mismo que /events. Response: array de matches simulados
```

**Archivos modificados:** `platform.ex` (función simulate), `platform_dashboard_live.ex` (UI), `platform_events_controller.ex` (endpoint), `router.ex`
**Esfuerzo:** 3-4 horas
**Impacto:** ALTO (herramienta de debugging única)

---

### B6. Webhook Testing Sandbox (RequestBin propio)

**Qué es:** URL temporal donde el usuario recibe requests de prueba y los ve en tiempo real. Como Webhook.site pero dentro de Jobcelis.

**Tabla nueva:**
```sql
CREATE TABLE sandbox_endpoints (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  slug VARCHAR(32) UNIQUE NOT NULL, -- URL: /sandbox/abc123
  name VARCHAR(100),
  expires_at TIMESTAMPTZ NOT NULL, -- Auto-expira en 24h
  inserted_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE sandbox_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  endpoint_id UUID REFERENCES sandbox_endpoints(id) ON DELETE CASCADE,
  method VARCHAR(10) NOT NULL,
  path TEXT,
  headers JSONB DEFAULT '{}',
  body TEXT,
  query_params JSONB DEFAULT '{}',
  ip VARCHAR(45),
  inserted_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_sandbox_requests_endpoint ON sandbox_requests(endpoint_id, inserted_at DESC);
```

**Flujo:**
1. Usuario crea sandbox → genera URL tipo `https://jobcelis.com/sandbox/a1b2c3`
2. Cualquiera puede hacer POST/GET/PUT a esa URL
3. El request se guarda en `sandbox_requests`
4. PubSub notifica al LiveView del usuario
5. El usuario ve los requests aparecer en tiempo real
6. Sandbox expira automáticamente en 24h (Oban purge worker)

**Rutas:**
```elixir
# Catch-all para recibir requests
match "/sandbox/:slug", SandboxController, :receive, via: [:get, :post, :put, :patch, :delete]
match "/sandbox/:slug/*path", SandboxController, :receive, via: [:get, :post, :put, :patch, :delete]
```

**Dashboard:** Nueva sección "Sandbox" con:
- Botón "Crear endpoint de prueba"
- URL copiable
- Lista de requests recibidos en tiempo real
- Detalle de cada request (headers, body, method, IP)

**Archivos nuevos:** `sandbox_endpoint.ex`, `sandbox_request.ex`, `sandbox_controller.ex`, `sandbox_live.ex`, migración
**Archivos modificados:** `router.ex`, `platform.ex` (funciones sandbox)
**Esfuerzo:** 2-3 días
**Impacto:** MUY ALTO (elimina dependencia de webhook.site)

---

### B7. Audit Log

**Qué es:** Registro inmutable de toda acción realizada en la plataforma. Para compliance, debugging y seguridad.

**Tabla nueva:**
```sql
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  project_id UUID REFERENCES projects(id) ON DELETE SET NULL,
  action VARCHAR(100) NOT NULL, -- webhook.created, event.sent, key.regenerated, etc.
  resource_type VARCHAR(50), -- webhook, event, job, api_key, user, project
  resource_id UUID,
  metadata JSONB DEFAULT '{}', -- Datos adicionales del cambio
  ip_address VARCHAR(45),
  user_agent TEXT,
  inserted_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_audit_project ON audit_logs(project_id, inserted_at DESC);
CREATE INDEX idx_audit_user ON audit_logs(user_id, inserted_at DESC);
CREATE INDEX idx_audit_action ON audit_logs(action, inserted_at DESC);
```

**Acciones a registrar:**
- `webhook.created`, `webhook.updated`, `webhook.deleted`
- `event.created`, `event.deleted`
- `job.created`, `job.updated`, `job.deleted`
- `api_key.regenerated`
- `project.updated`
- `user.login`, `user.logout`, `user.password_changed`, `user.email_changed`
- `delivery.retried`
- `replay.started`

**Dashboard:** Nueva página `/audit` con timeline de actividad. Filtros por acción, usuario, recurso, fecha.

**API endpoint:**
```
GET /api/v1/audit-log   # Filtros: action, resource_type, from, to, limit
```

**Archivos nuevos:** `audit_log.ex` (schema), migración, `audit_live.ex`, controller
**Archivos modificados:** Todos los controllers y funciones de platform.ex (agregar llamada a `AuditLog.record/4` después de cada operación)
**Esfuerzo:** 2-3 días
**Impacto:** ALTO (compliance, debugging, seguridad)

---

### B8. Analytics Dashboard con Gráficas

**Qué es:** Página con gráficas de uso: eventos por día, latencia, tasa de éxito, top topics.

**Queries (todo desde tablas existentes):**
```elixir
# Eventos por día (últimos 30 días)
def events_per_day(project_id) do
  from(e in WebhookEvent,
    where: e.project_id == ^project_id and e.inserted_at >= ago(30, "day"),
    group_by: fragment("DATE(?)""", e.inserted_at),
    order_by: fragment("DATE(?)""", e.inserted_at),
    select: %{date: fragment("DATE(?)", e.inserted_at), count: count(e.id)}
  ) |> Repo.all()
end

# Tasa de éxito por webhook
def delivery_stats_by_webhook(project_id) do
  from(d in Delivery,
    join: w in Webhook, on: w.id == d.webhook_id,
    where: w.project_id == ^project_id and d.inserted_at >= ago(7, "day"),
    group_by: [w.id, w.url],
    select: %{
      webhook_url: w.url,
      total: count(d.id),
      success: count(fragment("CASE WHEN ? = 'success' THEN 1 END", d.status)),
      avg_latency: avg(fragment("EXTRACT(EPOCH FROM ? - ?)", d.updated_at, d.inserted_at))
    }
  ) |> Repo.all()
end
```

**Gráficas (Chart.js, librería JS gratuita, ~60KB):**
- Eventos por día (línea)
- Deliveries success vs failed (barras apiladas)
- Latencia p50/p95 por día (línea)
- Top 10 topics por volumen (donut)
- Webhooks por tasa de éxito (barras horizontales)

**Dashboard:** Nueva página `/analytics` o tab en el dashboard principal.

**Archivos nuevos:** `analytics_live.ex`, migración (ninguna, usa tablas existentes)
**Archivos modificados:** `platform.ex` (funciones de stats), `router.ex`, `app.js` (agregar Chart.js hook)
**Esfuerzo:** 2-3 días
**Impacto:** ALTO (diferenciador visual)

---

### B9. Retry Policies Personalizables

**Qué es:** Permitir al usuario configurar por webhook: cuántos reintentos, qué delays, qué tipo de backoff.

**Cambio en schema webhooks:**
```elixir
# Agregar al schema webhook.ex:
field :retry_config, :map, default: %{
  "max_attempts" => 5,
  "backoff_type" => "exponential",  # linear, exponential, fixed
  "backoff_seconds" => [60, 300, 900, 3600],  # custom delays
  "timeout_connect" => 5000,
  "timeout_receive" => 15000
}
```

**Lógica en delivery_worker.ex:**
```elixir
# En vez de hardcodear @backoff_seconds, leer de webhook.retry_config
def backoff(%Oban.Job{args: args, attempt: attempt}) do
  delivery = get_delivery(args["delivery_id"])
  webhook = delivery.webhook
  config = webhook.retry_config || %{}
  delays = config["backoff_seconds"] || [60, 300, 900, 3600]
  Enum.at(delays, attempt - 1, List.last(delays))
end
```

**Dashboard:** En el formulario de webhook, sección "Retry Policy":
- Max intentos: slider 1-20
- Tipo: dropdown (exponential, linear, fixed)
- Delays custom: inputs por intento
- Timeouts: connect y receive

**API:** Agregar `retry_config` al body de `POST/PATCH /api/v1/webhooks`

**Archivos modificados:** `webhook.ex`, `delivery_worker.ex`, `oban_delivery_worker.ex`, `platform_dashboard_live.ex`, `platform_webhooks_controller.ex`
**Migración:** ALTER TABLE webhooks ADD COLUMN retry_config JSONB DEFAULT '{}'
**Esfuerzo:** 1 día
**Impacto:** MEDIO-ALTO

---

### B10. Delayed Events (Envío Programado)

**Qué es:** Enviar un evento ahora pero programar que se entregue después. "Entregar en 30 minutos" o "entregar mañana a las 9am".

**Cambio en schema webhook_events:**
```elixir
field :deliver_at, :utc_datetime_usec  # NULL = entrega inmediata
```

**Lógica:**
- Si `deliver_at` es NULL o pasado → crear deliveries inmediatamente (comportamiento actual)
- Si `deliver_at` es futuro → guardar evento, NO crear deliveries
- Oban cron job cada minuto: buscar eventos con `deliver_at <= now()` y deliveries no creadas → crear deliveries

**API:** Agregar campo opcional `deliver_at` al body de `POST /api/v1/events`:
```json
{
  "topic": "reminder",
  "payload": {"message": "Recordatorio"},
  "deliver_at": "2026-03-01T09:00:00Z"
}
```

**Dashboard:** Checkbox "Programar entrega" con date/time picker en la sección "Enviar evento de prueba".

**Archivos nuevos:** `delayed_event_worker.ex` (Oban cron)
**Archivos modificados:** `webhook_event.ex`, `platform.ex`, `platform_events_controller.ex`, `platform_dashboard_live.ex`, migración
**Esfuerzo:** 1-2 días
**Impacto:** MEDIO-ALTO

---

### B11. Multi-Proyecto

**Qué es:** Actualmente cada usuario tiene 1 proyecto. Permitir múltiples proyectos con API keys y datos independientes.

**Cambios:**
- Quitar restricción de 1 proyecto por usuario en `register_user/1`
- Agregar endpoint `POST /api/v1/projects` para crear proyecto
- Agregar selector de proyecto en el dashboard
- Cada proyecto tiene su propio API key, webhooks, eventos, etc.

**Dashboard:** Dropdown de proyectos en la parte superior del dashboard. Botón "Nuevo Proyecto".

**API endpoints nuevos:**
```
GET    /api/v1/projects          # Listar mis proyectos
POST   /api/v1/projects          # Crear proyecto
PATCH  /api/v1/projects/:id      # Actualizar proyecto
DELETE /api/v1/projects/:id      # Desactivar proyecto
```

**Archivos modificados:** `platform.ex`, `platform_dashboard_live.ex` (selector), `router.ex`, controller nuevo
**Esfuerzo:** 2-3 días
**Impacto:** ALTO (escalabilidad del servicio)

---

### B12. API Key Scopes (Permisos Granulares)

**Qué es:** Crear API keys con permisos limitados. Actualmente una key puede hacer todo.

**Cambio en schema api_keys:**
```elixir
field :scopes, {:array, :string}, default: ["*"]
# Scopes posibles: "*", "events:read", "events:write", "webhooks:read",
#   "webhooks:write", "jobs:read", "jobs:write", "deliveries:read", "deliveries:retry"
```

**Lógica en api_key_auth.ex:**
```elixir
def call(conn, opts) do
  required_scope = opts[:scope] || "*"
  # Después de verificar API key...
  if "*" in api_key.scopes or required_scope in api_key.scopes do
    conn |> assign(:current_project, ...)
  else
    conn |> put_status(:forbidden) |> json(%{error: "Insufficient scope"}) |> halt()
  end
end
```

**Router:**
```elixir
scope "/api/v1" do
  pipe_through [:api, :api_key_auth]
  post "/events", EventsController, :create, assigns: %{required_scope: "events:write"}
  get "/events", EventsController, :index, assigns: %{required_scope: "events:read"}
end
```

**Dashboard:** Al regenerar token, checkboxes para seleccionar permisos.

**Archivos modificados:** `api_key.ex`, `api_key_auth.ex`, `platform.ex`, `platform_dashboard_live.ex`, migración
**Esfuerzo:** 1-2 días
**Impacto:** MEDIO-ALTO (seguridad avanzada)

---

### B13. IP Allowlist

**Qué es:** El usuario configura IPs permitidas para su API key. Requests desde otras IPs son rechazados.

**Cambio en schema api_keys:**
```elixir
field :allowed_ips, {:array, :string}, default: []  # Vacío = cualquier IP
```

**Lógica en api_key_auth.ex:**
```elixir
if api_key.allowed_ips == [] or client_ip in api_key.allowed_ips do
  # Permitir
else
  conn |> put_status(:forbidden) |> json(%{error: "IP not allowed"}) |> halt()
end
```

**Dashboard:** Campo de texto "IPs permitidas (una por línea)" en configuración de API key.

**Archivos modificados:** `api_key.ex`, `api_key_auth.ex`, `platform_dashboard_live.ex`, migración
**Esfuerzo:** 3-4 horas
**Impacto:** MEDIO (seguridad)

---

### B14. Event Schema Validation

**Qué es:** Definir JSON Schema por topic. Validar eventos antes de procesarlos.

**Tabla nueva:**
```sql
CREATE TABLE event_schemas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  topic VARCHAR(255) NOT NULL,
  version INTEGER DEFAULT 1,
  json_schema JSONB NOT NULL,
  status VARCHAR(20) DEFAULT 'active',
  inserted_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(project_id, topic, version)
);
```

**Lógica en `create_event/2`:**
```elixir
# Antes de crear el evento:
schema = get_schema_for_topic(project_id, topic)
if schema do
  case ExJsonSchema.Validator.validate(schema.json_schema, payload) do
    :ok -> # continuar
    {:error, errors} -> {:error, :schema_validation_failed, errors}
  end
end
```

**Librería:** `{:ex_json_schema, "~> 0.10"}` (gratis, hex)

**API endpoints:**
```
GET    /api/v1/schemas                # Listar schemas
POST   /api/v1/schemas                # Crear schema para topic
GET    /api/v1/schemas/:topic         # Ver schema de topic
DELETE /api/v1/schemas/:topic         # Eliminar schema
```

**Archivos nuevos:** `event_schema.ex`, controller, migración
**Archivos modificados:** `platform.ex`, `mix.exs`
**Esfuerzo:** 2 días
**Impacto:** MEDIO-ALTO (calidad de datos)

---

### B15. Batch Events (Agrupación)

**Qué es:** Configurar en webhook: "acumular eventos durante N segundos y enviar un array en un solo POST". Reduce 100 requests a 1.

**Cambio en schema webhooks:**
```elixir
field :batch_config, :map, default: nil
# batch_config: %{"enabled" => true, "window_seconds" => 60, "max_batch_size" => 100}
```

**Lógica:**
1. Cuando un evento matchea un webhook con `batch_config.enabled`:
   - NO crear delivery inmediata
   - Insertar en tabla `batch_items` (webhook_id, event_id, inserted_at)
2. Oban cron worker cada 10 segundos:
   - Buscar batch_items agrupados por webhook_id donde el más antiguo >= window_seconds
   - Crear UNA delivery con body = array de payloads
   - Limpiar batch_items procesados

**Tabla nueva:**
```sql
CREATE TABLE batch_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  webhook_id UUID REFERENCES webhooks(id) ON DELETE CASCADE,
  event_id UUID REFERENCES webhook_events(id) ON DELETE CASCADE,
  inserted_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_batch_webhook ON batch_items(webhook_id, inserted_at);
```

**Archivos nuevos:** `batch_item.ex`, `batch_worker.ex`, migración
**Archivos modificados:** `webhook.ex`, `platform.ex`, `platform_dashboard_live.ex`
**Esfuerzo:** 2-3 días
**Impacto:** MEDIO (optimización para alto volumen)

---

### B16. Exportar Datos (CSV/JSON)

**Qué es:** Botón "Exportar" en cada tabla del dashboard para descargar datos.

**Lógica:**
```elixir
def export_events_csv(project_id, opts) do
  events = list_events(project_id, Keyword.put(opts, :limit, 10_000))
  header = "id,topic,status,occurred_at\n"
  rows = Enum.map(events, fn e ->
    "#{e.id},#{e.topic},#{e.status},#{e.occurred_at}\n"
  end)
  header <> Enum.join(rows)
end
```

**Dashboard:** Botón de descarga en cada sección (eventos, deliveries, jobs, audit log).
**Formatos:** CSV y JSON.
**Para datasets grandes:** Generar con Oban worker y notificar cuando esté listo.

**Archivos nuevos:** `export_controller.ex`
**Archivos modificados:** `platform.ex`, `platform_dashboard_live.ex`, `router.ex`
**Esfuerzo:** 1-2 días
**Impacto:** MEDIO

---

### B17. SSE Stream (Server-Sent Events)

**Qué es:** Endpoint donde el cliente se conecta y recibe eventos en tiempo real sin polling. Alternativa a webhooks para clientes que prefieren pull.

**Endpoint:**
```
GET /api/v1/stream?topics=user.created,order.paid
```

**Implementación con Phoenix Channels o SSE puro:**
```elixir
def stream(conn, params) do
  topics = String.split(params["topics"] || "", ",")
  conn = conn
    |> put_resp_content_type("text/event-stream")
    |> send_chunked(200)

  # Subscribe a PubSub
  for topic <- topics do
    Phoenix.PubSub.subscribe(StreamflixCore.PubSub, "events:#{project_id}:#{topic}")
  end

  # Loop esperando mensajes
  receive_loop(conn)
end
```

**Alternativa mejor:** Usar Phoenix Channels (WebSocket) que ya viene incluido:
```javascript
// Cliente JS
let channel = socket.channel("events:" + projectId, {token: apiKey})
channel.on("new_event", payload => console.log(payload))
channel.join()
```

**Archivos nuevos:** `events_channel.ex`, `stream_controller.ex` (si SSE)
**Archivos modificados:** `platform.ex` (broadcast en create_event), `router.ex`, `user_socket.ex`
**Esfuerzo:** 1-2 días
**Impacto:** ALTO (alternativa moderna a webhooks)

---

### B18. Cron Expression Builder Visual

**Qué es:** UI con dropdowns para construir expresiones cron sin saber la sintaxis. Preview de próximas ejecuciones.

**Implementación (todo frontend + función Elixir para preview):**
```elixir
def next_executions(cron_expr, count \\ 5) do
  # Parsear cron y calcular próximas N fechas
  now = DateTime.utc_now()
  # ... lógica de cron parsing (ya existe en list_jobs_to_run_now)
end
```

**Dashboard:** En el modal de crear/editar job:
- Dropdowns: "Cada [día/semana/mes] a las [HH:MM]"
- Input directo para cron avanzado
- Preview: "Próximas 5 ejecuciones:" con fechas

**Archivos modificados:** `platform_dashboard_live.ex` (UI), `platform.ex` (función next_executions)
**Esfuerzo:** 1 día
**Impacto:** MEDIO (UX)

---

### B19. Webhook Templates

**Qué es:** Templates predefinidos para integraciones comunes. El usuario elige uno y solo pone su URL.

**Templates (hardcodeados en código, sin tabla nueva):**
```elixir
@webhook_templates [
  %{
    name: "Slack",
    description: "Enviar a un canal de Slack",
    body_config: %{
      "body_mode" => "custom",
      "template" => %{
        "text" => "Nuevo evento: {{topic}}",
        "blocks" => [%{"type" => "section", "text" => %{"type" => "mrkdwn", "text" => "*{{topic}}*\n```{{payload}}```"}}]
      }
    },
    headers: %{"content-type" => "application/json"}
  },
  %{
    name: "Discord",
    description: "Enviar a un canal de Discord",
    body_config: %{
      "body_mode" => "custom",
      "template" => %{"content" => "Evento: {{topic}}", "embeds" => [%{"title" => "{{topic}}", "description" => "{{payload}}"}]}
    }
  },
  %{
    name: "Telegram Bot",
    description: "Enviar mensaje via Telegram Bot API",
    body_config: %{
      "body_mode" => "custom",
      "template" => %{"chat_id" => "{{CHAT_ID}}", "text" => "Evento {{topic}}: {{payload}}"}
    }
  },
  %{name: "Generic JSON", description: "Payload completo como JSON", body_config: %{"body_mode" => "full"}},
  %{name: "Custom", description: "Configurar manualmente", body_config: nil}
]
```

**Dashboard:** Al crear webhook, primer paso = seleccionar template. Se pre-llena body_config y headers.

**Archivos modificados:** `platform_dashboard_live.ex` (UI con selector), `platform.ex` (función templates)
**Esfuerzo:** 1 día
**Impacto:** MEDIO (UX, onboarding más fácil)

---

### B20. Team / Colaboradores

**Qué es:** Múltiples usuarios por proyecto con roles diferentes.

**Tabla nueva:**
```sql
CREATE TABLE project_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  role VARCHAR(20) DEFAULT 'viewer', -- owner, editor, viewer
  invited_by UUID REFERENCES users(id),
  inserted_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(project_id, user_id)
);
```

**Roles:**
- `owner` — Todo (incluye eliminar proyecto, gestionar miembros)
- `editor` — Crear/editar webhooks, enviar eventos, gestionar jobs
- `viewer` — Solo lectura

**Dashboard:** Sección "Team" en settings del proyecto. Invitar por email (el usuario debe tener cuenta).

**Archivos nuevos:** `project_member.ex`, migración, UI en settings
**Archivos modificados:** `platform.ex` (verificar permisos), todos los controllers/LiveViews (check role)
**Esfuerzo:** 3-4 días
**Impacto:** ALTO (colaboración)

---

## PARTE C: PRIORIZACIÓN FINAL

### Prioridad 1 — Fundación (1-2 semanas)
| # | Item | Tipo | Esfuerzo |
|---|------|------|----------|
| A1 | Encriptar cookies | Técnico | 30 min |
| A3 | Verificación SSL BD | Técnico | 30 min |
| A6 | Cachex | Técnico | 3-4h |
| A7 | Índices compuestos | Técnico | 2-3h |
| A9 | Compresión dinámica | Técnico | 30 min |
| A14 | Health check | Técnico | 30 min |
| A13 | Unique jobs Oban | Técnico | 15 min |

### Prioridad 2 — Features Core (2-3 semanas)
| # | Item | Tipo | Esfuerzo |
|---|------|------|----------|
| B3 | Webhook Health Score | Feature | 1 día |
| B5 | Webhook Simulator | Feature | 3-4h |
| B1 | Dead Letter Queue | Feature | 2-3 días |
| B4 | Alertas/Notificaciones | Feature | 2-3 días |
| A17 | PubSub real-time | Técnico | 3-4h |
| B9 | Retry personalizable | Feature | 1 día |

### Prioridad 3 — Diferenciadores (2-3 semanas)
| # | Item | Tipo | Esfuerzo |
|---|------|------|----------|
| B2 | Event Replay | Feature | 3-4 días |
| B6 | Sandbox (RequestBin) | Feature | 2-3 días |
| B7 | Audit Log | Feature | 2-3 días |
| B8 | Analytics Dashboard | Feature | 2-3 días |

### Prioridad 4 — Calidad y Docs (2-3 semanas)
| # | Item | Tipo | Esfuerzo |
|---|------|------|----------|
| A2 | Cloak Ecto | Técnico | 2-3h |
| A5 | Sobelow | Técnico | 1h |
| A11 | Oban Web | Técnico | 1-2h |
| A21 | OpenAPI/Swagger | Técnico | 3-5 días |
| A19 | Tests completos | Técnico | 2-3 sem |
| A22 | CI/CD Pipeline | Técnico | 3-4h |

### Prioridad 5 — Expansión (2-4 semanas)
| # | Item | Tipo | Esfuerzo |
|---|------|------|----------|
| B11 | Multi-proyecto | Feature | 2-3 días |
| B12 | API Key Scopes | Feature | 1-2 días |
| B10 | Delayed Events | Feature | 1-2 días |
| B17 | SSE/WebSocket Stream | Feature | 1-2 días |
| B14 | Schema Validation | Feature | 2 días |
| B20 | Teams/Colaboradores | Feature | 3-4 días |

### Prioridad 6 — Nice to Have
| # | Item | Tipo | Esfuerzo |
|---|------|------|----------|
| B15 | Batch Events | Feature | 2-3 días |
| B16 | Exportar CSV/JSON | Feature | 1-2 días |
| B18 | Cron Builder visual | Feature | 1 día |
| B19 | Webhook Templates | Feature | 1 día |
| B13 | IP Allowlist | Feature | 3-4h |
| A23 | Eliminar VideoPlayer | Técnico | 30 min |
| A24 | Migrar a Argon2 | Técnico | 1 día |

---

## RESUMEN TOTAL

| Categoría | Items | Esfuerzo Total |
|-----------|-------|----------------|
| Mejoras Técnicas (Parte A) | 24 | ~4-6 semanas |
| Nuevas Funcionalidades (Parte B) | 20 | ~6-10 semanas |
| **TOTAL** | **44 items** | **~10-16 semanas** |

**Librerías nuevas:** 14
**Tablas nuevas:** 7 (dead_letters, replays, notifications, sandbox_endpoints, sandbox_requests, audit_logs, event_schemas)
**Columnas nuevas en tablas existentes:** 4 (retry_config, deliver_at, allowed_ips, scopes)
**Endpoints API nuevos:** ~25
