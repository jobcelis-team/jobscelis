# StreamFlix - Plataforma de Streaming de Video

Una plataforma de streaming de video de alta performance construida 100% en Elixir, diseñada para superar la arquitectura de Netflix.

## Versiones de Tecnologías (Enero 2026)

| Tecnología | Versión |
|------------|---------|
| **Elixir** | 1.17+ |
| **Erlang/OTP** | 27+ |
| **Phoenix** | 1.8.3 |
| **Phoenix LiveView** | 1.1.19 |
| **Ecto** | 3.13.5 |
| **Ecto SQL** | 3.13.4 |
| **Postgrex** | 0.21.1 |
| **Horde** | 0.10.0 |
| **Oban** | 2.20.2 |
| **Guardian** | 2.4.0 |
| **Nebulex** | 2.6.5 |
| **Bandit** | 1.10.1 |
| **libcluster** | 3.5.0 |

## Configuración del Entorno

### 1. Configurar Variables de Entorno

**IMPORTANTE**: El proyecto usa variables de entorno para todas las configuraciones sensibles.

```bash
# Copiar el archivo de ejemplo
cp .env.example .env

# Editar con tus valores reales
# NUNCA subas .env a control de versiones!
```

### 2. Variables Requeridas

Las siguientes variables **DEBEN** ser configuradas en tu `.env`:

```bash
# Seguridad (generar con comandos indicados)
SECRET_KEY_BASE=         # mix phx.gen.secret
GUARDIAN_SECRET_KEY=     # mix guardian.gen.secret
LIVE_VIEW_SIGNING_SALT=  # mix phx.gen.secret (primeros 32 chars)

# Base de Datos
DB_USERNAME=
DB_PASSWORD=
DB_HOSTNAME=
DB_DATABASE=

# Azure Storage (para videos)
AZURE_STORAGE_ACCOUNT=
AZURE_STORAGE_KEY=
```

### 3. Generar Claves Secretas

```bash
# Generar SECRET_KEY_BASE
mix phx.gen.secret

# Generar GUARDIAN_SECRET_KEY
mix guardian.gen.secret

# O generar una clave genérica (64+ caracteres)
mix phx.gen.secret 64
```

## Arquitectura

```
┌─────────────────────────────────────────────────────────────────────┐
│                         STREAMFLIX PLATFORM                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐            │
│   │  Node 1     │◄──►│  Node 2     │◄──►│  Node N     │            │
│   │  (BEAM)     │    │  (BEAM)     │    │  (BEAM)     │            │
│   └─────────────┘    └─────────────┘    └─────────────┘            │
│         │                  │                  │                     │
│         └──────────────────┼──────────────────┘                     │
│                            │                                        │
│   ┌────────────────────────┼────────────────────────┐              │
│   │  PostgreSQL  │  Redis  │  Azure Blob Storage    │              │
│   └────────────────────────┼────────────────────────┘              │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Características

- **Event Sourcing** - Estado reconstruible desde eventos
- **CQRS** - Separación de comandos y consultas
- **Clustering Distribuido** - Múltiples nodos BEAM conectados con Horde 0.10
- **HLS Streaming** - Adaptive bitrate streaming
- **Azure Integration** - Blob Storage para videos
- **Real-time Updates** - Phoenix LiveView 1.1
- **High Availability** - Horde para procesos distribuidos
- **Background Jobs** - Oban 2.20 para procesamiento asíncrono

## Estructura del Proyecto

```
streamflix/
├── apps/
│   ├── streamflix_core/        # Core: Event Sourcing, CQRS, Distribución
│   ├── streamflix_accounts/    # Usuarios, Perfiles, Autenticación
│   ├── streamflix_catalog/     # Películas, Series, Géneros
│   ├── streamflix_streaming/   # HLS, Playback Sessions
│   ├── streamflix_cdn/         # Azure Blob Storage
│   └── streamflix_web/         # Phoenix API + LiveView
├── config/
│   ├── config.exs              # Configuración base
│   ├── dev.exs                 # Desarrollo
│   ├── prod.exs                # Producción
│   ├── runtime.exs             # Runtime (variables de entorno)
│   └── test.exs                # Tests
├── .env.example                # Template de variables de entorno
├── .env                        # TU configuración local (NO COMMITEAR)
├── docker-compose.yml
└── mix.exs
```

## Requisitos

- **Elixir** 1.17+
- **Erlang/OTP** 27+
- **PostgreSQL** 17+
- **Redis** 7.4+
- **Node.js** 20+ (para assets)
- **Azure Storage Account** (para videos)

## Instalación

### 1. Clonar y configurar entorno

```bash
cd streamflix

# Configurar variables de entorno (MUY IMPORTANTE)
cp .env.example .env
# Editar .env con tus valores reales

# Instalar dependencias
mix deps.get
```

### 2. Configurar base de datos

```bash
mix ecto.create
mix ecto.migrate
mix run apps/streamflix_core/priv/repo/seeds.exs
```

### 3. Iniciar servidor

```bash
# Cargar variables de entorno y ejecutar
source .env  # Linux/Mac
# o en PowerShell: Get-Content .env | ForEach-Object { if ($_ -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($matches[1], $matches[2]) } }

mix phx.server
```

Visita http://localhost:4000

## Desarrollo con Docker

```bash
# Asegurar que .env existe con valores reales
cp .env.example .env
# Editar .env

# Iniciar solo con un nodo
docker-compose up

# Iniciar con cluster de 3 nodos
docker-compose --profile cluster up

# Iniciar con monitoreo (Prometheus + Grafana)
docker-compose --profile monitoring up

# Ejecutar migraciones
docker-compose exec streamflix_node1 mix ecto.migrate
```

## Cluster Multi-Nodo (Desarrollo Local)

```bash
# Terminal 1
PORT=4000 iex --sname node1 -S mix phx.server

# Terminal 2
PORT=4001 iex --sname node2 -S mix phx.server

# Terminal 3
PORT=4002 iex --sname node3 -S mix phx.server
```

Los nodos se conectarán automáticamente con libcluster.

## API Endpoints

### Autenticación

```
POST /api/v1/auth/register
POST /api/v1/auth/login
POST /api/v1/auth/refresh
```

### Catálogo

```
GET  /api/v1/browse
GET  /api/v1/browse/genre/:genre
GET  /api/v1/content/:id
GET  /api/v1/search?q=query
```

### Playback

```
POST   /api/v1/playback/start
PUT    /api/v1/playback/:session_id/heartbeat
DELETE /api/v1/playback/:session_id
GET    /api/v1/playback/:session_id/manifest
```

## Planes de Suscripción

| Plan     | Streams | Perfiles | Calidad | Precio  |
|----------|---------|----------|---------|---------|
| Basic    | 1       | 1        | 480p    | $9.99   |
| Standard | 2       | 3        | 1080p   | $15.99  |
| Premium  | 4       | 5        | 4K+HDR  | $21.99  |

## Monitoreo

- **Phoenix LiveDashboard**: http://localhost:4000/dev/dashboard
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/[GRAFANA_PASSWORD de .env])

## Seguridad

### Variables de Entorno Sensibles

Las siguientes variables **NUNCA** deben estar en código:

- `SECRET_KEY_BASE` - Firma de cookies y sessions
- `GUARDIAN_SECRET_KEY` - Firma de JWT tokens
- `DB_PASSWORD` - Contraseña de base de datos
- `AZURE_STORAGE_KEY` - Clave de Azure Storage
- `STRIPE_SECRET_KEY` - Clave secreta de Stripe

### Mejores Prácticas

1. **NUNCA** commitear `.env` a git
2. Usar secretos de CI/CD para deploys
3. Rotar claves regularmente
4. Usar diferentes claves por ambiente (dev/staging/prod)

## Dependencias Principales

```elixir
# Phoenix Stack
{:phoenix, "~> 1.8"}
{:phoenix_live_view, "~> 1.1"}
{:phoenix_live_dashboard, "~> 0.8"}
{:bandit, "~> 1.10"}

# Database
{:ecto_sql, "~> 3.13"}
{:postgrex, "~> 0.21"}

# Distributed Systems
{:horde, "~> 0.10"}
{:libcluster, "~> 3.5"}
{:delta_crdt, "~> 0.6"}

# Background Jobs
{:oban, "~> 2.20"}

# Authentication
{:guardian, "~> 2.4"}
{:bcrypt_elixir, "~> 3.3"}

# Caching
{:nebulex, "~> 2.6"}

# HTTP Client
{:req, "~> 0.5"}
```

## Licencia

MIT
