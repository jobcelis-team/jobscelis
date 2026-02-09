# Auditoría de calidad, seguridad y estándares — Jobcelis

**Fecha de revisión:** Febrero 2025  
**Alcance:** Proyecto completo (sin modificar código)  
**Objetivo:** Evaluar calidad del sistema, seguridad y cumplimiento de normas y estándares internacionales.

---

## 1. Resumen ejecutivo

El proyecto es una aplicación web tipo umbrella (Phoenix) para eventos, webhooks y jobs programados, con API REST, autenticación JWT/API Key, panel de administración y despliegue en Azure. La revisión abarca seguridad, calidad de código, accesibilidad y buenas prácticas.

**Conclusiones principales:**
- **Seguridad:** Buena base (CSRF, cabeceras de seguridad, rate limiting, auth por token, contraseñas con Pbkdf2). Algunas mejoras recomendadas en configuración de producción.
- **Calidad:** Uso correcto de Ecto (sin SQL crudo), validación de parámetros, separación de contextos. Herramientas Credo y Dialyxir disponibles.
- **Estándares:** Cabeceras alineadas con OWASP; accesibilidad (WCAG) mejorada recientemente; documentación legal y de privacidad presente.

---

## 2. Seguridad

### 2.1 Autenticación y autorización

| Aspecto | Estado | Detalle |
|--------|--------|---------|
| **Browser (sesión)** | ✅ | `protect_from_forgery` en pipeline `:browser`; sesión firmada (cookie), `same_site: "Lax"`, `max_age` 30 días. |
| **API JWT** | ✅ | Guardian con secret desde env en prod; TTL 7 días; verificación de token y carga de usuario. |
| **API Key** | ✅ | Token por Bearer o `X-Api-Key`; verificación por hash SHA256 (no se guarda el valor plano); proyecto y clave activos comprobados. |
| **Contraseñas** | ✅ | Pbkdf2 (Comeonin); validación longitud 8–72, mayúscula, minúscula, dígito; mitigación de timing con `Pbkdf2.no_user_verify()` cuando usuario no existe o está inactivo. |
| **Admin** | ✅ | `LiveAuth.mount_admin_user` exige usuario autenticado y `role in ["admin", "superadmin"]`. |

**Recomendación:** En producción, considerar rotación de JWT (refresh tokens ya implementados) y políticas de expiración más cortas si el riesgo lo requiere.

### 2.2 Cabeceras HTTP y políticas de contenido

| Cabecera / política | Estado | Archivo |
|---------------------|--------|---------|
| **X-Frame-Options: DENY** | ✅ | `SecurityHeaders` |
| **X-Content-Type-Options: nosniff** | ✅ | Idem |
| **X-XSS-Protection: 1; mode=block** | ✅ | Idem |
| **Referrer-Policy: strict-origin-when-cross-origin** | ✅ | Idem |
| **Permissions-Policy** | ✅ | Restringe geolocation, microphone, camera |
| **Content-Security-Policy** | ✅ | default-src 'self'; script/style/img/font/connect acotados; frame-ancestors 'none'; form-action 'self'. Incluye `'unsafe-inline'` en style (habitual con Tailwind/LiveView). |

Alineado con recomendaciones OWASP para cabeceras de seguridad.

### 2.3 Rate limiting

| Ruta / API | Límite | Ventana |
|------------|--------|---------|
| POST /login (browser) | 5 | 60 s |
| POST /signup (browser) | 3 | 60 s |
| POST /api/v1/auth/login | 15 | 60 s |
| POST /api/v1/auth/register | 5 | 60 s |
| POST /api/v1/auth/refresh | 30 | 60 s |

Implementación con ETS por IP; respuesta 429 con `Retry-After: 60`. Reduce riesgo de fuerza bruta y abuso en registro/login.

### 2.4 Validación de entrada

| Punto | Estado | Detalle |
|-------|--------|---------|
| **Login/registro (API)** | ✅ | `ValidateAuthParams`: longitud email ≤254, contraseña 8–72, nombre ≤255, formato email; params reemplazados por mapa saneado. |
| **Webhooks (API)** | ✅ | Atributos pasados a cambiosets Ecto; `Webhook.changeset` valida URL (http/https), status, etc. |
| **IDs en URL** | ✅ | `Repo.get(Webhook, id)` / `Repo.get(WebhookEvent, id)` con `binary_id`; Ecto valida formato UUID, no hay concatenación SQL. |
| **Límites de listados** | ✅ | Ej. `parse_int(params["limit"], 50)` con `min(..., 100)` en eventos. |
| **Body máximo** | ✅ | `Plug.Parsers` con `length: 256_000` (256 KB). |

No se ha detectado uso de `fragment()` ni SQL crudo con interpolación de usuario; las consultas usan Ecto y parámetros enlazados.

### 2.5 CORS

- API: `Access-Control-Allow-Origin: *`; métodos y cabeceras documentados (Authorization, X-Api-Key, Content-Type, Accept).
- Aceptable para API pública; si en el futuro solo ciertos orígenes deben consumir la API, conviene restringir el origen.

### 2.6 Configuración y secretos

| Elemento | Estado | Nota |
|----------|--------|------|
| **SECRET_KEY_BASE** | ✅ | Obligatorio en prod vía env; generación documentada en .env.example. |
| **GUARDIAN_SECRET_KEY** | ✅ | Obligatorio en prod; dev con valor por defecto largo. |
| **LIVE_VIEW_SIGNING_SALT** | ✅ | Sobrescritura en runtime.exs desde env en prod. |
| **Sesión (Plug.Session)** | ✅ | Plug `SessionWithConfig` usa `SESSION_SIGNING_SALT` desde config (runtime.exs lee la variable de entorno). En producción configurar en Azure/entorno; si no se define, se usa valor por defecto. |
| **DATABASE_URL** | ✅ | Obligatorio en prod; pool_size y opciones desde env. |
| **.env** | ✅ | .env.example documenta variables; .gitignore debe incluir .env (revisar que no se suba .env). |

### 2.7 Base de datos y TLS

- **Producción:** `ssl: [verify: :verify_none]` para PostgreSQL. Aceptable en entornos donde el canal ya está protegido (por ejemplo, red interna o túnel); para cumplimiento estricto (p. ej. PCI, auditorías) suele pedirse `verify_peer` con CA.
- **Prepared statements:** `prepare: :unnamed` configurado (compatible con PgBouncer en modo transaction).

### 2.8 Riesgos conocidos y mitigaciones

| Riesgo | Mitigación actual | Recomendación |
|--------|-------------------|---------------|
| **SSRF en webhooks** | URL validada solo con `http://` o `https://`; el worker hace POST a esa URL. | Documentar que solo se deben configurar URLs propias o de confianza; opcional: lista de denegación (p. ej. 127.0.0.1, 169.254.x.x, IPs internas) o validación de DNS. |
| **Fuga de información en errores** | `render_errors` con formatos HTML/JSON; en prod el nivel de log es `:info`. | Asegurar que en prod no se expongan stack traces al usuario (Phoenix por defecto no los muestra en prod). |
| **Dependencias** | mix.lock fijado; Credo/Dialyxir en dev. | Ejecutar periódicamente `mix hex.audit` y revisar avisos de seguridad en Hex/ GitHub. |

---

## 3. Calidad de código y arquitectura

### 3.1 Estructura

- **Umbrella:** Separación clara entre `streamflix_core` (dominio, Ecto, Oban), `streamflix_accounts` (usuarios, Guardian) y `streamflix_web` (HTTP, LiveView, API).
- **Contextos:** Lógica de negocio en `StreamflixCore.Platform` y `StreamflixAccounts`; controladores delgados y uso de changesets.
- **Sin SQL crudo:** Uso de Repo y queries Ecto con parámetros; no se encontraron `fragment()` con entrada de usuario.

### 3.2 Consistencia y herramientas

- **Formatter:** `.formatter.exs` con import_deps Ecto/Phoenix; inputs definidos.
- **Credo:** Incluido en dev/test (mix.exs raíz).
- **Dialyxir:** Incluido en dev/test para análisis de tipos.
- **AGENTS.md:** Indica uso de `mix precommit`. El alias está definido en mix.exs raíz: `precommit` ejecuta format, credo --strict, hex.audit y test.

### 3.3 Tests

- Configuración de test con Ecto Sandbox, Oban en modo `:inline`, Guardian con issuer/secret de test.
- Existencia de tests en `streamflix_web_web` (controllers, error views, page_controller).
- Recomendación: mantener y ampliar cobertura en auth, API platform y contexto Platform.

### 3.4 Rendimiento y escalado

- **Oban:** Colas `delivery`, `scheduled_job`, `default` con concurrencia definida; workers con timeouts (Req: connect 5 s, receive 15 s).
- **Límites de listado:** Límite máximo (p. ej. 100) en listados de eventos.
- **Body size:** Límite global 256 KB en parsers.
- **Rate limit:** ETS con limpieza probabilística de entradas expiradas para evitar crecimiento indefinido.

---

## 4. Estándares internacionales y buenas prácticas

### 4.1 OWASP (Top 10 orientativo)

| Categoría | Medidas observadas |
|-----------|---------------------|
| **A01:2021 – Broken Access Control** | API Key y JWT asociados a proyecto/usuario; comprobación de `project_id` en recursos (webhooks, eventos, etc.). Admin por rol. |
| **A02:2021 – Cryptographic Failures** | Contraseñas con Pbkdf2; API keys almacenadas por hash SHA256; secretos por env en prod. |
| **A03:2021 – Injection** | Ecto changesets y Repo; sin concatenación de SQL con entrada de usuario. |
| **A04:2021 – Insecure Design** | Rate limiting, validación de entrada, separación de responsabilidades. |
| **A05:2021 – Security Misconfiguration** | Cabeceras de seguridad; force_ssl en prod; dev_routes deshabilitadas en prod. |
| **A06:2021 – Vulnerable Components** | Dependencias fijadas en mix.lock; recomendación: auditoría periódica (hex.audit). |
| **A07:2021 – Auth/Session** | Sesión firmada, SameSite Lax, JWT con expiración, API Key por hash. |
| **A08:2021 – Software/Data Integrity** | Dependencias desde Hex; no se detectan cargas desde fuentes no fiables en tiempo de ejecución. |
| **A09:2021 – Logging/Monitoring** | Logger con metadata; recomendación: en prod considerar auditoría de accesos sensibles (login, regeneración de token). |
| **A10:2021 – SSRF** | Citado arriba: webhooks; mitigación documentada y opcional (listas de bloqueo/validación). |

### 4.2 Accesibilidad (WCAG)

- **Skip link:** Presente en layout principal y en páginas clave (home, login, signup).
- **Landmarks:** Uso de `<header>`, `<main>`, `<nav>`, `<footer>`, `role="contentinfo"` y `role="main"` donde corresponde.
- **ARIA:** `aria-label` en navegación principal, selección de idioma y enlaces “Ir al inicio”; `aria-current="page"` en idioma activo.
- **Focus visible:** Estilos `focus-visible` en enlaces y controles (app.css y clases en componentes).
- **Contraste y texto:** Contraste de color y tamaños de fuente razonables; mensajes de error y estados comunicados por texto y no solo por color.
- **Formularios:** Labels asociados a inputs; `aria-label` en formularios donde aplica.
- Recomendación: revisar periódicamente con linters de accesibilidad (p. ej. axe) y pruebas con lector de pantalla.

### 4.3 Privacidad y datos personales (GDPR / LOPD orientativo)

- **Política de privacidad:** Página dedicada (`/privacy`) con responsable, finalidad, legitimación, derechos y contacto.
- **Términos de uso:** Página `/terms` con condiciones de uso.
- **Política de cookies:** Página `/cookies` describiendo cookies técnicas (sesión, idioma); sin cookies de seguimiento o publicitarias declaradas.
- **Datos mínimos:** Registro con email, nombre y contraseña; no se ha revisado en detalle retención y derecho al olvido en código (fuera del alcance de esta revisión estática).
- **Contacto:** Email de contacto configurable; enlace desde privacidad y términos.

### 4.4 Despliegue y contenedores

- **Dockerfile:** Multi-stage; usuario no root (`app`); HEALTHCHECK sobre HTTP al puerto de la app.
- **Secrets:** No se copian secretos en la imagen; se esperan por variable de entorno en tiempo de ejecución.
- **Producción:** `force_ssl`; `secret_key_base` y claves críticas desde env; dev_routes deshabilitadas.

---

## 5. Documentación y operaciones

- **README, CHANGELOG, AGENTS.md:** Presentes.
- **Documentación de API:** Página `/docs` con conceptos, primeros pasos y ejemplos.
- **Manual de usuario, FAQ, contacto, precios, sobre nosotros:** Páginas estáticas y enlaces en footer.
- **Despliegue:** Documentación en `docs/`, `.github/workflows` y archivos relacionados con Azure y secretos.
- **.env.example:** Incluye variables necesarias y advierte no commitear `.env`.

---

## 6. Checklist de recomendaciones

- [x] **CORS:** La API permite cualquier origen (`*`) para que cada cliente (su dominio: misfactura.com, ejemplo.com, etc.) pueda llamar desde el navegador. La seguridad la da el token del proyecto (Bearer / X-Api-Key); solo las peticiones con token válido son aceptadas.
- [x] **Sesión:** Signing salt de la sesión configurable con `SESSION_SIGNING_SALT` en producción (plug `SessionWithConfig`).
- [x] **Alias:** `mix precommit` definido (format, credo --strict, test).
- [x] **Dependencias:** `mix hex.audit` incluido en el alias `mix precommit`; ejecutar antes de subir cambios.
- [x] **Webhooks:** Riesgo SSRF y uso solo de URLs propias documentado en `docs/WEBHOOKS_EVENTS_SPEC.md` (sección 3.1).
- [x] **Producción (PostgreSQL):** Comentario en `config/runtime.exs` sobre `ssl: [verify: :verify_peer]` y CA para cuando lo exija la política de seguridad.
- [ ] **Logs:** En producción, no loguear cuerpos de petición ni cabeceras con tokens; el código actual no loguea contraseñas ni tokens completos (recordatorio para futuros cambios).

---

## 7. Conclusión

El proyecto presenta una base sólida de seguridad (autenticación, cabeceras, rate limiting, validación de entrada, sin SQL injection por diseño), calidad de código (Ecto, contextos, formatter, Credo, Dialyxir) y alineación con estándares (OWASP, WCAG, documentación legal y de privacidad). Las recomendaciones anteriores son mejoras incrementales para entornos de producción y cumplimiento más estricto, sin cambios realizados en esta auditoría.
