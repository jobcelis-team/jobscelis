# Registro de Actividades de Tratamiento (Art. 30 RGPD)

> **Responsable:** Jobcelis (proyecto personal)
> **Fecha de actualización:** 2026-03-03
> **Contacto:** Ver página /contact

---

## 1. Actividades de tratamiento

| # | Actividad | Propósito | Base legal (Art. 6) | Categorías de datos | Interesados | Retención |
|---|-----------|-----------|---------------------|---------------------|-------------|-----------|
| 1 | **Registro y autenticación** | Crear cuenta, autenticar usuario, gestionar sesiones | Art. 6.1.b — Ejecución de contrato | Email (cifrado), nombre (cifrado), contraseña (hash PBKDF2-SHA512), IP (cifrado), User-Agent (cifrado) | Usuarios registrados | Mientras la cuenta esté activa. Eliminación completa al borrar cuenta |
| 2 | **Eventos y webhooks** | Procesar eventos del usuario y entregarlos a webhooks configurados | Art. 6.1.b — Ejecución de contrato | Payloads de eventos (JSON), URLs de webhooks, headers personalizados, respuestas de entrega | Usuarios registrados | 90 días para entregas. Eventos según configuración del usuario |
| 3 | **Registro de auditoría** | Mantener trazabilidad de acciones para seguridad y cumplimiento | Art. 6.1.f — Interés legítimo (seguridad) | Acción realizada, user_id, IP (cifrada), User-Agent (cifrado), metadata | Usuarios registrados | 90 días. Pseudonimización al eliminar cuenta |
| 4 | **Gestión de sesiones** | Controlar accesos activos, permitir revocación | Art. 6.1.b — Ejecución de contrato | JWT jti, IP (cifrada), User-Agent (cifrado), tipo de dispositivo, última actividad | Usuarios registrados | 7 días (limpieza automática diaria) |
| 5 | **Registro de consentimientos** | Documentar consentimientos otorgados/revocados (GDPR) | Art. 6.1.c — Obligación legal | Propósito, fecha otorgamiento/revocación, IP, versión de política | Usuarios registrados | Indefinido (obligación legal de demostrar consentimiento) |
| 6 | **Detección de brechas de seguridad** | Detectar anomalías: fuerza bruta, ataques coordinados, exfiltración | Art. 6.1.f — Interés legítimo (seguridad) | IPs de origen, conteo de intentos, user_id de afectados, severidad | Usuarios registrados y visitantes | 90 días (como parte del audit log) |
| 7 | **Comunicaciones por email** | Enviar emails transaccionales (verificación, reset de contraseña) | Art. 6.1.b — Ejecución de contrato | Email (cifrado), nombre, tipo de email | Usuarios registrados | No se almacenan emails enviados. Logs del proveedor según su política |

---

## 2. Sub-procesadores

| Proveedor | Servicio | Datos procesados | Ubicación | Garantías |
|-----------|----------|------------------|-----------|-----------|
| **Supabase** | Base de datos PostgreSQL (hosting) | Todos los datos de la aplicación | US (AWS us-east-1) | SOC 2 Type II, cifrado en reposo y tránsito |
| **Resend** | Envío de emails transaccionales | Email del destinatario, contenido del email | US | DPA disponible, cifrado en tránsito |

---

## 3. Medidas de seguridad (Art. 32)

| Medida | Implementación |
|--------|----------------|
| **Cifrado en reposo** | AES-256-GCM vía Cloak.Ecto para todos los campos PII (email, nombre, IP, User-Agent) |
| **Cifrado en tránsito** | TLS en todas las conexiones (HTTPS, conexión a BD vía pooler SSL) |
| **Hashing de contraseñas** | PBKDF2-SHA512 con 210.000 iteraciones (OWASP compliant) |
| **HMAC para lookups** | HMAC-SHA512 para búsquedas de email sin exponer plaintext |
| **Control de acceso** | RBAC con roles (user, admin, superadmin) + scopes por API key |
| **Autenticación multifactor** | TOTP opcional con apps de autenticación |
| **Detección de intrusiones** | Análisis automático de audit logs cada 5 minutos |
| **Gestión de sesiones** | JWT con tracking, revocación individual/masiva, timeout configurable |
| **Rate limiting** | Límites por endpoint para prevenir abuso |
| **IP allowlist** | Restricción opcional de IPs por API key |

---

## 4. Derechos del interesado

| Derecho | Artículo | Implementación |
|---------|----------|----------------|
| **Acceso** | Art. 15 | `GET /api/v1/me/data` — DSAR completo con perfil, eventos, entregas, sesiones |
| **Rectificación** | Art. 16 | Edición de perfil (nombre, email, contraseña) desde la cuenta |
| **Supresión** | Art. 17 | Eliminación completa de cuenta con cascade de todos los datos asociados |
| **Portabilidad** | Art. 20 | Exportación en formato JSON máquina-readable vía DSAR |
| **Limitación** | Art. 18 | Estado `restricted` que detiene procesamiento de webhooks/eventos |
| **Oposición** | Art. 21 | Flag `processing_consent` con enforcement en workers |

---

## 5. Transferencias internacionales

Los datos se almacenan en servidores de Supabase (US). La transferencia se ampara en:
- Cláusulas contractuales tipo (SCCs) del proveedor
- Medidas técnicas suplementarias: cifrado end-to-end de campos PII antes de almacenamiento

---

*Documento revisado: 2026-03-03. Próxima revisión: 2026-09-03 (semestral).*
