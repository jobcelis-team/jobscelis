# Índice de documentación y checklist profesional — Jobcelis

Este documento enumera **toda la documentación y elementos** que tiene el proyecto y lo que se recomienda para una aplicación formal y profesional.

---

## 1. Documentación para usuarios finales (en la web)

| Elemento | Estado | Ubicación | Notas |
|----------|--------|-----------|--------|
| **Documentación API** | ✅ Hecho | `/docs` | Conceptos, primeros pasos, API, cron, códigos de respuesta. |
| **Manual de usuario / Guía** | ✅ Añadido | `docs/MANUAL-USUARIO.md` y enlace desde web | Guía paso a paso: registro, token, webhooks, jobs. Enlazar desde footer como "Guía" o "Manual". |
| **FAQ (preguntas frecuentes)** | ✅ Añadido | `/faq` | Preguntas frecuentes con respuestas cortas. |
| **Términos de uso** | ✅ Hecho | `/terms` | Página legal. |
| **Política de privacidad** | ✅ Hecho | `/privacy` | Página legal. |
| **Contacto** | ✅ Hecho | `/contact` | Email (vladimir.celi@proton.me por config), GitHub y perfil. |
| **Sobre nosotros / About** | ✅ Hecho | `/about` | Titular (owner), enlaces a GitHub y perfil desde `config :legal`. |
| **Precios / Planes** | ✅ Hecho | `/pricing` | "Es gratis", sin facturación; sección donaciones con enlaces opcionales PayPal y Payoneer (config o env). |
| **Política de cookies** | ✅ Hecho | `/cookies` | Cookies que usa el sitio (sesión `_streamflix_web_key`, idioma `locale`); sin cookies publicitarias ni de terceros. |
| **Changelog (página web)** | ✅ Hecho | `/changelog` | Mismo contenido que `CHANGELOG.md` del repositorio; historial de versiones en la web. |

---

## 2. Documentación técnica (repositorio)

| Documento | Estado | Ubicación | Uso |
|-----------|--------|-----------|-----|
| **README.md** | ✅ Hecho | Raíz | Descripción del proyecto, requisitos, configuración rápida, desarrollo. |
| **CHANGELOG.md** | ✅ Añadido | Raíz | Historial de versiones y cambios. Profesional. |
| **.env.example** | ✅ Hecho | Raíz | Variables de entorno necesarias. |
| **AGENTS.md** | ✅ Hecho | Raíz | Reglas para asistentes IA / Cursor. |
| **ADMIN_SETUP.md** | ✅ Hecho | Raíz | Creación de admin/superadmin. |
| **docs/LEGAL.md** | ✅ Hecho | docs/ | Notas internas sobre marca, dominio, términos. |
| **docs/WEBHOOKS_EVENTS_SPEC.md** | ✅ Hecho | docs/ | Especificación del producto (eventos, webhooks, jobs). |
| **docs/DEPLOY.md** | ✅ Hecho | docs/ | Cómo desplegar. |
| **docs/AZURE-PASO-A-PASO.md** | ✅ Hecho | docs/ | Pasos detallados para Azure. |
| **docs/MANUAL-USUARIO.md** | ✅ Añadido | docs/ | Manual para usuarios finales (registro, dashboard, token, webhooks, jobs). |
| **.github/workflows/** | ✅ Hecho | .github/ | CI/CD (deploy a Azure). |
| **.github/SECRETS-GITHUB.md** | ✅ Hecho | .github/ | Cómo configurar secrets para el deploy. |
| **.github/DEPLOY-AZURE-ACTIONS.md** | ✅ Hecho | .github/ | Documentación del workflow de deploy. |
| **docs/AUDITORIA-CALIDAD-SEGURIDAD.md** | ✅ Añadido | docs/ | Auditoría de calidad, seguridad y estándares (sin cambios en código). |

---

## 3. Elementos legales y de confianza

| Elemento | Estado | Notas |
|----------|--------|--------|
| Términos de uso | ✅ | `/terms` |
| Política de privacidad | ✅ | `/privacy` |
| Copyright en footer | ✅ | Año + titular (config :legal) |
| Enlace a contacto (GitHub/perfil) | ✅ | En términos y privacidad |
| Política de cookies | ✅ | Página `/cookies` con cookies reales del proyecto (sesión, idioma). |

---

## 4. Experiencia de usuario (UX) y navegación

| Elemento | Estado | Dónde |
|----------|--------|--------|
| Enlace a Documentación | ✅ | Nav y footer |
| Enlace a Términos | ✅ | Footer |
| Enlace a Privacidad | ✅ | Footer |
| Enlace a Cookies | ✅ | Footer |
| Enlace a Changelog | ✅ | Footer |
| Enlace a FAQ | ✅ | Footer / nav |
| Enlace a Guía / Manual | ✅ | Footer (a `/docs` o sección primeros pasos) |
| Cambio de idioma (ES/EN) | ✅ | Nav en docs y páginas públicas |
| Mensajes de error claros | ✅ | Flash, validaciones |
| Página 404/500 | ✅ | ErrorHTML |

---

## 5. Despliegue y operaciones

| Elemento | Estado | Dónde |
|----------|--------|--------|
| Dockerfile | ✅ | Raíz |
| docker-compose.yml | ✅ | Raíz |
| Variables de entorno documentadas | ✅ | .env.example, README |
| Deploy a Azure (GitHub Actions) | ✅ | .github/workflows/deploy-azure.yml |
| Documentación de secrets | ✅ | .github/SECRETS-GITHUB.md |

---

## 6. Resumen: qué añadimos en esta pasada

- **docs/INDICE-DOCUMENTACION.md** — Este índice y checklist.
- **docs/MANUAL-USUARIO.md** — Manual para usuarios (registro, dashboard, token, webhooks, jobs).
- **CHANGELOG.md** — Historial de versiones en la raíz.
- **Página /faq** — FAQ con preguntas frecuentes (ES/EN).
- **Enlaces en footer** — A FAQ y a Guía (docs o primeros pasos).

---

## 7. Opcionales y repositorio privado

- **Política de cookies** — ✅ Hecho: página `/cookies` con las cookies reales del proyecto (sesión, idioma).
- **Changelog en la web** — ✅ Hecho: página `/changelog` con el mismo contenido que `CHANGELOG.md`.
- **LICENSE / CONTRIBUTING / CODE_OF_CONDUCT** — No aplican: el **repositorio es privado**. Solo serían necesarios si el repo fuera público y aceptaras contribuciones.

**Configuración pendiente (cuando tengas los datos):**

- **Enlaces de donación** — En `config/config.exs` (o con env `DONATION_PAYPAL_URL`, `DONATION_PAYONEER_URL`) pon tus URLs de PayPal y Payoneer para que en `/pricing` aparezcan los botones de donar.

Con lo que tienes ahora, la aplicación está **completa** a nivel documentación, legal, contacto, planes y donaciones.
