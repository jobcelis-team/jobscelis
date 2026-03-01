defmodule StreamflixWebWeb.Mailer do
  @moduledoc """
  Email delivery via Resend API (https://resend.com).
  Falls back to Logger when RESEND_API_KEY is not configured.
  Emails are rendered in a single language based on the caller's locale.
  """
  require Logger

  @resend_url "https://api.resend.com/emails"

  # ── Translations ────────────────────────────────────────────

  @translations %{
    reset_password: %{
      "es" => %{
        subject: "Restablecer contraseña — Jobcelis",
        heading: "Restablecer contraseña",
        body:
          "Recibimos una solicitud para restablecer la contraseña de tu cuenta. Haz clic en el botón para crear una nueva contraseña:",
        cta_text: "Restablecer contraseña",
        note: "Este enlace expira en 60 minutos. Si no solicitaste esto, ignora este correo.",
        footer: "Todos los derechos reservados."
      },
      "en" => %{
        subject: "Reset your password — Jobcelis",
        heading: "Reset your password",
        body:
          "We received a request to reset your account password. Click the button below to create a new password:",
        cta_text: "Reset password",
        note:
          "This link expires in 60 minutes. If you didn\u2019t request this, please ignore this email.",
        footer: "All rights reserved."
      }
    },
    email_confirmation: %{
      "es" => %{
        subject: "Verifica tu email — Jobcelis",
        heading: "Verifica tu email",
        body:
          "Gracias por registrarte en Jobcelis. Verifica tu dirección de correo haciendo clic en el botón:",
        cta_text: "Verificar email",
        note: "Este enlace expira en 7 días. Si no creaste una cuenta, ignora este correo.",
        footer: "Todos los derechos reservados."
      },
      "en" => %{
        subject: "Verify your email — Jobcelis",
        heading: "Verify your email",
        body:
          "Thanks for signing up for Jobcelis. Verify your email address by clicking the button below:",
        cta_text: "Verify email",
        note:
          "This link expires in 7 days. If you didn\u2019t create an account, please ignore this email.",
        footer: "All rights reserved."
      }
    }
  }

  # ── Public API ──────────────────────────────────────────────

  def send_reset_password_email(user, url, locale \\ "es") do
    t = get_translation(:reset_password, locale)
    html = build_email(t, url, locale)
    deliver(user.email, t.subject, html)
  end

  def send_email_confirmation(user, url, locale \\ "es") do
    t = get_translation(:email_confirmation, locale)
    html = build_email(t, url, locale)
    deliver(user.email, t.subject, html)
  end

  # ── Helpers ─────────────────────────────────────────────────

  defp get_translation(type, locale) do
    lang = if locale in ["es", "en"], do: locale, else: "es"
    @translations[type][lang]
  end

  # ── Template builder ────────────────────────────────────────

  defp build_email(t, url, locale) do
    year = Date.utc_today().year
    lang = if locale in ["es", "en"], do: locale, else: "es"

    """
    <!DOCTYPE html>
    <html lang="#{lang}">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1.0" />
      <title>Jobcelis</title>
    </head>
    <body style="margin:0;padding:0;background-color:#f1f5f9;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f1f5f9;padding:32px 16px;">
        <tr>
          <td align="center">
            <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background-color:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,0.08);">
              <!-- Header -->
              <tr>
                <td style="padding:32px 40px 24px;border-bottom:3px solid #4f46e5;">
                  <h1 style="margin:0;font-size:24px;font-weight:700;color:#1e293b;letter-spacing:-0.5px;">Jobcelis</h1>
                  <p style="margin:4px 0 0;font-size:12px;color:#94a3b8;letter-spacing:0.5px;text-transform:uppercase;">Webhooks &amp; Events Platform</p>
                </td>
              </tr>

              <!-- Content -->
              <tr>
                <td style="padding:32px 40px 8px;">
                  <h2 style="margin:0 0 16px;font-size:20px;font-weight:600;color:#1e293b;">#{t.heading}</h2>
                  <p style="margin:0 0 24px;font-size:15px;line-height:1.6;color:#475569;">#{t.body}</p>
                  <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                    <tr>
                      <td align="center" style="border-radius:8px;background-color:#4f46e5;">
                        <a href="#{url}" target="_blank" style="display:inline-block;padding:14px 36px;font-size:14px;font-weight:600;color:#ffffff;text-decoration:none;border-radius:8px;">#{t.cta_text}</a>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
              <tr>
                <td style="padding:16px 40px 32px;">
                  <p style="margin:0;font-size:13px;line-height:1.5;color:#94a3b8;">#{t.note}</p>
                </td>
              </tr>

              <!-- Footer -->
              <tr>
                <td style="padding:24px 40px 32px;background-color:#f8fafc;border-top:1px solid #e2e8f0;">
                  <p style="margin:0 0 8px;font-size:13px;font-weight:600;color:#64748b;">Jobcelis</p>
                  <p style="margin:0 0 4px;font-size:11px;color:#94a3b8;">Webhooks &amp; Events Platform</p>
                  <p style="margin:0;font-size:11px;color:#cbd5e1;">&copy; #{year} Jobcelis. #{t.footer}</p>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
    """
  end

  # ── Delivery ────────────────────────────────────────────────

  defp deliver(to, subject, html) do
    config = Application.get_env(:streamflix_web, __MODULE__, [])
    api_key = config[:api_key]
    from_email = config[:from_email] || "noreply@jobcelis.com"
    from_name = config[:from_name] || "Jobcelis"

    if api_key do
      send_via_resend(api_key, from_name, from_email, to, subject, html)
    else
      Logger.info(
        "[Mailer] No RESEND_API_KEY — logging email instead\n  To: #{to}\n  Subject: #{subject}"
      )

      :ok
    end
  end

  defp send_via_resend(api_key, from_name, from_email, to, subject, html) do
    body =
      Jason.encode!(%{
        from: "#{from_name} <#{from_email}>",
        to: [to],
        subject: subject,
        html: html
      })

    case Req.post(@resend_url,
           body: body,
           headers: [
             {"authorization", "Bearer #{api_key}"},
             {"content-type", "application/json"}
           ],
           connect_options: [timeout: 10_000],
           receive_timeout: 10_000,
           retry: false
         ) do
      {:ok, %{status: status}} when status in 200..299 ->
        Logger.info("[Mailer] Email sent to #{to} (#{subject})")
        :ok

      {:ok, %{status: status, body: resp_body}} ->
        Logger.error("[Mailer] Resend API error #{status}: #{inspect(resp_body)}")
        {:error, {:resend_error, status, resp_body}}

      {:error, reason} ->
        Logger.error("[Mailer] HTTP error: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
