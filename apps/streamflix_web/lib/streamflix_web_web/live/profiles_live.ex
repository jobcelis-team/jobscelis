defmodule StreamflixWebWeb.ProfilesLive do
  use StreamflixWebWeb, :live_view

  alias StreamflixAccounts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    
    # Load user profiles from database
    profiles = StreamflixAccounts.list_profiles(user.id)
    
    socket =
      socket
      |> assign(:page_title, "¿Quién está viendo?")
      |> assign(:profiles, format_profiles(profiles))
      |> assign(:editing, false)
      |> assign(:editing_profile, nil)
      |> assign(:show_add_modal, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_profile", %{"id" => id}, socket) do
    # Store selected profile in assigns (session will be updated on redirect)
    socket = 
      socket
      |> assign(:selected_profile_id, id)
      |> redirect(to: "/browse")
    
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_edit", _, socket) do
    {:noreply, assign(socket, :editing, !socket.assigns.editing)}
  end

  @impl true
  def handle_event("edit_profile", %{"id" => id}, socket) do
    profile = Enum.find(socket.assigns.profiles, &(&1.id == id))
    {:noreply, assign(socket, :editing_profile, profile)}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, socket |> assign(:editing_profile, nil) |> assign(:show_add_modal, false)}
  end

  @impl true
  def handle_event("add_profile", _, socket) do
    {:noreply, socket |> assign(:show_add_modal, true) |> assign(:editing_profile, nil)}
  end

  @impl true
  def handle_event("save_profile", params, socket) do
    user = socket.assigns.current_user
    profile_id = params["_id"] || params["id"]
    
    attrs = %{
      name: params["name"],
      is_kids: params["is_kids"] == "true",
      language: params["language"] || "en",
      maturity_level: params["maturity_level"] || "all"
    }

    result = if profile_id do
      # Update existing profile
      case StreamflixAccounts.get_profile(profile_id) do
        nil -> {:error, :not_found}
        profile ->
          if profile.user_id == user.id do
            StreamflixAccounts.update_profile(profile, attrs)
          else
            {:error, :unauthorized}
          end
      end
    else
      # Create new profile
      StreamflixAccounts.create_profile(user.id, attrs)
    end

    case result do
      {:ok, _profile} ->
        # Reload profiles
        profiles = StreamflixAccounts.list_profiles(user.id)
        socket =
          socket
          |> assign(:profiles, format_profiles(profiles))
          |> assign(:editing_profile, nil)
          |> assign(:show_add_modal, false)
          |> put_flash(:info, if(profile_id, do: "Perfil actualizado", else: "Perfil creado"))
        {:noreply, socket}

      {:error, :max_profiles_reached} ->
        {:noreply, put_flash(socket, :error, "Has alcanzado el límite de perfiles para tu plan")}

      {:error, changeset} ->
        errors = format_changeset_errors(changeset)
        {:noreply, put_flash(socket, :error, "Error: #{errors}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("delete_profile", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    
    case StreamflixAccounts.get_profile(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Perfil no encontrado")}
      
      profile ->
        if profile.user_id == user.id do
          case StreamflixAccounts.delete_profile(profile) do
            {:ok, _} ->
              profiles = StreamflixAccounts.list_profiles(user.id)
              socket =
                socket
                |> assign(:profiles, format_profiles(profiles))
                |> put_flash(:info, "Perfil eliminado")
              {:noreply, socket}

            {:error, :cannot_delete_last_profile} ->
              {:noreply, put_flash(socket, :error, "No puedes eliminar el último perfil")}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Error al eliminar perfil")}
          end
        else
          {:noreply, put_flash(socket, :error, "No autorizado")}
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 flex items-center justify-center">
      <div class="text-center">
        <h1 class="text-4xl font-medium text-white mb-8">¿Quién está viendo?</h1>

        <div class="flex flex-wrap justify-center gap-6 mb-8">
          <%= for profile <- @profiles do %>
            <button
              phx-click="select_profile"
              phx-value-id={profile.id}
              class="group text-center"
            >
              <div class={"relative w-32 h-32 rounded overflow-hidden mb-2 border-2 transition #{if @editing, do: "border-white", else: "border-transparent group-hover:border-white"}"}>
                <div class={"w-full h-full #{profile.color}"}>
                  <%= if profile.avatar do %>
                    <img src={profile.avatar} alt={profile.name} class="w-full h-full object-cover" />
                  <% else %>
                    <div class="w-full h-full flex items-center justify-center">
                      <span class="text-4xl text-white font-bold"><%= String.first(profile.name) %></span>
                    </div>
                  <% end %>
                </div>
                <%= if @editing do %>
                  <div class="absolute inset-0 bg-black/60 flex items-center justify-center gap-2">
                    <button
                      phx-click="edit_profile"
                      phx-value-id={profile.id}
                      class="p-2 bg-blue-600 hover:bg-blue-700 rounded"
                      title="Editar"
                    >
                      <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                      </svg>
                    </button>
                    <button
                      phx-click="delete_profile"
                      phx-value-id={profile.id}
                      class="p-2 bg-red-600 hover:bg-red-700 rounded"
                      title="Eliminar"
                    >
                      <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                      </svg>
                    </button>
                  </div>
                <% end %>
              </div>
              <span class="text-gray-400 group-hover:text-white transition"><%= profile.name %></span>
            </button>
          <% end %>

          <!-- Add Profile -->
          <button
            phx-click="add_profile"
            class="group text-center"
          >
            <div class="w-32 h-32 rounded bg-gray-800 border-2 border-transparent group-hover:border-white flex items-center justify-center mb-2 transition">
              <svg class="w-16 h-16 text-gray-500 group-hover:text-white transition" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
            </div>
            <span class="text-gray-400 group-hover:text-white transition">Agregar perfil</span>
          </button>
        </div>

        <button
          phx-click="toggle_edit"
          class={"px-6 py-2 border rounded text-lg transition #{if @editing, do: "bg-white text-black border-white", else: "text-gray-400 border-gray-400 hover:text-white hover:border-white"}"}
        >
          <%= if @editing, do: "Listo", else: "Administrar perfiles" %>
        </button>
      </div>

      <!-- Profile Modal -->
      <%= if @editing_profile || @show_add_modal do %>
        <div class="fixed inset-0 bg-black/80 flex items-center justify-center z-50" phx-click="close_modal">
          <div class="bg-gray-900 rounded-lg p-8 max-w-md w-full mx-4" phx-click-away="close_modal">
            <h2 class="text-2xl font-bold text-white mb-6">
              <%= if @editing_profile, do: "Editar Perfil", else: "Nuevo Perfil" %>
            </h2>
            
            <form phx-submit="save_profile" class="space-y-4">
              <%= if @editing_profile do %>
                <input type="hidden" name="_id" value={@editing_profile.id} />
              <% end %>
              
              <div>
                <label class="block text-sm font-medium text-gray-300 mb-2">Nombre</label>
                <input
                  type="text"
                  name="name"
                  value={if @editing_profile, do: @editing_profile.name, else: ""}
                  required
                  class="w-full px-4 py-2 bg-gray-800 border border-gray-700 rounded text-white"
                  placeholder="Nombre del perfil"
                />
              </div>

              <div>
                <label class="flex items-center gap-2">
                  <input
                    type="checkbox"
                    name="is_kids"
                    value="true"
                    checked={if @editing_profile, do: @editing_profile.is_kids, else: false}
                    class="rounded"
                  />
                  <span class="text-sm text-gray-300">Perfil para niños</span>
                </label>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-300 mb-2">Idioma</label>
                <select
                  name="language"
                  class="w-full px-4 py-2 bg-gray-800 border border-gray-700 rounded text-white"
                >
                  <option value="en" selected={if @editing_profile, do: @editing_profile.language == "en"}>English</option>
                  <option value="es" selected={if @editing_profile, do: @editing_profile.language == "es"}>Español</option>
                  <option value="pt" selected={if @editing_profile, do: @editing_profile.language == "pt"}>Português</option>
                </select>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-300 mb-2">Nivel de madurez</label>
                <select
                  name="maturity_level"
                  class="w-full px-4 py-2 bg-gray-800 border border-gray-700 rounded text-white"
                >
                  <option value="all" selected={if @editing_profile, do: @editing_profile.maturity_level == "all"}>Todos los públicos</option>
                  <option value="pg" selected={if @editing_profile, do: @editing_profile.maturity_level == "pg"}>PG</option>
                  <option value="pg13" selected={if @editing_profile, do: @editing_profile.maturity_level == "pg13"}>PG-13</option>
                  <option value="r" selected={if @editing_profile, do: @editing_profile.maturity_level == "r"}>R</option>
                </select>
              </div>

              <div class="flex gap-4 pt-4">
                <button
                  type="submit"
                  class="flex-1 bg-red-600 hover:bg-red-700 text-white py-2 rounded font-medium"
                >
                  Guardar
                </button>
                <button
                  type="button"
                  phx-click="close_modal"
                  class="flex-1 bg-gray-700 hover:bg-gray-600 text-white py-2 rounded font-medium"
                >
                  Cancelar
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_profiles(profiles) do
    Enum.map(profiles, fn profile ->
      %{
        id: profile.id,
        name: profile.name,
        color: profile_color(profile),
        avatar: profile.avatar_url,
        is_kids: profile.is_kids,
        language: profile.language,
        maturity_level: profile.maturity_level
      }
    end)
  end

  defp profile_color(profile) do
    # Generate color based on profile name hash
    colors = ["bg-red-600", "bg-blue-600", "bg-green-600", "bg-yellow-500", "bg-purple-600", "bg-pink-600"]
    index = :erlang.phash2(profile.name || "default") |> rem(length(colors))
    Enum.at(colors, index)
  end
end
