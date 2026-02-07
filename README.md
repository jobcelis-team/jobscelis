# Jobscelis

**Eventos, webhooks y jobs programados** en una sola API. Publica eventos con cualquier payload, configura webhooks con filtros y recibe POST en tiempo real. Programa tareas recurrentes (diario, semanal, mensual o cron) que emitan eventos o llamen a tus URLs.

Construido con **Elixir**, **Phoenix** y **LiveView**.

---

## Características

| Funcionalidad | Descripción |
|---------------|-------------|
| **Eventos** | Publica eventos con `topic` y payload JSON vía API. Sin esquemas fijos. |
| **Webhooks** | URLs de destino, filtros por topic o por campos del payload, POST en tiempo real. Reintentos automáticos y seguimiento de entregas. |
| **Jobs programados** | Tareas recurrentes: diario, semanal, mensual o cron. Acción: emitir un evento o hacer POST a una URL con payload configurable. |
| **API Key** | Un token por proyecto. Autenticación Bearer o `X-Api-Key`. Genera y regenera desde el dashboard. |
| **Dashboard** | Envía eventos de prueba, gestiona webhooks, consulta eventos y entregas recientes. |
| **Admin** | Panel para superadmin: usuarios, proyectos, métricas (si tienes rol admin/superadmin). |

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
LIVE_VIEW_SIGNING_SALT=   # 32+ caracteres (mix phx.gen.secret | head -c 32)

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

### 5. Desarrollo con Docker

```bash
cp .env.example .env
# Editar .env (SECRET_KEY_BASE, GUARDIAN_SECRET_KEY, LIVE_VIEW_SIGNING_SALT, DB_*)

docker compose up --build
```

La app queda en **http://localhost:4000**. La base de datos en `localhost:5432`.

Migraciones (primera vez o después de cambios):

```bash
docker compose exec jobscelis mix ecto.migrate
docker compose exec jobscelis mix run apps/streamflix_core/priv/repo/seeds.exs
```

---

## Estructura del proyecto

```
streamflix/
├── apps/
│   ├── streamflix_core/     # Proyectos, API keys, eventos, webhooks, deliveries, jobs
│   ├── streamflix_accounts/ # Usuarios, autenticación (Guardian/JWT)
│   └── streamflix_web/      # Web (LiveView), API REST, docs
├── config/
├── .env.example
└── mix.exs
```

---

## API

### Autenticación (público)

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/api/v1/auth/register` | Registro (email, password, name) |
| POST | `/api/v1/auth/login` | Login (email, password) → JWT |
| POST | `/api/v1/auth/refresh` | Refrescar JWT |

### Plataforma (API Key requerida)

Header: `Authorization: Bearer <token>` o `X-Api-Key: <token>` (token del proyecto en Dashboard).

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/api/v1/events` | Crear evento (topic + payload) |
| GET | `/api/v1/events` | Listar eventos |
| GET | `/api/v1/webhooks` | Listar webhooks |
| POST | `/api/v1/webhooks` | Crear webhook |
| GET | `/api/v1/deliveries` | Listar entregas |
| GET | `/api/v1/jobs` | Listar jobs programados |
| POST | `/api/v1/jobs` | Crear job |
| GET | `/api/v1/project` | Ver proyecto |
| GET | `/api/v1/token` | Ver prefijo del token (no el valor completo) |
| POST | `/api/v1/token/regenerate` | Regenerar token (el valor completo se devuelve una sola vez) |

Documentación completa en la app: **http://localhost:4000/docs**

---

## Usuarios y roles

- **Usuario normal:** se registra, tiene un proyecto y un API Key. Gestiona sus eventos, webhooks y jobs desde el dashboard.
- **Admin / Superadmin:** además puede acceder a `/admin` para ver usuarios, proyectos y métricas. El rol no se muestra a usuarios normales (solo en contexto admin).

Crear superadmin (script):

```bash
mix run scripts/create_superadmin.exs
# o create_admin.exs / create_admin_quick.exs según tu setup
```

---

## Tecnologías

- **Phoenix** – Web y API
- **Phoenix LiveView** – Dashboard y pantallas en tiempo real
- **Ecto** – Persistencia (PostgreSQL)
- **Oban** – Jobs en background (entregas a webhooks, jobs programados)
- **Guardian** – JWT para autenticación

---

## Seguridad

- No commitear `.env`. Usar secretos en CI/CD para producción.
- El **API Key** completo solo se muestra una vez al generarlo; en base de datos solo se guarda un hash y un prefijo.
- Rotar `SECRET_KEY_BASE` y `GUARDIAN_SECRET_KEY` por entorno.

---

## Licencia

MIT
