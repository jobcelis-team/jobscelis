defmodule StreamflixWebWeb.Admin.ContentLive do
  use StreamflixWebWeb, :live_view

  import Phoenix.Component

  alias StreamflixCatalog
  alias StreamflixCdn

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
      |> assign(:seasons, [])
      |> assign(:selected_season, nil)
      |> assign(:episodes, [])
      |> assign(:show_season_modal, false)
      |> assign(:show_episode_modal, false)
      |> assign(:editing_season, nil)
      |> assign(:editing_episode, nil)
      |> allow_upload(:poster_file, 
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 1,
        max_file_size: 10_000_000,  # 10MB
        auto_upload: true,
        progress: &handle_upload_progress/3
      )
      |> allow_upload(:backdrop_file,
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 1,
        max_file_size: 10_000_000,  # 10MB
        auto_upload: true,
        progress: &handle_upload_progress/3
      )
      |> allow_upload(:video_file,
        accept: ~w(.mp4 .mov .avi .mkv),
        max_entries: 1,
        max_file_size: 5_000_000_000,  # 5GB
        auto_upload: true,
        chunk_size: 64_000,  # 64KB chunks para archivos grandes
        progress: &handle_upload_progress/3
      )

    if connected?(socket) do
      send(self(), :load_content)
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(:load_content, socket) do
    # Load all content (draft, published, archived) for admin
    content_list = StreamflixCatalog.list_content(include_all: true)

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
  def handle_event("validate", params, socket) do
    # Validate file uploads
    socket = socket
      |> validate_upload(:poster_file, params)
      |> validate_upload(:backdrop_file, params)
      |> validate_upload(:video_file, params)
    
    # Si cambió el tipo, actualizar el contenido en edición para reflejar el cambio
    type = params["type"]
    content_id = socket.assigns.editing_content && socket.assigns.editing_content.id
    
    socket = cond do
      # Si cambió a serie y hay contenido editándose, cargar temporadas
      type == "series" && content_id ->
        seasons = StreamflixCatalog.get_seasons(content_id)
        # Actualizar el tipo en editing_content usando Map.put para estructuras
        updated_content = if socket.assigns.editing_content do
          struct(socket.assigns.editing_content, type: "series")
        else
          nil
        end
        assign(socket, 
          seasons: seasons, 
          selected_season: nil, 
          episodes: [],
          editing_content: updated_content
        )
      
      # Si cambió a película, limpiar temporadas
      type == "movie" ->
        updated_content = if socket.assigns.editing_content do
          struct(socket.assigns.editing_content, type: "movie")
        else
          nil
        end
        assign(socket, 
          seasons: [], 
          selected_season: nil, 
          episodes: [],
          editing_content: updated_content
        )
      
      # Si no hay cambios relevantes, mantener estado
      true ->
        socket
    end
    
    {:noreply, socket}
  end

  defp validate_upload(socket, upload_name, _params) do
    # LiveView automatically validates uploads based on allow_upload constraints
    # This function is just a placeholder for any additional validation
    socket
  end

  @impl true
  def handle_event("new_content", _, socket) do
    {:noreply, assign(socket, 
      show_modal: true, 
      editing_content: nil,
      seasons: [],
      selected_season: nil,
      episodes: []
    )}
  end

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    content = Enum.find(socket.assigns.content_list, &(&1.id == id))
    
    # Load seasons and episodes if it's a series
    seasons = if content && content.type == "series" do
      StreamflixCatalog.get_seasons(content.id)
    else
      []
    end
    
    {:noreply, assign(socket, 
      show_modal: true, 
      editing_content: content,
      seasons: seasons,
      selected_season: nil,
      episodes: []
    )}
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
            # Reload content list to show updated status
            send(self(), :load_content)
            socket =
              socket
              |> put_flash(:info, "Contenido desactivado correctamente")
            {:noreply, socket}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Error al desactivar contenido")}
        end
    end
  end

  @impl true
  def handle_event("activate", %{"id" => id}, socket) do
    case StreamflixCatalog.get_content(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Contenido no encontrado")}

      content ->
        case StreamflixCatalog.activate_content(content) do
          {:ok, _} ->
            send(self(), :load_content)
            socket =
              socket
              |> put_flash(:info, "Contenido activado correctamente")
            {:noreply, socket}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Error al activar contenido")}
        end
    end
  end

  @impl true
  def handle_event("save_content", params, socket) do
    require Logger
    
    Logger.info("[ContentLive] save_content event triggered")
    Logger.info("[ContentLive] Params: #{inspect(params)}")
    Logger.info("[ContentLive] Uploads available: #{inspect(Map.keys(socket.assigns.uploads))}")
    
    # Check if there are uploaded entries
    poster_entries = socket.assigns.uploads[:poster_file].entries
    backdrop_entries = socket.assigns.uploads[:backdrop_file].entries
    video_entries = socket.assigns.uploads[:video_file].entries
    
    Logger.info("[ContentLive] Poster entries: #{length(poster_entries)}, Backdrop entries: #{length(backdrop_entries)}, Video entries: #{length(video_entries)}")
    
    # Build attrs - poster_url and backdrop_url will be set after file upload if files are provided
    attrs = %{
      title: params["title"],
      type: params["type"],
      description: params["description"],
      synopsis: params["synopsis"],
      release_year: parse_int(params["release_year"]),
      release_date: parse_date(params["release_date"]),
      duration_minutes: parse_int(params["duration"]),
      rating: params["maturity_rating"] || params["rating"],
      maturity_level: params["maturity_level"] || "adult",
      trailer_url: params["trailer_url"] || "",
      imdb_id: params["imdb_id"] || "",
      tmdb_id: parse_int(params["tmdb_id"]),
      featured: params["featured"] == "true" || params["featured"] == true,
      status: params["status"] || "draft"
    }
    |> Map.put(:poster_url, params["poster_url"] || "")
    |> Map.put(:backdrop_url, params["backdrop_url"] || "")

    Logger.info("[ContentLive] Creating/updating content with attrs: #{inspect(attrs)}")
    
    result = if socket.assigns.editing_content do
      Logger.info("[ContentLive] Updating existing content: #{socket.assigns.editing_content.id}")
      StreamflixCatalog.update_content(socket.assigns.editing_content, attrs)
    else
      Logger.info("[ContentLive] Creating new content")
      StreamflixCatalog.create_content(attrs)
    end

    Logger.info("[ContentLive] Content create/update result: #{inspect(result)}")

    case result do
      {:ok, content} ->
        # Consume uploaded files from LiveView uploads
        updated_content = consume_and_upload_files(content, socket)
        
        # Reload seasons if it's a series
        seasons = if content.type == "series" do
          StreamflixCatalog.get_seasons(content.id)
        else
          []
        end
        
        # Reload content list
        send(self(), :load_content)
        socket =
          socket
          |> assign(:show_modal, false)
          |> assign(:editing_content, nil)
          |> assign(:seasons, seasons)
          |> assign(:selected_season, nil)
          |> assign(:episodes, [])
          |> put_flash(:info, if(socket.assigns.editing_content, do: "Contenido actualizado", else: "Contenido creado"))
        {:noreply, socket}

      {:error, changeset} ->
        errors = format_changeset_errors(changeset)
        {:noreply, put_flash(socket, :error, "Error: #{errors}")}
    end
  end

  defp consume_and_upload_files(content, socket) do
    require Logger
    
    Logger.info("[ContentLive] Starting to consume uploaded files for content #{content.id}")
    
    # Consume poster file uploads
    Logger.info("[ContentLive] Checking poster_file entries before consuming...")
    poster_entries_before = socket.assigns.uploads[:poster_file].entries
    Logger.info("[ContentLive] Poster entries count: #{length(poster_entries_before)}")
    Logger.info("[ContentLive] Poster entries details: #{inspect(Enum.map(poster_entries_before, fn e -> %{name: e.client_name, done?: e.done?, progress: e.progress} end))}")
    
    poster_urls = consume_uploaded_entries(socket, :poster_file, fn %{path: path}, entry ->
      Logger.info("[ContentLive] Processing poster entry: #{inspect(entry.client_name)}, done?: #{entry.done?}, progress: #{entry.progress}")
      Logger.info("[ContentLive] File path: #{path}")
      Logger.info("[ContentLive] File exists?: #{File.exists?(path)}")
      case File.read(path) do
        {:ok, data} ->
          Logger.info("[ContentLive] Read poster file (#{byte_size(data)} bytes), uploading to Azure...")
          case StreamflixCdn.upload_thumbnail(content.id, data, type: "poster") do
            {:ok, url} ->
              Logger.info("[ContentLive] Poster uploaded successfully to Azure: #{url}")
              {:ok, url}
            error ->
              Logger.error("[ContentLive] Failed to upload poster to Azure: #{inspect(error)}")
              {:ok, nil}
          end
        error ->
          Logger.error("[ContentLive] Failed to read poster file from path #{path}: #{inspect(error)}")
          {:ok, nil}
      end
    end)
    
    Logger.info("[ContentLive] Poster URLs result: #{inspect(poster_urls)}")

    # Filter out nil values from results
    poster_urls = Enum.reject(poster_urls, &is_nil/1)

    # Consume backdrop file uploads
    backdrop_urls = consume_uploaded_entries(socket, :backdrop_file, fn %{path: path}, entry ->
      Logger.info("[ContentLive] Processing backdrop entry: #{inspect(entry.client_name)}, done?: #{entry.done?}")
      case File.read(path) do
        {:ok, data} ->
          Logger.info("[ContentLive] Read backdrop file (#{byte_size(data)} bytes), uploading to Azure...")
          case StreamflixCdn.upload_thumbnail(content.id, data, type: "backdrop") do
            {:ok, url} ->
              Logger.info("[ContentLive] Backdrop uploaded successfully to Azure: #{url}")
              {:ok, url}
            error ->
              Logger.error("[ContentLive] Failed to upload backdrop to Azure: #{inspect(error)}")
              {:ok, nil}
          end
        error ->
          Logger.error("[ContentLive] Failed to read backdrop file from path #{path}: #{inspect(error)}")
          {:ok, nil}
      end
    end)
    
    Logger.info("[ContentLive] Backdrop URLs result: #{inspect(backdrop_urls)}")

    # Filter out nil values from results
    backdrop_urls = Enum.reject(backdrop_urls, &is_nil/1)

    # Consume video file uploads
    video_urls = consume_uploaded_entries(socket, :video_file, fn %{path: path}, entry ->
      Logger.info("[ContentLive] Processing video entry: #{inspect(entry.client_name)}, done?: #{entry.done?}")
      Logger.info("[ContentLive] Uploading video from path: #{path}")
      case StreamflixCdn.upload_video(content.id, path) do
        {:ok, %{url: url}} ->
          Logger.info("[ContentLive] Video uploaded successfully to Azure: #{url}")
          {:ok, url}
        error ->
          Logger.error("[ContentLive] Failed to upload video to Azure: #{inspect(error)}")
          {:ok, nil}
      end
    end)
    
    Logger.info("[ContentLive] Video URLs result: #{inspect(video_urls)}")

    # Filter out nil values from results
    video_urls = Enum.reject(video_urls, &is_nil/1)

    # Update content with uploaded poster/backdrop URLs
    update_attrs = %{}
    update_attrs = if poster_url = List.first(poster_urls), do: Map.put(update_attrs, :poster_url, poster_url), else: update_attrs
    update_attrs = if backdrop_url = List.first(backdrop_urls), do: Map.put(update_attrs, :backdrop_url, backdrop_url), else: update_attrs

    Logger.info("[ContentLive] Final update_attrs: #{inspect(update_attrs)}")

    # Update content if there are poster/backdrop URLs
    content = if map_size(update_attrs) > 0 do
      case StreamflixCatalog.update_content(content, update_attrs) do
        {:ok, updated} ->
          Logger.info("[ContentLive] Content updated with uploaded URLs: poster=#{updated.poster_url}, backdrop=#{updated.backdrop_url}")
          updated
        error ->
          Logger.error("[ContentLive] Failed to update content with URLs: #{inspect(error)}")
          content
      end
    else
      if Enum.empty?(poster_urls) and Enum.empty?(backdrop_urls) do
        Logger.info("[ContentLive] No poster/backdrop files to upload")
      end
      content
    end

    # Create or update video record if video was uploaded
    if video_url = List.first(video_urls) do
      Logger.info("[ContentLive] Creating video record with URL: #{video_url}")
      create_or_update_video(content.id, video_url)
    end

    content
  end

  @impl true
  def handle_event("select_season", %{"id" => season_id}, socket) do
    season = StreamflixCatalog.get_season(season_id)
    episodes = if season do
      StreamflixCatalog.get_episodes(season_id)
    else
      []
    end
    
    {:noreply, assign(socket, selected_season: season, episodes: episodes)}
  end

  @impl true
  def handle_event("new_season", _, socket) do
    if socket.assigns.editing_content && socket.assigns.editing_content.type == "series" do
      {:noreply, assign(socket, 
        show_season_modal: true, 
        editing_season: nil,
        show_episode_modal: false
      )}
    else
      {:noreply, put_flash(socket, :error, "Solo las series pueden tener temporadas")}
    end
  end

  @impl true
  def handle_event("edit_season", %{"id" => id}, socket) do
    season = StreamflixCatalog.get_season(id)
    {:noreply, assign(socket, 
      show_season_modal: true, 
      editing_season: season,
      show_episode_modal: false
    )}
  end

  @impl true
  def handle_event("delete_season", %{"id" => id}, socket) do
    case StreamflixCatalog.get_season(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Temporada no encontrada")}
      season ->
        case StreamflixCatalog.delete_season(season) do
          {:ok, _} ->
            # Reload seasons
            seasons = if socket.assigns.editing_content do
              StreamflixCatalog.get_seasons(socket.assigns.editing_content.id)
            else
              []
            end
            {:noreply, assign(socket, 
              seasons: seasons,
              selected_season: nil,
              episodes: []
            ) |> put_flash(:info, "Temporada eliminada")}
          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Error al eliminar temporada")}
        end
    end
  end

  @impl true
  def handle_event("save_season", params, socket) do
    content_id = socket.assigns.editing_content.id
    season_id = params["_id"] || params["id"]
    
    attrs = %{
      season_number: parse_int(params["season_number"]),
      title: params["title"],
      description: params["description"],
      release_date: parse_date(params["release_date"]),
      poster_url: params["poster_url"]
    }

    result = if season_id do
      case StreamflixCatalog.get_season(season_id) do
        nil -> {:error, :not_found}
        season -> StreamflixCatalog.update_season(season, attrs)
      end
    else
      StreamflixCatalog.add_season(content_id, attrs)
    end

    case result do
      {:ok, _season} ->
        # Reload seasons
        seasons = StreamflixCatalog.get_seasons(content_id)
        {:noreply, assign(socket,
          seasons: seasons,
          show_season_modal: false,
          editing_season: nil
        ) |> put_flash(:info, if(season_id, do: "Temporada actualizada", else: "Temporada creada"))}
      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Temporada no encontrada")}
      {:error, changeset} ->
        errors = format_changeset_errors(changeset)
        {:noreply, put_flash(socket, :error, "Error: #{errors}")}
    end
  end

  @impl true
  def handle_event("close_season_modal", _, socket) do
    {:noreply, assign(socket, show_season_modal: false, editing_season: nil)}
  end

  @impl true
  def handle_event("new_episode", %{"season_id" => season_id}, socket) do
    {:noreply, assign(socket,
      show_episode_modal: true,
      editing_episode: nil,
      selected_season: StreamflixCatalog.get_season(season_id),
      show_season_modal: false
    )}
  end

  @impl true
  def handle_event("edit_episode", %{"id" => id}, socket) do
    episode = StreamflixCatalog.get_episode(id)
    season = if episode do
      StreamflixCatalog.get_season(episode.season_id)
    else
      nil
    end
    
    {:noreply, assign(socket,
      show_episode_modal: true,
      editing_episode: episode,
      selected_season: season,
      show_season_modal: false
    )}
  end

  @impl true
  def handle_event("delete_episode", %{"id" => id}, socket) do
    case StreamflixCatalog.get_episode(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Episodio no encontrado")}
      episode ->
        season_id = episode.season_id
        case StreamflixCatalog.delete_episode(episode) do
          {:ok, _} ->
            # Reload episodes if season is selected
            episodes = if socket.assigns.selected_season && socket.assigns.selected_season.id == season_id do
              StreamflixCatalog.get_episodes(season_id)
            else
              socket.assigns.episodes
            end
            {:noreply, assign(socket, episodes: episodes) |> put_flash(:info, "Episodio eliminado")}
          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Error al eliminar episodio")}
        end
    end
  end

  @impl true
  def handle_event("save_episode", params, socket) do
    season_id = params["season_id"] || (socket.assigns.selected_season && socket.assigns.selected_season.id)
    episode_id = params["_id"] || params["id"]
    
    if not season_id do
      {:noreply, put_flash(socket, :error, "Se requiere una temporada")}
    else
      attrs = %{
        episode_number: parse_int(params["episode_number"]),
        title: params["title"],
        description: params["description"],
        duration_minutes: parse_int(params["duration_minutes"]),
        release_date: parse_date(params["release_date"]),
        thumbnail_url: params["thumbnail_url"]
      }

      result = if episode_id do
        case StreamflixCatalog.get_episode(episode_id) do
          nil -> {:error, :not_found}
          episode -> StreamflixCatalog.update_episode(episode, attrs)
        end
      else
        StreamflixCatalog.add_episode(season_id, attrs)
      end

      case result do
        {:ok, _episode} ->
          # Reload episodes
          episodes = StreamflixCatalog.get_episodes(season_id)
          {:noreply, assign(socket,
            episodes: episodes,
            show_episode_modal: false,
            editing_episode: nil
          ) |> put_flash(:info, if(episode_id, do: "Episodio actualizado", else: "Episodio creado"))}
        {:error, :not_found} ->
          {:noreply, put_flash(socket, :error, "Episodio no encontrado")}
        {:error, changeset} ->
          errors = format_changeset_errors(changeset)
          {:noreply, put_flash(socket, :error, "Error: #{errors}")}
      end
    end
  end

  @impl true
  def handle_event("close_episode_modal", _, socket) do
    {:noreply, assign(socket, show_episode_modal: false, editing_episode: nil)}
  end

  @impl true
  def handle_event("publish", %{"id" => id}, socket) do
    case StreamflixCatalog.publish_content(id) do
      {:ok, _} ->
        send(self(), :load_content)
        socket =
          socket
          |> put_flash(:info, "Contenido publicado")
        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Error al publicar")}
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> nil
    end
  end
  defp parse_int(val) when is_integer(val), do: val

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil
  defp parse_date(str) when is_binary(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      _ -> nil
    end
  end
  defp parse_date(date), do: date

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
                      <span class={"px-2 py-1 rounded text-xs #{if content.type == "movie", do: "bg-blue-100 text-blue-800", else: "bg-purple-100 text-purple-800"}"}>
                        <%= if content.type == "movie", do: "Película", else: "Serie" %>
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
                        <%= if content.status == "archived" do %>
                          <button
                            phx-click="activate"
                            phx-value-id={content.id}
                            class="text-green-600 hover:text-green-800"
                            title="Activar"
                          >
                            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                            </svg>
                          </button>
                        <% else %>
                          <button
                            phx-click="delete"
                            phx-value-id={content.id}
                            class="text-red-600 hover:text-red-800"
                            title="Desactivar"
                          >
                            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                            </svg>
                          </button>
                        <% end %>
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
            <form phx-submit="save_content" phx-change="validate" phx-debounce="300" class="p-6 space-y-4">
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Título</label>
                  <input type="text" name="title" value={@editing_content && @editing_content.title} class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Tipo</label>
                  <select 
                    name="type" 
                    phx-change="validate" 
                    class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white"
                  >
                    <option value="movie" selected={@editing_content && @editing_content.type == "movie"}>Película</option>
                    <option value="series" selected={@editing_content && @editing_content.type == "series"}>Serie</option>
                  </select>
                </div>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Descripción</label>
                <textarea name="description" rows="3" class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white"><%= if @editing_content, do: @editing_content.description, else: "" %></textarea>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Sinopsis</label>
                <textarea name="synopsis" rows="3" class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white"><%= if @editing_content, do: @editing_content.synopsis, else: "" %></textarea>
              </div>
              <div class="grid grid-cols-3 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Año</label>
                  <input type="number" name="release_year" value={@editing_content && @editing_content.release_year} class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Duración (min)</label>
                  <input type="number" name="duration" value={@editing_content && @editing_content.duration_minutes} class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Clasificación</label>
                  <select name="maturity_rating" class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white">
                    <option value="G" selected={@editing_content && @editing_content.rating == "G"}>G</option>
                    <option value="PG" selected={@editing_content && @editing_content.rating == "PG"}>PG</option>
                    <option value="PG-13" selected={@editing_content && @editing_content.rating == "PG-13"}>PG-13</option>
                    <option value="R" selected={@editing_content && @editing_content.rating == "R"}>R</option>
                    <option value="NC-17" selected={@editing_content && @editing_content.rating == "NC-17"}>NC-17</option>
                    <option value="TV-MA" selected={@editing_content && @editing_content.rating == "TV-MA"}>TV-MA</option>
                  </select>
                </div>
              </div>
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Poster</label>
                  <div class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white">
                    <.live_file_input upload={@uploads.poster_file} />
                  </div>
                  <%= for entry <- @uploads.poster_file.entries do %>
                    <div class="mt-1">
                      <p class="text-xs text-gray-600"><%= entry.client_name %> - <%= entry.progress %>%</p>
                      <%= for err <- upload_errors(@uploads.poster_file, entry) do %>
                        <p class="text-xs text-red-600"><%= error_to_string(err) %></p>
                      <% end %>
                    </div>
                  <% end %>
                  <%= if @editing_content && @editing_content.poster_url do %>
                    <p class="text-xs text-gray-500 mt-1">Actual: <a href={@editing_content.poster_url} target="_blank" class="text-blue-600 hover:underline">Ver</a></p>
                    <input type="hidden" name="poster_url" value={@editing_content.poster_url} />
                  <% else %>
                    <input type="url" name="poster_url" placeholder="O ingresa URL" class="w-full border border-gray-300 rounded-lg px-4 py-2 mt-2 text-gray-900 bg-white" />
                  <% end %>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Backdrop</label>
                  <div class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white">
                    <.live_file_input upload={@uploads.backdrop_file} />
                  </div>
                  <%= for entry <- @uploads.backdrop_file.entries do %>
                    <div class="mt-1">
                      <p class="text-xs text-gray-600"><%= entry.client_name %> - <%= entry.progress %>%</p>
                      <%= for err <- upload_errors(@uploads.backdrop_file, entry) do %>
                        <p class="text-xs text-red-600"><%= error_to_string(err) %></p>
                      <% end %>
                    </div>
                  <% end %>
                  <%= if @editing_content && @editing_content.backdrop_url do %>
                    <p class="text-xs text-gray-500 mt-1">Actual: <a href={@editing_content.backdrop_url} target="_blank" class="text-blue-600 hover:underline">Ver</a></p>
                    <input type="hidden" name="backdrop_url" value={@editing_content.backdrop_url} />
                  <% else %>
                    <input type="url" name="backdrop_url" placeholder="O ingresa URL" class="w-full border border-gray-300 rounded-lg px-4 py-2 mt-2 text-gray-900 bg-white" />
                  <% end %>
                </div>
              </div>
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Fecha de Lanzamiento</label>
                  <input type="date" name="release_date" value={@editing_content && @editing_content.release_date && Date.to_string(@editing_content.release_date)} class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Nivel de Madurez</label>
                  <select name="maturity_level" class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white">
                    <option value="adult" selected={@editing_content && @editing_content.maturity_level == "adult"}>Adulto</option>
                    <option value="teen" selected={@editing_content && @editing_content.maturity_level == "teen"}>Adolescente</option>
                    <option value="kids" selected={@editing_content && @editing_content.maturity_level == "kids"}>Infantil</option>
                  </select>
                </div>
              </div>
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Trailer URL</label>
                  <input type="url" name="trailer_url" value={@editing_content && @editing_content.trailer_url} placeholder="https://youtube.com/..." class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Video (Archivo)</label>
                  <div class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white">
                    <.live_file_input upload={@uploads.video_file} />
                  </div>
                  <%= for entry <- @uploads.video_file.entries do %>
                    <div class="mt-1">
                      <p class="text-xs text-gray-600"><%= entry.client_name %> - <%= entry.progress %>%</p>
                      <%= for err <- upload_errors(@uploads.video_file, entry) do %>
                        <p class="text-xs text-red-600"><%= error_to_string(err) %></p>
                      <% end %>
                    </div>
                  <% end %>
                  <p class="text-xs text-gray-500 mt-1">Se subirá a Azure Blob Storage</p>
                </div>
              </div>
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">IMDB ID</label>
                  <input type="text" name="imdb_id" value={@editing_content && @editing_content.imdb_id} placeholder="tt1234567" class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">TMDB ID</label>
                  <input type="number" name="tmdb_id" value={@editing_content && @editing_content.tmdb_id} placeholder="12345" class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white" />
                </div>
              </div>
              <div class="flex items-center gap-2">
                <input type="checkbox" name="featured" value="true" id="featured" checked={@editing_content && @editing_content.featured} class="w-4 h-4 text-blue-600 border-gray-300 rounded" />
                <label for="featured" class="text-sm font-medium text-gray-700">Destacado</label>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Estado</label>
                <select name="status" class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white">
                  <option value="draft" selected={@editing_content && @editing_content.status == "draft"}>Borrador</option>
                  <option value="published" selected={@editing_content && @editing_content.status == "published"}>Publicado</option>
                  <option value="archived" selected={@editing_content && @editing_content.status == "archived"}>Archivado</option>
                </select>
              </div>

              <!-- Seasons and Episodes Section (Only for Series) -->
              <%= if @editing_content && @editing_content.type == "series" do %>
                <div class="border-t pt-4 mt-4">
                  <div class="flex justify-between items-center mb-4">
                    <h3 class="text-lg font-semibold text-gray-900">Temporadas y Episodios</h3>
                    <button
                      type="button"
                      phx-click="new_season"
                      class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg text-sm"
                    >
                      + Agregar Temporada
                    </button>
                  </div>

                  <%= if Enum.empty?(@seasons) do %>
                    <p class="text-gray-500 text-sm">No hay temporadas agregadas. Crea una temporada para comenzar.</p>
                  <% else %>
                    <div class="space-y-4">
                      <%= for season <- @seasons do %>
                        <div class="border rounded-lg p-4 bg-gray-50">
                          <div class="flex justify-between items-start mb-2">
                            <div>
                              <h4 class="font-medium text-gray-900">
                                Temporada <%= season.season_number %>
                                <%= if season.title, do: " - #{season.title}" %>
                              </h4>
                              <%= if season.description do %>
                                <p class="text-sm text-gray-600 mt-1"><%= season.description %></p>
                              <% end %>
                            </div>
                            <div class="flex gap-2">
                              <button
                                type="button"
                                phx-click="select_season"
                                phx-value-id={season.id}
                                class="text-blue-600 hover:text-blue-800 text-sm"
                              >
                                Ver Episodios
                              </button>
                              <button
                                type="button"
                                phx-click="edit_season"
                                phx-value-id={season.id}
                                class="text-green-600 hover:text-green-800 text-sm"
                              >
                                Editar
                              </button>
                              <button
                                type="button"
                                phx-click="delete_season"
                                phx-value-id={season.id}
                                class="text-red-600 hover:text-red-800 text-sm"
                              >
                                Eliminar
                              </button>
                            </div>
                          </div>
                          
                          <%= if @selected_season && @selected_season.id == season.id do %>
                            <div class="mt-4 border-t pt-4">
                              <div class="flex justify-between items-center mb-2">
                                <span class="text-sm font-medium text-gray-700">Episodios</span>
                                <button
                                  type="button"
                                  phx-click="new_episode"
                                  phx-value-season_id={season.id}
                                  class="px-3 py-1 bg-green-600 hover:bg-green-700 text-white rounded text-xs"
                                >
                                  + Agregar Episodio
                                </button>
                              </div>
                              <%= if Enum.empty?(@episodes) do %>
                                <p class="text-gray-500 text-xs">No hay episodios en esta temporada.</p>
                              <% else %>
                                <div class="space-y-2">
                                  <%= for episode <- @episodes do %>
                                    <div class="flex justify-between items-center p-2 bg-white rounded border">
                                      <div>
                                        <span class="text-sm font-medium text-gray-900">
                                          Episodio <%= episode.episode_number %>: <%= episode.title %>
                                        </span>
                                        <%= if episode.duration_minutes do %>
                                          <span class="text-xs text-gray-500 ml-2">(<%= episode.duration_minutes %> min)</span>
                                        <% end %>
                                      </div>
                                      <div class="flex gap-2">
                                        <button
                                          type="button"
                                          phx-click="edit_episode"
                                          phx-value-id={episode.id}
                                          class="text-blue-600 hover:text-blue-800 text-xs"
                                        >
                                          Editar
                                        </button>
                                        <button
                                          type="button"
                                          phx-click="delete_episode"
                                          phx-value-id={episode.id}
                                          class="text-red-600 hover:text-red-800 text-xs"
                                        >
                                          Eliminar
                                        </button>
                                      </div>
                                    </div>
                                  <% end %>
                                </div>
                              <% end %>
                            </div>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              <% end %>

              <!-- Season Modal -->
              <%= if @show_season_modal do %>
                <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50" phx-click="close_season_modal">
                  <div class="bg-white rounded-lg shadow-xl w-full max-w-md mx-4" phx-click="noop">
                    <div class="p-6 border-b flex justify-between items-center">
                      <h3 class="text-lg font-semibold text-gray-900">
                        <%= if @editing_season, do: "Editar Temporada", else: "Nueva Temporada" %>
                      </h3>
                      <button phx-click="close_season_modal" class="text-gray-400 hover:text-gray-600">
                        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                        </svg>
                      </button>
                    </div>
                    <form phx-submit="save_season" class="p-6 space-y-4">
                      <%= if @editing_season do %>
                        <input type="hidden" name="_id" value={@editing_season.id} />
                      <% end %>
                      
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Número de Temporada</label>
                        <input
                          type="number"
                          name="season_number"
                          value={@editing_season && @editing_season.season_number}
                          min="1"
                          required
                          class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white"
                        />
                      </div>

                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Título (opcional)</label>
                        <input
                          type="text"
                          name="title"
                          value={@editing_season && @editing_season.title}
                          class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white"
                          placeholder="Ej: Temporada 1"
                        />
                      </div>

                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Descripción</label>
                        <textarea
                          name="description"
                          rows="3"
                          class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white"
                        ><%= if @editing_season, do: @editing_season.description, else: "" %></textarea>
                      </div>

                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Fecha de Lanzamiento</label>
                        <input
                          type="date"
                          name="release_date"
                          value={@editing_season && @editing_season.release_date && Date.to_iso8601(@editing_season.release_date)}
                          class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white"
                        />
                      </div>

                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">URL Poster</label>
                        <input
                          type="url"
                          name="poster_url"
                          value={@editing_season && @editing_season.poster_url}
                          class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white"
                          placeholder="https://..."
                        />
                      </div>

                      <div class="flex justify-end gap-4 pt-4 border-t">
                        <button
                          type="button"
                          phx-click="close_season_modal"
                          class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 text-gray-700"
                        >
                          Cancelar
                        </button>
                        <button
                          type="submit"
                          class="px-6 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg"
                        >
                          Guardar
                        </button>
                      </div>
                    </form>
                  </div>
                </div>
              <% end %>

              <!-- Episode Modal -->
              <%= if @show_episode_modal do %>
                <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50" phx-click="close_episode_modal">
                  <div class="bg-white rounded-lg shadow-xl w-full max-w-md mx-4" phx-click="noop">
                    <div class="p-6 border-b flex justify-between items-center">
                      <h3 class="text-lg font-semibold text-gray-900">
                        <%= if @editing_episode, do: "Editar Episodio", else: "Nuevo Episodio" %>
                      </h3>
                      <button phx-click="close_episode_modal" class="text-gray-400 hover:text-gray-600">
                        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                        </svg>
                      </button>
                    </div>
                    <form phx-submit="save_episode" class="p-6 space-y-4">
                      <%= if @editing_episode do %>
                        <input type="hidden" name="_id" value={@editing_episode.id} />
                      <% end %>
                      <input type="hidden" name="season_id" value={@selected_season && @selected_season.id} />
                      
                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Número de Episodio</label>
                        <input
                          type="number"
                          name="episode_number"
                          value={@editing_episode && @editing_episode.episode_number}
                          min="1"
                          required
                          class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white"
                        />
                      </div>

                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Título</label>
                        <input
                          type="text"
                          name="title"
                          value={@editing_episode && @editing_episode.title}
                          required
                          class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white"
                          placeholder="Título del episodio"
                        />
                      </div>

                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">Descripción</label>
                        <textarea
                          name="description"
                          rows="3"
                          class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white"
                        ><%= if @editing_episode, do: @editing_episode.description, else: "" %></textarea>
                      </div>

                      <div class="grid grid-cols-2 gap-4">
                        <div>
                          <label class="block text-sm font-medium text-gray-700 mb-1">Duración (min)</label>
                          <input
                            type="number"
                            name="duration_minutes"
                            value={@editing_episode && @editing_episode.duration_minutes}
                            min="1"
                            class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white"
                          />
                        </div>
                        <div>
                          <label class="block text-sm font-medium text-gray-700 mb-1">Fecha de Lanzamiento</label>
                          <input
                            type="date"
                            name="release_date"
                            value={@editing_episode && @editing_episode.release_date && Date.to_iso8601(@editing_episode.release_date)}
                            class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white"
                          />
                        </div>
                      </div>

                      <div>
                        <label class="block text-sm font-medium text-gray-700 mb-1">URL Thumbnail</label>
                        <input
                          type="url"
                          name="thumbnail_url"
                          value={@editing_episode && @editing_episode.thumbnail_url}
                          class="w-full border border-gray-300 rounded-lg px-4 py-2 text-gray-900 bg-white"
                          placeholder="https://..."
                        />
                      </div>

                      <div class="flex justify-end gap-4 pt-4 border-t">
                        <button
                          type="button"
                          phx-click="close_episode_modal"
                          class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 text-gray-700"
                        >
                          Cancelar
                        </button>
                        <button
                          type="submit"
                          class="px-6 py-2 bg-green-600 hover:bg-green-700 text-white rounded-lg"
                        >
                          Guardar
                        </button>
                      </div>
                    </form>
                  </div>
                </div>
              <% end %>

              <div class="flex justify-end gap-4 pt-4 border-t">
                <button type="button" phx-click="close_modal" class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 text-gray-700">Cancelar</button>
                <button type="submit" phx-disable-with="Guardando..." class="px-6 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg disabled:opacity-50">
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

  defp error_to_string(:too_large), do: "Archivo demasiado grande"
  defp error_to_string(:too_many_files), do: "Demasiados archivos"
  defp error_to_string(:not_accepted), do: "Tipo de archivo no aceptado"
  defp error_to_string(error), do: "Error: #{inspect(error)}"

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref, "upload" => upload_name}, socket) do
    {:noreply, cancel_upload(socket, String.to_atom(upload_name), ref)}
  end

  defp handle_upload_progress(upload_name, entry, socket) do
    require Logger
    # Access struct field using pattern matching to avoid ambiguity
    client_name = case entry do
      %{client_name: name} when is_binary(name) -> name
      _ -> "unknown"
    end
    progress = Map.get(entry, :progress, 0)
    Logger.info("[ContentLive] Upload progress for #{upload_name}: #{client_name} - #{progress}%")
    # The callback must return {:noreply, socket}
    {:noreply, socket}
  end

  defp create_or_update_video(content_id, video_url) do
    require Logger
    alias StreamflixCatalog.Schemas.Video
    alias StreamflixCore.Repo

    # Check if video already exists for this content
    case Repo.get_by(Video, content_id: content_id) do
      nil ->
        # Create new video
        Logger.info("[ContentLive] Creating new video record for content #{content_id}")
        %Video{}
        |> Video.changeset(%{
          content_id: content_id,
          original_url: video_url,
          status: "ready"
        })
        |> Repo.insert()
        |> case do
          {:ok, video} ->
            Logger.info("[ContentLive] Video record created: #{video.id}")
            {:ok, video}
          {:error, changeset} ->
            Logger.error("[ContentLive] Failed to create video: #{inspect(changeset.errors)}")
            {:error, changeset}
        end

      video ->
        # Update existing video
        Logger.info("[ContentLive] Updating existing video record #{video.id}")
        video
        |> Video.changeset(%{
          original_url: video_url,
          status: "ready"
        })
        |> Repo.update()
        |> case do
          {:ok, updated_video} ->
            Logger.info("[ContentLive] Video record updated: #{updated_video.id}")
            {:ok, updated_video}
          {:error, changeset} ->
            Logger.error("[ContentLive] Failed to update video: #{inspect(changeset.errors)}")
            {:error, changeset}
        end
    end
  end
end
