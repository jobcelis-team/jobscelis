# Proceso de Notificación de Brechas de Seguridad (Art. 33-34 RGPD)

> **Responsable:** Jobcelis (proyecto personal)
> **Fecha de actualización:** 2026-03-03
> **Plazo máximo:** 72 horas desde la detección

---

## 1. Timeline de respuesta

| Fase | Plazo | Responsable | Acciones |
|------|-------|-------------|----------|
| **T+0: Detección** | Inmediato | Sistema automático | El `ObanBreachDetectionWorker` detecta anomalías cada 5 min. Clasifica severidad (critical/high/medium). Registra en audit log con `breach_notification_required: true` si aplica. Notifica a administradores. |
| **T+24h: Investigación** | 0-24h | Administrador | Revisar audit logs de las últimas 24-48h. Identificar alcance: qué datos, cuántos usuarios afectados. Determinar si hubo acceso no autorizado real. Documentar hallazgos. |
| **T+48h: Preparación** | 24-48h | Administrador | Preparar notificación Art. 33 para la autoridad. Si alto riesgo: preparar notificación Art. 34 para usuarios. Aplicar medidas de contención (revocar sesiones, bloquear IPs, etc.). |
| **T+72h: Notificación** | 48-72h | Administrador | Enviar notificación a la autoridad de control (Art. 33). Si alto riesgo: notificar a usuarios afectados (Art. 34). Registrar todo en audit log. |

---

## 2. Clasificación de severidad

| Severidad | Criterio | Notificación requerida |
|-----------|----------|----------------------|
| **Critical** | Exfiltración de datos (>5 exports masivos por usuario en 10 min) | Art. 33 (autoridad) + Art. 34 (usuarios) |
| **High** | Ataque coordinado (>50 intentos login globales en 10 min) | Art. 33 (autoridad) — evaluar Art. 34 |
| **Medium** | Fuerza bruta por IP, bloqueos de cuenta aislados | Registrar internamente — evaluar Art. 33 |

---

## 3. Template de notificación a la autoridad (Art. 33.3)

### Información requerida:

**1. Naturaleza de la brecha**
- Tipo de incidente: [fuerza bruta / exfiltración / acceso no autorizado / otro]
- Fecha y hora de detección: [YYYY-MM-DD HH:MM UTC]
- Fecha estimada de inicio: [YYYY-MM-DD HH:MM UTC]
- Descripción del incidente: [narrativa breve]

**2. Categorías de datos afectados**
- Datos personales comprometidos: [email, nombre, IP, otros]
- Categorías especiales (Art. 9): [Sí/No — especificar si aplica]

**3. Número aproximado de afectados**
- Interesados afectados: [número o rango estimado]
- Registros de datos afectados: [número o rango estimado]

**4. Datos de contacto del responsable**
- Nombre: [Responsable del proyecto]
- Email: [email de contacto]
- Teléfono: [si aplica]

**5. Consecuencias probables**
- Riesgo para los interesados: [bajo/medio/alto]
- Posibles consecuencias: [suplantación de identidad, spam, acceso no autorizado a cuentas, etc.]

**6. Medidas adoptadas o propuestas**
- Medidas de contención: [sesiones revocadas, IPs bloqueadas, etc.]
- Medidas correctivas: [cambio de contraseñas forzado, parches aplicados, etc.]
- Medidas preventivas: [mejoras de seguridad planificadas]

---

## 4. Template de notificación a usuarios (Art. 34)

### Cuándo aplica:
La notificación a usuarios es obligatoria cuando la brecha supone un **alto riesgo** para sus derechos y libertades. Esto incluye:
- Exfiltración confirmada de datos personales
- Acceso no autorizado a cuentas de usuario
- Compromiso de credenciales

### Contenido de la notificación:

> **Asunto:** Aviso de seguridad importante sobre tu cuenta en Jobcelis
>
> Estimado/a usuario/a,
>
> Te informamos que el [FECHA] detectamos un incidente de seguridad que puede afectar a tu cuenta.
>
> **¿Qué ocurrió?**
> [Descripción clara y sencilla del incidente]
>
> **¿Qué datos se vieron afectados?**
> [Lista de categorías de datos comprometidos]
>
> **¿Qué hemos hecho?**
> - [Medida 1: ej. "Hemos revocado todas las sesiones activas"]
> - [Medida 2: ej. "Hemos bloqueado las IPs sospechosas"]
> - [Medida 3: ej. "Hemos notificado a la autoridad de control"]
>
> **¿Qué puedes hacer?**
> - Cambia tu contraseña inmediatamente en [URL]
> - Revisa tus sesiones activas en la sección "Cuenta"
> - Activa la autenticación de dos factores (MFA) si no lo has hecho
> - Si usas la misma contraseña en otros servicios, cámbiala también
>
> **Contacto**
> Si tienes preguntas, contáctanos en [email de contacto].
>
> Lamentamos las molestias.

---

## 5. Registro de incidentes

Todos los incidentes se registran en el audit log con:
- `action: "security.anomaly_detected"`
- `metadata.severity`: critical / high / medium
- `metadata.breach_notification_required`: true / false
- `metadata.anomalies`: detalle de las anomalías detectadas

### Información adicional a documentar manualmente:
- Decisión de notificar o no (y justificación)
- Fecha de notificación a la autoridad
- Fecha de notificación a usuarios (si aplica)
- Medidas correctivas aplicadas
- Lecciones aprendidas

---

## 6. Medidas de contención disponibles

| Acción | Cómo ejecutarla |
|--------|----------------|
| **Revocar todas las sesiones de un usuario** | Cuenta → Gestión de sesiones → "Cerrar todas las demás sesiones" |
| **Bloquear cuenta** | El sistema bloquea automáticamente tras 5 intentos fallidos |
| **Restringir procesamiento** | Cuenta → Protección de datos → "Restringir procesamiento" (Art. 18) |
| **Revocar API keys** | Dashboard → API Keys → Eliminar key comprometida |
| **Forzar cambio de contraseña** | Enviar email de reset vía `/api/v1/auth/forgot-password` |

---

*Documento revisado: 2026-03-03. Próxima revisión: 2026-06-03 (trimestral).*
