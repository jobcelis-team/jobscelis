# Manual de usuario — Jobcelis

Guía paso a paso para usar Jobcelis: registro, acceso al dashboard, API Token, eventos, webhooks y jobs programados.

---

## 1. Registrarse e iniciar sesión

1. Entra en la web de Jobcelis (por ejemplo `https://jobcelis.com`).
2. Pulsa **Registrarse**.
3. Introduce tu **email** y una **contraseña** (mínimo 8 caracteres; mayúsculas, minúsculas y números recomendados).
4. Opcional: nombre.
5. Tras registrarte, inicia sesión con **Iniciar sesión** usando ese email y contraseña.

Si tu cuenta queda inactiva (por ejemplo por el administrador), verás un mensaje indicando que contactes al soporte.

---

## 2. El Dashboard y tu API Token

Después de iniciar sesión accedes al **Dashboard** (enlace "Dashboard" en la barra superior).

- **Proyecto:** Cada cuenta tiene un proyecto asociado. En el Dashboard gestionas ese proyecto.
- **API Token:** Es la clave que usas para todas las llamadas a la API (enviar eventos, crear webhooks, listar entregas, etc.).
  - Lo ves en la sección **API Token** del Dashboard (a veces solo el prefijo por seguridad).
  - Si acabas de registrarte, el token pudo mostrarse una sola vez al crear el proyecto; guárdalo en un lugar seguro.
  - Puedes **regenerar** el token desde el Dashboard; el token anterior dejará de funcionar.
- En las peticiones a la API debes enviar el token en el encabezado:
  - `Authorization: Bearer TU_TOKEN`  
  - o `X-Api-Key: TU_TOKEN`

---

## 3. Enviar eventos

Un **evento** es un mensaje (cualquier JSON) que envías a Jobcelis. Opcionalmente puedes añadir un **topic** (etiqueta) para clasificarlo.

**Desde el Dashboard:**  
Suele haber un formulario o botón para "Enviar evento de prueba": escribes un JSON (y opcionalmente un topic) y se envía como un evento real. Puedes ver el evento en la lista de eventos.

**Desde tu aplicación:**  
Haz un `POST` a `/api/v1/events` (o `/api/v1/send`) con:

- Header: `Authorization: Bearer TU_TOKEN` o `X-Api-Key: TU_TOKEN`
- Header: `Content-Type: application/json`
- Body: JSON libre, por ejemplo `{"topic":"pedido.creado","order_id":123,"total":99.99}`

La respuesta incluirá un `event_id`. En el Dashboard puedes ver el evento y sus entregas.

---

## 4. Configurar webhooks

Un **webhook** es una URL a la que Jobcelis envía un POST cuando llega un evento que cumple las condiciones que tú defines.

1. En el Dashboard entra en **Webhooks**.
2. Pulsa **Crear** (o similar).
3. Indica la **URL** que debe recibir los POST (debe ser accesible desde internet; en producción usa HTTPS).
4. Opcional:
   - **Topics:** Solo recibir eventos con ciertos topics (por ejemplo `pedido.creado`, `pago.completado`).
   - **Filtros:** Condiciones sobre el contenido (por ejemplo "solo si amount &gt; 100").
   - **Secret:** Para firmar los POST y comprobar en tu servidor que el mensaje viene de Jobcelis.
5. Guarda el webhook.

Cuando envíes un evento que coincida con ese webhook, Jobcelis hará un POST a la URL. En **Entregas** puedes ver cada intento (éxito o fallo) y **reintentar** manualmente si falló.

---

## 5. Jobs programados

Un **job** es una tarea que se ejecuta automáticamente en un horario que tú configuras (diario, semanal, mensual o expresión cron).

1. En el Dashboard entra en **Jobs**.
2. Pulsa **Crear**.
3. **Nombre:** Por ejemplo "Resumen diario".
4. **Programación:**
   - **Diario:** Hora y minuto (ej. 14:30).
   - **Semanal:** Día de la semana (1 = Lunes, 7 = Domingo) y hora.
   - **Mensual:** Día del mes (1–31) y hora.
   - **Cron:** Expresión de 5 campos (minuto hora día_mes mes día_semana). Ejemplo: `0 0 * * *` = todos los días a medianoche.
5. **Acción:**
   - **Emitir evento:** Jobcelis genera un evento (topic y payload que configuras); tus webhooks pueden recibirlo.
   - **POST a URL:** Jobcelis hace un POST a una URL que indicas (útil para llamar a tu API periódicamente).
6. Guarda el job. Se ejecutará a la hora indicada; en Jobs puedes ver el historial de ejecuciones.

Para más detalle sobre cron y ejemplos, usa la **Documentación** en la web, sección "Configurar jobs y cron".

---

## 6. Ver eventos y entregas

- **Eventos:** En el Dashboard, sección Eventos, verás la lista de eventos recientes (topic, vista previa del payload). Puedes abrir uno para ver el detalle y las entregas asociadas.
- **Entregas:** Cada intento de envío a una URL de webhook es una "entrega". Tienen estado: pendiente, éxito, fallo. Puedes filtrar por evento o webhook y **reintentar** una entrega fallida.

---

## 7. Cuenta y seguridad

- **Cuenta:** Desde el enlace "Cuenta" (o "Mi cuenta") puedes cambiar email, contraseña y ver tus datos.
- **Cerrar sesión:** Usa "Cerrar sesión" en la barra superior.
- **Token:** No compartas tu API Token. Si lo expones, regenera el token desde el Dashboard.

---

## 8. Dónde encontrar más ayuda

- **Documentación:** En la web, enlace "Documentación" — conceptos, API, primeros pasos, cron y códigos de respuesta.
- **FAQ:** Preguntas frecuentes en la sección o página "FAQ".
- **Términos y privacidad:** En el footer, "Términos" y "Privacidad"; incluyen datos de contacto del titular del servicio.

Si algo no funciona, revisa que el token esté bien en el header, que la URL del webhook sea accesible (HTTPS en producción) y que los eventos que envías cumplan los topics y filtros de tus webhooks.
