defmodule StreamflixWebWeb.AccountLive do
  use StreamflixWebWeb, :live_view

  alias StreamflixAccounts

  @impl true
  def mount(_params, session, socket) do
    user = socket.assigns.current_user
    user = StreamflixAccounts.get_user!(user.id)
    current_jti = Map.get(session, "current_jti")

    socket =
      socket
      |> assign(:page_title, gettext("Cuenta"))
      |> assign(:active_page, :account)
      |> assign(:user, user)
      |> assign(:email_form, to_form(email_form_params(), as: "email_change"))
      |> assign(:password_form, to_form(password_form_params(), as: "password_change"))
      |> assign(:email_form_errors, [])
      |> assign(:password_form_errors, [])
      |> assign(:show_email_modal, false)
      |> assign(:show_password_modal, false)
      |> assign(:show_name_modal, false)
      |> assign(:show_delete_modal, false)
      |> assign(:name_form, to_form(%{"name" => user.name || ""}, as: "name_change"))
      |> assign(:name_form_errors, [])
      |> assign(:delete_form_errors, [])
      # MFA
      |> assign(:mfa_step, nil)
      |> assign(:mfa_secret, nil)
      |> assign(:mfa_uri, nil)
      |> assign(:mfa_qr_svg, nil)
      |> assign(:mfa_backup_codes, nil)
      |> assign(:mfa_setup_errors, [])
      |> assign(:mfa_disable_errors, [])
      |> assign(:show_mfa_disable_modal, false)
      # Sessions
      |> assign(:sessions, StreamflixAccounts.list_sessions(user.id))
      |> assign(:current_jti, current_jti)
      # GDPR / Consents — backfill for users created before consent system
      |> assign(:consents, ensure_consents(user.id))

    {:ok, socket}
  end

  # ── Modal open / close ──────────────────────────────────────────────

  def handle_event("open_email_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_email_modal, true)
     |> assign(:show_password_modal, false)
     |> assign(:email_form, to_form(email_form_params(), as: "email_change"))
     |> assign(:email_form_errors, [])}
  end

  def handle_event("close_email_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_email_modal, false)
     |> assign(:email_form, to_form(email_form_params(), as: "email_change"))
     |> assign(:email_form_errors, [])}
  end

  def handle_event("open_password_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_password_modal, true)
     |> assign(:show_email_modal, false)
     |> assign(:password_form, to_form(password_form_params(), as: "password_change"))
     |> assign(:password_form_errors, [])}
  end

  def handle_event("close_password_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_password_modal, false)
     |> assign(:password_form, to_form(password_form_params(), as: "password_change"))
     |> assign(:password_form_errors, [])}
  end

  # ── Email validation & save ─────────────────────────────────────────

  @impl true
  def handle_event("validate_email", %{"email_change" => params}, socket) do
    validated = email_form_params(params) |> email_form_validate()
    errors = Map.get(validated, :errors, [])
    form = to_form(Map.delete(validated, :errors), as: "email_change")

    {:noreply,
     socket
     |> assign(:email_form, form)
     |> assign(:email_form_errors, errors)}
  end

  def handle_event("save_email", %{"email_change" => params}, socket) do
    user = socket.assigns.user
    new_email = (params["new_email"] || "") |> String.trim() |> String.downcase()
    current_password = params["current_password"] || ""

    cond do
      new_email == "" ->
        {:noreply,
         socket
         |> assign(:email_form, to_form(email_form_params(params), as: "email_change"))
         |> assign(:email_form_errors, [gettext("El nuevo correo es obligatorio.")])}

      current_password == "" ->
        {:noreply,
         socket
         |> assign(:email_form, to_form(email_form_params(params), as: "email_change"))
         |> assign(:email_form_errors, [
           gettext("La contraseña actual es obligatoria para cambiar el correo.")
         ])}

      true ->
        case StreamflixAccounts.update_email(user, new_email, current_password) do
          {:ok, updated_user} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Correo actualizado correctamente."))
             |> assign(:user, updated_user)
             |> assign(:email_form, to_form(email_form_params(), as: "email_change"))
             |> assign(:email_form_errors, [])
             |> assign(:show_email_modal, false)}

          {:error, :wrong_password} ->
            {:noreply,
             socket
             |> assign(:email_form, to_form(email_form_params(params), as: "email_change"))
             |> assign(:email_form_errors, [gettext("La contraseña actual no es correcta.")])}

          {:error, :same_email} ->
            {:noreply,
             socket
             |> assign(:email_form, to_form(email_form_params(params), as: "email_change"))
             |> assign(:email_form_errors, [
               gettext("El nuevo correo no puede ser igual al actual.")
             ])}

          {:error, :email_taken} ->
            {:noreply,
             socket
             |> assign(:email_form, to_form(email_form_params(params), as: "email_change"))
             |> assign(:email_form_errors, [gettext("Ese correo ya está en uso por otra cuenta.")])}

          {:error, %Ecto.Changeset{} = changeset} ->
            errors =
              Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
              |> Enum.flat_map(fn {_, msgs} -> msgs end)

            {:noreply,
             socket
             |> assign(:email_form, to_form(email_form_params(params), as: "email_change"))
             |> assign(:email_form_errors, errors)}
        end
    end
  end

  # ── Password validation & save ──────────────────────────────────────

  def handle_event("validate_password", %{"password_change" => params}, socket) do
    validated = password_form_params(params) |> password_form_validate()
    errors = Map.get(validated, :errors, [])
    form = to_form(Map.delete(validated, :errors), as: "password_change")

    {:noreply,
     socket
     |> assign(:password_form, form)
     |> assign(:password_form_errors, errors)}
  end

  def handle_event("save_password", %{"password_change" => params}, socket) do
    user = socket.assigns.user
    current = params["current_password"] || ""
    new_pass = params["new_password"] || ""
    confirm = params["new_password_confirm"] || ""

    cond do
      current == "" ->
        {:noreply,
         socket
         |> assign(:password_form, to_form(password_form_params(params), as: "password_change"))
         |> assign(:password_form_errors, [gettext("La contraseña actual es obligatoria.")])}

      new_pass != confirm ->
        {:noreply,
         socket
         |> assign(:password_form, to_form(password_form_params(params), as: "password_change"))
         |> assign(:password_form_errors, [
           gettext("La nueva contraseña y la confirmación no coinciden.")
         ])}

      String.length(new_pass) < 8 ->
        {:noreply,
         socket
         |> assign(:password_form, to_form(password_form_params(params), as: "password_change"))
         |> assign(:password_form_errors, [
           gettext("La nueva contraseña debe tener al menos 8 caracteres.")
         ])}

      true ->
        case StreamflixAccounts.update_password(user, current, new_pass) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Contraseña actualizada correctamente."))
             |> assign(:password_form, to_form(password_form_params(), as: "password_change"))
             |> assign(:password_form_errors, [])
             |> assign(:show_password_modal, false)}

          {:error, :wrong_password} ->
            {:noreply,
             socket
             |> assign(
               :password_form,
               to_form(password_form_params(params), as: "password_change")
             )
             |> assign(:password_form_errors, [gettext("La contraseña actual no es correcta.")])}

          {:error, :password_recently_used} ->
            {:noreply,
             socket
             |> assign(
               :password_form,
               to_form(password_form_params(params), as: "password_change")
             )
             |> assign(:password_form_errors, [
               gettext("Esta contraseña fue usada recientemente. Elige una diferente.")
             ])}

          {:error, %Ecto.Changeset{} = changeset} ->
            errors =
              Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
              |> Enum.flat_map(fn {_, msgs} -> msgs end)

            {:noreply,
             socket
             |> assign(
               :password_form,
               to_form(password_form_params(params), as: "password_change")
             )
             |> assign(:password_form_errors, errors)}
        end
    end
  end

  # ── Name modal ─────────────────────────────────────────────────────

  def handle_event("open_name_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_name_modal, true)
     |> assign(
       :name_form,
       to_form(%{"name" => socket.assigns.user.name || ""}, as: "name_change")
     )
     |> assign(:name_form_errors, [])}
  end

  def handle_event("close_name_modal", _, socket) do
    {:noreply, assign(socket, :show_name_modal, false)}
  end

  def handle_event("save_name", %{"name_change" => %{"name" => name}}, socket) do
    name = String.trim(name)

    cond do
      name == "" ->
        {:noreply,
         socket
         |> assign(:name_form_errors, [gettext("El nombre es obligatorio.")])}

      String.length(name) > 255 ->
        {:noreply,
         socket
         |> assign(:name_form_errors, [gettext("El nombre es demasiado largo.")])}

      true ->
        case StreamflixAccounts.update_name(socket.assigns.user, name) do
          {:ok, updated_user} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Nombre actualizado correctamente."))
             |> assign(:user, updated_user)
             |> assign(:show_name_modal, false)
             |> assign(:name_form_errors, [])}

          {:error, _} ->
            {:noreply,
             socket
             |> assign(:name_form_errors, [gettext("No se pudo actualizar el nombre.")])}
        end
    end
  end

  # ── Delete account modal ──────────────────────────────────────────

  def handle_event("open_delete_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_delete_modal, true)
     |> assign(:delete_form_errors, [])}
  end

  def handle_event("close_delete_modal", _, socket) do
    {:noreply, assign(socket, :show_delete_modal, false)}
  end

  def handle_event("delete_account", %{"password" => password}, socket) do
    user = socket.assigns.user

    case StreamflixAccounts.delete_user(user, password) do
      {:ok, %{delete_user: _}} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Cuenta eliminada correctamente."))
         |> redirect(to: "/logout")}

      {:error, :wrong_password} ->
        {:noreply,
         socket
         |> assign(:delete_form_errors, [gettext("La contraseña no es correcta.")])}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:delete_form_errors, [gettext("No se pudo eliminar la cuenta.")])}
    end
  end

  # ── GDPR: Revoke consent ─────────────────────────────────────────

  # ── Session management ──────────────────────────────────────────

  def handle_event("revoke_session", %{"id" => session_id}, socket) do
    user = socket.assigns.user

    case StreamflixAccounts.revoke_session(session_id, user.id) do
      {:ok, _} ->
        StreamflixCore.Audit.record("user.session_revoked",
          user_id: user.id,
          resource_type: "user",
          resource_id: user.id,
          metadata: %{session_id: session_id}
        )

        {:noreply,
         socket
         |> put_flash(:info, gettext("Sesión cerrada."))
         |> assign(:sessions, StreamflixAccounts.list_sessions(user.id))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("No se pudo cerrar la sesión."))}
    end
  end

  def handle_event("revoke_all_sessions", _, socket) do
    user = socket.assigns.user
    current_jti = socket.assigns.current_jti

    case StreamflixAccounts.revoke_all_sessions(user.id, except_jti: current_jti) do
      {:ok, count} ->
        StreamflixCore.Audit.record("user.all_sessions_revoked",
          user_id: user.id,
          resource_type: "user",
          resource_id: user.id,
          metadata: %{count: count}
        )

        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext("Se cerraron %{count} sesiones.", count: count)
         )
         |> assign(:sessions, StreamflixAccounts.list_sessions(user.id))}
    end
  end

  def handle_event("revoke_consent", %{"id" => consent_id}, socket) do
    case StreamflixCore.GDPR.revoke_consent(consent_id) do
      {:ok, _consent} ->
        user = socket.assigns.user

        StreamflixCore.Audit.record("gdpr.consent_revoked",
          user_id: user.id,
          metadata: %{consent_id: consent_id}
        )

        {:noreply,
         socket
         |> put_flash(:info, gettext("Consentimiento revocado."))
         |> assign(:consents, StreamflixCore.GDPR.list_consents(user.id))}

      {:error, :already_revoked} ->
        {:noreply, put_flash(socket, :info, gettext("Este consentimiento ya fue revocado."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("No se pudo revocar el consentimiento."))}
    end
  end

  # ── Resend email verification ─────────────────────────────────────

  def handle_event("resend_verification", _, socket) do
    user = socket.assigns.user

    if user.email_verified_at do
      {:noreply, put_flash(socket, :info, gettext("Tu correo ya está verificado."))}
    else
      case StreamflixAccounts.generate_email_confirmation_token(user) do
        {:ok, token} ->
          url = StreamflixWebWeb.Endpoint.url() <> "/confirm-email/#{token}"
          locale = socket.assigns[:locale] || "es"
          StreamflixWebWeb.Mailer.send_email_confirmation(user, url, locale)
          {:noreply, put_flash(socket, :info, gettext("Enlace de verificación enviado."))}

        {:error, :rate_limited} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             gettext("Debes esperar 5 minutos entre cada solicitud de correo.")
           )}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("No se pudo enviar el enlace."))}
      end
    end
  end

  def handle_event("logout", _, socket) do
    {:noreply, redirect(socket, to: "/logout", external: true)}
  end

  # ── MFA Setup ────────────────────────────────────────────────────

  def handle_event("start_mfa_setup", _, socket) do
    user = socket.assigns.user
    {:ok, secret, uri} = StreamflixAccounts.setup_mfa(user)

    qr_svg =
      uri
      |> EQRCode.encode()
      |> EQRCode.svg(width: 200)

    {:noreply,
     socket
     |> assign(:mfa_step, :setup)
     |> assign(:mfa_secret, secret)
     |> assign(:mfa_uri, uri)
     |> assign(:mfa_qr_svg, qr_svg)
     |> assign(:mfa_setup_errors, [])
     |> assign(:mfa_backup_codes, nil)}
  end

  def handle_event("cancel_mfa_setup", _, socket) do
    {:noreply,
     socket
     |> assign(:mfa_step, nil)
     |> assign(:mfa_secret, nil)
     |> assign(:mfa_uri, nil)
     |> assign(:mfa_qr_svg, nil)
     |> assign(:mfa_setup_errors, [])
     |> assign(:mfa_backup_codes, nil)}
  end

  def handle_event("confirm_mfa_setup", %{"code" => code}, socket) do
    user = socket.assigns.user
    secret = socket.assigns.mfa_secret

    case StreamflixAccounts.enable_mfa(user, secret, String.trim(code)) do
      {:ok, updated_user, backup_codes} ->
        {:noreply,
         socket
         |> assign(:user, updated_user)
         |> assign(:mfa_step, :backup_codes)
         |> assign(:mfa_backup_codes, backup_codes)
         |> assign(:mfa_setup_errors, [])
         |> put_flash(:info, gettext("Autenticación de dos factores activada."))}

      {:error, :invalid_code} ->
        {:noreply,
         assign(socket, :mfa_setup_errors, [
           gettext(
             "Código incorrecto. Verifica tu aplicación de autenticación e inténtalo de nuevo."
           )
         ])}

      {:error, _} ->
        {:noreply, assign(socket, :mfa_setup_errors, [gettext("No se pudo activar MFA.")])}
    end
  end

  def handle_event("close_mfa_backup_codes", _, socket) do
    {:noreply,
     socket
     |> assign(:mfa_step, nil)
     |> assign(:mfa_secret, nil)
     |> assign(:mfa_uri, nil)
     |> assign(:mfa_qr_svg, nil)
     |> assign(:mfa_backup_codes, nil)
     |> assign(:mfa_setup_errors, [])}
  end

  def handle_event("show_mfa_backup_codes", _, socket) do
    {:noreply, assign(socket, :mfa_step, :view_backup_codes)}
  end

  def handle_event("regenerate_mfa_backup_codes", _, socket) do
    case StreamflixAccounts.regenerate_backup_codes(socket.assigns.user) do
      {:ok, updated_user, backup_codes} ->
        {:noreply,
         socket
         |> assign(:user, updated_user)
         |> assign(:mfa_step, :backup_codes)
         |> assign(:mfa_backup_codes, backup_codes)
         |> put_flash(:info, gettext("Códigos de recuperación regenerados."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("No se pudieron regenerar los códigos."))}
    end
  end

  def handle_event("open_mfa_disable_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_mfa_disable_modal, true)
     |> assign(:mfa_disable_errors, [])}
  end

  def handle_event("close_mfa_disable_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_mfa_disable_modal, false)
     |> assign(:mfa_disable_errors, [])}
  end

  def handle_event("disable_mfa", %{"password" => password}, socket) do
    case StreamflixAccounts.disable_mfa(socket.assigns.user, password) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:user, updated_user)
         |> assign(:show_mfa_disable_modal, false)
         |> assign(:mfa_disable_errors, [])
         |> assign(:mfa_step, nil)
         |> put_flash(:info, gettext("Autenticación de dos factores desactivada."))}

      {:error, :wrong_password} ->
        {:noreply,
         assign(socket, :mfa_disable_errors, [gettext("La contraseña no es correcta.")])}

      {:error, _} ->
        {:noreply, assign(socket, :mfa_disable_errors, [gettext("No se pudo desactivar MFA.")])}
    end
  end

  # ── GDPR helpers ──────────────────────────────────────────────────

  defp ensure_consents(user_id) do
    case StreamflixCore.GDPR.list_consents(user_id) do
      [] ->
        StreamflixCore.GDPR.register_signup_consents(user_id)
        StreamflixCore.GDPR.list_consents(user_id)

      consents ->
        consents
    end
  end

  # ── Form helpers ────────────────────────────────────────────────────

  defp email_form_params(attrs \\ %{}) do
    attrs = attrs || %{}

    %{
      "new_email" => attrs["new_email"] || "",
      "current_password" => attrs["current_password"] || ""
    }
  end

  defp email_form_validate(params) do
    errors = []

    errors =
      if (params["new_email"] || "") |> String.trim() == "",
        do: [gettext("El nuevo correo es obligatorio.") | errors],
        else: errors

    errors =
      if (params["current_password"] || "") == "",
        do: [gettext("La contraseña actual es obligatoria.") | errors],
        else: errors

    email = (params["new_email"] || "") |> String.trim()

    errors =
      if email != "" and not String.match?(email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/),
        do: [gettext("El correo no tiene un formato válido.") | errors],
        else: errors

    params
    |> Map.put(:errors, Enum.reverse(errors))
  end

  defp password_form_params(attrs \\ %{}) do
    attrs = attrs || %{}

    %{
      "current_password" => attrs["current_password"] || "",
      "new_password" => attrs["new_password"] || "",
      "new_password_confirm" => attrs["new_password_confirm"] || ""
    }
  end

  defp password_form_validate(params) do
    errors = []

    errors =
      if (params["current_password"] || "") == "",
        do: [gettext("La contraseña actual es obligatoria.") | errors],
        else: errors

    new_pass = params["new_password"] || ""

    errors =
      if new_pass == "",
        do: [gettext("La nueva contraseña es obligatoria.") | errors],
        else: errors

    errors =
      if new_pass != "" and String.length(new_pass) < 8,
        do: [gettext("La nueva contraseña debe tener al menos 8 caracteres.") | errors],
        else: errors

    errors =
      if (params["new_password_confirm"] || "") != new_pass,
        do: [gettext("La confirmación no coincide.") | errors],
        else: errors

    params
    |> Map.put(:errors, Enum.reverse(errors))
  end

  # ── Render ──────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    assigns =
      assign(
        assigns,
        :input_class,
        "mt-1.5 block w-full rounded-lg border border-slate-300 bg-white px-4 py-3 text-base text-slate-900 placeholder-slate-400 shadow-sm transition focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/25"
      )

    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={:account}
      current_user={@current_user}
      locale={@locale}
      active_page={@active_page}
      main_class="w-full max-w-[1600px] mx-auto px-6 sm:px-10 lg:px-16 py-8 flex-1"
    >
      <div class="w-full">
        <%!-- Page header --%>
        <div class="mb-8">
          <h1 class="text-3xl font-semibold text-slate-900">{gettext("Cuenta")}</h1>

          <p class="mt-2 text-base text-slate-500">
            {gettext("Gestiona tu perfil y preferencias de seguridad.")}
          </p>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <%!-- Profile card --%>
          <div class="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
            <div class="px-6 sm:px-8 py-5 border-b border-slate-100 bg-slate-50/50">
              <h2 class="text-lg font-semibold text-slate-800 flex items-center gap-2.5">
                <svg
                  class="w-5 h-5 text-indigo-500"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="1.5"
                    d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z"
                  />
                </svg>
                {gettext("Información de tu perfil.")}
              </h2>
            </div>

            <div class="p-6 sm:p-8 space-y-0 divide-y divide-slate-100">
              <%!-- Email verification banner --%>
              <%= if is_nil(@user.email_verified_at) do %>
                <div class="mb-4 flex items-start gap-2.5 px-4 py-3 rounded-lg bg-amber-50 border border-amber-200 text-amber-800 text-sm">
                  <svg
                    class="w-5 h-5 shrink-0 mt-0.5 text-amber-500"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126z"
                    />
                  </svg>
                  <div>
                    <span>{gettext("Tu correo no ha sido verificado.")}</span>
                    <button
                      type="button"
                      phx-click="resend_verification"
                      class="ml-2 text-amber-700 underline hover:text-amber-900 font-medium"
                    >
                      {gettext("Reenviar enlace")}
                    </button>
                  </div>
                </div>
              <% end %>
              <%!-- Name row --%>
              <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 pb-6">
                <div class="min-w-0">
                  <dt class="text-sm font-medium text-slate-500 uppercase tracking-wide">
                    {gettext("Nombre")}
                  </dt>
                  <dd class="mt-1 text-lg text-slate-900 font-medium truncate">
                    {@user.name || gettext("Sin nombre")}
                  </dd>
                </div>
                <button
                  type="button"
                  phx-click="open_name_modal"
                  class="flex-shrink-0 inline-flex items-center gap-2 px-4 py-2.5 rounded-lg border border-indigo-200 bg-indigo-50 text-indigo-700 text-sm font-medium hover:bg-indigo-100 hover:border-indigo-300 transition"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Zm0 0L19.5 7.125"
                    />
                  </svg>
                  {gettext("Editar nombre")}
                </button>
              </div>
              <%!-- Email row --%>
              <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 py-6">
                <div class="min-w-0">
                  <dt class="text-sm font-medium text-slate-500 uppercase tracking-wide">
                    {gettext("Email")}
                  </dt>

                  <dd class="mt-1 text-lg text-slate-900 font-medium truncate">{@user.email}</dd>
                </div>

                <button
                  type="button"
                  phx-click="open_email_modal"
                  class="flex-shrink-0 inline-flex items-center gap-2 px-4 py-2.5 rounded-lg border border-indigo-200 bg-indigo-50 text-indigo-700 text-sm font-medium hover:bg-indigo-100 hover:border-indigo-300 transition"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75"
                    />
                  </svg>
                  {gettext("Cambiar correo")}
                </button>
              </div>
              <%!-- Role row (admin/superadmin only) --%>
              <%= if @user.role in ["admin", "superadmin"] do %>
                <div class="py-6">
                  <dt class="text-sm font-medium text-slate-500 uppercase tracking-wide">
                    {gettext("Rol")}
                  </dt>

                  <dd class="mt-2">
                    <span class={[
                      "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm font-medium",
                      @user.role == "superadmin" && "bg-amber-100 text-amber-800",
                      @user.role == "admin" && "bg-slate-100 text-slate-700"
                    ]}>
                      <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z"
                        />
                      </svg>
                      {@user.role}
                    </span>
                  </dd>
                </div>
              <% end %>
              <%!-- Password row --%>
              <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 pt-6">
                <div>
                  <dt class="text-sm font-medium text-slate-500 uppercase tracking-wide">
                    {gettext("Contraseña")}
                  </dt>

                  <dd class="mt-1 text-lg text-slate-400 tracking-wider">••••••••••••</dd>
                </div>

                <button
                  type="button"
                  phx-click="open_password_modal"
                  class="flex-shrink-0 inline-flex items-center gap-2 px-4 py-2.5 rounded-lg border border-indigo-200 bg-indigo-50 text-indigo-700 text-sm font-medium hover:bg-indigo-100 hover:border-indigo-300 transition"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"
                    />
                  </svg>
                  {gettext("Cambiar contraseña")}
                </button>
              </div>
            </div>
          </div>
          <%!-- Quick actions card --%>
          <div class="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
            <div class="px-6 sm:px-8 py-5 border-b border-slate-100 bg-slate-50/50">
              <h2 class="text-lg font-semibold text-slate-800 flex items-center gap-2.5">
                <svg
                  class="w-5 h-5 text-indigo-500"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="1.5"
                    d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z"
                  />
                </svg>
                {gettext("Acciones rápidas")}
              </h2>
            </div>

            <div class="p-6 sm:p-8 space-y-3">
              <.link
                navigate="/platform"
                class="flex items-center gap-4 w-full px-5 py-4 rounded-xl bg-slate-50 hover:bg-slate-100 border border-slate-200 hover:border-slate-300 text-slate-700 transition group"
              >
                <div class="flex-shrink-0 w-10 h-10 rounded-lg bg-indigo-100 flex items-center justify-center group-hover:bg-indigo-200 transition">
                  <svg
                    class="w-5 h-5 text-indigo-600"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z"
                    />
                  </svg>
                </div>

                <div>
                  <p class="text-base font-medium text-slate-800">{gettext("Ir al dashboard")}</p>

                  <p class="text-sm text-slate-500">{gettext("Volver al panel principal")}</p>
                </div>

                <svg
                  class="w-5 h-5 text-slate-400 ml-auto"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M8.25 4.5l7.5 7.5-7.5 7.5"
                  />
                </svg>
              </.link>
              <button
                type="button"
                phx-click="open_delete_modal"
                class="flex items-center gap-4 w-full px-5 py-4 rounded-xl bg-slate-50 hover:bg-red-50 border border-slate-200 hover:border-red-200 text-slate-700 hover:text-red-700 transition group text-left"
              >
                <div class="flex-shrink-0 w-10 h-10 rounded-lg bg-slate-100 flex items-center justify-center group-hover:bg-red-100 transition">
                  <svg
                    class="w-5 h-5 text-slate-500 group-hover:text-red-600 transition"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
                    />
                  </svg>
                </div>
                <div>
                  <p class="text-base font-medium">{gettext("Eliminar cuenta")}</p>
                  <p class="text-sm text-slate-500 group-hover:text-red-500 transition">
                    {gettext("Eliminar permanentemente tu cuenta y datos")}
                  </p>
                </div>
                <svg
                  class="w-5 h-5 text-slate-400 ml-auto"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M8.25 4.5l7.5 7.5-7.5 7.5"
                  />
                </svg>
              </button>
              <a
                href="/logout"
                class="flex items-center gap-4 w-full px-5 py-4 rounded-xl bg-slate-50 hover:bg-red-50 border border-slate-200 hover:border-red-200 text-slate-700 hover:text-red-700 transition group"
              >
                <div class="flex-shrink-0 w-10 h-10 rounded-lg bg-slate-100 flex items-center justify-center group-hover:bg-red-100 transition">
                  <svg
                    class="w-5 h-5 text-slate-500 group-hover:text-red-600 transition"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m3 0l3-3m0 0l-3-3m3 3H9"
                    />
                  </svg>
                </div>

                <div>
                  <p class="text-base font-medium">{gettext("Cerrar sesión")}</p>

                  <p class="text-sm text-slate-500 group-hover:text-red-500 transition">
                    {gettext("Salir de tu cuenta")}
                  </p>
                </div>

                <svg
                  class="w-5 h-5 text-slate-400 ml-auto"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M8.25 4.5l7.5 7.5-7.5 7.5"
                  />
                </svg>
              </a>
            </div>
          </div>
        </div>

        <%!-- ══════════════════════════════════════════════════════════ --%>
        <%!-- MFA / Two-Factor Authentication                          --%>
        <%!-- ══════════════════════════════════════════════════════════ --%>
        <div class="mt-6 bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
          <div class="px-6 sm:px-8 py-5 border-b border-slate-100 bg-slate-50/50">
            <h2 class="text-lg font-semibold text-slate-800 flex items-center gap-2.5">
              <svg
                class="w-5 h-5 text-indigo-500"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="1.5"
                  d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z"
                />
              </svg>
              {gettext("Autenticación de dos factores")}
            </h2>
          </div>

          <div class="p-6 sm:p-8">
            <%= if @user.mfa_enabled do %>
              <%!-- MFA is ON --%>
              <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                <div class="flex items-center gap-3">
                  <div class="flex-shrink-0 w-10 h-10 rounded-full bg-emerald-100 flex items-center justify-center">
                    <svg
                      class="w-5 h-5 text-emerald-600"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                      />
                    </svg>
                  </div>
                  <div>
                    <p class="text-base font-medium text-slate-800">{gettext("MFA activado")}</p>
                    <p class="text-sm text-slate-500">
                      {gettext("Tu cuenta está protegida con autenticación de dos factores.")}
                    </p>
                  </div>
                </div>
                <div class="flex flex-col sm:flex-row gap-2">
                  <button
                    type="button"
                    phx-click="regenerate_mfa_backup_codes"
                    class="inline-flex items-center gap-2 px-4 py-2.5 rounded-lg border border-slate-200 bg-white text-slate-700 text-sm font-medium hover:bg-slate-50 transition"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182"
                      />
                    </svg>
                    {gettext("Regenerar códigos")}
                  </button>
                  <button
                    type="button"
                    phx-click="open_mfa_disable_modal"
                    class="inline-flex items-center gap-2 px-4 py-2.5 rounded-lg border border-red-200 bg-white text-red-700 text-sm font-medium hover:bg-red-50 transition"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"
                      />
                    </svg>
                    {gettext("Desactivar MFA")}
                  </button>
                </div>
              </div>

              <%!-- Show backup codes after regeneration --%>
              <%= if @mfa_step == :backup_codes and @mfa_backup_codes do %>
                <div class="mt-6 p-5 bg-amber-50 border border-amber-200 rounded-xl">
                  <div class="flex items-start gap-3 mb-4">
                    <svg
                      class="w-5 h-5 text-amber-600 flex-shrink-0 mt-0.5"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126z"
                      />
                    </svg>
                    <div>
                      <p class="font-medium text-amber-900">{gettext("Códigos de recuperación")}</p>
                      <p class="text-sm text-amber-700 mt-1">
                        {gettext(
                          "Guarda estos códigos en un lugar seguro. Cada código solo se puede usar una vez."
                        )}
                      </p>
                    </div>
                  </div>
                  <div class="grid grid-cols-2 gap-2">
                    <%= for code <- @mfa_backup_codes do %>
                      <code class="bg-white px-3 py-2 rounded-lg border border-amber-200 text-sm font-mono text-slate-800 text-center">
                        {code}
                      </code>
                    <% end %>
                  </div>
                  <div class="mt-4 flex justify-end">
                    <button
                      type="button"
                      phx-click="close_mfa_backup_codes"
                      class="px-4 py-2 rounded-lg bg-amber-600 hover:bg-amber-700 text-white text-sm font-medium transition"
                    >
                      {gettext("Ya guardé mis códigos")}
                    </button>
                  </div>
                </div>
              <% end %>
            <% else %>
              <%!-- MFA is OFF --%>
              <%= if @mfa_step == nil do %>
                <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                  <div class="flex items-center gap-3">
                    <div class="flex-shrink-0 w-10 h-10 rounded-full bg-slate-100 flex items-center justify-center">
                      <svg
                        class="w-5 h-5 text-slate-500"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z"
                        />
                      </svg>
                    </div>
                    <div>
                      <p class="text-base font-medium text-slate-800">{gettext("MFA desactivado")}</p>
                      <p class="text-sm text-slate-500">
                        {gettext("Agrega una capa extra de seguridad a tu cuenta.")}
                      </p>
                    </div>
                  </div>
                  <button
                    type="button"
                    phx-click="start_mfa_setup"
                    class="inline-flex items-center gap-2 px-4 py-2.5 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium transition"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z"
                      />
                    </svg>
                    {gettext("Activar MFA")}
                  </button>
                </div>
              <% end %>

              <%!-- MFA Setup flow --%>
              <%= if @mfa_step == :setup do %>
                <div class="space-y-6">
                  <div class="text-center">
                    <p class="text-sm text-slate-600 mb-4">
                      {gettext(
                        "Escanea este código QR con tu aplicación de autenticación (Google Authenticator, Authy, etc.)"
                      )}
                    </p>
                    <div class="inline-block p-4 bg-white border border-slate-200 rounded-xl shadow-sm">
                      {raw(@mfa_qr_svg)}
                    </div>
                  </div>

                  <%!-- Manual secret --%>
                  <div class="bg-slate-50 rounded-lg border border-slate-200 px-4 py-3">
                    <p class="text-xs font-medium text-slate-500 uppercase tracking-wide mb-1">
                      {gettext("Clave manual")}
                    </p>
                    <code class="text-sm font-mono text-slate-800 break-all select-all">
                      {Base.encode32(@mfa_secret, padding: false)}
                    </code>
                  </div>

                  <%!-- Verify code --%>
                  <form phx-submit="confirm_mfa_setup" class="space-y-4">
                    <div>
                      <label
                        for="mfa_setup_code"
                        class="block text-sm font-medium text-slate-700 mb-1.5"
                      >
                        {gettext("Ingresa el código de 6 dígitos para confirmar")}
                      </label>
                      <input
                        id="mfa_setup_code"
                        type="text"
                        name="code"
                        inputmode="numeric"
                        pattern="[0-9]{6}"
                        maxlength="6"
                        autocomplete="one-time-code"
                        autofocus
                        required
                        placeholder="000000"
                        class="w-full px-3.5 py-3 rounded-lg border border-slate-300 bg-white text-slate-900 placeholder-slate-400 text-center text-2xl font-mono tracking-[0.5em] focus:outline-none focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500 transition"
                      />
                    </div>

                    <%= if @mfa_setup_errors != [] do %>
                      <div
                        class="flex items-start gap-2 rounded-lg bg-red-50 border border-red-200 px-4 py-3"
                        role="alert"
                      >
                        <svg
                          class="w-5 h-5 text-red-500 flex-shrink-0 mt-0.5"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z"
                          />
                        </svg>
                        <div class="text-sm text-red-700">
                          <%= for error <- @mfa_setup_errors do %>
                            <p>{error}</p>
                          <% end %>
                        </div>
                      </div>
                    <% end %>

                    <div class="flex flex-col-reverse sm:flex-row sm:justify-end gap-3">
                      <button
                        type="button"
                        phx-click="cancel_mfa_setup"
                        class="w-full sm:w-auto px-5 py-2.5 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-slate-700 text-sm font-medium transition"
                      >
                        {gettext("Cancelar")}
                      </button>
                      <button
                        type="submit"
                        phx-disable-with={gettext("Verificando...")}
                        class="w-full sm:w-auto px-5 py-2.5 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium transition"
                      >
                        {gettext("Activar MFA")}
                      </button>
                    </div>
                  </form>
                </div>
              <% end %>

              <%!-- Show backup codes after enabling --%>
              <%= if @mfa_step == :backup_codes and @mfa_backup_codes do %>
                <div class="p-5 bg-amber-50 border border-amber-200 rounded-xl">
                  <div class="flex items-start gap-3 mb-4">
                    <svg
                      class="w-5 h-5 text-amber-600 flex-shrink-0 mt-0.5"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126z"
                      />
                    </svg>
                    <div>
                      <p class="font-medium text-amber-900">{gettext("Códigos de recuperación")}</p>
                      <p class="text-sm text-amber-700 mt-1">
                        {gettext(
                          "Guarda estos códigos en un lugar seguro. Cada código solo se puede usar una vez. No podrás verlos de nuevo."
                        )}
                      </p>
                    </div>
                  </div>
                  <div class="grid grid-cols-2 gap-2">
                    <%= for code <- @mfa_backup_codes do %>
                      <code class="bg-white px-3 py-2 rounded-lg border border-amber-200 text-sm font-mono text-slate-800 text-center">
                        {code}
                      </code>
                    <% end %>
                  </div>
                  <div class="mt-4 flex justify-end">
                    <button
                      type="button"
                      phx-click="close_mfa_backup_codes"
                      class="px-4 py-2 rounded-lg bg-amber-600 hover:bg-amber-700 text-white text-sm font-medium transition"
                    >
                      {gettext("Ya guardé mis códigos")}
                    </button>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>

      <%!-- ══════════════════════════════════════════════════════════════ --%>
      <%!-- Active Sessions                                              --%>
      <%!-- ══════════════════════════════════════════════════════════════ --%>
      <div class="mt-6 bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
        <div class="px-6 sm:px-8 py-5 border-b border-slate-100 bg-slate-50/50">
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
            <h2 class="text-lg font-semibold text-slate-800 flex items-center gap-2.5">
              <svg
                class="w-5 h-5 text-indigo-500"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="1.5"
                  d="M9 17.25v1.007a3 3 0 01-.879 2.122L7.5 21h9l-.621-.621A3 3 0 0115 18.257V17.25m6-12V15a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 15V5.25A2.25 2.25 0 015.25 3h13.5A2.25 2.25 0 0121 5.25z"
                />
              </svg>
              {gettext("Sesiones activas")}
            </h2>
            <%= if length(@sessions) > 1 do %>
              <button
                type="button"
                phx-click="revoke_all_sessions"
                data-confirm={gettext("¿Cerrar todas las demás sesiones?")}
                class="inline-flex items-center gap-2 px-3 py-2 rounded-lg border border-red-200 bg-red-50 text-red-700 text-xs sm:text-sm font-medium hover:bg-red-100 hover:border-red-300 transition"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m3 0l3-3m0 0l-3-3m3 3H9"
                  />
                </svg>
                {gettext("Cerrar todas las demás sesiones")}
              </button>
            <% end %>
          </div>
        </div>
        <div class="p-6 sm:p-8">
          <div class="overflow-x-auto">
            <table class="min-w-full text-sm">
              <thead>
                <tr class="border-b border-slate-200">
                  <th class="text-left py-2 px-3 text-xs font-medium text-slate-500 uppercase">
                    {gettext("Dispositivo")}
                  </th>
                  <th class="text-left py-2 px-3 text-xs font-medium text-slate-500 uppercase hidden sm:table-cell">
                    {gettext("IP")}
                  </th>
                  <th class="text-left py-2 px-3 text-xs font-medium text-slate-500 uppercase hidden sm:table-cell">
                    {gettext("Última actividad")}
                  </th>
                  <th class="text-left py-2 px-3 text-xs font-medium text-slate-500 uppercase">
                    {gettext("Fecha")}
                  </th>
                  <th class="text-right py-2 px-3 text-xs font-medium text-slate-500 uppercase">
                    {gettext("Acción")}
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <%= for session <- @sessions do %>
                  <tr class="hover:bg-slate-50">
                    <td class="py-2.5 px-3 text-slate-700 font-medium">
                      <div class="flex items-center gap-2">
                        <%= case session.device_info do %>
                          <% "Mobile" -> %>
                            <svg
                              class="w-4 h-4 text-slate-400 flex-shrink-0"
                              fill="none"
                              stroke="currentColor"
                              viewBox="0 0 24 24"
                            >
                              <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                stroke-width="2"
                                d="M10.5 1.5H8.25A2.25 2.25 0 006 3.75v16.5a2.25 2.25 0 002.25 2.25h7.5A2.25 2.25 0 0018 20.25V3.75a2.25 2.25 0 00-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 18.75h3"
                              />
                            </svg>
                          <% "Tablet" -> %>
                            <svg
                              class="w-4 h-4 text-slate-400 flex-shrink-0"
                              fill="none"
                              stroke="currentColor"
                              viewBox="0 0 24 24"
                            >
                              <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                stroke-width="2"
                                d="M10.5 19.5h3m-6.75 2.25h10.5a2.25 2.25 0 002.25-2.25v-15a2.25 2.25 0 00-2.25-2.25H6.75A2.25 2.25 0 004.5 4.5v15a2.25 2.25 0 002.25 2.25z"
                              />
                            </svg>
                          <% _ -> %>
                            <svg
                              class="w-4 h-4 text-slate-400 flex-shrink-0"
                              fill="none"
                              stroke="currentColor"
                              viewBox="0 0 24 24"
                            >
                              <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                stroke-width="2"
                                d="M9 17.25v1.007a3 3 0 01-.879 2.122L7.5 21h9l-.621-.621A3 3 0 0115 18.257V17.25m6-12V15a2.25 2.25 0 01-2.25 2.25H5.25A2.25 2.25 0 013 15V5.25A2.25 2.25 0 015.25 3h13.5A2.25 2.25 0 0121 5.25z"
                              />
                            </svg>
                        <% end %>
                        <span>
                          {session.device_info || "Desktop"}
                          <%= if @current_jti && session.token_jti == @current_jti do %>
                            <span class="ml-1 inline-flex items-center px-1.5 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-100 text-emerald-700">
                              {gettext("Esta sesión")}
                            </span>
                          <% end %>
                        </span>
                      </div>
                    </td>
                    <td class="py-2.5 px-3 text-slate-500 hidden sm:table-cell">
                      <span class="truncate max-w-[8rem] inline-block">
                        {session.ip_address || "—"}
                      </span>
                    </td>
                    <td class="py-2.5 px-3 text-slate-500 hidden sm:table-cell">
                      <%= if session.last_activity_at do %>
                        {Calendar.strftime(session.last_activity_at, "%d/%m/%Y %H:%M")}
                      <% else %>
                        —
                      <% end %>
                    </td>
                    <td class="py-2.5 px-3 text-slate-500">
                      {Calendar.strftime(session.inserted_at, "%d/%m/%Y %H:%M")}
                    </td>
                    <td class="py-2.5 px-3 text-right">
                      <%= if @current_jti && session.token_jti == @current_jti do %>
                        <span class="text-xs text-slate-400">—</span>
                      <% else %>
                        <button
                          type="button"
                          phx-click="revoke_session"
                          phx-value-id={session.id}
                          data-confirm={gettext("¿Cerrar esta sesión?")}
                          class="text-xs text-red-600 hover:text-red-800 font-medium"
                        >
                          {gettext("Revocar")}
                        </button>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
                <%= if @sessions == [] do %>
                  <tr>
                    <td colspan="5" class="py-4 px-3 text-center text-slate-400 text-sm">
                      {gettext("Sin sesiones activas.")}
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <%!-- ══════════════════════════════════════════════════════════════ --%>
      <%!-- Data Protection (GDPR)                                       --%>
      <%!-- ══════════════════════════════════════════════════════════════ --%>
      <div class="mt-6 bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
        <div class="px-6 sm:px-8 py-5 border-b border-slate-100 bg-slate-50/50">
          <h2 class="text-lg font-semibold text-slate-800 flex items-center gap-2.5">
            <svg class="w-5 h-5 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="1.5"
                d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z"
              />
            </svg>
            {gettext("Protección de datos")}
          </h2>
        </div>
        <div class="p-6 sm:p-8 space-y-6">
          <%!-- Export data --%>
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
            <div>
              <h3 class="text-sm font-semibold text-slate-800">{gettext("Exportar mis datos")}</h3>
              <p class="text-sm text-slate-500 mt-0.5">
                {gettext("Descarga una copia de todos tus datos personales (RGPD Art. 15).")}
              </p>
            </div>
            <a
              href="/export/my-data"
              class="flex-shrink-0 inline-flex items-center gap-2 px-4 py-2.5 rounded-lg border border-indigo-200 bg-indigo-50 text-indigo-700 text-sm font-medium hover:bg-indigo-100 hover:border-indigo-300 transition"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3"
                />
              </svg>
              {gettext("Exportar datos")}
            </a>
          </div>

          <%!-- Consents table --%>
          <div>
            <h3 class="text-sm font-semibold text-slate-800 mb-3">{gettext("Consentimientos")}</h3>
            <div class="overflow-x-auto">
              <table class="min-w-full text-sm">
                <thead>
                  <tr class="border-b border-slate-200">
                    <th class="text-left py-2 px-3 text-xs font-medium text-slate-500 uppercase">
                      {gettext("Propósito")}
                    </th>
                    <th class="text-left py-2 px-3 text-xs font-medium text-slate-500 uppercase hidden sm:table-cell">
                      {gettext("Fecha")}
                    </th>
                    <th class="text-left py-2 px-3 text-xs font-medium text-slate-500 uppercase">
                      {gettext("Estado")}
                    </th>
                    <th class="text-right py-2 px-3 text-xs font-medium text-slate-500 uppercase">
                      {gettext("Acción")}
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-100">
                  <%= for consent <- @consents do %>
                    <tr class="hover:bg-slate-50">
                      <td class="py-2.5 px-3 text-slate-700 font-medium">
                        <%= case consent.purpose do %>
                          <% "terms" -> %>
                            {gettext("Términos de uso")}
                          <% "privacy" -> %>
                            {gettext("Política de privacidad")}
                          <% "data_processing" -> %>
                            {gettext("Procesamiento de datos")}
                          <% "marketing" -> %>
                            {gettext("Marketing")}
                          <% _ -> %>
                            {consent.purpose}
                        <% end %>
                      </td>
                      <td class="py-2.5 px-3 text-slate-500 hidden sm:table-cell">
                        {Calendar.strftime(consent.granted_at, "%d/%m/%Y %H:%M")}
                      </td>
                      <td class="py-2.5 px-3">
                        <%= if is_nil(consent.revoked_at) do %>
                          <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-emerald-100 text-emerald-700">
                            {gettext("Activo")}
                          </span>
                        <% else %>
                          <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-700">
                            {gettext("Revocado")}
                          </span>
                        <% end %>
                      </td>
                      <td class="py-2.5 px-3 text-right">
                        <%= if is_nil(consent.revoked_at) do %>
                          <button
                            type="button"
                            phx-click="revoke_consent"
                            phx-value-id={consent.id}
                            data-confirm={gettext("¿Revocar este consentimiento?")}
                            class="text-xs text-red-600 hover:text-red-800 font-medium"
                          >
                            {gettext("Revocar")}
                          </button>
                        <% else %>
                          <span class="text-xs text-slate-400">—</span>
                        <% end %>
                      </td>
                    </tr>
                  <% end %>
                  <%= if @consents == [] do %>
                    <tr>
                      <td colspan="4" class="py-4 px-3 text-center text-slate-400 text-sm">
                        {gettext("Sin consentimientos registrados.")}
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <%!-- ══════════════════════════════════════════════════════════════ --%>
      <%!-- MODAL: Change email                                          --%>
      <%!-- ══════════════════════════════════════════════════════════════ --%>
      <%= if @show_email_modal do %>
        <div
          class="fixed inset-0 z-50 flex items-center justify-center p-4"
          id="email-modal-container"
          phx-mounted={
            JS.transition({"ease-out duration-200", "opacity-0", "opacity-100"},
              to: "#email-modal-container"
            )
          }
        >
          <%!-- Backdrop --%>
          <div
            class="absolute inset-0 bg-black/50 backdrop-blur-sm"
            phx-click="close_email_modal"
            id="email-modal-backdrop"
            aria-hidden="true"
          >
          </div>
          <%!-- Modal panel --%>
          <div
            class="relative z-10 bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-auto overflow-hidden"
            id="email-modal-content"
            role="dialog"
            aria-modal="true"
            aria-labelledby="email-modal-title"
          >
            <%!-- Header --%>
            <div class="px-6 pt-6 pb-4">
              <div class="flex items-start justify-between">
                <div class="flex items-center gap-3">
                  <div class="flex-shrink-0 w-10 h-10 rounded-full bg-indigo-100 flex items-center justify-center">
                    <svg
                      class="w-5 h-5 text-indigo-600"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75"
                      />
                    </svg>
                  </div>

                  <div>
                    <h2 id="email-modal-title" class="text-lg font-semibold text-slate-900">
                      {gettext("Cambiar correo")}
                    </h2>

                    <p class="text-sm text-slate-500 mt-0.5">
                      {gettext(
                        "El correo debe ser único en el sistema. Necesitas tu contraseña actual."
                      )}
                    </p>
                  </div>
                </div>

                <button
                  type="button"
                  phx-click="close_email_modal"
                  class="rounded-lg p-1.5 text-slate-400 hover:text-slate-600 hover:bg-slate-100 transition"
                  aria-label={gettext("Cerrar")}
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M6 18L18 6M6 6l12 12"
                    />
                  </svg>
                </button>
              </div>
            </div>
            <%!-- Current email indicator --%>
            <div class="mx-6 mb-4 px-4 py-3 bg-slate-50 rounded-lg border border-slate-200">
              <p class="text-xs font-medium text-slate-500 uppercase tracking-wide">
                {gettext("Email")} {gettext("actual")}
              </p>

              <p class="mt-0.5 text-sm text-slate-800 font-medium">{@user.email}</p>
            </div>
            <%!-- Form --%>
            <.form
              for={@email_form}
              id="email-modal-form"
              phx-change="validate_email"
              phx-submit="save_email"
              class="px-6 pb-6"
            >
              <div class="space-y-4">
                <div>
                  <label for="email_change_new_email" class="block text-sm font-medium text-slate-700">
                    {gettext("Nuevo correo")}
                  </label>
                  <.input
                    field={@email_form["new_email"]}
                    type="email"
                    placeholder={gettext("nuevo@ejemplo.com")}
                    class={@input_class}
                  />
                </div>

                <div>
                  <label
                    for="email_change_current_password"
                    class="block text-sm font-medium text-slate-700"
                  >
                    {gettext("Contraseña actual")}
                  </label>
                  <.input
                    field={@email_form["current_password"]}
                    type="password"
                    placeholder="••••••••"
                    class={@input_class}
                  />
                </div>
              </div>
              <%!-- Errors --%>
              <%= if @email_form_errors != [] do %>
                <div
                  class="mt-4 flex items-start gap-2 rounded-lg bg-red-50 border border-red-200 px-4 py-3"
                  role="alert"
                >
                  <svg
                    class="w-5 h-5 text-red-500 flex-shrink-0 mt-0.5"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z"
                    />
                  </svg>
                  <div class="text-sm text-red-700">
                    <%= for error <- @email_form_errors do %>
                      <p>{error}</p>
                    <% end %>
                  </div>
                </div>
              <% end %>
              <%!-- Footer buttons --%>
              <div class="mt-6 flex flex-col-reverse sm:flex-row sm:justify-end gap-3">
                <button
                  type="button"
                  phx-click="close_email_modal"
                  class="w-full sm:w-auto px-5 py-2.5 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-slate-700 text-sm font-medium transition"
                >
                  {gettext("Cancelar")}
                </button>
                <button
                  type="submit"
                  phx-disable-with={gettext("Actualizando...")}
                  class="w-full sm:w-auto px-5 py-2.5 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium transition disabled:opacity-70 disabled:cursor-not-allowed"
                >
                  {gettext("Actualizar correo")}
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>

      <%!-- ══════════════════════════════════════════════════════════════ --%>
      <%!-- MODAL: Change password                                       --%>
      <%!-- ══════════════════════════════════════════════════════════════ --%>
      <%= if @show_password_modal do %>
        <div
          class="fixed inset-0 z-50 flex items-center justify-center p-4"
          id="password-modal-container"
          phx-mounted={
            JS.transition({"ease-out duration-200", "opacity-0", "opacity-100"},
              to: "#password-modal-container"
            )
          }
        >
          <%!-- Backdrop --%>
          <div
            class="absolute inset-0 bg-black/50 backdrop-blur-sm"
            phx-click="close_password_modal"
            id="password-modal-backdrop"
            aria-hidden="true"
          >
          </div>
          <%!-- Modal panel --%>
          <div
            class="relative z-10 bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-auto overflow-hidden"
            id="password-modal-content"
            role="dialog"
            aria-modal="true"
            aria-labelledby="password-modal-title"
          >
            <%!-- Header --%>
            <div class="px-6 pt-6 pb-4">
              <div class="flex items-start justify-between">
                <div class="flex items-center gap-3">
                  <div class="flex-shrink-0 w-10 h-10 rounded-full bg-indigo-100 flex items-center justify-center">
                    <svg
                      class="w-5 h-5 text-indigo-600"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"
                      />
                    </svg>
                  </div>

                  <div>
                    <h2 id="password-modal-title" class="text-lg font-semibold text-slate-900">
                      {gettext("Cambiar contraseña")}
                    </h2>

                    <p class="text-sm text-slate-500 mt-0.5">
                      {gettext("Mínimo 8 caracteres, con mayúsculas, minúsculas y números.")}
                    </p>
                  </div>
                </div>

                <button
                  type="button"
                  phx-click="close_password_modal"
                  class="rounded-lg p-1.5 text-slate-400 hover:text-slate-600 hover:bg-slate-100 transition"
                  aria-label={gettext("Cerrar")}
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M6 18L18 6M6 6l12 12"
                    />
                  </svg>
                </button>
              </div>
            </div>
            <%!-- Form --%>
            <.form
              for={@password_form}
              id="password-modal-form"
              phx-change="validate_password"
              phx-submit="save_password"
              class="px-6 pb-6"
            >
              <div class="space-y-4">
                <div>
                  <label
                    for="password_change_current_password"
                    class="block text-sm font-medium text-slate-700"
                  >
                    {gettext("Contraseña actual")}
                  </label>
                  <.input
                    field={@password_form["current_password"]}
                    type="password"
                    placeholder="••••••••"
                    class={@input_class}
                  />
                </div>

                <div class="pt-2 border-t border-slate-100">
                  <label
                    for="password_change_new_password"
                    class="block text-sm font-medium text-slate-700"
                  >
                    {gettext("Nueva contraseña")}
                  </label>
                  <.input
                    field={@password_form["new_password"]}
                    type="password"
                    placeholder="••••••••"
                    class={@input_class}
                  />
                </div>

                <div>
                  <label
                    for="password_change_new_password_confirm"
                    class="block text-sm font-medium text-slate-700"
                  >
                    {gettext("Confirmar nueva contraseña")}
                  </label>
                  <.input
                    field={@password_form["new_password_confirm"]}
                    type="password"
                    placeholder="••••••••"
                    class={@input_class}
                  />
                </div>
              </div>
              <%!-- Errors --%>
              <%= if @password_form_errors != [] do %>
                <div
                  class="mt-4 flex items-start gap-2 rounded-lg bg-red-50 border border-red-200 px-4 py-3"
                  role="alert"
                >
                  <svg
                    class="w-5 h-5 text-red-500 flex-shrink-0 mt-0.5"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z"
                    />
                  </svg>
                  <div class="text-sm text-red-700">
                    <%= for error <- @password_form_errors do %>
                      <p>{error}</p>
                    <% end %>
                  </div>
                </div>
              <% end %>
              <%!-- Footer buttons --%>
              <div class="mt-6 flex flex-col-reverse sm:flex-row sm:justify-end gap-3">
                <button
                  type="button"
                  phx-click="close_password_modal"
                  class="w-full sm:w-auto px-5 py-2.5 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-slate-700 text-sm font-medium transition"
                >
                  {gettext("Cancelar")}
                </button>
                <button
                  type="submit"
                  phx-disable-with={gettext("Actualizando...")}
                  class="w-full sm:w-auto px-5 py-2.5 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium transition disabled:opacity-70 disabled:cursor-not-allowed"
                >
                  {gettext("Actualizar contraseña")}
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>

      <%!-- ══════════════════════════════════════════════════════════════ --%>
      <%!-- MODAL: Change name                                           --%>
      <%!-- ══════════════════════════════════════════════════════════════ --%>
      <%= if @show_name_modal do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center p-4" id="name-modal-container">
          <div
            class="absolute inset-0 bg-black/50 backdrop-blur-sm"
            phx-click="close_name_modal"
            aria-hidden="true"
          >
          </div>
          <div
            class="relative z-10 bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-auto overflow-hidden"
            role="dialog"
            aria-modal="true"
          >
            <div class="px-6 pt-6 pb-4">
              <div class="flex items-start justify-between">
                <h2 class="text-lg font-semibold text-slate-900">{gettext("Editar nombre")}</h2>
                <button
                  type="button"
                  phx-click="close_name_modal"
                  class="rounded-lg p-1.5 text-slate-400 hover:text-slate-600 hover:bg-slate-100 transition"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M6 18L18 6M6 6l12 12"
                    />
                  </svg>
                </button>
              </div>
            </div>
            <.form for={@name_form} id="name-modal-form" phx-submit="save_name" class="px-6 pb-6">
              <div>
                <label for="name_change_name" class="block text-sm font-medium text-slate-700">
                  {gettext("Nombre")}
                </label>
                <.input
                  field={@name_form["name"]}
                  type="text"
                  placeholder={gettext("Tu nombre")}
                  class={@input_class}
                />
              </div>
              <%= if @name_form_errors != [] do %>
                <div
                  class="mt-4 flex items-start gap-2 rounded-lg bg-red-50 border border-red-200 px-4 py-3"
                  role="alert"
                >
                  <div class="text-sm text-red-700">
                    <%= for error <- @name_form_errors do %>
                      <p>{error}</p>
                    <% end %>
                  </div>
                </div>
              <% end %>
              <div class="mt-6 flex flex-col-reverse sm:flex-row sm:justify-end gap-3">
                <button
                  type="button"
                  phx-click="close_name_modal"
                  class="w-full sm:w-auto px-5 py-2.5 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-slate-700 text-sm font-medium transition"
                >
                  {gettext("Cancelar")}
                </button>
                <button
                  type="submit"
                  phx-disable-with={gettext("Actualizando...")}
                  class="w-full sm:w-auto px-5 py-2.5 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium transition"
                >
                  {gettext("Guardar nombre")}
                </button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>

      <%!-- ══════════════════════════════════════════════════════════════ --%>
      <%!-- MODAL: Delete account                                        --%>
      <%!-- ══════════════════════════════════════════════════════════════ --%>
      <%= if @show_delete_modal do %>
        <div
          class="fixed inset-0 z-50 flex items-center justify-center p-4"
          id="delete-modal-container"
        >
          <div
            class="absolute inset-0 bg-black/50 backdrop-blur-sm"
            phx-click="close_delete_modal"
            aria-hidden="true"
          >
          </div>
          <div
            class="relative z-10 bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-auto overflow-hidden"
            role="dialog"
            aria-modal="true"
          >
            <div class="px-6 pt-6 pb-4">
              <div class="flex items-start gap-3">
                <div class="flex-shrink-0 w-10 h-10 rounded-full bg-red-100 flex items-center justify-center">
                  <svg
                    class="w-5 h-5 text-red-600"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126z"
                    />
                  </svg>
                </div>
                <div>
                  <h2 class="text-lg font-semibold text-red-900">
                    {gettext("Eliminar cuenta")}
                  </h2>
                  <p class="text-sm text-slate-500 mt-0.5">
                    {gettext(
                      "Esta acción es irreversible. Se eliminarán todos tus datos, proyectos y configuración."
                    )}
                  </p>
                </div>
              </div>
            </div>
            <form phx-submit="delete_account" class="px-6 pb-6">
              <div>
                <label for="delete_password" class="block text-sm font-medium text-slate-700 mb-1.5">
                  {gettext("Confirma tu contraseña para eliminar la cuenta")}
                </label>
                <input
                  id="delete_password"
                  type="password"
                  name="password"
                  required
                  placeholder="••••••••"
                  class={@input_class}
                />
              </div>
              <%= if @delete_form_errors != [] do %>
                <div
                  class="mt-4 flex items-start gap-2 rounded-lg bg-red-50 border border-red-200 px-4 py-3"
                  role="alert"
                >
                  <div class="text-sm text-red-700">
                    <%= for error <- @delete_form_errors do %>
                      <p>{error}</p>
                    <% end %>
                  </div>
                </div>
              <% end %>
              <div class="mt-6 flex flex-col-reverse sm:flex-row sm:justify-end gap-3">
                <button
                  type="button"
                  phx-click="close_delete_modal"
                  class="w-full sm:w-auto px-5 py-2.5 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-slate-700 text-sm font-medium transition"
                >
                  {gettext("Cancelar")}
                </button>
                <button
                  type="submit"
                  phx-disable-with={gettext("Eliminando...")}
                  class="w-full sm:w-auto px-5 py-2.5 rounded-lg bg-red-600 hover:bg-red-700 text-white text-sm font-medium transition"
                >
                  {gettext("Eliminar mi cuenta")}
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <%!-- ══════════════════════════════════════════════════════════════ --%>
      <%!-- MODAL: Disable MFA                                           --%>
      <%!-- ══════════════════════════════════════════════════════════════ --%>
      <%= if @show_mfa_disable_modal do %>
        <div
          class="fixed inset-0 z-50 flex items-center justify-center p-4"
          id="mfa-disable-modal-container"
        >
          <div
            class="absolute inset-0 bg-black/50 backdrop-blur-sm"
            phx-click="close_mfa_disable_modal"
            aria-hidden="true"
          >
          </div>
          <div
            class="relative z-10 bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-auto overflow-hidden"
            role="dialog"
            aria-modal="true"
          >
            <div class="px-6 pt-6 pb-4">
              <div class="flex items-start gap-3">
                <div class="flex-shrink-0 w-10 h-10 rounded-full bg-red-100 flex items-center justify-center">
                  <svg
                    class="w-5 h-5 text-red-600"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"
                    />
                  </svg>
                </div>
                <div>
                  <h2 class="text-lg font-semibold text-red-900">
                    {gettext("Desactivar MFA")}
                  </h2>
                  <p class="text-sm text-slate-500 mt-0.5">
                    {gettext("Tu cuenta quedará menos segura. Ingresa tu contraseña para confirmar.")}
                  </p>
                </div>
              </div>
            </div>
            <form phx-submit="disable_mfa" class="px-6 pb-6">
              <div>
                <label
                  for="mfa_disable_password"
                  class="block text-sm font-medium text-slate-700 mb-1.5"
                >
                  {gettext("Contraseña actual")}
                </label>
                <input
                  id="mfa_disable_password"
                  type="password"
                  name="password"
                  required
                  placeholder="••••••••"
                  class={@input_class}
                />
              </div>
              <%= if @mfa_disable_errors != [] do %>
                <div
                  class="mt-4 flex items-start gap-2 rounded-lg bg-red-50 border border-red-200 px-4 py-3"
                  role="alert"
                >
                  <div class="text-sm text-red-700">
                    <%= for error <- @mfa_disable_errors do %>
                      <p>{error}</p>
                    <% end %>
                  </div>
                </div>
              <% end %>
              <div class="mt-6 flex flex-col-reverse sm:flex-row sm:justify-end gap-3">
                <button
                  type="button"
                  phx-click="close_mfa_disable_modal"
                  class="w-full sm:w-auto px-5 py-2.5 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-slate-700 text-sm font-medium transition"
                >
                  {gettext("Cancelar")}
                </button>
                <button
                  type="submit"
                  phx-disable-with={gettext("Desactivando...")}
                  class="w-full sm:w-auto px-5 py-2.5 rounded-lg bg-red-600 hover:bg-red-700 text-white text-sm font-medium transition"
                >
                  {gettext("Desactivar MFA")}
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
