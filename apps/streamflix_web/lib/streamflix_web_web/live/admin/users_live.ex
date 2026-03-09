defmodule StreamflixWebWeb.Admin.UsersLive do
  use StreamflixWebWeb, :live_view

  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixAccounts.Schemas.User

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    socket =
      socket
      |> assign(:page_title, gettext("Usuarios"))
      |> assign(:users, [])
      |> assign(:loading, true)
      |> assign(:search, "")
      |> assign(:all_users, [])
      |> assign(:editing_user, nil)
      |> assign(:current_user_role, current_user.role)

    if connected?(socket) do
      send(self(), :load_users)
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(:load_users, socket) do
    users = load_users_from_db()

    socket =
      socket
      |> assign(:all_users, users)
      |> assign(:users, filter_users(users, socket.assigns.search))
      |> assign(:loading, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => term}, socket) do
    filtered = filter_users(socket.assigns.all_users, term)
    {:noreply, assign(socket, search: term, users: filtered)}
  end

  @impl true
  def handle_event("edit_user", %{"id" => id}, socket) do
    user = Enum.find(socket.assigns.users, &(&1.id == id))
    {:noreply, assign(socket, :editing_user, user)}
  end

  @impl true
  def handle_event("close_user_modal", _, socket) do
    {:noreply, assign(socket, :editing_user, nil)}
  end

  @impl true
  def handle_event("deactivate_user", %{"id" => id}, socket) do
    case StreamflixAccounts.deactivate_user(id) do
      {:ok, _} ->
        send(self(), :load_users)
        {:noreply, put_flash(socket, :info, gettext("Usuario desactivado correctamente"))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Error al desactivar usuario"))}
    end
  end

  @impl true
  def handle_event("activate_user", %{"id" => id}, socket) do
    case StreamflixAccounts.activate_user(id) do
      {:ok, _} ->
        send(self(), :load_users)
        {:noreply, put_flash(socket, :info, gettext("Usuario activado correctamente"))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Error al activar usuario"))}
    end
  end

  @impl true
  def handle_event("save_user", params, socket) do
    user_id = params["_id"] || params["id"]
    requested_role = params["role"] || "user"
    # Only a superadmin can assign the superadmin role
    role =
      if requested_role == "superadmin" and socket.assigns.current_user_role != "superadmin" do
        "admin"
      else
        requested_role
      end

    attrs = %{
      name: params["name"],
      email: params["email"],
      role: role,
      status: params["status"] || "active"
    }

    case StreamflixAccounts.get_user(user_id) do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("Usuario no encontrado"))}

      user ->
        case StreamflixAccounts.update_user(user, attrs) do
          {:ok, _} ->
            send(self(), :load_users)

            socket =
              socket
              |> assign(:editing_user, nil)
              |> put_flash(:info, gettext("Usuario actualizado correctamente"))

            {:noreply, socket}

          {:error, changeset} ->
            errors = format_changeset_errors(changeset)
            {:noreply, put_flash(socket, :error, gettext("Error: %{details}", details: errors))}
        end
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join("; ", fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
  end

  defp filter_users(users, ""), do: users
  defp filter_users(users, nil), do: users

  defp filter_users(users, term) do
    term = String.downcase(term)

    Enum.filter(users, fn user ->
      String.contains?(String.downcase(user.name || ""), term) or
        String.contains?(String.downcase(user.email || ""), term) or
        String.contains?(String.downcase(user.role || ""), term)
    end)
  end

  defp load_users_from_db() do
    User
    |> order_by([u], desc: u.inserted_at)
    |> limit(100)
    |> Repo.all()
    |> Enum.map(fn user ->
      %{
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        registered: format_date(user.inserted_at),
        active: user.status == "active"
      }
    end)
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d %b %Y")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_layout active="users" current_user_role={@current_user_role}>
      <h1 class="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-slate-100 mb-6 sm:mb-8">
        {gettext("Usuarios")}
      </h1>
      <%!-- Search --%>
      <form phx-change="search" class="bg-white dark:bg-slate-800 rounded-lg shadow p-4 mb-6">
        <input
          type="text"
          name="search"
          value={@search}
          placeholder={gettext("Buscar usuarios...")}
          phx-debounce="300"
          class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white dark:bg-slate-700 dark:border-slate-600 dark:text-slate-100"
        />
      </form>
      <%!-- Users Table --%>
      <div class="bg-white dark:bg-slate-800 rounded-lg shadow overflow-hidden">
        <div class="overflow-x-auto">
          <table class="min-w-full">
            <thead class="bg-gray-50 dark:bg-slate-800 border-b dark:border-slate-700">
              <tr>
                <th class="px-4 sm:px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-slate-400 uppercase">
                  {gettext("Usuario")}
                </th>

                <th class="px-4 sm:px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-slate-400 uppercase">
                  {gettext("Rol")}
                </th>

                <th class="px-4 sm:px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-slate-400 uppercase hidden sm:table-cell">
                  {gettext("Registrado")}
                </th>

                <th class="px-4 sm:px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-slate-400 uppercase">
                  {gettext("Estado")}
                </th>

                <th class="px-4 sm:px-6 py-3 text-right text-xs font-medium text-gray-500 dark:text-slate-400 uppercase">
                  {gettext("Acciones")}
                </th>
              </tr>
            </thead>

            <tbody class="divide-y dark:divide-slate-700">
              <%= for user <- @users do %>
                <tr class="hover:bg-gray-50 dark:hover:bg-slate-700">
                  <td class="px-4 sm:px-6 py-3 sm:py-4">
                    <div class="flex items-center gap-3">
                      <div class="w-8 h-8 sm:w-10 sm:h-10 rounded-full bg-gray-300 dark:bg-slate-600 flex items-center justify-center shrink-0">
                        <span class="font-medium text-gray-600 dark:text-slate-300 text-sm">
                          {String.first(user.name)}
                        </span>
                      </div>

                      <div class="min-w-0">
                        <p class="font-medium dark:text-slate-100 truncate">{user.name}</p>

                        <p class="text-sm text-gray-500 dark:text-slate-400 truncate">{user.email}</p>
                      </div>
                    </div>
                  </td>

                  <td class="px-4 sm:px-6 py-3 sm:py-4">
                    <span class={"px-2 py-1 rounded text-xs #{role_class(user.role)}"}>
                      {user.role}
                    </span>
                  </td>

                  <td class="px-4 sm:px-6 py-3 sm:py-4 text-gray-500 dark:text-slate-400 hidden sm:table-cell">
                    {user.registered}
                  </td>

                  <td class="px-4 sm:px-6 py-3 sm:py-4">
                    <span class={"px-2 py-1 rounded text-xs #{if user.active, do: "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300", else: "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300"}"}>
                      {if user.active, do: gettext("Activo"), else: gettext("Inactivo")}
                    </span>
                  </td>

                  <td class="px-4 sm:px-6 py-3 sm:py-4 text-right">
                    <div class="flex flex-col sm:flex-row sm:justify-end gap-1">
                      <button
                        phx-click="edit_user"
                        phx-value-id={user.id}
                        phx-disable-with={gettext("Cargando...")}
                        class="text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300 text-sm disabled:opacity-70"
                      >
                        {gettext("Editar")}
                      </button>
                      <%= if user.active do %>
                        <button
                          phx-click="deactivate_user"
                          phx-value-id={user.id}
                          phx-disable-with={gettext("Desactivando...")}
                          class="text-red-600 hover:text-red-800 dark:text-red-400 dark:hover:text-red-300 text-sm disabled:opacity-70"
                        >
                          {gettext("Desactivar")}
                        </button>
                      <% else %>
                        <button
                          phx-click="activate_user"
                          phx-value-id={user.id}
                          phx-disable-with={gettext("Activando...")}
                          class="text-green-600 hover:text-green-800 dark:text-green-400 dark:hover:text-green-300 text-sm disabled:opacity-70"
                        >
                          {gettext("Activar")}
                        </button>
                      <% end %>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
      <%!-- User Edit Modal --%>
      <%= if @editing_user do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center p-4" id="user-modal-container">
          <div
            class="absolute inset-0 bg-black/50"
            phx-click="close_user_modal"
            id="user-modal-backdrop"
            aria-hidden="true"
          >
          </div>

          <div
            class="relative z-10 bg-white dark:bg-slate-800 rounded-lg shadow-xl w-full max-w-md"
            id="user-modal-content"
            role="dialog"
            aria-modal="true"
          >
            <div class="p-4 sm:p-6 border-b dark:border-slate-700 flex justify-between items-center">
              <h2 class="text-lg sm:text-xl font-semibold text-gray-900 dark:text-slate-100">
                {gettext("Editar Usuario")}
              </h2>

              <button
                phx-click="close_user_modal"
                class="text-gray-400 hover:text-gray-600 dark:text-slate-400 dark:hover:text-slate-300"
              >
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M6 18L18 6M6 6l12 12"
                  />
                </svg>
              </button>
            </div>

            <form phx-submit="save_user" class="p-4 sm:p-6 space-y-4">
              <input type="hidden" name="_id" value={@editing_user.id} />
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-slate-300 mb-1">
                  {gettext("Nombre")}
                </label>
                <input
                  type="text"
                  name="name"
                  value={@editing_user.name}
                  class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white dark:bg-slate-700 dark:border-slate-600 dark:text-slate-100"
                  required
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-slate-300 mb-1">
                  {gettext("Email")}
                </label>
                <input
                  type="email"
                  name="email"
                  value={@editing_user.email}
                  class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white dark:bg-slate-700 dark:border-slate-600 dark:text-slate-100"
                  required
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-slate-300 mb-1">
                  {gettext("Rol")}
                </label>
                <select
                  name="role"
                  class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white dark:bg-slate-700 dark:border-slate-600 dark:text-slate-100"
                >
                  <option value="user" selected={@editing_user.role == "user"}>
                    {gettext("Usuario")}
                  </option>

                  <option value="moderator" selected={@editing_user.role == "moderator"}>
                    {gettext("Moderador")}
                  </option>

                  <option value="admin" selected={@editing_user.role == "admin"}>
                    {gettext("Administrador")}
                  </option>

                  <%= if @current_user_role == "superadmin" do %>
                    <option value="superadmin" selected={@editing_user.role == "superadmin"}>
                      {gettext("Superadmin")}
                    </option>
                  <% end %>
                </select>
                <%= if @current_user_role != "superadmin" do %>
                  <p class="text-xs text-gray-500 dark:text-slate-400 mt-1">
                    {gettext("Solo un superadmin puede asignar el rol Superadmin.")}
                  </p>
                <% end %>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-slate-300 mb-1">
                  {gettext("Estado")}
                </label>
                <select
                  name="status"
                  class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white dark:bg-slate-700 dark:border-slate-600 dark:text-slate-100"
                >
                  <option value="active" selected={@editing_user.active}>{gettext("Activo")}</option>

                  <option value="inactive" selected={!@editing_user.active}>
                    {gettext("Inactivo")}
                  </option>
                </select>
              </div>

              <div class="flex flex-col-reverse sm:flex-row sm:justify-end gap-3 pt-4 border-t dark:border-slate-700">
                <button
                  type="button"
                  phx-click="close_user_modal"
                  class="w-full sm:w-auto px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 text-gray-700 dark:border-slate-600 dark:text-slate-300 dark:hover:bg-slate-700"
                >
                  {gettext("Cancelar")}
                </button>
                <button
                  type="submit"
                  phx-disable-with={gettext("Guardando...")}
                  class="w-full sm:w-auto px-6 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg disabled:opacity-70 disabled:cursor-not-allowed"
                >
                  {gettext("Guardar Cambios")}
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </.admin_layout>
    """
  end

  defp admin_layout(assigns), do: StreamflixWebWeb.Admin.DashboardLive.admin_layout(assigns)

  defp role_class("superadmin"),
    do: "bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-300"

  defp role_class("admin"), do: "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300"

  defp role_class("moderator"),
    do: "bg-slate-100 text-slate-800 dark:bg-slate-700 dark:text-slate-300"

  defp role_class(_), do: "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300"
end
