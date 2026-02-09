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
      |> assign(:page_title, "Usuarios")
      |> assign(:users, [])
      |> assign(:loading, true)
      |> assign(:search, "")
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
      |> assign(:users, users)
      |> assign(:loading, false)

    {:noreply, socket}
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
    # Solo un superadmin puede asignar el rol superadmin
    role = if requested_role == "superadmin" and socket.assigns.current_user_role != "superadmin" do
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
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end

  defp load_users_from_db do
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
    <div class="min-h-screen bg-gray-100">
      <.admin_sidebar active="users" current_user_role={@current_user_role} />

      <div class="ml-64 p-8">
        <h1 class="text-3xl font-bold text-gray-900 mb-8"><%= gettext("Usuarios") %></h1>

        <!-- Search -->
        <div class="bg-white rounded-lg shadow p-4 mb-6">
          <input
            type="text"
            placeholder={gettext("Buscar usuarios...")}
            class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white"
          />
        </div>

        <!-- Users Table -->
        <div class="bg-white rounded-lg shadow overflow-hidden">
          <table class="w-full">
            <thead class="bg-gray-50 border-b">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"><%= gettext("Usuario") %></th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"><%= gettext("Rol") %></th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"><%= gettext("Registrado") %></th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"><%= gettext("Estado") %></th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase"><%= gettext("Acciones") %></th>
              </tr>
            </thead>
            <tbody class="divide-y">
              <%= for user <- @users do %>
                <tr class="hover:bg-gray-50">
                  <td class="px-6 py-4">
                    <div class="flex items-center gap-3">
                      <div class="w-10 h-10 rounded-full bg-gray-300 flex items-center justify-center">
                        <span class="font-medium text-gray-600"><%= String.first(user.name) %></span>
                      </div>
                      <div>
                        <p class="font-medium"><%= user.name %></p>
                        <p class="text-sm text-gray-500"><%= user.email %></p>
                      </div>
                    </div>
                  </td>
                  <td class="px-6 py-4">
                    <span class={"px-2 py-1 rounded text-xs #{role_class(user.role)}"}><%= user.role %></span>
                  </td>
                  <td class="px-6 py-4 text-gray-500"><%= user.registered %></td>
                  <td class="px-6 py-4">
                    <span class={"px-2 py-1 rounded text-xs #{if user.active, do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800"}"}>
                      <%= if user.active, do: gettext("Activo"), else: gettext("Inactivo") %>
                    </span>
                  </td>
                  <td class="px-6 py-4 text-right">
                    <button
                      phx-click="edit_user"
                      phx-value-id={user.id}
                      phx-disable-with={gettext("Cargando...")}
                      class="text-blue-600 hover:text-blue-800 mr-2 disabled:opacity-70"
                    >
                      <%= gettext("Editar") %>
                    </button>
                    <%= if user.active do %>
                      <button
                        phx-click="deactivate_user"
                        phx-value-id={user.id}
                        phx-disable-with={gettext("Desactivando...")}
                        class="text-red-600 hover:text-red-800 disabled:opacity-70"
                      >
                        <%= gettext("Desactivar") %>
                      </button>
                    <% else %>
                      <button
                        phx-click="activate_user"
                        phx-value-id={user.id}
                        phx-disable-with={gettext("Activando...")}
                        class="text-green-600 hover:text-green-800 disabled:opacity-70"
                      >
                        <%= gettext("Activar") %>
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <!-- User Edit Modal: backdrop and modal are siblings so clicking inside modal doesn't close -->
      <%= if @editing_user do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center p-4" id="user-modal-container">
          <div class="absolute inset-0 bg-black/50" phx-click="close_user_modal" id="user-modal-backdrop" aria-hidden="true"></div>
          <div class="relative z-10 bg-white rounded-lg shadow-xl w-full max-w-md mx-4" id="user-modal-content" role="dialog" aria-modal="true">
            <div class="p-6 border-b flex justify-between items-center">
              <h2 class="text-xl font-semibold text-gray-900"><%= gettext("Editar Usuario") %></h2>
              <button phx-click="close_user_modal" class="text-gray-400 hover:text-gray-600">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            <form phx-submit="save_user" class="p-6 space-y-4">
              <input type="hidden" name="_id" value={@editing_user.id} />
              
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1"><%= gettext("Nombre") %></label>
                <input
                  type="text"
                  name="name"
                  value={@editing_user.name}
                  class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white"
                  required
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1"><%= gettext("Email") %></label>
                <input
                  type="email"
                  name="email"
                  value={@editing_user.email}
                  class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white"
                  required
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1"><%= gettext("Rol") %></label>
                <select name="role" class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white">
                  <option value="user" selected={@editing_user.role == "user"}><%= gettext("Usuario") %></option>
                  <option value="moderator" selected={@editing_user.role == "moderator"}><%= gettext("Moderador") %></option>
                  <option value="admin" selected={@editing_user.role == "admin"}><%= gettext("Administrador") %></option>
                  <%= if @current_user_role == "superadmin" do %>
                    <option value="superadmin" selected={@editing_user.role == "superadmin"}>Superadmin</option>
                  <% end %>
                </select>
                <%= if @current_user_role != "superadmin" do %>
                  <p class="text-xs text-gray-500 mt-1"><%= gettext("Solo un superadmin puede asignar el rol Superadmin.") %></p>
                <% end %>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1"><%= gettext("Estado") %></label>
                <select name="status" class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white">
                  <option value="active" selected={@editing_user.active}><%= gettext("Activo") %></option>
                  <option value="inactive" selected={!@editing_user.active}><%= gettext("Inactivo") %></option>
                </select>
              </div>

              <div class="flex justify-end gap-4 pt-4 border-t">
                <button
                  type="button"
                  phx-click="close_user_modal"
                  class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 text-gray-700"
                >
                  <%= gettext("Cancelar") %>
                </button>
                <button
                  type="submit"
                  phx-disable-with={gettext("Guardando...")}
                  class="px-6 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg disabled:opacity-70 disabled:cursor-not-allowed"
                >
                  <%= gettext("Guardar Cambios") %>
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp admin_sidebar(assigns), do: StreamflixWebWeb.Admin.DashboardLive.admin_sidebar(assigns)

  defp role_class("superadmin"), do: "bg-amber-100 text-amber-800"
  defp role_class("admin"), do: "bg-blue-100 text-blue-800"
  defp role_class("moderator"), do: "bg-slate-100 text-slate-800"
  defp role_class(_), do: "bg-gray-100 text-gray-800"
end
