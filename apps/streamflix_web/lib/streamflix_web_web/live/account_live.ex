defmodule StreamflixWebWeb.AccountLive do
  use StreamflixWebWeb, :live_view

  alias StreamflixAccounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    user = StreamflixAccounts.get_user!(user.id)

    socket =
      socket
      |> assign(:page_title, gettext("Cuenta"))
      |> assign(:user, user)
      |> assign(:email_form, to_form(email_form_params(), as: "email_change"))
      |> assign(:password_form, to_form(password_form_params(), as: "password_change"))
      |> assign(:email_form_errors, [])
      |> assign(:password_form_errors, [])
      |> assign(:show_email_form, false)
      |> assign(:show_password_form, false)

    {:ok, socket}
  end

  def handle_event("toggle_email_form", _, socket) do
    {:noreply,
     socket
     |> assign(:show_email_form, not socket.assigns.show_email_form)
     |> assign(:show_password_form, false)}
  end

  def handle_event("toggle_password_form", _, socket) do
    {:noreply,
     socket
     |> assign(:show_password_form, not socket.assigns.show_password_form)
     |> assign(:show_email_form, false)}
  end

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
         |> assign(:email_form_errors, [gettext("La contraseña actual es obligatoria para cambiar el correo.")])}

      true ->
        case StreamflixAccounts.update_email(user, new_email, current_password) do
          {:ok, updated_user} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Correo actualizado correctamente."))
             |> assign(:user, updated_user)
             |> assign(:email_form, to_form(email_form_params(), as: "email_change"))
             |> assign(:email_form_errors, [])
             |> assign(:show_email_form, false)}

          {:error, :wrong_password} ->
            {:noreply,
             socket
             |> assign(:email_form, to_form(email_form_params(params), as: "email_change"))
             |> assign(:email_form_errors, [gettext("La contraseña actual no es correcta.")])}

          {:error, :same_email} ->
            {:noreply,
             socket
             |> assign(:email_form, to_form(email_form_params(params), as: "email_change"))
             |> assign(:email_form_errors, [gettext("El nuevo correo no puede ser igual al actual.")])}

          {:error, :email_taken} ->
            {:noreply,
             socket
             |> assign(:email_form, to_form(email_form_params(params), as: "email_change"))
             |> assign(:email_form_errors, [gettext("Ese correo ya está en uso por otra cuenta.")])}

          {:error, %Ecto.Changeset{} = changeset} ->
            errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end) |> Enum.flat_map(fn {_, msgs} -> msgs end)
            {:noreply,
             socket
             |> assign(:email_form, to_form(email_form_params(params), as: "email_change"))
             |> assign(:email_form_errors, errors)}
        end
    end
  end

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
         |> assign(:password_form_errors, [gettext("La nueva contraseña y la confirmación no coinciden.")])}

      String.length(new_pass) < 8 ->
        {:noreply,
         socket
         |> assign(:password_form, to_form(password_form_params(params), as: "password_change"))
         |> assign(:password_form_errors, [gettext("La nueva contraseña debe tener al menos 8 caracteres.")])}

      true ->
        case StreamflixAccounts.update_password(user, current, new_pass) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Contraseña actualizada correctamente."))
             |> assign(:password_form, to_form(password_form_params(), as: "password_change"))
             |> assign(:password_form_errors, [])
             |> assign(:show_password_form, false)}

          {:error, :wrong_password} ->
            {:noreply,
             socket
             |> assign(:password_form, to_form(password_form_params(params), as: "password_change"))
             |> assign(:password_form_errors, [gettext("La contraseña actual no es correcta.")])}

          {:error, %Ecto.Changeset{} = changeset} ->
            errors =
              Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
              |> Enum.flat_map(fn {_, msgs} -> msgs end)

            {:noreply,
             socket
             |> assign(:password_form, to_form(password_form_params(params), as: "password_change"))
             |> assign(:password_form_errors, errors)}
        end
    end
  end

  def handle_event("logout", _, socket) do
    {:noreply, redirect(socket, to: "/logout", external: true)}
  end

  defp email_form_params(attrs \\ %{}) do
    attrs = attrs || %{}
    %{
      "new_email" => attrs["new_email"] || "",
      "current_password" => attrs["current_password"] || ""
    }
  end

  defp email_form_validate(params) do
    errors = []
    errors = if (params["new_email"] || "") |> String.trim() == "", do: [gettext("El nuevo correo es obligatorio.") | errors], else: errors
    errors = if (params["current_password"] || "") == "", do: [gettext("La contraseña actual es obligatoria.") | errors], else: errors

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
    errors = if (params["current_password"] || "") == "", do: [gettext("La contraseña actual es obligatoria.") | errors], else: errors
    new_pass = params["new_password"] || ""
    errors = if new_pass == "", do: [gettext("La nueva contraseña es obligatoria.") | errors], else: errors
    errors = if new_pass != "" and String.length(new_pass) < 8, do: [gettext("La nueva contraseña debe tener al menos 8 caracteres.") | errors], else: errors
    errors = if (params["new_password_confirm"] || "") != new_pass, do: [gettext("La confirmación no coincide.") | errors], else: errors

    params
    |> Map.put(:errors, Enum.reverse(errors))
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns, :input_class,
        "mt-2 block w-full rounded-lg border border-slate-300 bg-white px-4 py-3 text-base text-slate-900 placeholder-slate-400 shadow-sm transition focus:border-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500/25"
      )

    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={:account}
      current_user={@current_user}
      locale={@locale}
      main_class="w-full max-w-[1600px] mx-auto px-6 sm:px-10 lg:px-16 py-8 flex-1"
    >
      <div class="w-full">
        <h1 class="text-3xl font-semibold text-slate-900"><%= gettext("Cuenta") %></h1>

        <div class="mt-8 bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
          <%!-- Bloque principal: datos + acciones --%>
          <div class="p-8 sm:p-10">
            <dl class="space-y-6">
              <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
                <div>
                  <dt class="text-base text-slate-500"><%= gettext("Email") %></dt>
                  <dd class="mt-1 text-lg text-slate-900 font-medium">{@user.email}</dd>
                </div>
                <button
                  type="button"
                  phx-click="toggle_email_form"
                  class="text-base font-medium text-indigo-600 hover:text-indigo-700 whitespace-nowrap py-1"
                >
                  <%= if @show_email_form, do: gettext("Cancelar"), else: gettext("Cambiar correo") %>
                </button>
              </div>
              <%= if @user.role in ["admin", "superadmin"] do %>
                <div>
                  <dt class="text-base text-slate-500"><%= gettext("Rol") %></dt>
                  <dd class="mt-1">
                    <span class={[
                      "inline-flex px-3 py-1 rounded-md text-sm font-medium",
                      @user.role == "superadmin" && "bg-amber-100 text-amber-800",
                      @user.role == "admin" && "bg-slate-100 text-slate-700"
                    ]}>
                      {@user.role}
                    </span>
                  </dd>
                </div>
              <% end %>
              <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 pt-4 border-t border-slate-200">
                <span class="text-base text-slate-500"><%= gettext("Contraseña") %></span>
                <button
                  type="button"
                  phx-click="toggle_password_form"
                  class="text-base font-medium text-indigo-600 hover:text-indigo-700 whitespace-nowrap py-1"
                >
                  <%= if @show_password_form, do: gettext("Cancelar"), else: gettext("Cambiar contraseña") %>
                </button>
              </div>
            </dl>

            <%!-- Formulario cambiar email (solo si está abierto) --%>
            <div :if={@show_email_form} class="mt-8 pt-8 border-t border-slate-200">
              <.form
                for={@email_form}
                id="email-form"
                phx-change="validate_email"
                phx-submit="save_email"
                class="space-y-5"
              >
                <div>
                  <label for="email_change_new_email" class="block text-base font-medium text-slate-700">
                    <%= gettext("Nuevo correo") %>
                  </label>
                  <.input
                    field={@email_form["new_email"]}
                    type="email"
                    placeholder="nuevo@ejemplo.com"
                    class={@input_class}
                  />
                </div>
                <div>
                  <label for="email_change_current_password" class="block text-base font-medium text-slate-700">
                    <%= gettext("Contraseña actual") %>
                  </label>
                  <.input
                    field={@email_form["current_password"]}
                    type="password"
                    placeholder="••••••••"
                    class={@input_class}
                  />
                </div>
                <%= if @email_form_errors != [] do %>
                  <p class="text-sm text-red-600" role="alert"><%= Enum.join(@email_form_errors, " ") %></p>
                <% end %>
                <button
                  type="submit"
                  class="w-full sm:w-auto inline-flex justify-center items-center px-6 py-3 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white text-base font-medium transition"
                >
                  <%= gettext("Actualizar correo") %>
                </button>
              </.form>
            </div>

            <%!-- Formulario cambiar contraseña (solo si está abierto) --%>
            <div :if={@show_password_form} class="mt-8 pt-8 border-t border-slate-200">
              <.form
                for={@password_form}
                id="password-form"
                phx-change="validate_password"
                phx-submit="save_password"
                class="space-y-5"
              >
                <div>
                  <label for="password_change_current_password" class="block text-base font-medium text-slate-700">
                    <%= gettext("Contraseña actual") %>
                  </label>
                  <.input
                    field={@password_form["current_password"]}
                    type="password"
                    placeholder="••••••••"
                    class={@input_class}
                  />
                </div>
                <div>
                  <label for="password_change_new_password" class="block text-base font-medium text-slate-700">
                    <%= gettext("Nueva contraseña") %>
                  </label>
                  <.input
                    field={@password_form["new_password"]}
                    type="password"
                    placeholder="••••••••"
                    class={@input_class}
                  />
                </div>
                <div>
                  <label for="password_change_new_password_confirm" class="block text-base font-medium text-slate-700">
                    <%= gettext("Confirmar nueva contraseña") %>
                  </label>
                  <.input
                    field={@password_form["new_password_confirm"]}
                    type="password"
                    placeholder="••••••••"
                    class={@input_class}
                  />
                </div>
                <%= if @password_form_errors != [] do %>
                  <p class="text-sm text-red-600" role="alert"><%= Enum.join(@password_form_errors, " ") %></p>
                <% end %>
                <button
                  type="submit"
                  class="w-full sm:w-auto inline-flex justify-center items-center px-6 py-3 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white text-base font-medium transition"
                >
                  <%= gettext("Actualizar contraseña") %>
                </button>
              </.form>
            </div>

            <div class="mt-8 pt-6 flex flex-wrap gap-4">
              <.link
                navigate="/platform"
                class="inline-flex items-center px-5 py-3 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-700 text-base font-medium transition"
              >
                <%= gettext("Ir al dashboard") %>
              </.link>
              <a
                href="/logout"
                class="inline-flex items-center px-5 py-3 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-700 text-base font-medium transition"
              >
                <%= gettext("Cerrar sesión") %>
              </a>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
