defmodule StreamflixWebWeb.Admin.ContentLive do
  use StreamflixWebWeb, :live_view

  alias StreamflixCatalog

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Administrar Contenido")
      |> assign(:content_list, [])
      |> assign(:loading, true)
      |> assign(:filter_type, nil)
      |> assign(:filter_status, nil)
      |> assign(:search, "")
      |> assign(:show_modal, false)
      |> assign(:editing_content, nil)

    if connected?(socket) do
      send(self(), :load_content)
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(:load_content, socket) do
    content_list = StreamflixCatalog.list_content()

    socket =
      socket
      |> assign(:content_list, content_list)
      |> assign(:loading, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", %{"type" => type, "status" => status}, socket) do
    socket =
      socket
      |> assign(:filter_type, if(type == "", do: nil, else: type))
      |> assign(:filter_status, if(status == "", do: nil, else: status))

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, :search, search)}
  end

  @impl true
  def handle_event("new_content", _, socket) do
    {:noreply, assign(socket, show_modal: true, editing_content: nil)}
  end

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    content = Enum.find(socket.assigns.content_list, &(&1.id == id))
    {:noreply, assign(socket, show_modal: true, editing_content: content)}
  end

  @impl true
  def handle_event("close_modal", _, socket) do
    {:noreply, assign(socket, show_modal: false, editing_content: nil)}
  end

  @impl true
  def handle_event("noop", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case StreamflixCatalog.get_content(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Contenido no encontrado")}

      content ->
        case StreamflixCatalog.delete_content(content) do
          {:ok, _} ->
            content_list = Enum.reject(socket.assigns.content_list, &(&1.id == id))
            socket =
              socket
              |> assign(:content_list, content_list)
              |> put_flash(:info, "Contenido eliminado correctamente")
            {:noreply, socket}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Error al eliminar contenido")}
        end
    end
  end

  @impl true
  def handle_event("save_content", params, socket) do
    attrs = %{
      title: params["title"],
      type: params["type"],
      description: params["description"],
      release_year: parse_int(params["release_year"]),
      duration_minutes: parse_int(params["duration"]),
      rating: params["maturity_rating"],
      poster_url: params["poster_url"],
      backdrop_url: params["backdrop_url"],
      status: "draft"
    }

    result = if socket.assigns.editing_content do
      StreamflixCatalog.update_content(socket.assigns.editing_content, attrs)
    else
      StreamflixCatalog.create_content(attrs)
    end

    case result do
      {:ok, _content} ->
        # Reload content list
        content_list = StreamflixCatalog.list_content()
        socket =
          socket
          |> assign(:content_list, content_list)
          |> assign(:show_modal, false)
          |> assign(:editing_content, nil)
          |> put_flash(:info, if(socket.assigns.editing_content, do: "Contenido actualizado", else: "Contenido creado"))
        {:noreply, socket}

      {:error, changeset} ->
        errors = format_changeset_errors(changeset)
        {:noreply, put_flash(socket, :error, "Error: #{errors}")}
    end
  end

  @impl true
  def handle_event("publish", %{"id" => id}, socket) do
    case StreamflixCatalog.publish_content(id) do
      {:ok, _} ->
        content_list = StreamflixCatalog.list_content()
        socket =
          socket
          |> assign(:content_list, content_list)
          |> put_flash(:info, "Contenido publicado")
        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Error al publicar")}
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(val) when is_binary(val), do: String.to_integer(val)
  defp parse_int(val) when is_integer(val), do: val

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
    <div class="min-h-screen bg-gray-100">
      <.admin_sidebar active="content" />

      <div class="ml-64 p-8">
        <div class="flex justify-between items-center mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Contenido</h1>
          <button
            phx-click="new_content"
            class="bg-red-600 hover:bg-red-700 text-white px-6 py-2 rounded-lg font-medium flex items-center gap-2"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
            </svg>
            Nuevo Contenido
          </button>
        </div>

        <!-- Filters -->
        <div class="bg-white rounded-lg shadow p-4 mb-6">
          <form phx-change="filter" class="flex flex-wrap gap-4 items-center">
            <div class="flex-1 min-w-[200px]">
              <input
                type="text"
                name="search"
                value={@search}
                placeholder="Buscar contenido..."
                phx-debounce="300"
                phx-change="search"
                class="w-full border border-gray-300 rounded-lg px-4 py-2 focus:outline-none focus:border-red-500"
              />
            </div>
            <select name="type" class="border border-gray-300 rounded-lg px-4 py-2">
              <option value="">Todos los tipos</option>
              <option value="movie" selected={@filter_type == "movie"}>Películas</option>
              <option value="series" selected={@filter_type == "series"}>Series</option>
            </select>
            <select name="status" class="border border-gray-300 rounded-lg px-4 py-2">
              <option value="">Todos los estados</option>
              <option value="published" selected={@filter_status == "published"}>Publicado</option>
              <option value="draft" selected={@filter_status == "draft"}>Borrador</option>
              <option value="processing" selected={@filter_status == "processing"}>Procesando</option>
            </select>
          </form>
        </div>

        <!-- Content Table -->
        <div class="bg-white rounded-lg shadow overflow-hidden">
          <%= if @loading do %>
            <div class="flex justify-center py-12">
              <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-red-600"></div>
            </div>
          <% else %>
            <table class="w-full">
              <thead class="bg-gray-50 border-b">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Contenido</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Tipo</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Año</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Estado</th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Vistas</th>
                  <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Acciones</th>
                </tr>
              </thead>
              <tbody class="divide-y">
                <%= for content <- filtered_content(@content_list, @filter_type, @filter_status, @search) do %>
                  <tr class="hover:bg-gray-50">
                    <td class="px-6 py-4">
                      <div class="flex items-center gap-3">
                        <div class="w-16 h-10 rounded bg-gray-200 overflow-hidden flex-shrink-0">
                          <img src={content.poster_url || "/images/default-poster.svg"} alt="" class="w-full h-full object-cover" />
                        </div>
                        <div>
                          <p class="font-medium text-gray-900"><%= content.title %></p>
                          <p class="text-sm text-gray-500"><%= content.slug %></p>
                        </div>
                      </div>
                    </td>
                    <td class="px-6 py-4">
                      <span class={"px-2 py-1 rounded text-xs #{if content.type == :movie, do: "bg-blue-100 text-blue-800", else: "bg-purple-100 text-purple-800"}"}>
                        <%= if content.type == :movie, do: "Película", else: "Serie" %>
                      </span>
                    </td>
                    <td class="px-6 py-4 text-gray-500"><%= content.release_year %></td>
                    <td class="px-6 py-4">
                      <span class={"px-2 py-1 rounded text-xs #{status_class(content.status)}"}>
                        <%= status_label(content.status) %>
                      </span>
                    </td>
                    <td class="px-6 py-4 text-gray-500"><%= content.view_count || 0 %></td>
                    <td class="px-6 py-4 text-right">
                      <div class="flex justify-end gap-2">
                        <button
                          phx-click="edit"
                          phx-value-id={content.id}
                          class="text-blue-600 hover:text-blue-800"
                        >
                          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                          </svg>
                        </button>
                        <button
                          phx-click="delete"
                          phx-value-id={content.id}
                          data-confirm="¿Estás seguro de eliminar este contenido?"
                          class="text-red-600 hover:text-red-800"
                        >
                          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                          </svg>
                        </button>
                      </div>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          <% end %>
        </div>
      </div>

      <!-- Modal -->
      <%= if @show_modal do %>
        <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50" phx-click="close_modal">
          <div class="bg-white rounded-lg shadow-xl w-full max-w-2xl max-h-[90vh] overflow-y-auto" phx-click="noop">
            <div class="p-6 border-b flex justify-between items-center">
              <h2 class="text-xl font-semibold">
                <%= if @editing_content, do: "Editar Contenido", else: "Nuevo Contenido" %>
              </h2>
              <button phx-click="close_modal" class="text-gray-400 hover:text-gray-600">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            <form phx-submit="save_content" class="p-6 space-y-4">
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Título</label>
                  <input type="text" name="title" value={@editing_content && @editing_content.title} class="w-full border border-gray-300 rounded-lg px-4 py-2" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Tipo</label>
                  <select name="type" class="w-full border border-gray-300 rounded-lg px-4 py-2">
                    <option value="movie">Película</option>
                    <option value="series">Serie</option>
                  </select>
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Descripción</label>
                <textarea name="description" rows="3" class="w-full border border-gray-300 rounded-lg px-4 py-2"><%= @editing_content && @editing_content.description %></textarea>
              </div>
              <div class="grid grid-cols-3 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Año</label>
                  <input type="number" name="release_year" value={@editing_content && @editing_content.release_year} class="w-full border border-gray-300 rounded-lg px-4 py-2" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Duración (min)</label>
                  <input type="number" name="duration" value={@editing_content && @editing_content.duration_minutes} class="w-full border border-gray-300 rounded-lg px-4 py-2" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Clasificación</label>
                  <select name="maturity_rating" class="w-full border border-gray-300 rounded-lg px-4 py-2">
                    <option value="G">G</option>
                    <option value="PG">PG</option>
                    <option value="PG-13">PG-13</option>
                    <option value="R">R</option>
                    <option value="TV-MA">TV-MA</option>
                  </select>
                </div>
              </div>
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">URL Poster</label>
                  <input type="url" name="poster_url" value={@editing_content && @editing_content.poster_url} class="w-full border border-gray-300 rounded-lg px-4 py-2" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">URL Backdrop</label>
                  <input type="url" name="backdrop_url" value={@editing_content && @editing_content.backdrop_url} class="w-full border border-gray-300 rounded-lg px-4 py-2" />
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Video (Azure Blob)</label>
                <div class="flex gap-2">
                  <input type="url" name="video_url" value={@editing_content && @editing_content.video_url} class="flex-1 border border-gray-300 rounded-lg px-4 py-2" placeholder="https://streamflix.blob.core.windows.net/videos/..." />
                  <button type="button" class="bg-gray-200 hover:bg-gray-300 px-4 py-2 rounded-lg">Subir</button>
                </div>
              </div>
              <div class="flex justify-end gap-4 pt-4 border-t">
                <button type="button" phx-click="close_modal" class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">Cancelar</button>
                <button type="submit" class="px-6 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg">
                  <%= if @editing_content, do: "Guardar Cambios", else: "Crear Contenido" %>
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Reuse sidebar from dashboard
  defp admin_sidebar(assigns), do: StreamflixWebWeb.Admin.DashboardLive.admin_sidebar(assigns)

  defp filtered_content(content, type, status, search) do
    content
    |> Enum.filter(fn c ->
      type_match = is_nil(type) || to_string(c.type) == type
      status_match = is_nil(status) || to_string(c.status) == status
      search_match = search == "" || String.contains?(String.downcase(c.title), String.downcase(search))
      type_match && status_match && search_match
    end)
  end

  defp status_class(:published), do: "bg-green-100 text-green-800"
  defp status_class(:draft), do: "bg-yellow-100 text-yellow-800"
  defp status_class(:processing), do: "bg-blue-100 text-blue-800"
  defp status_class(_), do: "bg-gray-100 text-gray-800"

  defp status_label(:published), do: "Publicado"
  defp status_label(:draft), do: "Borrador"
  defp status_label(:processing), do: "Procesando"
  defp status_label(_), do: "Desconocido"
end
