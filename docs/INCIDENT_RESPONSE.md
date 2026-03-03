# Plan de Respuesta a Incidentes de Seguridad

> **Versión:** 1.0
> **Fecha:** 2026-03-06
> **Responsable:** Security Officer (ver Contactos)
> **Marco regulatorio:** SOC 2 (Disponibilidad), GDPR Art. 33-34

---

## 1. Severidades

| Severidad | Descripción | Tiempo de respuesta | Ejemplo |
|---|---|---|---|
| **P1 — Crítico** | Brecha activa, datos expuestos, sistema caído | < 15 minutos | Acceso no autorizado a BD, exfiltración de datos |
| **P2 — Alto** | Vulnerabilidad explotable, degradación severa | < 1 hora | Inyección SQL detectada, circuit breaker masivo |
| **P3 — Medio** | Anomalía de seguridad, degradación menor | < 4 horas | Brute force detectado, health check degraded |
| **P4 — Bajo** | Actividad sospechosa, mejora preventiva | < 24 horas | Login fallidos inusuales, dependencia con CVE bajo |

---

## 2. Procedimiento de Respuesta

### Fase 1: Detección

**Fuentes de detección:**
- **Automatizada:** ObanBreachDetectionWorker (cada 5 min) — brute force, ataques coordinados, exfiltración
- **Automatizada:** ObanUptimeWorker (cada 5 min) — health degraded/unhealthy
- **Automatizada:** Circuit breaker — fallos consecutivos en webhooks
- **Manual:** Revisión de audit_logs en dashboard
- **Externa:** Reporte de usuario o tercero

**Acciones inmediatas:**
1. Verificar la alerta (¿falso positivo?)
2. Clasificar severidad (P1-P4)
3. Registrar en audit_log: `security.incident_opened`
4. Notificar al equipo según severidad

### Fase 2: Contención

**P1/P2 — Contención inmediata:**
- Bloquear IPs sospechosas (IP allowlist en API keys)
- Desactivar cuentas comprometidas (`user.status = "locked"`)
- Desactivar webhooks afectados (`webhook.status = "inactive"`)
- Revocar API keys comprometidas
- Si es necesario: modo mantenimiento

**P3/P4 — Contención preventiva:**
- Aumentar monitoreo (revisar logs manualmente)
- Aplicar rate limiting más estricto
- Notificar a usuarios afectados

### Fase 3: Erradicación

1. Identificar la causa raíz
2. Corregir la vulnerabilidad (hotfix)
3. Verificar que no hay persistencia del atacante
4. Rotar credenciales afectadas (API keys, tokens, secrets)
5. Aplicar parches de seguridad si aplica

### Fase 4: Recuperación

1. Restaurar servicios desde backup si es necesario (`Platform.Backup`)
2. Verificar integridad de datos (checksums SHA256 en eventos)
3. Re-habilitar servicios gradualmente
4. Monitorear activamente durante 24-48h post-incidente
5. Confirmar operación normal con health checks

### Fase 5: Lecciones aprendidas

1. Documentar timeline completo del incidente
2. Identificar mejoras en detección/respuesta
3. Actualizar este plan si es necesario
4. Implementar mejoras preventivas
5. Comunicar lecciones al equipo

---

## 3. Notificación GDPR (Art. 33-34)

### Art. 33 — Notificación a la autoridad supervisora (72 horas)

**¿Cuándo notificar?** Si la brecha afecta datos personales de ciudadanos UE.

**Plazo:** Máximo 72 horas desde la detección.

**Contenido de la notificación:**
- Naturaleza de la brecha
- Categorías y número aproximado de interesados afectados
- Datos de contacto del DPO
- Consecuencias probables
- Medidas adoptadas o propuestas

### Art. 34 — Notificación a los interesados

**¿Cuándo notificar?** Si la brecha supone alto riesgo para derechos y libertades.

**Excepciones:** No es necesario si los datos estaban cifrados (AES-256-GCM) o si las medidas adoptadas eliminaron el riesgo.

---

## 4. Plantillas de Comunicación

### Plantilla: Inicio de incidente

```
INCIDENTE DE SEGURIDAD — [SEVERIDAD]
Fecha/hora: [TIMESTAMP UTC]
Detectado por: [FUENTE]
Descripción: [DESCRIPCIÓN BREVE]
Impacto estimado: [USUARIOS/DATOS AFECTADOS]
Estado: EN INVESTIGACIÓN
Próxima actualización: [HORA]
```

### Plantilla: Actualización

```
ACTUALIZACIÓN — Incidente [ID]
Fecha/hora: [TIMESTAMP UTC]
Estado: [CONTENIDO/EN ERRADICACIÓN/EN RECUPERACIÓN]
Progreso: [ACCIONES TOMADAS]
Impacto actualizado: [CAMBIOS]
Próxima actualización: [HORA]
```

### Plantilla: Resolución

```
RESOLUCIÓN — Incidente [ID]
Fecha/hora resolución: [TIMESTAMP UTC]
Duración total: [HORAS/MINUTOS]
Causa raíz: [DESCRIPCIÓN]
Datos afectados: [DETALLE]
Acciones correctivas: [LISTA]
Mejoras preventivas: [LISTA]
```

---

## 5. Contactos

| Rol | Nombre | Contacto |
|---|---|---|
| Security Officer | [NOMBRE] | [EMAIL] |
| Desarrollador principal | [NOMBRE] | [EMAIL] |
| DPO (GDPR) | [NOMBRE] | [EMAIL] |

---

## 6. Herramientas del sistema

| Herramienta | Uso en incidentes |
|---|---|
| Audit Log (`/dashboard` → Audit) | Timeline de acciones, evidencia |
| Health Check (`GET /health`) | Estado de servicios |
| Uptime Monitoring (dashboard) | Historial de disponibilidad |
| Circuit Breaker (automático) | Aislamiento de webhooks fallidos |
| Breach Detection (automático) | Detección de anomalías cada 5 min |
| Backup (`Platform.Backup`) | Restauración de datos |
| Notificaciones (dashboard bell) | Alertas en tiempo real |

---

## 7. Revisión

Este plan debe revisarse:
- Después de cada incidente P1/P2
- Trimestralmente como mínimo
- Cuando se agreguen nuevas fuentes de detección
