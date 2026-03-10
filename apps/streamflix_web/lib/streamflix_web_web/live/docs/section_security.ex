defmodule StreamflixWebWeb.Docs.SectionSecurity do
  @moduledoc "Security and compliance documentation section covering account lockout, session management, MFA/TOTP, password policy, data encryption, circuit breaker, breach detection, event integrity, monitoring, backups, GDPR/RGPD, and consent versioning."

  use Phoenix.Component
  use Gettext, backend: StreamflixWebWeb.Gettext

  import StreamflixWebWeb.Docs.Components

  attr :base_url, :string, required: true

  def render(assigns) do
    ~H"""
    <.docs_section
      id="account-lockout"
      title={gettext("Bloqueo de cuenta")}
      subtitle={gettext("Protección contra ataques de fuerza bruta.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "Después de múltiples intentos de autenticación fallidos en un período corto, la cuenta se bloquea temporalmente. Proporciona protección contra ataques de fuerza bruta y credenciales comprometidas."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="session-management"
      title={gettext("Gestión de sesiones")}
      subtitle={gettext("Control de sesiones activas.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "Las sesiones web utilizan cookies cifradas con timeout de inactividad. La sesión se cierra automáticamente tras un período de inactividad."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="mfa-totp"
      title="MFA / TOTP"
      subtitle={gettext("Autenticación de dos factores.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Activar la autenticación de dos factores desde la página de cuenta. Utilizar una aplicación de autenticación compatible (Google Authenticator, Authy, etc.) para escanear el código QR. Cada inicio de sesión requiere la contraseña y el código TOTP de la aplicación."
        )}
      </p>
      <.callout kind="tip">
        {gettext(
          "Al activar MFA se generan códigos de respaldo de un solo uso. Deben almacenarse de forma segura para permitir acceso en caso de pérdida del dispositivo."
        )}
      </.callout>
    </.docs_section>

    <.docs_section
      id="password-policy"
      title={gettext("Política de contraseñas")}
      subtitle={gettext("Política de requisitos de contraseña.")}
    >
      <div class="rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-4">
        <ul class="text-slate-700 text-sm space-y-2">
          <li>{gettext("Longitud mínima requerida")}</li>
          <li>{gettext("Debe incluir mayúsculas, minúsculas y números")}</li>
          <li>{gettext("Se recomienda incluir caracteres especiales")}</li>
          <li>
            {gettext("Las contraseñas se almacenan con hashing seguro de alto consumo de memoria")}
          </li>
        </ul>
      </div>
    </.docs_section>

    <.docs_section
      id="data-encryption"
      title={gettext("Cifrado de datos")}
      subtitle={gettext("Protección de datos personales.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Los datos personales (email, nombre) se cifran en reposo con cifrado de nivel industrial. Las búsquedas por email utilizan un hash determinista, evitando la necesidad de descifrar durante las consultas."
        )}
      </p>
      <.callout kind="info">
        {gettext(
          "El cifrado en reposo protege los datos incluso en caso de acceso directo a la base de datos. Solo la aplicación puede descifrar los datos."
        )}
      </.callout>
    </.docs_section>

    <.docs_section
      id="circuit-breaker"
      title="Circuit Breaker"
      subtitle={gettext("Protección automática para webhooks inestables.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "Si un webhook falla repetidamente, el circuit breaker lo desactiva temporalmente para prevenir cascadas de fallos. Cuando el endpoint se recupera, el webhook se reactiva automáticamente."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="breach-detection"
      title={gettext("Detección de brechas")}
      subtitle={gettext("Monitoreo continuo de seguridad.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "El sistema monitorea continuamente patrones anómalos: múltiples intentos de autenticación fallidos, accesos desde ubicaciones inusuales y otros indicadores de posibles incidentes de seguridad."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="event-integrity"
      title={gettext("Integridad de eventos")}
      subtitle={gettext("Garantía de integridad e inmutabilidad de eventos.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Cada evento recibe un hash criptográfico único al momento de creación. Permite verificar que el contenido no ha sido alterado. Los eventos se almacenan de forma inmutable."
        )}
      </p>
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "Adicionalmente, cada evento soporta un idempotency_key opcional para prevención de duplicados. Si se envían múltiples eventos con el mismo idempotency_key, solo el primero se procesa."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="uptime-monitoring"
      title={gettext("Monitoreo")}
      subtitle={gettext("Supervisión automática de la plataforma.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "La plataforma se monitorea de forma continua. El estado actual está disponible en la página de estado (/status). Los componentes monitoreados incluyen la base de datos, el sistema de procesamiento y la capa de caché."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="backups"
      title={gettext("Backups")}
      subtitle={gettext("Copias de seguridad automáticas.")}
    >
      <p class="text-slate-700 leading-relaxed">
        {gettext(
          "Se realizan copias de seguridad automáticas periódicamente. Los backups se almacenan de forma segura y cifrada. En caso de incidente, los datos pueden restaurarse de forma expedita."
        )}
      </p>
    </.docs_section>

    <.docs_section
      id="data-protection"
      title={gettext("GDPR / RGPD")}
      subtitle={gettext("Derechos de protección de datos.")}
    >
      <p class="text-slate-700 leading-relaxed mb-4">
        {gettext(
          "Jobcelis cumple con el RGPD/GDPR. Los usuarios tienen los siguientes derechos de protección de datos:"
        )}
      </p>
      <ul class="text-slate-700 text-sm space-y-2 mb-4">
        <li>
          <strong>{gettext("Acceso:")}</strong> {gettext(
            "Exporta todos tus datos personales (GET /api/v1/me/data)"
          )}
        </li>
        <li>
          <strong>{gettext("Rectificación:")}</strong> {gettext("Actualiza tu perfil desde la cuenta")}
        </li>
        <li>
          <strong>{gettext("Restricción:")}</strong> {gettext(
            "Restringe el procesamiento (POST /api/v1/me/restrict)"
          )}
        </li>
        <li>
          <strong>{gettext("Objeción:")}</strong> {gettext(
            "Objeta el procesamiento (POST /api/v1/me/object)"
          )}
        </li>
        <li>
          <strong>{gettext("Portabilidad:")}</strong> {gettext(
            "Exporta datos en formato JSON estándar"
          )}
        </li>
      </ul>

      <div class="space-y-4">
        <.api_endpoint
          id="gdpr-export-data"
          method="GET"
          path="/api/v1/me/data"
          description={
            gettext(
              "Exporta todos tus datos personales almacenados en la plataforma (GDPR Artículo 15 — derecho de acceso)."
            )
          }
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/me/data\" \\\n  -H \"Authorization: Bearer YOUR_JWT_TOKEN\""}
            copy_id="copy-gdpr-export-data"
          />
          <.response_block
            code={
              ~s|{\n  "data": {\n    "profile": {\n      "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "email": "user@example.com",\n      "name": "Jane Doe",\n      "role": "user",\n      "inserted_at": "2026-01-10T08:00:00Z"\n    },\n    "consents": [...],\n    "activity": [...]\n  }\n}|
            }
            copy_id="copy-gdpr-export-data-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="gdpr-restrict-processing"
          method="POST"
          path="/api/v1/me/restrict"
          description={
            gettext(
              "Restringe el procesamiento de tus datos personales (GDPR Artículo 18). Requiere confirmación con contraseña."
            )
          }
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/me/restrict\" \\\n  -H \"Authorization: Bearer YOUR_JWT_TOKEN\" \\\n  -H \"Content-Type: application/json\" \\\n  -d '{\"password\": \"YOUR_PASSWORD\"}'"}
            copy_id="copy-gdpr-restrict"
          />
          <.response_block
            code={~s|{\n  "status": "restricted",\n  "restricted_at": "2026-03-10T12:00:00Z"\n}|}
            copy_id="copy-gdpr-restrict-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="gdpr-lift-restriction"
          method="DELETE"
          path="/api/v1/me/restrict"
          description={
            gettext("Levanta la restricción de procesamiento de datos, restaurando el estado activo.")
          }
        >
          <.code_block
            code={"curl -X DELETE \"#{@base_url}/api/v1/me/restrict\" \\\n  -H \"Authorization: Bearer YOUR_JWT_TOKEN\""}
            copy_id="copy-gdpr-lift-restriction"
          />
          <.response_block
            code={~s|{\n  "status": "active"\n}|}
            copy_id="copy-gdpr-lift-restriction-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="gdpr-object-processing"
          method="POST"
          path="/api/v1/me/object"
          description={
            gettext(
              "Registra una objeción al procesamiento de tus datos personales (GDPR Artículo 21)."
            )
          }
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/me/object\" \\\n  -H \"Authorization: Bearer YOUR_JWT_TOKEN\""}
            copy_id="copy-gdpr-object"
          />
          <.response_block
            code={~s|{\n  "processing_consent": false\n}|}
            copy_id="copy-gdpr-object-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="gdpr-withdraw-objection"
          method="DELETE"
          path="/api/v1/me/object"
          description={
            gettext(
              "Retira la objeción al procesamiento, restaurando el consentimiento de procesamiento."
            )
          }
        >
          <.code_block
            code={"curl -X DELETE \"#{@base_url}/api/v1/me/object\" \\\n  -H \"Authorization: Bearer YOUR_JWT_TOKEN\""}
            copy_id="copy-gdpr-withdraw-objection"
          />
          <.response_block
            code={~s|{\n  "processing_consent": true\n}|}
            copy_id="copy-gdpr-withdraw-objection-response"
            status="200 OK"
          />
        </.api_endpoint>
      </div>
    </.docs_section>

    <.docs_section
      id="consent-versióning"
      title={gettext("Consentimientos")}
      subtitle={gettext("Gestión versionada de consentimientos GDPR.")}
    >
      <div class="space-y-4">
        <.api_endpoint
          id="consent-status"
          method="GET"
          path="/api/v1/me/consents"
          description={
            gettext("Obtiene el estado actual de los consentimientos de procesamiento de datos.")
          }
        >
          <.code_block
            code={"curl \"#{@base_url}/api/v1/me/consents\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-consent-status"
          />
          <.response_block
            code={
              ~s|{\n  "consents": [\n    {\n      "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",\n      "purpose": "essential",\n      "version": 1,\n      "granted_at": "2026-01-15T10:00:00Z"\n    },\n    {\n      "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",\n      "purpose": "analytics",\n      "version": 2,\n      "granted_at": "2026-02-20T14:00:00Z"\n    }\n  ],\n  "outdated": ["analytics"],\n  "current_versions": {\n    "essential": 1,\n    "analytics": 3\n  }\n}|
            }
            copy_id="copy-consent-status-response"
            status="200 OK"
          />
        </.api_endpoint>
        <.api_endpoint
          id="consent-accept"
          method="POST"
          path="/api/v1/me/consents/:purpose/accept"
          description={gettext("Acepta un consentimiento específico por identificador de propósito.")}
        >
          <.code_block
            code={"curl -X POST \"#{@base_url}/api/v1/me/consents/analytics/accept\" \\\n  -H \"Authorization: Bearer YOUR_TOKEN\""}
            copy_id="copy-consent-accept"
          />
          <.response_block
            code={
              ~s|{\n  "consent": {\n    "id": "c3d4e5f6-a7b8-9012-cdef-234567890abc",\n    "purpose": "analytics",\n    "version": 3,\n    "granted_at": "2026-03-07T14:30:00Z"\n  }\n}|
            }
            copy_id="copy-consent-accept-response"
            status="200 OK"
          />
        </.api_endpoint>
      </div>
    </.docs_section>
    """
  end
end
