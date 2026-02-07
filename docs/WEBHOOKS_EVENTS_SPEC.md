# Especificación: Webhooks + Events (producto dinámico)

Producto: **plataforma de eventos y webhooks 100% configurable por el cliente**. El cliente define qué envía, qué recibe, con qué forma y bajo qué condiciones. En su código solo usa nuestro servicio (un `fetch`) con el contenido que quiera; nosotros enrutamos, filtramos, transformamos y entregamos. Además puede **programar jobs** (ej. “cada día a las 12:00” o “cada mes”) para que el sistema envíe algo automáticamente.

**Diferenciador:** No hay esquemas fijos ni tipos de evento predefinidos. Todo es dinámico: el cliente configura eventos, campos, filtros y la forma del payload que llega a cada webhook, como una extensión que se adapta a su caso.

**Modelo:** El servicio es **100% gratuito**. No hay cobros, pasarelas de pago ni facturación.

**Regla de datos:** **No se elimina nada del sistema.** No hay borrados físicos (DELETE que borre filas). Todo se maneja con un **status**: lo que el usuario o el API “eliminan” solo pasa a **inactivo** (status = `inactive`). Así se conserva historial, auditoría y posibilidad de reactivar. Los listados y la lógica de negocio usan por defecto solo registros **activos** (status = `active`); el Superadmin o filtros explícitos pueden ver también inactivos si se implementa.

---

## 1. Roles: Superadmin y usuarios normales

### 1.1 Superadmin (dueño del sistema)

- **Un solo superadmin** (o unos pocos): el dueño del sistema.
- **Puede hacer todo lo que un usuario normal** (crear proyectos, enviar eventos, configurar webhooks, jobs, ver su token, etc.) como si fuera un usuario más.
- **Además** tiene un **módulo de administración grande** para:
  - **Monitorizar todo el sistema:** ver todos los proyectos, todos los usuarios, todos los eventos, webhooks, entregas y jobs programados de toda la plataforma.
  - **Gestionar usuarios:** listar usuarios, ver actividad, desactivar cuenta si fuera necesario.
  - **Ver métricas globales:** eventos por día, entregas por estado, uso por proyecto, etc.
  - **Acceder a cualquier proyecto** (solo lectura o como “impersonar” para soporte).
- No hay pagos: el superadmin no gestiona planes ni cobros; solo administra y monitorea.

### 1.2 Usuario normal

- **Cualquiera se puede registrar** (email/contraseña o el flujo que definas).
- Tras **iniciar sesión**, tiene **un proyecto** (o varios, según diseño) y **un token (API key)** asociado. Ese token **se puede cambiar** desde su cuenta (regenerar token).
- **Ese token sirve para todo:** todas las consultas, todos los `fetch`, todas las peticiones al API (enviar eventos, listar eventos, CRUD webhooks, CRUD jobs, listar entregas, etc.). Autenticación = Bearer token en las peticiones.
- **Solo administra lo suyo:** ve y gestiona únicamente su proyecto (sus eventos, sus webhooks, sus jobs, sus entregas). No ve otros usuarios ni otros proyectos.
- **Dashboard de usuario:** enviar eventos, configurar webhooks (filtros, forma del body), configurar jobs programados, ver eventos y entregas, ver/rotar su token. Sin opciones de pago: todo gratis.

Resumen: **Superadmin = dueño, monitorea todo y tiene panel grande; usuario normal = se registra, inicia sesión, usa su token en todo y administra solo su proyecto. Todo gratis.**

---

## 2. Valor para el cliente

- **Problema:** Los servicios de webhooks del mercado suelen usar eventos y payloads fijos. Si quieres enviar “lo que tú quieras” y que cada destino reciba “solo lo que le interesa”, sueles montar tú la cola, los filtros y las transformaciones.
- **Solución:** Un solo endpoint donde envías **cualquier JSON** (desde tu código con un `fetch`). Tú configuras en nuestro dashboard o API:
  - **Qué** debe llegar a cada URL (filtros por contenido).
  - **Cómo** debe llegar (qué campos, renombrados o anidados, o el payload completo).
  - **Cuándo** (solo si se cumple una condición sobre el payload).
  - **Jobs programados:** “cada día a las 12:00” o “cada mes” enviar un evento o hacer un POST a una URL que tú configuras.

Así el cliente no mantiene lógica de routing ni de formato ni de cron: solo nos llama y configura reglas dinámicas y horarios.

**Casos de uso:** enviar desde el front con `fetch` un objeto libre (formulario, tracking, estado); que un webhook reciba solo campos que él eligió; que otro reciba el mismo evento pero con otros campos o estructura; filtrar “solo si `amount > 100`” o “solo si `type === 'premium'`”; programar “todos los días a las 00:00 enviar un resumen” o “cada 1 del mes llamar a esta URL”.

---

## 3. Conceptos principales (dinámicos)

| Concepto | Descripción |
|----------|-------------|
| **Proyecto** | Workspace del cliente (multi-tenant). Tiene API keys y toda su configuración. |
| **Evento** | Cualquier envío del cliente: un **topic** opcional (string libre, ej. `"orders"`, `"analytics"`) y un **payload** (objeto JSON arbitrario). No hay tipos fijos: el cliente inventa topics y campos. |
| **Webhook (destino)** | URL + configuración **dinámica**: filtros (cuándo entregar), proyección del payload (qué enviar), headers extra, secret para firma. |
| **Filtro** | Regla sobre el payload: “entregar solo si este campo cumple esta condición”. Lo define el cliente (ej. `payload.amount > 100`, `payload.type in ["a","b"]`). |
| **Proyección / forma del body** | Qué enviar en el POST al webhook: “todo el payload”, “solo estos campos”, “renombrar X a Y”, “añadir campo calculado”. Todo configurable por el cliente. |
| **Entrega** | Un intento de POST a una URL; se guarda estado (pending, success, failed) y se reintenta si falla. |
| **Job programado** | Tarea recurrente que el cliente configura por proyecto: horario (ej. diario a las 12:00, mensual el día 1) y acción (enviar un evento interno o hacer POST a una URL con un payload que él define). |
| **Status (activo/inactivo)** | Todas las entidades que el usuario puede “eliminar” tienen status (`active` \| `inactive`). “Eliminar” = pasar a `inactive`; no se borra el registro. Por defecto solo se usan/muestran activos. |

---

## 4. Cómo lo usa el cliente en su código (tipo “extensión”)

Solo necesita nuestro endpoint y su API key. **Envía lo que quiera.**

```javascript
// En su app (front o back): un solo fetch con lo que quiera
await fetch('https://api.tu-servicio.com/v1/send', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer SU_API_KEY',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    topic: 'checkout',           // opcional; string libre
    ...cualquierCosa             // el resto es su payload dinámico
    orderId: '123',
    total: 99.99,
    items: [...],
    customField: 'lo que sea'
  })
});
```

- No hay esquema obligatorio: puede mandar `topic` + cualquier objeto.
- Si no usa `topic`, puede ser un objeto totalmente libre; nosotros lo guardamos y aplicamos filtros/proyecciones que él configuró por webhook.

**Recibir:** en su URL (webhook) recibe el POST con el body que **él configuró** (completo, solo ciertos campos, renombrados, etc.) más headers estándar (`X-Event-Id`, `X-Signature`, etc.).

---

## 5. Configuración dinámica por webhook

Cada webhook es un “destino” con configuración flexible.

### 5.1 Suscripción (a qué eventos aplica)

- **Por topic (opcional):** “Solo eventos con `topic` = `orders`” (o una lista de topics).
- **Todos:** si no indica topic, puede recibir todos los eventos (y usar filtros para acotar).

### 5.2 Filtros (cuándo entregar)

El cliente define condiciones sobre el **payload** (y opcionalmente sobre `topic`). Solo si se cumplen, se crea la entrega.

Ejemplos de configuración (que luego traducimos a reglas ejecutables):

- `topic` igual a `"orders"`.
- `payload.amount` mayor que `100`.
- `payload.status` en `["paid", "shipped"]`.
- `payload.user.plan` igual a `"premium"`.
- Combinaciones: `topic == "orders" AND payload.amount > 50`.

Formato sugerido en API/dashboard (ejemplo):

```json
{
  "filters": [
    { "path": "topic", "op": "eq", "value": "orders" },
    { "path": "payload.amount", "op": "gte", "value": 100 }
  ]
}
```

Operadores útiles: `eq`, `neq`, `in`, `not_in`, `gte`, `lte`, `gt`, `lt`, `exists`, `contains` (para strings/arrays).

### 5.3 Forma del body (qué enviar al webhook)

El cliente elige qué llega en el body del POST a su URL:

- **Full:** enviar el payload completo (y opcionalmente `event_id`, `topic`, `occurred_at`).
- **Pick (proyección):** solo los campos que él liste (ej. `["orderId", "total", "email"]`); el resto no se envía.
- **Rename / map:** “en mi sistema tengo `order_id`, quiero que a este webhook llegue como `id`”.
- **Extra fields:** añadir campos fijos o derivados (ej. `"source": "webhooks-service"`, o `timestamp` como ISO).

Ejemplo de configuración:

```json
{
  "body_mode": "pick",
  "body_pick": ["orderId", "total", "customerEmail"],
  "body_rename": { "orderId": "id", "customerEmail": "email" },
  "body_extra": { "source": "my-app" }
}
```

Así el cliente controla exactamente qué ve cada destino, sin tocar su código: solo configura.

### 5.4 Headers del webhook

- Siempre incluimos: `X-Event-Id`, `X-Delivery-Id`, `X-Signature`, `Content-Type: application/json`.
- El cliente puede añadir **headers fijos** por webhook (ej. `X-Custom-Auth: token`, `X-API-Version: 2`).

---

## 6. Jobs programados (por proyecto)

Cada **proyecto** puede configurar **jobs** que se ejecutan en un horario que el cliente elige. Así puede “enviar algo” de forma automática sin tener que correr cron en su propio servidor.

### 6.1 Qué hace un job

- **Programación (schedule):** el cliente define **cuándo** se ejecuta. Opciones típicas:
  - **Diario:** a una hora fija (ej. todos los días a las 00:00, o a las 12:00).
  - **Semanal:** un día de la semana + hora (ej. lunes a las 09:00).
  - **Mensual:** un día del mes + hora (ej. día 1 de cada mes a las 00:00).
  - **Cron (opcional):** expresión tipo cron para casos más avanzados (ej. `0 0 * * *` = diario a medianoche).
- **Acción:** qué hace el job cuando se dispara. Dos opciones útiles:
  - **Enviar evento interno:** el sistema genera un evento (con topic y payload que el cliente configura). Ese evento pasa por las mismas reglas que los eventos normales: filtros de webhooks, proyecciones, etc. Así “cada día a las 12:00” se emite un evento y todos los webhooks que correspondan lo reciben.
  - **POST a una URL:** el sistema hace un POST a una URL que el cliente indica, con un body (payload) que él define (estático o con variables tipo “fecha de hoy”). Útil para “llamar a mi API cada mes el día 1”.

### 6.2 Configuración de un job (ejemplo)

El cliente crea/edita un job con:

- **Nombre** (ej. “Resumen diario”).
- **Schedule:** tipo (daily / weekly / monthly / cron) + hora; si weekly, día de la semana; si monthly, día del mes.
- **Acción:**
  - Si “evento”: `topic` + `payload` (objeto JSON, puede incluir placeholders como `{{date}}` para la fecha de ejecución).
  - Si “POST URL”: `url`, `payload` (body del POST), opcionalmente headers.
- **Status:** active (se ejecuta) o inactive (“eliminado” lógico; no se borra, solo deja de ejecutarse).

### 6.3 Ejecución

- Un **scheduler** en el backend (ej. cada minuto) revisa qué **jobs con status = active** están programados para ese momento y los encola. Los jobs inactivos no se ejecutan.
- Cada ejecución se registra (job_run: id, job_id, executed_at, status, result o error). El usuario puede ver historial de ejecuciones en su dashboard.
- Si la acción es “enviar evento”, se crea el evento en el proyecto y se disparan las entregas a webhooks como siempre. Si es “POST URL”, se hace la petición y se guarda el resultado.

Así el cliente puede configurar cosas como “todos los días a las 12:00 enviar un evento” o “cada mes a las 00:00 llamar a esta URL” sin pagar nada ni montar su propio cron.

---

## 7. Flujos

### 7.1 Cliente envía un evento (desde su código)

1. `POST /api/v1/send` (o `/api/v1/events`) con body JSON arbitrario; opcionalmente un campo `topic` (string).
2. Backend guarda el evento (topic + payload completo en jsonb).
3. Backend obtiene todos los webhooks del proyecto con **status = active** que apliquen:
   - Por topic (si el webhook tiene topics definidos y el evento tiene topic).
   - Evalúa **filtros** de cada webhook sobre `{ topic, ...payload }`.
4. Por cada webhook activo que pase los filtros: crea una **delivery** (pending), aplica la **proyección/forma** configurada para ese webhook y encola el job que hace el POST.
5. Responde `202 Accepted` + `event_id`.

### 7.2 Entrega (delivery)

1. Job toma una delivery pending.
2. Construye el body según la configuración del webhook (full / pick / rename / extra).
3. POST a la URL con headers estándar + headers custom del webhook + `X-Signature` (HMAC del body con el secret del webhook).
4. Si 2xx → success; si no → failed y reintento con backoff.

### 7.3 Cliente configura un webhook (dashboard o API)

- Crea/edita webhook: URL, secret, **topics** (opcional), **filtros** (opcional), **body_mode + pick/rename/extra** (opcional), **headers** (opcional).
- **“Eliminar” webhook:** no se borra; se pone **status = inactive**. Deja de recibir entregas; el registro sigue en BD. Opcional: poder reactivar (PATCH status = active).
- Si no pone filtros, recibe todos los eventos que coincidan por topic (o todos si no filtra por topic). Si no pone proyección, por defecto enviamos payload completo (+ metadatos opcionales).

---

## 8. API (resumen)

Autenticación: **API Key** en header `Authorization: Bearer <key>` o `X-Api-Key: <key>`.

**DELETE = pasar a inactivo.** En este sistema no hay borrado físico. Cualquier endpoint que se describa como “eliminar” (DELETE) **solo actualiza el status del registro a `inactive`**. El registro sigue en la base de datos; los listados por defecto no lo muestran (solo activos). Opcionalmente se puede ofrecer “reactivar” (PATCH con status = active) o que el Superadmin vea inactivos.

### Enviar (desde el código del cliente)

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST   | `/api/v1/send` o `/api/v1/events` | Enviar un evento. Body: cualquier JSON; opcionalmente `topic` (string). Dispara entregas según configuración de cada webhook. |

### Eventos

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET    | `/api/v1/events` | Listar eventos (paginado; por defecto solo status = active; filtros por topic, fecha). Opcional: `?include=inactive` para incluir inactivos. |
| GET    | `/api/v1/events/:id` | Detalle de un evento (payload completo + deliveries). |
| DELETE | `/api/v1/events/:id` | Pasar evento a inactivo (status = inactive). No borra el registro. |

### Webhooks (configuración dinámica)

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST   | `/api/v1/webhooks` | Crear webhook: url, secret, **topics** (array opcional), **filters** (array opcional), **body_config** (mode, pick, rename, extra), **headers** (objeto opcional). |
| GET    | `/api/v1/webhooks` | Listar webhooks del proyecto (por defecto solo status = active). Opcional: `?include=inactive`. |
| PATCH  | `/api/v1/webhooks/:id` | Actualizar configuración (url, filters, body_config, etc.) o **status** (active/inactive) para reactivar. |
| DELETE | `/api/v1/webhooks/:id` | Pasar webhook a inactivo (status = inactive). No se usa para entregas; no borra el registro. |

### Entregas

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET    | `/api/v1/deliveries` | Listar entregas (filtros por event_id, webhook_id, status). |
| POST   | `/api/v1/deliveries/:id/retry` | Reintentar una entrega fallida. |

### Jobs programados

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST   | `/api/v1/jobs` | Crear job: name, schedule (type, hour, day_of_week/day_of_month), action (event con topic+payload, o post_url con url+payload), active. |
| GET    | `/api/v1/jobs` | Listar jobs del proyecto (por defecto solo status = active). Opcional: `?include=inactive`. |
| GET    | `/api/v1/jobs/:id` | Detalle de un job (incl. últimas ejecuciones). |
| PATCH  | `/api/v1/jobs/:id` | Actualizar job (schedule, action, active, o status para reactivar). |
| DELETE | `/api/v1/jobs/:id` | Pasar job a inactivo (status = inactive). Deja de ejecutarse; no borra el registro. |
| GET    | `/api/v1/jobs/:id/runs` | Listar ejecuciones (runs) del job. |

Todas estas rutas requieren el **token del usuario** (Bearer). El token identifica al usuario y a su proyecto; con ese mismo token hace todas las peticiones (eventos, webhooks, jobs, etc.).

### Configuración del proyecto (opcional)

| Método | Ruta | Descripción |
|--------|------|-------------|
| GET    | `/api/v1/topics` | Listar topics que el proyecto ha usado (para ayudar al cliente a elegir en filtros). |
| GET/PATCH | `/api/v1/project` | Ver/editar nombre del proyecto. Sin límites de pago (servicio gratis). |
| GET    | `/api/v1/me` o `/api/v1/token` | Ver info del usuario y su token (prefix); endpoint para regenerar token si se implementa. |

---

## 9. Modelo de datos (resumen)

**Status en todo lo “eliminable”.** Las entidades que el usuario puede “eliminar” tienen **status** (`active` \| `inactive`). No se hace DELETE físico; solo se actualiza status a `inactive`. Los listados y la lógica (qué webhooks reciben eventos, qué jobs se ejecutan) usan solo registros con status = `active`.

- **projects** — id, name, settings (jsonb, opcional), **status** (active \| inactive), created_at, updated_at.
- **api_keys** — id, project_id, user_id (opcional), prefix, hash, name, **status** (active \| inactive), created_at. Las keys inactivas no autentican.
- **webhooks** — id, project_id, url, secret_encrypted, **status** (active \| inactive), topics (array o jsonb), filters (jsonb), body_config (jsonb), headers (jsonb), created_at, updated_at. Solo webhooks activos reciben entregas. (Se puede mantener un campo `active` booleano como alias de status si se prefiere.)
- **events** — id, project_id, topic (string, nullable), payload (jsonb), **status** (active \| inactive), occurred_at, created_at. “Eliminar” evento = status inactive; listados por defecto solo activos.
- **deliveries** — id, event_id, webhook_id, **status** (pending \| success \| failed; es el estado de la entrega, no borrado). No se “eliminan”; se mantiene historial. Opcional: **deleted_at** o status `archived` si en el futuro se quiere ocultar sin borrar.
- **users** — id, email, password_hash, role (user \| superadmin), **status** (active \| inactive), created_at, updated_at. “Desactivar” usuario = status inactive; no puede iniciar sesión ni usar token.
- **jobs** — id, project_id, name, schedule_type, schedule_config, action_type, action_config, **status** (active \| inactive), created_at, updated_at. Solo jobs activos se ejecutan. “Eliminar” job = status inactive.
- **job_runs** — id, job_id, executed_at, status (success \| failed), result (jsonb o text), created_at. Son historial; no se eliminan.

Para que el token sea “del usuario” y se pueda cambiar: **api_keys** puede tener `user_id` y `project_id` (un usuario tiene un proyecto; al regenerar token se invalida el anterior y se crea uno nuevo). O el token es único por usuario y el proyecto se deduce del usuario. No hay tablas de pagos ni facturación.

No hace falta tabla `event_types`: el “tipo” es el topic (string libre) o el propio contenido del payload; los filtros se aplican sobre ese contenido.

---

## 10. Evaluación de filtros (lógica)

- Entrada: evento `{ topic, payload }` (el payload es el body recibido menos el campo `topic` si existe).
- Solo se consideran webhooks con **status = active**.
- Por cada webhook activo:
  - Si el webhook tiene `topics` y el evento tiene `topic`: el evento debe estar en la lista de topics (si no, se salta).
  - Se evalúa cada condición en `filters` sobre un objeto que combine topic y payload (ej. `event.topic`, `event.orderId`, `event.amount` según path). Si alguna falla, no se entrega.
- Implementación: expresiones simples (path + op + value) en Elixir; para algo más complejo se puede permitir una expresión tipo JSON Logic en una fase posterior.

---

## 11. Seguridad

- **API Key** por proyecto; en BD solo hash. Se muestra el valor una sola vez al crear.
- **Firma:** en cada POST al webhook, header `X-Signature: sha256=<hmac_body>` con el secret del webhook. El cliente verifica en su endpoint que el request es nuestro.
- **HTTPS** obligatorio para URLs de webhook en producción.
- **Timeouts y tamaño:** ej. 10 s por request; limitar tamaño del payload entrante (ej. 256 KB) y del body de respuesta que guardamos (ej. 64 KB).

---

## 12. Reintentos

- Máximo intentos por delivery: ej. 5.
- Backoff: 1 min → 5 min → 15 min → 1 h.
- Tras último fallo: delivery `failed`; opcional dead-letter o notificación al proyecto.

---

## 13. Dashboards: usuario normal y Superadmin

### 13.1 Dashboard del usuario normal (su proyecto)

- **Mi cuenta:** ver email, **ver / regenerar su token** (ese token usa en todas las peticiones y en los `fetch`). Sin opciones de pago.
- **Enviar evento de prueba:** formulario donde escribe un JSON libre (y opcional topic) y dispara un evento real; ve a qué webhooks se envió y el resultado.
- **Eventos:** listado con topic, preview del payload, enlace a detalle (payload completo + deliveries).
- **Webhooks:** para cada uno editar URL, secret, **topics**, **filtros**, **forma del body**, **headers**; ver últimas entregas y reintentar. **“Eliminar”** = pasar a inactivo (no se borra); opcional ver lista de inactivos y reactivar.
- **Jobs programados:** listar (solo activos por defecto), crear, editar, pausar o **“eliminar”** (pasar a inactivo); ver historial de ejecuciones (runs).
- **Entregas:** listar por evento o webhook; reintentar. No se eliminan; son historial.
- **Documentación:** ejemplo de `fetch` con el endpoint real y cómo configurar filtros y body. Todo lo que ve y administra es **solo de su proyecto**.

### 13.2 Dashboard del Superadmin (módulo de administración grande)

- **Vista global:** listado de **todos los proyectos** y **todos los usuarios**; métricas agregadas (eventos totales, entregas por estado, jobs activos, etc.).
- **Monitorización:** ver todos los eventos recientes de todos los proyectos (con filtro por proyecto); todas las entregas (éxito/fallo); todos los jobs y sus últimas ejecuciones. Permite detectar errores y uso del sistema.
- **Usuarios:** listar usuarios, ver último acceso, **desactivar cuenta** (status = inactive; no se borra el usuario). Sin gestión de pagos (no aplica).
- **Proyectos:** entrar en cualquier proyecto (solo lectura o “vista”) para soporte o revisión; ver webhooks, jobs y eventos de ese proyecto.
- **El Superadmin puede hacer todo lo que un usuario:** si quiere, puede crear su propio proyecto, obtener token y usar el API igual que cualquier usuario (enviar eventos, configurar webhooks y jobs).

---

## 14. Diferenciación frente a servicios “normales”

| Aspecto | Servicios típicos | Nuestro servicio (dinámico) |
|---------|-------------------|-----------------------------|
| Eventos | Tipos fijos (ej. `invoice.paid`). | Cualquier JSON + topic opcional; el cliente define qué envía. |
| Payload | Esquema fijo por tipo. | Payload libre; el cliente elige qué campos enviar a cada webhook. |
| Filtros | Pocos o ninguno. | Filtros configurables sobre el payload (path + op + value). |
| Forma del body | Siempre el mismo. | Proyección/renombrado/extra por webhook. |
| Uso en código | Integración SDK o muchos endpoints. | Un `fetch` con lo que quiera; el resto es configuración. |

Así el producto se siente como una **extensión configurable**: el cliente pone en su código solo la llamada con sus datos y en nuestro lado configura qué sale y a dónde va.

---

## 15. Encaje en tu arquitectura

| Actual (Streamflix) | Webhooks + Events (dinámico) |
|---------------------|------------------------------|
| Cuentas / perfiles | Proyectos + API keys. |
| Catálogo | Eventos (topic + payload jsonb) y webhooks con filters/body_config. |
| Workers | Cola de deliveries: por cada una se aplica body_config, POST y actualización de estado. |
| Admin LiveView | Dashboard: eventos, webhooks con editor de filtros y de forma del body, deliveries, API keys. |

La evaluación de filtros y la aplicación de body_config (pick/rename/extra) pueden vivir en un contexto de “deliveries” o “webhooks” dentro de una app del umbrella; la API puede ser un scope en `streamflix_web` con pipeline API + API key.

---

## 16. Fases de implementación

**Fase 1 — MVP dinámico**
- Proyectos + API key; **status (active/inactive)** en proyectos, api_keys, webhooks, events. No hay DELETE físico; “eliminar” = status inactive.
- `POST /send`: aceptar cualquier JSON, guardar como evento (topic opcional + payload). Solo webhooks activos reciben entregas.
- Webhooks: url, secret, **topics** (opcional), sin filtros aún; body = payload completo. DELETE = pasar a inactivo.
- Job: POST con firma HMAC; reintentos simples.

**Fase 2 — Filtros y forma del body**
- **Filtros:** almacenar en webhooks (jsonb), evaluar antes de crear delivery (path + op + value).
- **Body config:** full / pick con lista de campos; opcional rename y extra. Aplicar al construir el body del POST.
- Dashboard: CRUD webhooks, editor de filtros y de “qué campos enviar”.

**Fase 3 — Usuarios, token y Superadmin**
- **Registro e inicio de sesión** de usuarios; cada usuario tiene su proyecto (o se crea al registrarse) y **un token (API key)** que usa en todas las peticiones.
- **Ver y regenerar token** desde “Mi cuenta”; el token es el mismo para eventos, webhooks, jobs y consultas.
- **Rol superadmin:** al menos un usuario con `role = superadmin`; panel de administración: listar todos los proyectos y usuarios, ver eventos/entregas/jobs de todo el sistema, métricas globales. El superadmin puede hacer todo lo que un usuario normal (tiene su token y su proyecto si quiere).
- Dashboard usuario: solo ve su proyecto (eventos, webhooks, entregas, jobs, token).

**Fase 4 — Jobs programados**
- Modelo **jobs** (con **status** active/inactive) y **job_runs**; CRUD jobs por API y desde el dashboard. DELETE job = status inactive; solo jobs activos se ejecutan.
- Scheduler en el backend que ejecuta jobs activos a la hora configurada; registrar cada ejecución en job_runs (no se eliminan runs).
- En el dashboard del usuario: listar jobs (activos por defecto), crear/editar, “eliminar” (inactivo), ver historial de ejecuciones. Sin cobros: todo gratis.

**Fase 5 (opcional)**
- Reintentos con backoff; retry manual; listados completos por API.
- Headers custom por webhook.
- Documentación pública y ejemplo de `fetch` + configuración dinámica.

**Importante:** En todo el producto **no se implementan pagos ni facturación**. El servicio es 100% gratuito.

Con esto el servicio queda **muy dinámico**: el cliente configura todo lo que quiere enviar y recibir (y cuándo, con jobs), y en su código solo usa nuestro servicio con un `fetch` y su token; el Superadmin puede monitorizar todo el sistema.
