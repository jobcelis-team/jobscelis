# Changelog

Todos los cambios notables del proyecto se documentan en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/).

---

## [Unreleased]

### Añadido

- Documentación ampliada: conceptos básicos (eventos, webhooks, entregas, jobs, topics), primeros pasos y guía de configuración de jobs y cron.
- Página FAQ con preguntas frecuentes (ES/EN).
- Manual de usuario en `docs/MANUAL-USUARIO.md`.
- Índice de documentación en `docs/INDICE-DOCUMENTACION.md`.
- CHANGELOG.md para historial de versiones.
- Enlaces en footer a FAQ y documentación/guía.
- Página **Contacto** (`/contact`): email de contacto (config `contact_email`), GitHub y perfil.
- Página **Planes y precios** (`/pricing`): servicio gratuito; sección "Apoyar el proyecto" con enlaces opcionales a PayPal y Payoneer (config `donation_paypal_url`, `donation_payoneer_url` o env `DONATION_PAYPAL_URL`, `DONATION_PAYONEER_URL`).
- Config `:legal`: `contact_email`, `donation_paypal_url`, `donation_payoneer_url`; en producción se pueden sobrescribir con variables de entorno.

### Cambiado

- Nombre de producto unificado a "Jobcelis" (dominio jobcelis.com) en toda la aplicación.
- Traducciones completas en la tabla de cron (EN).

### Corregido

- Alias no usado en `DeliveryWorker` (Webhook).
- Duplicados en archivos gettext (.po) que provocaban error de compilación.

---

## [0.1.0] — Fecha inicial

- Eventos, webhooks, entregas y jobs programados (diario, semanal, mensual, cron).
- API con autenticación por API Key (Bearer / X-Api-Key).
- Registro e inicio de sesión (JWT para API de auth).
- Dashboard: proyecto, token, eventos, webhooks, jobs, entregas.
- Panel de administración (superadmin): usuarios, proyectos, métricas.
- Términos de uso y política de privacidad.
- Documentación API en `/docs`.
- Despliegue con GitHub Actions a Azure (ACR + Web App).
- Soporte multidioma (ES/EN) en la interfaz.
