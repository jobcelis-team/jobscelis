# Configuración de Usuario Administrador

## Crear Usuario Administrador

Para crear un usuario administrador que pueda gestionar toda la aplicación, ejecuta:

```bash
mix run scripts/create_admin.exs
```

El script te pedirá:
- Email del administrador
- Nombre del administrador
- Contraseña

## Promover Usuario Existente a Admin

Si ya tienes un usuario registrado, puedes promoverlo a administrador:

1. Ejecuta `mix run scripts/create_admin.exs`
2. Ingresa el email del usuario existente
3. Cuando pregunte si quieres promoverlo, responde `s`

## Acceso al Panel de Administración

Una vez creado el usuario admin:

1. Inicia sesión en `/login` con las credenciales del admin
2. Serás redirigido automáticamente a `/admin`
3. Desde el panel admin puedes:
   - Ver dashboard con estadísticas
   - Gestionar contenido (películas, series, novelas)
   - Administrar usuarios
   - Ver analíticas
   - Configurar settings (precios, plataforma, etc.)

## Funcionalidades del Admin

### Gestión de Contenido
- Crear/editar/eliminar películas
- Crear/editar/eliminar series
- Subir videos a Azure Blob Storage
- Gestionar géneros
- Publicar contenido

### Gestión de Usuarios
- Ver todos los usuarios
- Ver suscripciones
- Gestionar perfiles

### Configuración
- Cambiar precios de planes
- Configurar nombre de plataforma
- Configurar Azure Storage
- Configurar CDN endpoint
- Modo mantenimiento

### Analíticas
- Ver estadísticas de reproducciones
- Horas vistas
- Usuarios activos
- Contenido más visto

## Notas

- Solo usuarios con `role = "admin"` pueden acceder a `/admin/*`
- El sistema verifica el rol en cada petición
- Los admins también pueden usar la aplicación normalmente como usuarios
