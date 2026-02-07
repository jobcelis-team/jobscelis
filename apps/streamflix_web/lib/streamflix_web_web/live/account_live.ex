defmodule StreamflixWebWeb.AccountLive do
  use StreamflixWebWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    socket =
      socket
      |> assign(:page_title, "Cuenta")
      |> assign(:user, user)

    {:ok, socket}
  end

  @impl true
  def handle_event("logout", _, socket) do
    {:noreply, redirect(socket, to: "/logout", external: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={:account} current_user={@current_user}>
      <div class="max-w-2xl">
        <h1 class="text-2xl font-bold text-slate-900 mb-6">Cuenta</h1>
        <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-6" aria-labelledby="account-heading">
          <h2 id="account-heading" class="sr-only">Datos de tu cuenta</h2>
          <dl class="space-y-3">
            <div>
              <dt class="text-sm font-medium text-slate-500">Email</dt>
              <dd class="text-slate-900">{@user.email}</dd>
            </div>
            <%= if @user.role in ["admin", "superadmin"] do %>
              <div>
                <dt class="text-sm font-medium text-slate-500">Rol</dt>
                <dd class="text-slate-900">{@user.role}</dd>
              </div>
            <% end %>
          </dl>
          <div class="mt-6 flex flex-wrap gap-3">
            <.link navigate="/platform" class="text-indigo-600 hover:text-indigo-700 font-medium text-sm">
              Ir al dashboard
            </.link>
            <a href="/logout" class="inline-flex items-center px-4 py-2 bg-slate-200 hover:bg-slate-300 text-slate-800 rounded-lg font-medium text-sm transition">
              Cerrar sesión
            </a>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
