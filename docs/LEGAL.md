# Marca y páginas legales (tu servicio, todo legal)

**Titular:** Vladimir Celi ([GitHub](https://github.com/vladimirCeli) · [Perfil](https://vladimirceli.github.io/perfil/)). Sin empresa: el servicio es personal.

Para que la web sea **tuya** a nivel legal y de marca, el proyecto incluye:

- **Términos de uso** (`/terms`): aceptación, propiedad intelectual, uso aceptable, contacto.
- **Política de privacidad** (`/privacy`): responsable, datos, finalidad, derechos, cookies.
- **Copyright** en el footer de la web y del dashboard: «© Año TuNombre. Todos los derechos reservados.»

Los textos están en español y son una **base**. Si quieres que sean válidos al 100 % en tu país, conviene que los revise un abogado.

---

## Cómo está configurado (Vladimir Celi)

En `config/config.exs`:

```elixir
config :streamflix_web, :legal,
  product_name: "Jobscelis",
  owner: "Vladimir Celi",
  contact_url: "https://github.com/vladimirCeli",
  profile_url: "https://vladimirceli.github.io/perfil/"
```

Así el copyright y los Términos/Privacidad muestran tu nombre y enlaces a GitHub y a tu perfil para contacto.

### Opción 2: En producción con variables de entorno

Sin tocar código, en Azure (o donde despliegues) añade en **Configuration → Application settings**:

- `LEGAL_OWNER` = `Tu Nombre o Empresa S.L.`
- `LEGAL_PRODUCT_NAME` = `Jobscelis` (o el nombre que uses)

Así el copyright y las páginas legales mostrarán tu nombre en producción.

---

## Dónde se ve

- **Página de inicio**: footer con ©, enlaces a Términos y Privacidad.
- **Dashboard (platform, account, admin)**: footer con ©, Términos y Privacidad.
- **/terms** y **/privacy**: páginas completas con el nombre del producto y del titular.

Con esto dejas claro que el servicio es tuyo, es gratuito pero no libre para que otros lo copien o lo hagan pasar por propio.

---

## Cómo protegerte: dominio, nombre y evitar conflictos

**Esto no es asesoramiento jurídico.** Son pasos prácticos que suelen recomendarse; si quieres estar 100 % tranquilo en tu país, conviene que un abogado te asesore.

### 1. Dominio propio

El servicio está en **https://jobcelis.com**. Para que siga siendo **claramente tuyo** y profesional:

- **Registra un dominio** (ej. `jobcelis.com`, `jobcelis.io` o uno que combine tu nombre + servicio).
- Registradores habituales: [Cloudflare](https://www.cloudflare.com/products/registrar/), [Namecheap](https://www.namecheap.com), [Google Domains](https://domains.google), etc.
- En Azure: **App Service** → tu app → **Custom domains** → añades el dominio y sigues las instrucciones (DNS).
- En los Términos y en la documentación puedes indicar que el servicio “oficial” es `https://tudominio.com`.

Así evitas depender solo de un subdominio de Azure y refuerzas que el servicio es tuyo.

### 2. Comprobar que el nombre no choca con otros

Para reducir el riesgo de que alguien alegue que “les copias” la marca o el nombre:

- **Busca en Google** “Jobscelis” y variantes (Jobscelis API, Jobscelis webhooks, etc.). Comprueba si existe otro producto o marca con nombre muy similar.
- **Bases de datos de marcas** (según tu país): en España, [OEPM](https://www.oepm.es); en Latinoamérica, la oficina de propiedad industrial de tu país. Busca “Jobscelis” o nombres parecidos en la misma clase (software, servicios en línea).
- Si encuentras algo muy similar en tu mismo sector, valorar **cambiar el nombre** del producto o **consultar a un abogado** antes de crecer o monetizar.

### 3. Lo que ya tienes en los Términos

En la web ya está:

- **Copyright** con tu nombre (Vladimir Celi) en footer y páginas legales.
- **Propiedad intelectual**: el Servicio, marca y código son del titular; no se puede copiar ni hacer pasar por propio.
- **Sección “Originalidad y no afiliación”**: deja claro que Jobscelis es un proyecto original, que no estás afiliado a nadie con nombre o servicio parecido, y que cualquier similitud es casual. Si alguien cree que hay conflicto, puede contactarte.

Eso no evita al 100 % una reclamación, pero **demuestra buena fe** y deja claro que no intentas imitar a nadie.

### 4. Resumen práctico

| Paso | Acción |
|------|--------|
| Dominio | Registrar un dominio (ej. jobcelis.com) y usarlo en Azure como dominio personalizado. |
| Nombre | Buscar “Jobscelis” (y similares) en Google y en la oficina de marcas de tu país. |
| Términos | Ya indican que es servicio original y no afiliado; enlace a GitHub/perfil para contacto. |
| Dudas | Si el proyecto crece o quieres monetizar, consultar a un abogado (propiedad intelectual / marcas). |

Si en el futuro alguien te contacta alegando conflicto de marca, tener dominio propio, términos claros y haber hecho una búsqueda previa te ayuda a mostrar que actúas de buena fe.
