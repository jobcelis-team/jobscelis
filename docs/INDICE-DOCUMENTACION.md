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
| **Contacto** | ⚠️ Parcial | Términos/Privacidad | "Contacta al titular" con enlace a GitHub/perfil. Opcional: página `/contact` con formulario o email. |
| **Sobre nosotros / About** | ❌ Opcional | — | Página "Qué es Jobcelis" / "Quiénes somos". Puede cubrirse en la home. |
| **Precios / Planes** | ❌ Opcional | — | Servicio gratuito; si quieres, una página "Planes" o "Es gratis" da imagen seria. |

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

---

## 3. Elementos legales y de confianza

| Elemento | Estado | Notas |
|----------|--------|--------|
| Términos de uso | ✅ | `/terms` |
| Política de privacidad | ✅ | `/privacy` |
| Copyright en footer | ✅ | Año + titular (config :legal) |
| Enlace a contacto (GitHub/perfil) | ✅ | En términos y privacidad |
| Política de cookies | ❌ Opcional | Si usas cookies no esenciales, conviene página o aviso. Sesión = cookie; si solo sesión, suele mencionarse en privacidad. |

---

## 4. Experiencia de usuario (UX) y navegación

| Elemento | Estado | Dónde |
|----------|--------|--------|
| Enlace a Documentación | ✅ | Nav y footer |
| Enlace a Términos | ✅ | Footer |
| Enlace a Privacidad | ✅ | Footer |
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

## 7. Opcionales para más adelante

- **Página /contact** — Formulario o email de contacto.
- **Página /about** — "Qué es Jobcelis" / "Quiénes somos".
- **Página /pricing** o "Es gratis" — Dejar claro que no hay cobros.
- **Política de cookies** — Página o sección si amplías uso de cookies.
- **Changelog público** — Versión resumida en la web (enlazando a CHANGELOG.md o copiando).
- **LICENSE** — Si el código es abierto (MIT, Apache, etc.).
- **CONTRIBUTING.md / CODE_OF_CONDUCT** — Si aceptas contribuciones.

Con lo que tienes ahora (docs API, manual, FAQ, términos, privacidad, changelog, índice) la aplicación queda **más formal y completa** para usuarios y para ti como mantenedor.
