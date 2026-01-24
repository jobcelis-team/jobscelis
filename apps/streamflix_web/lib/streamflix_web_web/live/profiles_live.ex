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
                  <div class="absolute inset-0 bg-black/60 flex items-center justify-center">
                    <svg class="w-10 h-10 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                    </svg>
                  </div>
                <% end %>
              </div>
              <span class="text-gray-400 group-hover:text-white transition"><%= profile.name %></span>
            </button>
          <% end %>

          <!-- Add Profile -->
          <button class="group text-center">
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
    </div>
    """
  end

  defp format_profiles(profiles) do
    Enum.map(profiles, fn profile ->
      %{
        id: profile.id,
        name: profile.name,
        color: profile_color(profile),
        avatar: profile.avatar_url
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
