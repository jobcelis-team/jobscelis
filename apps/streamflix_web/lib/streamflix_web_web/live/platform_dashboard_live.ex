defmodule StreamflixWebWeb.PlatformDashboardLive do
  use StreamflixWebWeb, :live_view

  alias StreamflixCore.Platform
  alias StreamflixCore.Notifications
  alias StreamflixCore.Audit
  alias StreamflixCore.Teams

  @impl true
  def mount(_params, session, socket) do
    user = socket.assigns.current_user
    projects = Teams.list_all_accessible_projects(user.id)
    project = Enum.find(projects, & &1.is_default) || List.first(projects)
    api_key = if project, do: Platform.get_api_key_for_project(project.id), else: nil
    events = if project, do: Platform.list_events(project.id, limit: 20), else: []
    webhooks = if project, do: Platform.list_webhooks(project.id), else: []
    webhook_health = if project, do: Platform.webhooks_health(project.id), else: %{}
    jobs = if project, do: Platform.list_jobs(project.id, include_inactive: true), else: []

    deliveries =
      if project, do: Platform.list_deliveries(project_id: project.id, limit: 30), else: []

    dead_letters = if project, do: Platform.list_dead_letters(project.id), else: []
    replays = if project, do: Platform.list_replays(project.id, limit: 10), else: []
    audit_logs = if project, do: Audit.list_for_project(project.id, limit: 20), else: []
    sandbox_endpoints = if project, do: Platform.list_sandbox_endpoints(project.id), else: []
    event_schemas = if project, do: Platform.list_event_schemas(project.id), else: []
    team_members = if project, do: Teams.list_members(project.id), else: []
    analytics = if project, do: load_analytics(project.id), else: %{}
    notifications = Notifications.list_for_user(user.id, limit: 10)
    unread_count = Notifications.unread_count(user.id)

    # Check if we have a fresh API key from registration
    {new_token, token_source} =
      case session["fresh_api_key"] do
        fresh_key when is_binary(fresh_key) and fresh_key != "" ->
          # Only use if prefix still matches (prevents stale key after regeneration)
          if api_key && String.starts_with?(fresh_key, api_key.prefix) do
            {fresh_key, :registration}
          else
            {nil, nil}
          end

        _ ->
          {nil, nil}
      end

    socket =
      socket
      |> assign(:projects, projects)
      |> assign(:project, project)
      |> assign(:show_project_selector, false)
      |> assign(:api_key, api_key)
      |> assign(:events, events)
      |> assign(:webhooks, webhooks)
      |> assign(:webhook_health, webhook_health)
      |> assign(:simulation_result, nil)
      |> assign(:dead_letters, dead_letters)
      |> assign(:replays, replays)
      |> assign(:replay_modal, false)
      |> assign(:sandbox_endpoints, sandbox_endpoints)
      |> assign(:sandbox_active, nil)
      |> assign(:sandbox_requests, [])
      |> assign(:audit_logs, audit_logs)
      |> assign(:event_schemas, event_schemas)
      |> assign(:team_members, team_members)
      |> assign(:analytics, analytics)
      |> assign(:show_analytics, false)
      |> assign(:notifications, notifications)
      |> assign(:unread_count, unread_count)
      |> assign(:show_notifications, false)
      |> assign(:jobs, jobs)
      |> assign(:deliveries, deliveries)
      |> assign(:test_topic, "")
      |> assign(:test_payload, "{}")
      |> assign(:new_token, new_token)
      |> assign(:token_source, token_source)
      |> assign(:token_visible, true)
      |> assign(:editing_project_name, false)
      |> assign(:job_modal, nil)
      |> assign(:job_runs_modal, nil)
      |> assign(:job_form, nil)
      |> assign(:cron_preview, [])
      |> assign(:page_title, "Jobcelis Dashboard")
      |> assign(:active_page, :dashboard)

    if connected?(socket) do
      if project, do: Platform.subscribe(project.id)
      Notifications.subscribe(user.id)
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("send_test", %{"topic" => topic, "payload" => payload_str} = _params, socket) do
    project = socket.assigns.project

    payload =
      case Jason.decode(payload_str) do
        {:ok, map} when is_map(map) -> map
        _ -> %{}
      end

    body = if topic != "", do: Map.put(payload, "topic", topic), else: payload

    result = Platform.create_event(project.id, body)

    socket =
      case result do
        {:ok, event} ->
          Audit.record("event.created",
            user_id: socket.assigns.current_user.id,
            project_id: project.id,
            resource_type: "event",
            resource_id: event.id
          )

          events = [event | Platform.list_events(project.id, limit: 19)]
          put_flash(socket, :info, gettext("Event sent. ID: %{id}", id: event.id))
          assign(socket, :events, events)

        {:error, _} ->
          put_flash(socket, :error, gettext("Failed to send event"))
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_project_name", _params, socket) do
    {:noreply, assign(socket, :editing_project_name, true)}
  end

  @impl true
  def handle_event("cancel_edit_project_name", _params, socket) do
    {:noreply, assign(socket, :editing_project_name, false)}
  end

  @impl true
  def handle_event("update_project_name", %{"name" => name}, socket) do
    project = socket.assigns.project
    name = String.trim(name)

    socket =
      if name == "" do
        put_flash(socket, :error, gettext("El nombre no puede estar vacío."))
        |> assign(:editing_project_name, false)
      else
        case Platform.update_project(project, %{name: name}) do
          {:ok, updated} ->
            socket
            |> put_flash(:info, gettext("Nombre del proyecto actualizado."))
            |> assign(:project, updated)
            |> assign(:editing_project_name, false)

          {:error, _} ->
            put_flash(socket, :error, gettext("No se pudo actualizar el nombre."))
            |> assign(:editing_project_name, false)
        end
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_token_visibility", _params, socket) do
    {:noreply, assign(socket, :token_visible, !socket.assigns.token_visible)}
  end

  @impl true
  def handle_event("regenerate_token", _params, socket) do
    project = socket.assigns.project

    case Platform.regenerate_api_key(project.id) do
      {:ok, _api_key, raw_key} ->
        api_key = Platform.get_api_key_for_project(project.id)

        socket =
          Audit.record("api_key.regenerated",
            user_id: socket.assigns.current_user.id,
            project_id: project.id,
            resource_type: "api_key"
          )

        socket
        |> put_flash(:info, gettext("Token regenerado correctamente."))
        |> assign(:api_key, api_key)
        |> assign(:new_token, raw_key)
        |> assign(:token_source, :regenerated)
        |> assign(:token_visible, true)

        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, gettext("No se pudo regenerar el token."))}
    end
  end

  # Jobs: open create modal
  @impl true
  def handle_event("new_job", _, socket) do
    project = socket.assigns.project

    if project do
      form =
        to_form(%{
          "name" => "",
          "schedule_type" => "daily",
          "schedule_hour" => "0",
          "schedule_minute" => "0",
          "schedule_day_of_week" => "1",
          "schedule_day_of_month" => "1",
          "schedule_cron" => "0 0 * * *",
          "action_type" => "emit_event",
          "action_topic" => "",
          "action_payload" => "{}",
          "action_url" => "",
          "action_method" => "POST"
        })

      {:noreply,
       socket
       |> assign(:job_modal, :new)
       |> assign(:job_form, form)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("edit_job", %{"id" => id}, socket) do
    project = socket.assigns.project
    job = project && Platform.get_job(id)

    if job && job.project_id == project.id do
      sc = job.schedule_config || %{}
      ac = job.action_config || %{}

      form =
        to_form(%{
          "name" => job.name || "",
          "schedule_type" => job.schedule_type || "daily",
          "schedule_hour" => to_str(Map.get(sc, "hour", 0)),
          "schedule_minute" => to_str(Map.get(sc, "minute", 0)),
          "schedule_day_of_week" => to_str(Map.get(sc, "day_of_week", 1)),
          "schedule_day_of_month" => to_str(Map.get(sc, "day_of_month", 1)),
          "schedule_cron" => Map.get(sc, "expr") || Map.get(sc, "expression") || "0 0 * * *",
          "action_type" => job.action_type || "emit_event",
          "action_topic" => Map.get(ac, "topic") || "",
          "action_payload" => (ac["payload"] && Jason.encode!(ac["payload"])) || "{}",
          "action_url" => Map.get(ac, "url") || "",
          "action_method" => Map.get(ac, "method") || "POST",
          "status" => job.status || "active"
        })

      {:noreply,
       socket
       |> assign(:job_modal, {:edit, job.id})
       |> assign(:job_form, form)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_job_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:job_modal, nil)
     |> assign(:job_form, nil)}
  end

  @impl true
  def handle_event("save_job", params, socket) do
    project = socket.assigns.project

    if project do
      schedule_config = build_schedule_config(params)
      action_config = build_action_config(params)

      attrs = %{
        "name" => params["name"] || "",
        "schedule_type" => params["schedule_type"] || "daily",
        "schedule_config" => schedule_config,
        "action_type" => params["action_type"] || "emit_event",
        "action_config" => action_config
      }

      attrs =
        if match?({:edit, _}, socket.assigns.job_modal),
          do: Map.put(attrs, "status", params["status"] || "active"),
          else: attrs

      result =
        case socket.assigns.job_modal do
          :new ->
            Platform.create_job(project.id, attrs)

          {:edit, id} ->
            job_id = params["job_id"] || id
            job = Platform.get_job(job_id)

            if job && job.project_id == project.id,
              do: Platform.update_job(job, attrs),
              else: {:error, nil}
        end

      socket =
        case result do
          {:ok, _job} ->
            jobs = Platform.list_jobs(project.id, include_inactive: true)

            socket
            |> put_flash(:info, gettext("Job guardado."))
            |> assign(:jobs, jobs)
            |> assign(:job_modal, nil)
            |> assign(:job_form, nil)

          {:error, _} ->
            put_flash(socket, :error, gettext("Error al guardar el job."))
        end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("preview_cron", %{"expression" => expr}, socket) when is_binary(expr) do
    executions = Platform.next_cron_executions(expr, 5)
    formatted = Enum.map(executions, &Calendar.strftime(&1, "%Y-%m-%d %H:%M UTC"))
    {:noreply, assign(socket, :cron_preview, formatted)}
  end

  def handle_event("preview_cron", _, socket) do
    {:noreply, assign(socket, :cron_preview, [])}
  end

  @impl true
  def handle_event("show_job_runs", %{"id" => id}, socket) do
    project = socket.assigns.project
    job = project && Platform.get_job(id)

    if job && job.project_id == project.id do
      runs = Platform.list_job_runs(job.id, limit: 50)

      {:noreply,
       socket
       |> assign(:job_runs_modal, %{job: job, runs: runs})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_job_runs_modal", _, socket) do
    {:noreply, assign(socket, :job_runs_modal, nil)}
  end

  @impl true
  def handle_event("deactivate_job", %{"id" => id}, socket) do
    project = socket.assigns.project
    job = project && Platform.get_job(id)

    if job && job.project_id == project.id do
      Platform.set_job_inactive(job)
      jobs = Platform.list_jobs(project.id, include_inactive: true)

      {:noreply,
       socket
       |> put_flash(:info, gettext("Job desactivado."))
       |> assign(:jobs, jobs)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("retry_delivery", %{"id" => id}, socket) do
    project = socket.assigns.project

    if project do
      case Platform.retry_delivery(project.id, id) do
        {:ok, _} ->
          deliveries = Platform.list_deliveries(project_id: project.id, limit: 30)

          {:noreply,
           socket
           |> put_flash(:info, gettext("Reintento encolado."))
           |> assign(:deliveries, deliveries)}

        {:error, :not_found} ->
          {:noreply, put_flash(socket, :error, gettext("Entrega no encontrada."))}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_notifications", _, socket) do
    {:noreply, assign(socket, :show_notifications, !socket.assigns.show_notifications)}
  end

  @impl true
  def handle_event("mark_all_read", _, socket) do
    user = socket.assigns.current_user
    Notifications.mark_all_read(user.id)

    {:noreply,
     socket
     |> assign(:notifications, Notifications.list_for_user(user.id, limit: 10))
     |> assign(:unread_count, 0)}
  end

  @impl true
  def handle_event("mark_notification_read", %{"id" => id}, socket) do
    Notifications.mark_as_read(id)
    user = socket.assigns.current_user

    {:noreply,
     socket
     |> assign(:notifications, Notifications.list_for_user(user.id, limit: 10))
     |> assign(:unread_count, Notifications.unread_count(user.id))}
  end

  @impl true
  def handle_event("retry_dead_letter", %{"id" => id}, socket) do
    case Platform.retry_dead_letter(id) do
      {:ok, _} ->
        dead_letters = Platform.list_dead_letters(socket.assigns.project.id)
        deliveries = Platform.list_deliveries(project_id: socket.assigns.project.id, limit: 30)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Reintento encolado desde DLQ."))
         |> assign(:dead_letters, dead_letters)
         |> assign(:deliveries, deliveries)}

      {:error, :webhook_inactive} ->
        {:noreply, put_flash(socket, :error, gettext("El webhook está inactivo."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Error al reintentar."))}
    end
  end

  @impl true
  def handle_event("resolve_dead_letter", %{"id" => id}, socket) do
    case Platform.resolve_dead_letter(id) do
      {:ok, _} ->
        dead_letters = Platform.list_dead_letters(socket.assigns.project.id)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Marcado como resuelto."))
         |> assign(:dead_letters, dead_letters)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Error al resolver."))}
    end
  end

  @impl true
  def handle_event("simulate_event", %{"topic" => topic, "payload" => payload_str}, socket) do
    project = socket.assigns.project

    payload =
      case Jason.decode(payload_str) do
        {:ok, map} when is_map(map) -> map
        _ -> %{}
      end

    body = if topic != "", do: Map.put(payload, "topic", topic), else: payload

    case Platform.simulate_event(project.id, body) do
      matches when is_list(matches) ->
        {:noreply, assign(socket, :simulation_result, matches)}

      _ ->
        {:noreply, put_flash(socket, :error, gettext("Error en simulación"))}
    end
  end

  @impl true
  def handle_event("close_simulation", _, socket) do
    {:noreply, assign(socket, :simulation_result, nil)}
  end

  # ---------- Replay ----------

  @impl true
  def handle_event("open_replay_modal", _, socket) do
    {:noreply, assign(socket, :replay_modal, true)}
  end

  @impl true
  def handle_event("close_replay_modal", _, socket) do
    {:noreply, assign(socket, :replay_modal, false)}
  end

  @impl true
  def handle_event("start_replay", params, socket) do
    project = socket.assigns.project
    user = socket.assigns.current_user

    filters = %{
      "topic" => params["topic"],
      "from_date" => params["from_date"],
      "to_date" => params["to_date"],
      "webhook_id" => params["webhook_id"]
    }

    case Platform.create_replay(project.id, user.id, filters) do
      {:ok, _replay} ->
        replays = Platform.list_replays(project.id, limit: 10)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Replay iniciado."))
         |> assign(:replays, replays)
         |> assign(:replay_modal, false)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Error al iniciar replay."))}
    end
  end

  @impl true
  def handle_event("cancel_replay", %{"id" => id}, socket) do
    case Platform.cancel_replay(id) do
      {:ok, _} ->
        replays = Platform.list_replays(socket.assigns.project.id, limit: 10)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Replay cancelado."))
         |> assign(:replays, replays)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Error al cancelar replay."))}
    end
  end

  # ---------- Sandbox ----------

  @impl true
  def handle_event("create_sandbox", params, socket) do
    project = socket.assigns.project

    case Platform.create_sandbox_endpoint(project.id, params["name"]) do
      {:ok, endpoint} ->
        endpoints = Platform.list_sandbox_endpoints(project.id)
        requests = Platform.list_sandbox_requests(endpoint.id)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Sandbox creado."))
         |> assign(:sandbox_endpoints, endpoints)
         |> assign(:sandbox_active, endpoint)
         |> assign(:sandbox_requests, requests)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Error al crear sandbox."))}
    end
  end

  @impl true
  def handle_event("select_sandbox", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.sandbox_endpoints, &(&1.id == id)) do
      nil ->
        {:noreply, socket}

      endpoint ->
        requests = Platform.list_sandbox_requests(endpoint.id)

        {:noreply,
         socket
         |> assign(:sandbox_active, endpoint)
         |> assign(:sandbox_requests, requests)}
    end
  end

  @impl true
  def handle_event("delete_sandbox", %{"id" => id}, socket) do
    Platform.delete_sandbox_endpoint(id)
    endpoints = Platform.list_sandbox_endpoints(socket.assigns.project.id)

    active =
      if socket.assigns.sandbox_active && socket.assigns.sandbox_active.id == id,
        do: nil,
        else: socket.assigns.sandbox_active

    {:noreply,
     socket
     |> put_flash(:info, gettext("Sandbox eliminado."))
     |> assign(:sandbox_endpoints, endpoints)
     |> assign(:sandbox_active, active)
     |> assign(:sandbox_requests, if(active, do: socket.assigns.sandbox_requests, else: []))}
  end

  # ---------- Analytics ----------

  @impl true
  def handle_event("toggle_analytics", _, socket) do
    show = !socket.assigns.show_analytics

    analytics =
      if show and socket.assigns.analytics == %{},
        do: load_analytics(socket.assigns.project.id),
        else: socket.assigns.analytics

    {:noreply,
     socket
     |> assign(:show_analytics, show)
     |> assign(:analytics, analytics)}
  end

  # ---------- Project Selector (B11) ----------

  @impl true
  def handle_event("toggle_project_selector", _, socket) do
    {:noreply, assign(socket, :show_project_selector, !socket.assigns.show_project_selector)}
  end

  @impl true
  def handle_event("switch_project", %{"id" => id}, socket) do
    old_project = socket.assigns.project

    case Platform.get_project(id) do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("Proyecto no encontrado."))}

      project ->
        if old_project,
          do: Phoenix.PubSub.unsubscribe(StreamflixCore.PubSub, "project:#{old_project.id}")

        if connected?(socket), do: Platform.subscribe(project.id)

        api_key = Platform.get_api_key_for_project(project.id)
        events = Platform.list_events(project.id, limit: 20)
        webhooks = Platform.list_webhooks(project.id)
        webhook_health = Platform.webhooks_health(project.id)
        jobs = Platform.list_jobs(project.id, include_inactive: true)
        deliveries = Platform.list_deliveries(project_id: project.id, limit: 30)
        dead_letters = Platform.list_dead_letters(project.id)
        replays = Platform.list_replays(project.id, limit: 10)
        audit_logs = Audit.list_for_project(project.id, limit: 20)
        sandbox_endpoints = Platform.list_sandbox_endpoints(project.id)
        event_schemas = Platform.list_event_schemas(project.id)
        team_members = Teams.list_members(project.id)
        analytics = load_analytics(project.id)

        {:noreply,
         socket
         |> assign(:project, project)
         |> assign(:api_key, api_key)
         |> assign(:events, events)
         |> assign(:webhooks, webhooks)
         |> assign(:webhook_health, webhook_health)
         |> assign(:jobs, jobs)
         |> assign(:deliveries, deliveries)
         |> assign(:dead_letters, dead_letters)
         |> assign(:replays, replays)
         |> assign(:audit_logs, audit_logs)
         |> assign(:sandbox_endpoints, sandbox_endpoints)
         |> assign(:sandbox_active, nil)
         |> assign(:sandbox_requests, [])
         |> assign(:event_schemas, event_schemas)
         |> assign(:team_members, team_members)
         |> assign(:analytics, analytics)
         |> assign(:show_project_selector, false)
         |> assign(:new_token, nil)
         |> assign(:token_source, nil)
         |> put_flash(:info, gettext("Proyecto cambiado a: %{name}", name: project.name))}
    end
  end

  @impl true
  def handle_event("create_project", %{"name" => name}, socket) do
    user = socket.assigns.current_user
    name = String.trim(name)

    if name == "" do
      {:noreply, put_flash(socket, :error, gettext("El nombre no puede estar vacío."))}
    else
      case Platform.create_project(%{user_id: user.id, name: name}) do
        {:ok, project} ->
          Platform.create_api_key(project.id, %{name: "Default"})
          projects = Teams.list_all_accessible_projects(user.id)

          {:noreply,
           socket
           |> assign(:projects, projects)
           |> put_flash(:info, gettext("Proyecto creado: %{name}", name: project.name))}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Error al crear proyecto."))}
      end
    end
  end

  @impl true
  def handle_event("delete_project", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    case Platform.get_project(id) do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("Proyecto no encontrado."))}

      project ->
        if project.user_id != user.id do
          {:noreply,
           put_flash(socket, :error, gettext("Solo el dueño puede eliminar el proyecto."))}
        else
          case Platform.delete_project(project) do
            {:ok, _} ->
              projects = Teams.list_all_accessible_projects(user.id)
              new_project = List.first(projects)

              socket =
                socket
                |> assign(:projects, projects)
                |> assign(:project, new_project)
                |> put_flash(:info, gettext("Proyecto eliminado."))

              if new_project do
                events = Platform.list_events(new_project.id, limit: 20)
                webhooks = Platform.list_webhooks(new_project.id)
                api_key = Platform.get_api_key_for_project(new_project.id)

                socket
                |> assign(:api_key, api_key)
                |> assign(:events, events)
                |> assign(:webhooks, webhooks)
              else
                socket
                |> assign(:api_key, nil)
                |> assign(:events, [])
                |> assign(:webhooks, [])
              end
              |> then(&{:noreply, &1})

            {:error, _} ->
              {:noreply, put_flash(socket, :error, gettext("Error al eliminar proyecto."))}
          end
        end
    end
  end

  # ---------- Event Schemas (B14) ----------

  @impl true
  def handle_event("create_event_schema", %{"topic" => topic, "schema" => schema_str}, socket) do
    project = socket.assigns.project

    case Jason.decode(schema_str) do
      {:ok, schema_map} ->
        case Platform.create_event_schema(project.id, %{"topic" => topic, "schema" => schema_map}) do
          {:ok, _} ->
            schemas = Platform.list_event_schemas(project.id)

            {:noreply,
             socket
             |> assign(:event_schemas, schemas)
             |> put_flash(:info, gettext("Schema creado."))}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, gettext("Error al crear schema."))}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("JSON inválido para el schema."))}
    end
  end

  @impl true
  def handle_event("delete_event_schema", %{"id" => id}, socket) do
    project = socket.assigns.project

    case Platform.get_event_schema(id) do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("Schema no encontrado."))}

      schema ->
        if schema.project_id == project.id do
          Platform.delete_event_schema(schema)
          schemas = Platform.list_event_schemas(project.id)

          {:noreply,
           socket
           |> assign(:event_schemas, schemas)
           |> put_flash(:info, gettext("Schema eliminado."))}
        else
          {:noreply, put_flash(socket, :error, gettext("Schema no encontrado."))}
        end
    end
  end

  # ---------- Team Management (B20) ----------

  @impl true
  def handle_event("invite_member", %{"email" => email, "role" => role}, socket) do
    project = socket.assigns.project
    user = socket.assigns.current_user

    case StreamflixAccounts.get_user_by_email(email) do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("Usuario no encontrado con ese email."))}

      target_user ->
        case Teams.invite_member(project.id, target_user.id, role, user.id) do
          {:ok, _member} ->
            Notifications.create(%{
              user_id: target_user.id,
              type: "team_invite",
              title: "Invitación a proyecto",
              message: "Has sido invitado al proyecto #{project.name} como #{role}.",
              metadata: %{"project_id" => project.id}
            })

            members = Teams.list_members(project.id)

            {:noreply,
             socket
             |> assign(:team_members, members)
             |> put_flash(:info, gettext("Miembro invitado."))}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, gettext("Error al invitar miembro."))}
        end
    end
  end

  @impl true
  def handle_event("remove_member", %{"id" => id}, socket) do
    case Teams.remove_member(id) do
      {:ok, _} ->
        members = Teams.list_members(socket.assigns.project.id)

        {:noreply,
         socket
         |> assign(:team_members, members)
         |> put_flash(:info, gettext("Miembro removido."))}

      {:error, :cannot_remove_owner} ->
        {:noreply, put_flash(socket, :error, gettext("No se puede remover al dueño."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Error al remover miembro."))}
    end
  end

  @impl true
  def handle_event("update_member_role", %{"id" => id, "role" => role}, socket) do
    case Teams.update_member_role(id, role) do
      {:ok, _} ->
        members = Teams.list_members(socket.assigns.project.id)

        {:noreply,
         socket |> assign(:team_members, members) |> put_flash(:info, gettext("Rol actualizado."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Error al actualizar rol."))}
    end
  end

  # ---------- PubSub handlers (real-time) ----------

  @impl true
  def handle_info({:event_created, _event}, socket) do
    project = socket.assigns.project
    events = Platform.list_events(project.id, limit: 20)
    deliveries = Platform.list_deliveries(project_id: project.id, limit: 30)
    {:noreply, socket |> assign(:events, events) |> assign(:deliveries, deliveries)}
  end

  @impl true
  def handle_info({:delivery_updated, _delivery}, socket) do
    project = socket.assigns.project
    deliveries = Platform.list_deliveries(project_id: project.id, limit: 30)
    {:noreply, assign(socket, :deliveries, deliveries)}
  end

  @impl true
  def handle_info({:new_notification, _notif}, socket) do
    user = socket.assigns.current_user
    notifications = Notifications.list_for_user(user.id, limit: 10)
    unread_count = Notifications.unread_count(user.id)

    {:noreply,
     socket
     |> assign(:notifications, notifications)
     |> assign(:unread_count, unread_count)}
  end

  @impl true
  def handle_info(:notifications_read, socket) do
    {:noreply, assign(socket, :unread_count, 0)}
  end

  @impl true
  def handle_info({:replay_progress, %{id: _id, status: _status} = _progress}, socket) do
    replays = Platform.list_replays(socket.assigns.project.id, limit: 10)
    {:noreply, assign(socket, :replays, replays)}
  end

  @impl true
  def handle_info({:sandbox_request, req}, socket) do
    active = socket.assigns.sandbox_active

    if active && req.endpoint_id == active.id do
      requests = [req | socket.assigns.sandbox_requests] |> Enum.take(50)
      {:noreply, assign(socket, :sandbox_requests, requests)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={:platform}
      current_user={@current_user}
      locale={@locale}
      active_page={@active_page}
    >
      <div>
        <div class="flex items-center justify-between mb-6 sm:mb-8">
          <div class="flex items-center gap-3">
            <h1 class="text-xl sm:text-2xl font-bold text-slate-900">{gettext("Dashboard")}</h1>
            <%!-- Project Selector (B11) --%>
            <%= if length(@projects) > 1 do %>
              <div class="relative">
                <button
                  type="button"
                  phx-click="toggle_project_selector"
                  class="inline-flex items-center gap-1.5 px-3 py-1.5 bg-indigo-50 hover:bg-indigo-100 text-indigo-700 rounded-lg text-sm font-medium transition border border-indigo-200"
                >
                  <.icon name="hero-rectangle-stack" class="w-4 h-4" />
                  <span class="hidden sm:inline truncate max-w-[10rem]">
                    {@project && @project.name}
                  </span>
                  <.icon name="hero-chevron-down" class="w-3.5 h-3.5" />
                </button>
                <%= if @show_project_selector do %>
                  <div class="fixed inset-x-3 top-20 sm:absolute sm:inset-x-auto sm:top-auto sm:right-0 mt-1 sm:w-72 bg-white rounded-xl shadow-xl border border-slate-200 z-50 max-h-80 overflow-y-auto">
                    <div class="p-3 border-b border-slate-200">
                      <.form
                        for={%{}}
                        id="create-project-form"
                        phx-submit="create_project"
                        class="flex gap-2"
                      >
                        <input
                          type="text"
                          name="name"
                          placeholder={gettext("Nuevo proyecto...")}
                          class="flex-1 min-w-0 border border-slate-300 rounded-lg px-3 py-1.5 text-sm"
                        />
                        <button
                          type="submit"
                          class="px-3 py-1.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-xs font-medium"
                        >
                          {gettext("Crear")}
                        </button>
                      </.form>
                    </div>

                    <%= for p <- @projects do %>
                      <div
                        class={"flex items-center justify-between px-4 py-2.5 hover:bg-slate-50 cursor-pointer transition #{if @project && @project.id == p.id, do: "bg-indigo-50/50"}"}
                        phx-click="switch_project"
                        phx-value-id={p.id}
                      >
                        <div class="min-w-0">
                          <p class="text-sm font-medium text-slate-800 truncate">{p.name}</p>

                          <p class="text-[10px] text-slate-400 font-mono">
                            {String.slice(p.id, 0, 8)}...
                          </p>
                        </div>

                        <div class="flex items-center gap-1.5 shrink-0">
                          <%= if p.is_default do %>
                            <span class="px-1.5 py-0.5 rounded text-[10px] font-medium bg-indigo-100 text-indigo-700">
                              {gettext("Default")}
                            </span>
                          <% end %>

                          <%= if p.user_id != @current_user.id do %>
                            <span class="px-1.5 py-0.5 rounded text-[10px] font-medium bg-slate-100 text-slate-600">
                              {gettext("Miembro")}
                            </span>
                          <% end %>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
          <%!-- Notification Bell --%>
          <div class="relative">
            <button
              type="button"
              phx-click="toggle_notifications"
              class="relative p-2 text-slate-500 hover:text-slate-700 hover:bg-slate-100 rounded-lg transition"
            >
              <.icon name="hero-bell" class="w-6 h-6" />
              <%= if @unread_count > 0 do %>
                <span class="absolute -top-0.5 -right-0.5 flex items-center justify-center w-5 h-5 text-[10px] font-bold text-white bg-red-500 rounded-full">
                  {@unread_count}
                </span>
              <% end %>
            </button>
            <%= if @show_notifications do %>
              <div class="fixed inset-x-3 top-16 sm:absolute sm:inset-x-auto sm:top-auto sm:right-0 mt-2 sm:w-96 bg-white rounded-xl shadow-xl border border-slate-200 z-50 max-h-96 overflow-y-auto">
                <div class="flex items-center justify-between px-4 py-3 border-b border-slate-200">
                  <h3 class="font-semibold text-slate-900 text-sm">{gettext("Notificaciones")}</h3>

                  <%= if @unread_count > 0 do %>
                    <button
                      phx-click="mark_all_read"
                      class="text-xs text-indigo-600 hover:text-indigo-700 font-medium"
                    >
                      {gettext("Marcar todo leído")}
                    </button>
                  <% end %>
                </div>

                <%= if @notifications == [] do %>
                  <div class="px-4 py-8 text-center text-sm text-slate-400">
                    {gettext("Sin notificaciones")}
                  </div>
                <% else %>
                  <%= for notif <- @notifications do %>
                    <div
                      class={"px-4 py-3 border-b border-slate-100 last:border-0 hover:bg-slate-50 transition cursor-pointer #{if !notif.read, do: "bg-indigo-50/50"}"}
                      phx-click="mark_notification_read"
                      phx-value-id={notif.id}
                    >
                      <div class="flex items-start gap-2">
                        <span class={"mt-1 w-2 h-2 rounded-full shrink-0 #{if !notif.read, do: "bg-indigo-500", else: "bg-transparent"}"}>
                        </span>
                        <div class="min-w-0">
                          <p class="text-sm font-medium text-slate-900 truncate">
                            {notification_title(notif)}
                          </p>

                          <p class="text-xs text-slate-500 truncate">{notification_message(notif)}</p>

                          <p class="text-[10px] text-slate-400 mt-1">
                            {format_dt(notif.inserted_at)}
                          </p>
                        </div>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <%= if @project do %>
          <div class="space-y-6 sm:space-y-8">
            <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 overflow-hidden">
              <h2 class="text-lg font-semibold text-slate-900 mb-2">{gettext("Proyecto")}</h2>

              <%= if @editing_project_name do %>
                <.form
                  for={%{}}
                  id="project-name-form"
                  phx-submit="update_project_name"
                  class="flex flex-wrap items-center gap-2"
                >
                  <.input
                    type="text"
                    name="name"
                    value={@project.name}
                    class="w-full max-w-xs px-3 py-2 bg-white border border-slate-300 rounded-lg text-slate-900"
                    placeholder={gettext("Nombre del proyecto")}
                  />
                  <button
                    type="submit"
                    phx-disable-with={gettext("Guardando...")}
                    class="px-3 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-sm font-medium disabled:opacity-70 disabled:cursor-not-allowed"
                  >
                    {gettext("Guardar")}
                  </button>
                  <button
                    type="button"
                    phx-click="cancel_edit_project_name"
                    class="px-3 py-2 bg-slate-200 hover:bg-slate-300 text-slate-800 rounded-lg text-sm font-medium"
                  >
                    {gettext("Cancelar")}
                  </button>
                </.form>
              <% else %>
                <p class="text-slate-600">
                  <strong>{@project.name}</strong>
                  <button
                    type="button"
                    phx-click="edit_project_name"
                    class="ml-2 text-indigo-600 hover:text-indigo-700 text-sm font-medium"
                  >
                    {gettext("Editar nombre")}
                  </button>
                </p>
              <% end %>

              <p class="text-slate-500 text-sm font-mono mt-1 break-all">{@project.id}</p>
            </section>

            <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 overflow-hidden">
              <h2 class="text-lg font-semibold text-slate-900 mb-1">{gettext("API Token")}</h2>

              <p class="text-slate-500 text-xs sm:text-sm mb-3 break-words">
                {gettext("Header:")}
                <code class="bg-slate-100 px-1 rounded text-xs break-all">
                  Authorization: Bearer &lt;token&gt;
                </code>
                {gettext("o")}
                <code class="bg-slate-100 px-1 rounded text-xs">X-Api-Key</code>
              </p>
              <%!-- State 1: Fresh token from registration --%>
              <%= if @new_token && @token_source == :registration do %>
                <div class="rounded-lg border-2 border-emerald-300 bg-emerald-50 p-3 sm:p-4">
                  <div class="flex items-center gap-2 mb-3">
                    <.icon name="hero-check-circle" class="w-5 h-5 text-emerald-600" />
                    <span class="text-emerald-800 font-medium text-sm">
                      {gettext("Tu API token ha sido creado. Cópialo y guárdalo ahora.")}
                    </span>
                  </div>

                  <div class="flex items-stretch gap-0 overflow-hidden rounded-lg border border-emerald-200 bg-white">
                    <input
                      id="token-input"
                      type="text"
                      readonly
                      value={if @token_visible, do: @new_token, else: String.duplicate("•", 38)}
                      data-real-value={@new_token}
                      class="flex-1 min-w-0 font-mono text-sm px-4 py-3 bg-transparent border-0 text-slate-900 focus:ring-0"
                      phx-no-feedback
                    />
                    <button
                      type="button"
                      phx-click="toggle_token_visibility"
                      class="p-3 border-l border-emerald-200 bg-white hover:bg-slate-50 text-slate-500 hover:text-slate-700 transition"
                      title={if @token_visible, do: gettext("Ocultar"), else: gettext("Mostrar")}
                      aria-label={
                        if @token_visible,
                          do: gettext("Ocultar token"),
                          else: gettext("Mostrar token")
                      }
                    >
                      <%= if @token_visible do %>
                        <.icon name="hero-eye-slash" class="w-5 h-5" />
                      <% else %>
                        <.icon name="hero-eye" class="w-5 h-5" />
                      <% end %>
                    </button>
                    <button
                      type="button"
                      id="copy-token-btn"
                      phx-hook="CopyClipboard"
                      data-copy-target="token-input"
                      class="p-3 border-l border-emerald-200 bg-white hover:bg-slate-50 text-slate-500 hover:text-emerald-600 transition"
                      title={gettext("Copiar token")}
                      aria-label={gettext("Copiar token")}
                    >
                      <span data-copy-icon>
                        <.icon name="hero-clipboard-document" class="w-5 h-5" />
                      </span>
                      <span data-check-icon class="hidden">
                        <.icon name="hero-check" class="w-5 h-5 text-emerald-600" />
                      </span>
                    </button>
                  </div>
                </div>

                <div class="mt-3 flex items-center gap-3">
                  <button
                    phx-click="regenerate_token"
                    phx-disable-with={gettext("Regenerando...")}
                    data-confirm={gettext("¿Regenerar token? El token actual dejará de funcionar.")}
                    type="button"
                    class="px-4 py-2 bg-slate-200 hover:bg-slate-300 text-slate-800 rounded-lg font-medium text-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
                  >
                    {gettext("Regenerar token")}
                  </button>
                </div>
                <%!-- State 2: Regenerated token --%>
              <% else %>
                <%= if @new_token && @token_source == :regenerated do %>
                  <div class="rounded-lg border-2 border-amber-300 bg-amber-50 p-3 sm:p-4">
                    <div class="flex items-center gap-2 mb-3">
                      <.icon name="hero-exclamation-triangle" class="w-5 h-5 text-amber-600" />
                      <span class="text-amber-800 font-medium text-sm">
                        {gettext("El token anterior ha sido revocado. Copia y guarda el nuevo.")}
                      </span>
                    </div>

                    <div class="flex items-stretch gap-0 overflow-hidden rounded-lg border border-amber-200 bg-white">
                      <input
                        id="token-input"
                        type="text"
                        readonly
                        value={if @token_visible, do: @new_token, else: String.duplicate("•", 38)}
                        data-real-value={@new_token}
                        class="flex-1 min-w-0 font-mono text-sm px-4 py-3 bg-transparent border-0 text-slate-900 focus:ring-0"
                        phx-no-feedback
                      />
                      <button
                        type="button"
                        phx-click="toggle_token_visibility"
                        class="p-3 border-l border-amber-200 bg-white hover:bg-slate-50 text-slate-500 hover:text-slate-700 transition"
                        title={if @token_visible, do: gettext("Ocultar"), else: gettext("Mostrar")}
                        aria-label={
                          if @token_visible,
                            do: gettext("Ocultar token"),
                            else: gettext("Mostrar token")
                        }
                      >
                        <%= if @token_visible do %>
                          <.icon name="hero-eye-slash" class="w-5 h-5" />
                        <% else %>
                          <.icon name="hero-eye" class="w-5 h-5" />
                        <% end %>
                      </button>
                      <button
                        type="button"
                        id="copy-token-btn"
                        phx-hook="CopyClipboard"
                        data-copy-target="token-input"
                        class="p-3 border-l border-amber-200 bg-white hover:bg-slate-50 text-slate-500 hover:text-amber-600 transition"
                        title={gettext("Copiar token")}
                        aria-label={gettext("Copiar token")}
                      >
                        <span data-copy-icon>
                          <.icon name="hero-clipboard-document" class="w-5 h-5" />
                        </span>
                        <span data-check-icon class="hidden">
                          <.icon name="hero-check" class="w-5 h-5 text-amber-600" />
                        </span>
                      </button>
                    </div>
                  </div>

                  <div class="mt-3 flex items-center gap-3">
                    <button
                      phx-click="regenerate_token"
                      phx-disable-with={gettext("Regenerando...")}
                      data-confirm={gettext("¿Regenerar token? El token actual dejará de funcionar.")}
                      type="button"
                      class="px-4 py-2 bg-slate-200 hover:bg-slate-300 text-slate-800 rounded-lg font-medium text-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
                    >
                      {gettext("Regenerar token")}
                    </button>
                  </div>
                  <%!-- State 3: Prefix only (no full token available) --%>
                <% else %>
                  <%= if @api_key != nil do %>
                    <div class="rounded-lg border border-slate-200 bg-slate-50">
                      <input
                        type="text"
                        readonly
                        value={"#{@api_key.prefix}••••••••••"}
                        class="w-full font-mono text-sm px-4 py-3 bg-transparent border-0 text-slate-600 focus:ring-0"
                        aria-label={gettext("Prefijo del token")}
                      />
                    </div>

                    <p class="text-slate-500 text-sm mt-2">
                      {gettext("Solo se muestra el prefijo. Regenera para obtener el token completo.")}
                    </p>

                    <div class="flex flex-col sm:flex-row gap-2 mt-3">
                      <button
                        phx-click="regenerate_token"
                        phx-disable-with={gettext("Regenerando...")}
                        data-confirm={
                          gettext("¿Regenerar token? El token actual dejará de funcionar.")
                        }
                        type="button"
                        class="px-4 py-2 bg-slate-200 hover:bg-slate-300 text-slate-800 rounded-lg font-medium text-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
                      >
                        {gettext("Regenerar token")}
                      </button>
                    </div>
                    <%!-- Scopes & IP Allowlist info --%>
                    <div class="mt-4 pt-4 border-t border-slate-200 space-y-2">
                      <div class="flex items-center gap-2">
                        <span class="text-xs font-medium text-slate-500 uppercase">
                          {gettext("Scopes")}:
                        </span>
                        <%= for scope <- (@api_key.scopes || ["*"]) do %>
                          <span class="px-2 py-0.5 bg-indigo-50 text-indigo-700 rounded text-xs font-mono">
                            {scope}
                          </span>
                        <% end %>
                      </div>

                      <div class="flex items-start gap-2">
                        <span class="text-xs font-medium text-slate-500 uppercase shrink-0">
                          {gettext("IPs permitidas")}:
                        </span>
                        <%= if @api_key.allowed_ips && @api_key.allowed_ips != [] do %>
                          <div class="flex flex-wrap gap-1">
                            <%= for ip <- @api_key.allowed_ips do %>
                              <span class="px-2 py-0.5 bg-emerald-50 text-emerald-700 rounded text-xs font-mono">
                                {ip}
                              </span>
                            <% end %>
                          </div>
                        <% else %>
                          <span class="text-xs text-slate-400">
                            {gettext("Sin restricción (cualquier IP)")}
                          </span>
                        <% end %>
                      </div>
                    </div>
                    <%!-- State 4: No API key at all --%>
                  <% else %>
                    <p class="text-slate-600 mb-3">
                      {gettext("No hay API token. Genera uno para empezar.")}
                    </p>

                    <button
                      phx-click="regenerate_token"
                      phx-disable-with={gettext("Generando...")}
                      type="button"
                      class="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg font-medium text-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
                    >
                      {gettext("Generar token")}
                    </button>
                  <% end %>
                <% end %>
              <% end %>
            </section>

            <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 overflow-hidden">
              <h2 class="text-lg font-semibold text-slate-900 mb-4">
                {gettext("Enviar evento de prueba")}
              </h2>

              <.form
                for={%{}}
                id="test-event-form"
                phx-submit="send_test"
                class="space-y-3 sm:max-w-lg"
              >
                <.input
                  type="text"
                  name="topic"
                  id="test-topic"
                  value={@test_topic}
                  placeholder={gettext("Topic (opcional)")}
                  class="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg text-slate-900 placeholder-slate-400 font-mono text-sm"
                />
                <.input
                  type="textarea"
                  name="payload"
                  id="test-payload"
                  value={@test_payload}
                  class="w-full px-3 py-2 bg-white border border-slate-300 rounded-lg text-slate-900 placeholder-slate-400 font-mono text-sm"
                />
                <div class="flex gap-2">
                  <button
                    type="submit"
                    phx-disable-with={gettext("Enviando...")}
                    class="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg font-medium text-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
                  >
                    {gettext("Enviar")}
                  </button>
                  <button
                    type="button"
                    phx-click="simulate_event"
                    phx-value-topic={@test_topic}
                    phx-value-payload={@test_payload}
                    phx-disable-with={gettext("Simulando...")}
                    class="px-4 py-2 bg-amber-500 hover:bg-amber-600 text-white rounded-lg font-medium text-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
                  >
                    {gettext("Simular")}
                  </button>
                </div>
              </.form>
              <%!-- Simulation Result --%>
              <%= if @simulation_result do %>
                <div class="mt-4 p-4 bg-amber-50 border border-amber-200 rounded-lg">
                  <div class="flex items-center justify-between mb-3">
                    <h3 class="font-semibold text-amber-900">{gettext("Resultado de simulación")}</h3>

                    <button
                      type="button"
                      phx-click="close_simulation"
                      class="text-amber-600 hover:text-amber-800 text-sm"
                    >
                      {gettext("Cerrar")}
                    </button>
                  </div>

                  <%= if @simulation_result == [] do %>
                    <p class="text-sm text-amber-800">
                      {gettext("Ningún webhook matchearía con este evento.")}
                    </p>
                  <% else %>
                    <p class="text-sm text-amber-800 mb-2">
                      {gettext("%{count} webhook(s) recibirían este evento:",
                        count: length(@simulation_result)
                      )}
                    </p>

                    <%= for sim <- @simulation_result do %>
                      <div class="mt-2 p-3 bg-white border border-amber-100 rounded text-sm">
                        <p class="font-mono text-xs text-slate-600 truncate">{sim.webhook_url}</p>

                        <p class="text-xs text-slate-500 mt-1">
                          {gettext("Topics")}:
                          <span class="font-medium">
                            {if sim.matched_by_topics, do: "✓", else: "✗"}
                          </span>
                          · {gettext("Filtros")}:
                          <span class="font-medium">
                            {if sim.matched_by_filters, do: "✓", else: "✗"}
                          </span>
                          <%= if sim.would_send_headers["x-signature"] do %>
                            · HMAC:
                            <span class="font-mono text-xs">
                              {String.slice(sim.would_send_headers["x-signature"], 0, 20)}...
                            </span>
                          <% end %>
                        </p>
                      </div>
                    <% end %>
                  <% end %>
                </div>
              <% end %>
            </section>

            <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 overflow-hidden">
              <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-4">
                <h2 class="text-lg font-semibold text-slate-900">{gettext("Eventos recientes")}</h2>

                <div class="flex flex-wrap gap-2">
                  <a
                    href="/api/v1/export/events?format=csv"
                    target="_blank"
                    class="inline-flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-lg transition"
                  >
                    <.icon name="hero-arrow-down-tray" class="w-3.5 h-3.5" /> CSV
                  </a>
                  <a
                    href="/api/v1/export/events?format=json"
                    target="_blank"
                    class="inline-flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-lg transition"
                  >
                    <.icon name="hero-arrow-down-tray" class="w-3.5 h-3.5" /> JSON
                  </a>
                </div>
              </div>

              <div class="overflow-x-auto rounded-lg border border-slate-200">
                <table class="min-w-full">
                  <thead>
                    <tr class="bg-slate-50 border-b border-slate-200">
                      <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                        ID
                      </th>

                      <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                        {gettext("Topic")}
                      </th>

                      <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                        {gettext("Estado")}
                      </th>

                      <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700 hidden sm:table-cell">
                        {gettext("Fecha")}
                      </th>
                    </tr>
                  </thead>

                  <tbody>
                    <%= for e <- @events do %>
                      <tr class="border-b border-slate-100 last:border-0">
                        <td class="px-3 sm:px-4 py-2 sm:py-3 font-mono text-xs sm:text-sm text-slate-600">
                          {String.slice(e.id, 0, 8)}...
                        </td>

                        <td class="px-3 sm:px-4 py-2 sm:py-3 text-sm text-slate-700 truncate max-w-[8rem] sm:max-w-none">
                          {e.topic || "—"}
                        </td>

                        <td class="px-3 sm:px-4 py-2 sm:py-3">
                          <span class="px-2 py-0.5 rounded text-xs font-medium bg-slate-100 text-slate-700">
                            {e.status}
                          </span>
                          <%= if e.deliver_at && DateTime.compare(e.deliver_at, DateTime.utc_now()) == :gt do %>
                            <span class="ml-1 px-1.5 py-0.5 rounded text-[10px] font-medium bg-amber-100 text-amber-700">
                              {gettext("Programado")}
                            </span>
                          <% end %>
                        </td>

                        <td class="px-3 sm:px-4 py-2 sm:py-3 text-sm text-slate-600 hidden sm:table-cell">
                          {format_dt(e.occurred_at)}
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </section>

            <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 overflow-hidden">
              <h2 class="text-lg font-semibold text-slate-900 mb-4">{gettext("Webhooks")}</h2>

              <div class="overflow-x-auto rounded-lg border border-slate-200">
                <table class="min-w-full">
                  <thead>
                    <tr class="bg-slate-50 border-b border-slate-200">
                      <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                        URL
                      </th>

                      <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                        {gettext("Salud")}
                      </th>

                      <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                        {gettext("Estado")}
                      </th>
                    </tr>
                  </thead>

                  <tbody>
                    <%= for w <- @webhooks do %>
                      <% health = @webhook_health[w.id] %>
                      <tr class="border-b border-slate-100 last:border-0">
                        <td class="px-3 sm:px-4 py-2 sm:py-3 font-mono text-xs sm:text-sm text-slate-600 truncate max-w-[12rem] sm:max-w-none">
                          {w.url}
                        </td>

                        <td class="px-3 sm:px-4 py-2 sm:py-3">
                          <%= if health do %>
                            <span
                              title={"#{health.success_rate}% — #{health.total} deliveries (24h)"}
                              class={"inline-flex items-center gap-1 px-2 py-0.5 rounded text-xs font-medium #{health_class(health.score)}"}
                            >
                              <span class={"w-2 h-2 rounded-full #{health_dot(health.score)}"}></span> {health_label(
                                health.score
                              )}
                            </span>
                          <% end %>
                        </td>

                        <td class="px-3 sm:px-4 py-2 sm:py-3">
                          <span class="px-2 py-0.5 rounded text-xs font-medium bg-slate-100 text-slate-700">
                            {w.status}
                          </span>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </section>

            <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 overflow-hidden">
              <div class="flex flex-wrap items-center justify-between gap-3 sm:gap-4 mb-4 sm:mb-6">
                <h2 class="text-lg font-semibold text-slate-900">{gettext("Jobs")}</h2>

                <div class="flex flex-wrap gap-2">
                  <a
                    href="/api/v1/export/jobs?format=csv"
                    target="_blank"
                    class="inline-flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-lg transition"
                  >
                    <.icon name="hero-arrow-down-tray" class="w-3.5 h-3.5" /> CSV
                  </a>
                  <button
                    type="button"
                    phx-click="new_job"
                    phx-disable-with={gettext("Cargando...")}
                    class="inline-flex items-center gap-2 px-3 sm:px-4 py-2 sm:py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl font-medium text-sm shadow-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
                  >
                    <.icon name="hero-plus" class="w-4 h-4" /> {gettext("Nuevo job")}
                  </button>
                </div>
              </div>

              <div class="overflow-x-auto rounded-xl border border-slate-200">
                <table class="min-w-full divide-y divide-slate-200">
                  <thead>
                    <tr class="bg-slate-50/80">
                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">
                        {gettext("Nombre")}
                      </th>

                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider hidden sm:table-cell">
                        {gettext("Programación")}
                      </th>

                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider hidden sm:table-cell">
                        {gettext("Acción")}
                      </th>

                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">
                        {gettext("Estado")}
                      </th>

                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-right text-xs font-semibold text-slate-600 uppercase tracking-wider">
                        {gettext("Acciones")}
                      </th>
                    </tr>
                  </thead>

                  <tbody class="divide-y divide-slate-100">
                    <%= for j <- @jobs do %>
                      <tr class="hover:bg-slate-50/50 transition">
                        <td class="px-3 sm:px-5 py-3 sm:py-4 font-medium text-slate-800 text-sm">
                          {j.name}
                        </td>

                        <td class="px-3 sm:px-5 py-3 sm:py-4 text-sm text-slate-600 hidden sm:table-cell">
                          {j.schedule_type}
                        </td>

                        <td class="px-3 sm:px-5 py-3 sm:py-4 text-sm text-slate-600 hidden sm:table-cell">
                          {j.action_type}
                        </td>

                        <td class="px-3 sm:px-5 py-3 sm:py-4">
                          <span class={[
                            "inline-flex px-2 sm:px-2.5 py-0.5 sm:py-1 rounded-lg text-xs font-medium",
                            if(j.status == "active",
                              do: "bg-emerald-100 text-emerald-800",
                              else: "bg-slate-200 text-slate-600"
                            )
                          ]}>
                            {j.status}
                          </span>
                        </td>

                        <td class="px-3 sm:px-5 py-3 sm:py-4 text-right">
                          <div class="flex flex-col sm:flex-row sm:inline-flex gap-1 sm:gap-2 items-end sm:items-center">
                            <button
                              phx-click="edit_job"
                              phx-value-id={j.id}
                              phx-disable-with={gettext("Cargando...")}
                              class="text-indigo-600 hover:text-indigo-700 font-medium text-xs sm:text-sm disabled:opacity-70"
                            >
                              {gettext("Editar")}
                            </button>
                            <button
                              phx-click="show_job_runs"
                              phx-value-id={j.id}
                              phx-disable-with={gettext("Cargando...")}
                              class="text-slate-600 hover:text-slate-700 font-medium text-xs sm:text-sm disabled:opacity-70"
                            >
                              {gettext("Runs")}
                            </button>
                            <%= if j.status == "active" do %>
                              <button
                                phx-click="deactivate_job"
                                phx-value-id={j.id}
                                phx-disable-with={gettext("Desactivando...")}
                                class="text-red-600 hover:text-red-700 font-medium text-xs sm:text-sm disabled:opacity-70"
                              >
                                {gettext("Desactivar")}
                              </button>
                            <% end %>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </section>

            <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 overflow-hidden">
              <h2 class="text-lg font-semibold text-slate-900 mb-4 sm:mb-6">{gettext("Entregas")}</h2>

              <div class="overflow-x-auto rounded-xl border border-slate-200">
                <table class="min-w-full divide-y divide-slate-200">
                  <thead>
                    <tr class="bg-slate-50/80">
                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">
                        {gettext("Evento / Topic")}
                      </th>

                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider hidden md:table-cell">
                        {gettext("Webhook")}
                      </th>

                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">
                        {gettext("Estado")}
                      </th>

                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider hidden lg:table-cell">
                        {gettext("Intento")}
                      </th>

                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider hidden sm:table-cell">
                        {gettext("HTTP")}
                      </th>

                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider hidden sm:table-cell">
                        {gettext("Fecha")}
                      </th>

                      <th class="px-3 sm:px-5 py-2.5 sm:py-3.5 text-right text-xs font-semibold text-slate-600 uppercase tracking-wider">
                        {gettext("Acciones")}
                      </th>
                    </tr>
                  </thead>

                  <tbody class="divide-y divide-slate-100">
                    <%= for d <- @deliveries do %>
                      <tr class="hover:bg-slate-50/50 transition">
                        <td class="px-3 sm:px-5 py-3 sm:py-4 text-xs sm:text-sm text-slate-600 font-mono truncate max-w-[8rem] sm:max-w-none">
                          {if d.event,
                            do: d.event.topic || String.slice(d.event_id, 0, 8),
                            else: String.slice(d.event_id, 0, 8)}
                        </td>

                        <td class="px-3 sm:px-5 py-3 sm:py-4 font-mono text-xs text-slate-600 max-w-[14rem] truncate hidden md:table-cell">
                          {if d.webhook, do: d.webhook.url, else: d.webhook_id}
                        </td>

                        <td class="px-3 sm:px-5 py-3 sm:py-4">
                          <span class={[
                            "inline-flex px-2 sm:px-2.5 py-0.5 sm:py-1 rounded-lg text-xs font-medium",
                            if(d.status == "success",
                              do: "bg-emerald-100 text-emerald-800",
                              else:
                                if(d.status == "pending",
                                  do: "bg-amber-100 text-amber-800",
                                  else: "bg-red-100 text-red-800"
                                )
                            )
                          ]}>
                            {d.status}
                          </span>
                        </td>

                        <td class="px-3 sm:px-5 py-3 sm:py-4 text-sm text-slate-600 hidden lg:table-cell">
                          {d.attempt_number}
                        </td>

                        <td class="px-3 sm:px-5 py-3 sm:py-4 text-sm text-slate-600 font-mono hidden sm:table-cell">
                          {d.response_status || "—"}
                        </td>

                        <td class="px-3 sm:px-5 py-3 sm:py-4 text-sm text-slate-600 hidden sm:table-cell">
                          {format_dt(d.inserted_at)}
                        </td>

                        <td class="px-3 sm:px-5 py-3 sm:py-4 text-right">
                          <%= if d.status != "success" and d.status != "pending" do %>
                            <button
                              phx-click="retry_delivery"
                              phx-value-id={d.id}
                              phx-disable-with={gettext("Reintentando...")}
                              class="text-indigo-600 hover:text-indigo-700 font-medium text-xs sm:text-sm disabled:opacity-70"
                            >
                              {gettext("Reintentar")}
                            </button>
                          <% end %>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </section>
            <%!-- Dead Letter Queue --%>
            <%= if @dead_letters != [] do %>
              <section class="bg-white rounded-xl border border-red-200 shadow-sm p-4 sm:p-6 overflow-hidden">
                <div class="flex items-center gap-2 mb-4">
                  <span class="w-2.5 h-2.5 rounded-full bg-red-500 animate-pulse"></span>
                  <h2 class="text-lg font-semibold text-red-900">{gettext("Dead Letter Queue")}</h2>

                  <span class="px-2 py-0.5 rounded-full bg-red-100 text-red-700 text-xs font-medium">
                    {length(@dead_letters)}
                  </span>
                </div>

                <p class="text-sm text-red-700 mb-4">
                  {gettext(
                    "Entregas que agotaron todos los reintentos. Puedes reintentar o descartar."
                  )}
                </p>

                <div class="overflow-x-auto rounded-lg border border-red-100">
                  <table class="min-w-full divide-y divide-red-100">
                    <thead>
                      <tr class="bg-red-50/50">
                        <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs font-semibold text-red-700 uppercase">
                          {gettext("Webhook")}
                        </th>

                        <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs font-semibold text-red-700 uppercase hidden sm:table-cell">
                          {gettext("Error")}
                        </th>

                        <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs font-semibold text-red-700 uppercase">
                          {gettext("Intentos")}
                        </th>

                        <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs font-semibold text-red-700 uppercase hidden sm:table-cell">
                          {gettext("Fecha")}
                        </th>

                        <th class="px-3 sm:px-4 py-2 sm:py-3 text-right text-xs font-semibold text-red-700 uppercase">
                          {gettext("Acciones")}
                        </th>
                      </tr>
                    </thead>

                    <tbody class="divide-y divide-red-50">
                      <%= for dl <- @dead_letters do %>
                        <tr class="hover:bg-red-50/30 transition">
                          <td class="px-3 sm:px-4 py-2 sm:py-3 font-mono text-xs text-slate-600 truncate max-w-[10rem] sm:max-w-none">
                            {if dl.webhook, do: dl.webhook.url, else: "—"}
                          </td>

                          <td class="px-3 sm:px-4 py-2 sm:py-3 text-xs text-red-700 truncate max-w-[12rem] hidden sm:table-cell">
                            {dl.last_error || "—"}
                          </td>

                          <td class="px-3 sm:px-4 py-2 sm:py-3 text-sm text-slate-600">
                            {dl.attempts_exhausted}
                          </td>

                          <td class="px-3 sm:px-4 py-2 sm:py-3 text-sm text-slate-600 hidden sm:table-cell">
                            {format_dt(dl.inserted_at)}
                          </td>

                          <td class="px-3 sm:px-4 py-2 sm:py-3 text-right">
                            <div class="flex flex-col sm:flex-row sm:justify-end gap-1">
                              <button
                                phx-click="retry_dead_letter"
                                phx-value-id={dl.id}
                                phx-disable-with={gettext("...")}
                                class="text-indigo-600 hover:text-indigo-700 font-medium text-xs disabled:opacity-70"
                              >
                                {gettext("Reintentar")}
                              </button>
                              <button
                                phx-click="resolve_dead_letter"
                                phx-value-id={dl.id}
                                phx-disable-with={gettext("...")}
                                class="text-slate-500 hover:text-slate-700 font-medium text-xs disabled:opacity-70"
                              >
                                {gettext("Descartar")}
                              </button>
                            </div>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </section>
            <% end %>
            <%!-- Event Replay --%>
            <section class="bg-white rounded-xl border border-blue-200 shadow-sm p-4 sm:p-6 overflow-hidden">
              <div class="flex flex-wrap items-center justify-between gap-3 mb-4">
                <div class="flex items-center gap-2">
                  <.icon name="hero-arrow-uturn-left" class="w-5 h-5 text-blue-600" />
                  <h2 class="text-lg font-semibold text-slate-900">{gettext("Event Replay")}</h2>
                </div>

                <button
                  type="button"
                  phx-click="open_replay_modal"
                  class="inline-flex items-center gap-2 px-3 sm:px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-medium text-sm shadow-sm transition"
                >
                  <.icon name="hero-play" class="w-4 h-4" /> {gettext("Nuevo replay")}
                </button>
              </div>

              <%= if @replays == [] do %>
                <p class="text-sm text-slate-500">
                  {gettext(
                    "No hay replays. Usa esta función para re-enviar eventos históricos a tus webhooks."
                  )}
                </p>
              <% else %>
                <div class="overflow-x-auto rounded-lg border border-slate-200">
                  <table class="min-w-full divide-y divide-slate-200">
                    <thead>
                      <tr class="bg-slate-50/80">
                        <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs font-semibold text-slate-600 uppercase">
                          {gettext("Estado")}
                        </th>

                        <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs font-semibold text-slate-600 uppercase">
                          {gettext("Progreso")}
                        </th>

                        <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs font-semibold text-slate-600 uppercase hidden sm:table-cell">
                          {gettext("Filtros")}
                        </th>

                        <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs font-semibold text-slate-600 uppercase hidden sm:table-cell">
                          {gettext("Fecha")}
                        </th>

                        <th class="px-3 sm:px-4 py-2 sm:py-3 text-right text-xs font-semibold text-slate-600 uppercase">
                          {gettext("Acciones")}
                        </th>
                      </tr>
                    </thead>

                    <tbody class="divide-y divide-slate-100">
                      <%= for r <- @replays do %>
                        <tr class="hover:bg-slate-50/50 transition">
                          <td class="px-3 sm:px-4 py-2 sm:py-3">
                            <span class={"inline-flex px-2 py-0.5 rounded text-xs font-medium #{replay_status_class(r.status)}"}>
                              {replay_status_label(r.status)}
                            </span>
                          </td>

                          <td class="px-3 sm:px-4 py-2 sm:py-3">
                            <div class="flex items-center gap-2">
                              <div class="flex-1 bg-slate-200 rounded-full h-2 max-w-[8rem]">
                                <div
                                  class="bg-blue-600 h-2 rounded-full transition-all"
                                  style={"width: #{if r.total_events > 0, do: Float.round(r.processed_events / r.total_events * 100, 0), else: 0}%"}
                                >
                                </div>
                              </div>

                              <span class="text-xs text-slate-600">
                                {r.processed_events}/{r.total_events}
                              </span>
                            </div>
                          </td>

                          <td class="px-3 sm:px-4 py-2 sm:py-3 text-xs text-slate-600 hidden sm:table-cell">
                            {if r.filters["topic"],
                              do: "topic: #{r.filters["topic"]}",
                              else: gettext("Todos")}
                          </td>

                          <td class="px-3 sm:px-4 py-2 sm:py-3 text-sm text-slate-600 hidden sm:table-cell">
                            {format_dt(r.inserted_at)}
                          </td>

                          <td class="px-3 sm:px-4 py-2 sm:py-3 text-right">
                            <%= if r.status in ["pending", "running"] do %>
                              <button
                                phx-click="cancel_replay"
                                phx-value-id={r.id}
                                class="text-red-600 hover:text-red-700 font-medium text-xs"
                              >
                                {gettext("Cancelar")}
                              </button>
                            <% end %>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              <% end %>
            </section>
            <%!-- Replay Modal --%>
            <%= if @replay_modal do %>
              <div class="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6">
                <div
                  class="absolute inset-0 bg-slate-900/60 backdrop-blur-sm"
                  phx-click="close_replay_modal"
                  aria-hidden="true"
                >
                </div>

                <div class="relative z-10 w-full max-w-lg bg-white rounded-2xl shadow-2xl p-4 sm:p-6 border border-slate-200/50">
                  <div class="flex items-center justify-between mb-4">
                    <h2 class="text-lg font-semibold text-slate-900">{gettext("Nuevo replay")}</h2>

                    <button
                      type="button"
                      phx-click="close_replay_modal"
                      class="text-slate-400 hover:text-slate-600"
                    >
                      <.icon name="hero-x-mark" class="w-5 h-5" />
                    </button>
                  </div>

                  <.form for={%{}} id="replay-form" phx-submit="start_replay" class="space-y-4">
                    <div>
                      <label class="block text-sm font-medium text-slate-700 mb-1">
                        {gettext("Topic (opcional)")}
                      </label>
                      <input
                        type="text"
                        name="topic"
                        class="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm"
                        placeholder={gettext("Filtrar por topic")}
                      />
                    </div>

                    <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                      <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1">
                          {gettext("Desde")}
                        </label>
                        <input
                          type="datetime-local"
                          name="from_date"
                          class="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm"
                        />
                      </div>

                      <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1">
                          {gettext("Hasta")}
                        </label>
                        <input
                          type="datetime-local"
                          name="to_date"
                          class="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm"
                        />
                      </div>
                    </div>

                    <div class="flex justify-end gap-3 pt-2">
                      <button
                        type="button"
                        phx-click="close_replay_modal"
                        class="px-4 py-2 border border-slate-300 rounded-lg text-slate-700 hover:bg-slate-50 text-sm font-medium"
                      >
                        {gettext("Cancelar")}
                      </button>
                      <button
                        type="submit"
                        phx-disable-with={gettext("Iniciando...")}
                        class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg text-sm font-medium"
                      >
                        {gettext("Iniciar replay")}
                      </button>
                    </div>
                  </.form>
                </div>
              </div>
            <% end %>
            <%!-- Sandbox (RequestBin) --%>
            <section class="bg-white rounded-xl border border-purple-200 shadow-sm p-4 sm:p-6 overflow-hidden">
              <div class="flex flex-wrap items-center justify-between gap-3 mb-4">
                <div class="flex items-center gap-2">
                  <.icon name="hero-beaker" class="w-5 h-5 text-purple-600" />
                  <h2 class="text-lg font-semibold text-slate-900">{gettext("Sandbox")}</h2>
                </div>

                <button
                  type="button"
                  phx-click="create_sandbox"
                  class="inline-flex items-center gap-2 px-3 sm:px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded-xl font-medium text-sm shadow-sm transition"
                >
                  <.icon name="hero-plus" class="w-4 h-4" /> {gettext("Crear endpoint")}
                </button>
              </div>

              <%= if @sandbox_endpoints == [] do %>
                <p class="text-sm text-slate-500">
                  {gettext("Crea un endpoint temporal para recibir y ver requests en tiempo real.")}
                </p>
              <% else %>
                <div class="flex flex-wrap gap-2 mb-4">
                  <%= for ep <- @sandbox_endpoints do %>
                    <div
                      class={"inline-flex items-center gap-1 px-3 py-1.5 rounded-lg border text-sm cursor-pointer transition #{if @sandbox_active && @sandbox_active.id == ep.id, do: "bg-purple-50 border-purple-300 text-purple-800", else: "bg-white border-slate-200 text-slate-600 hover:bg-slate-50"}"}
                      phx-click="select_sandbox"
                      phx-value-id={ep.id}
                    >
                      <span class="font-mono text-xs">{ep.slug}</span>
                      <button
                        type="button"
                        phx-click="delete_sandbox"
                        phx-value-id={ep.id}
                        class="ml-1 text-slate-400 hover:text-red-500"
                        title={gettext("Eliminar")}
                      >
                        <.icon name="hero-x-mark" class="w-3.5 h-3.5" />
                      </button>
                    </div>
                  <% end %>
                </div>
              <% end %>

              <%= if @sandbox_active do %>
                <div class="rounded-lg border border-purple-100 bg-purple-50/50 p-3 mb-4">
                  <p class="text-sm text-purple-800 mb-1">{gettext("URL del endpoint:")}</p>

                  <code class="text-xs font-mono text-purple-900 break-all">
                    {sandbox_url(@sandbox_active)}
                  </code>
                </div>

                <%= if @sandbox_requests == [] do %>
                  <p class="text-sm text-slate-500 text-center py-4">
                    {gettext("Esperando requests... Envía un POST/GET a la URL de arriba.")}
                  </p>
                <% else %>
                  <div class="overflow-x-auto rounded-lg border border-slate-200">
                    <table class="min-w-full divide-y divide-slate-200">
                      <thead>
                        <tr class="bg-slate-50/80">
                          <th class="px-3 sm:px-4 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                            {gettext("Método")}
                          </th>

                          <th class="px-3 sm:px-4 py-2 text-left text-xs font-semibold text-slate-600 uppercase hidden sm:table-cell">
                            {gettext("Body")}
                          </th>

                          <th class="px-3 sm:px-4 py-2 text-left text-xs font-semibold text-slate-600 uppercase hidden sm:table-cell">
                            IP
                          </th>

                          <th class="px-3 sm:px-4 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                            {gettext("Fecha")}
                          </th>
                        </tr>
                      </thead>

                      <tbody class="divide-y divide-slate-100">
                        <%= for req <- @sandbox_requests do %>
                          <tr class="hover:bg-slate-50/50 transition">
                            <td class="px-3 sm:px-4 py-2">
                              <span class={"inline-flex px-2 py-0.5 rounded text-xs font-medium #{method_color(req.method)}"}>
                                {req.method}
                              </span>
                            </td>

                            <td class="px-3 sm:px-4 py-2 text-xs text-slate-600 font-mono truncate max-w-[16rem] hidden sm:table-cell">
                              {if req.body && req.body != "",
                                do: String.slice(req.body, 0, 80),
                                else: "—"}
                            </td>

                            <td class="px-3 sm:px-4 py-2 text-xs text-slate-600 hidden sm:table-cell">
                              {req.ip || "—"}
                            </td>

                            <td class="px-3 sm:px-4 py-2 text-xs text-slate-600">
                              {format_dt(req.inserted_at)}
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                <% end %>
              <% end %>
            </section>
            <%!-- Analytics --%>
            <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 overflow-hidden">
              <div class="flex flex-wrap items-center justify-between gap-3 mb-4">
                <div class="flex items-center gap-2">
                  <.icon name="hero-chart-bar" class="w-5 h-5 text-indigo-600" />
                  <h2 class="text-lg font-semibold text-slate-900">{gettext("Analíticas")}</h2>
                </div>

                <button
                  type="button"
                  phx-click="toggle_analytics"
                  class="text-sm text-indigo-600 hover:text-indigo-700 font-medium"
                >
                  {if @show_analytics, do: gettext("Ocultar"), else: gettext("Mostrar")}
                </button>
              </div>

              <%= if @show_analytics and @analytics != %{} do %>
                <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6">
                  <%!-- Events per day chart --%>
                  <div class="border border-slate-200 rounded-lg p-3 sm:p-4">
                    <h3 class="text-sm font-semibold text-slate-700 mb-3">
                      {gettext("Eventos por día (30d)")}
                    </h3>

                    <div class="h-48 sm:h-56">
                      <canvas
                        id="events-chart"
                        phx-hook="Chart"
                        data-chart-type="line"
                        data-chart-labels={
                          Jason.encode!(Enum.map(@analytics.events_per_day, & &1.date))
                        }
                        data-chart-datasets={
                          Jason.encode!([
                            %{
                              label: gettext("Eventos"),
                              data: Enum.map(@analytics.events_per_day, & &1.count),
                              borderColor: "#6366f1",
                              backgroundColor: "rgba(99,102,241,0.1)",
                              fill: true,
                              tension: 0.3
                            }
                          ])
                        }
                      >
                      </canvas>
                    </div>
                  </div>
                  <%!-- Deliveries per day chart --%>
                  <div class="border border-slate-200 rounded-lg p-3 sm:p-4">
                    <h3 class="text-sm font-semibold text-slate-700 mb-3">
                      {gettext("Entregas por día (30d)")}
                    </h3>

                    <div class="h-48 sm:h-56">
                      <canvas
                        id="deliveries-chart"
                        phx-hook="Chart"
                        data-chart-type="bar"
                        data-chart-labels={
                          Jason.encode!(Enum.map(@analytics.deliveries_per_day, & &1.date))
                        }
                        data-chart-datasets={
                          Jason.encode!([
                            %{
                              label: gettext("Exitosas"),
                              data: Enum.map(@analytics.deliveries_per_day, & &1.success),
                              backgroundColor: "#10b981"
                            },
                            %{
                              label: gettext("Fallidas"),
                              data: Enum.map(@analytics.deliveries_per_day, & &1.failed),
                              backgroundColor: "#ef4444"
                            }
                          ])
                        }
                      >
                      </canvas>
                    </div>
                  </div>
                  <%!-- Top topics --%>
                  <div class="border border-slate-200 rounded-lg p-3 sm:p-4">
                    <h3 class="text-sm font-semibold text-slate-700 mb-3">{gettext("Top topics")}</h3>

                    <div class="h-48 sm:h-56">
                      <canvas
                        id="topics-chart"
                        phx-hook="Chart"
                        data-chart-type="doughnut"
                        data-chart-labels={Jason.encode!(Enum.map(@analytics.top_topics, & &1.topic))}
                        data-chart-datasets={
                          Jason.encode!([
                            %{
                              data: Enum.map(@analytics.top_topics, & &1.count),
                              backgroundColor: [
                                "#6366f1",
                                "#8b5cf6",
                                "#a78bfa",
                                "#c4b5fd",
                                "#ddd6fe",
                                "#818cf8",
                                "#6d28d9",
                                "#5b21b6",
                                "#4c1d95",
                                "#312e81"
                              ]
                            }
                          ])
                        }
                      >
                      </canvas>
                    </div>
                  </div>
                  <%!-- Webhook stats --%>
                  <div class="border border-slate-200 rounded-lg p-3 sm:p-4">
                    <h3 class="text-sm font-semibold text-slate-700 mb-3">
                      {gettext("Entregas por webhook (7d)")}
                    </h3>

                    <%= if @analytics.webhook_stats == [] do %>
                      <p class="text-sm text-slate-400 text-center py-8">{gettext("Sin datos")}</p>
                    <% else %>
                      <div class="space-y-2 max-h-56 overflow-y-auto">
                        <%= for ws <- @analytics.webhook_stats do %>
                          <div class="flex items-center gap-2 text-sm">
                            <span class="font-mono text-xs text-slate-600 truncate flex-1 min-w-0">
                              {ws.webhook_url}
                            </span>
                            <span class="text-emerald-700 font-medium text-xs shrink-0">
                              {ws.success}
                            </span>
                            <span class="text-slate-300 shrink-0">/</span>
                            <span class="text-red-600 font-medium text-xs shrink-0">{ws.failed}</span>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </section>
            <%!-- Event Schemas (B14) --%>
            <section class="bg-white rounded-xl border border-teal-200 shadow-sm p-4 sm:p-6 overflow-hidden">
              <div class="flex flex-wrap items-center justify-between gap-3 mb-4">
                <div class="flex items-center gap-2">
                  <.icon name="hero-document-check" class="w-5 h-5 text-teal-600" />
                  <h2 class="text-lg font-semibold text-slate-900">{gettext("Event Schemas")}</h2>
                </div>
              </div>

              <.form
                for={%{}}
                id="event-schema-form"
                phx-submit="create_event_schema"
                class="flex flex-col sm:flex-row gap-2 mb-4"
              >
                <input
                  type="text"
                  name="topic"
                  placeholder={gettext("Topic (ej: order.created)")}
                  required
                  class="flex-1 min-w-0 border border-slate-300 rounded-lg px-3 py-2 text-sm"
                /> <textarea
                  name="schema"
                  rows="2"
                  placeholder={
                    gettext("JSON Schema (ej: {\"type\":\"object\",\"required\":[\"amount\"]})")
                  }
                  required
                  class="flex-1 min-w-0 border border-slate-300 rounded-lg px-3 py-2 text-sm font-mono"
                ></textarea>
                <button
                  type="submit"
                  phx-disable-with={gettext("Creando...")}
                  class="px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white rounded-lg text-sm font-medium shrink-0"
                >
                  {gettext("Crear")}
                </button>
              </.form>

              <%= if @event_schemas == [] do %>
                <p class="text-sm text-slate-500">
                  {gettext("Sin schemas. Los eventos no serán validados.")}
                </p>
              <% else %>
                <div class="overflow-x-auto rounded-lg border border-slate-200">
                  <table class="min-w-full divide-y divide-slate-200">
                    <thead>
                      <tr class="bg-slate-50/80">
                        <th class="px-3 sm:px-4 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                          {gettext("Topic")}
                        </th>

                        <th class="px-3 sm:px-4 py-2 text-left text-xs font-semibold text-slate-600 uppercase hidden sm:table-cell">
                          {gettext("Versión")}
                        </th>

                        <th class="px-3 sm:px-4 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                          {gettext("Estado")}
                        </th>

                        <th class="px-3 sm:px-4 py-2 text-right text-xs font-semibold text-slate-600 uppercase">
                          {gettext("Acciones")}
                        </th>
                      </tr>
                    </thead>

                    <tbody class="divide-y divide-slate-100">
                      <%= for s <- @event_schemas do %>
                        <tr class="hover:bg-slate-50/50 transition">
                          <td class="px-3 sm:px-4 py-2 text-sm text-slate-700 font-mono">
                            {s.topic}
                          </td>

                          <td class="px-3 sm:px-4 py-2 text-sm text-slate-600 hidden sm:table-cell">
                            v{s.version}
                          </td>

                          <td class="px-3 sm:px-4 py-2">
                            <span class="px-2 py-0.5 rounded text-xs font-medium bg-teal-100 text-teal-800">
                              {s.status}
                            </span>
                          </td>

                          <td class="px-3 sm:px-4 py-2 text-right">
                            <button
                              phx-click="delete_event_schema"
                              phx-value-id={s.id}
                              data-confirm={gettext("¿Eliminar este schema?")}
                              class="text-red-600 hover:text-red-700 text-xs font-medium"
                            >
                              {gettext("Eliminar")}
                            </button>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              <% end %>
            </section>
            <%!-- Team / Collaborators (B20) --%>
            <section class="bg-white rounded-xl border border-cyan-200 shadow-sm p-4 sm:p-6 overflow-hidden">
              <div class="flex flex-wrap items-center justify-between gap-3 mb-4">
                <div class="flex items-center gap-2">
                  <.icon name="hero-user-group" class="w-5 h-5 text-cyan-600" />
                  <h2 class="text-lg font-semibold text-slate-900">{gettext("Equipo")}</h2>
                </div>
              </div>

              <.form
                for={%{}}
                id="invite-member-form"
                phx-submit="invite_member"
                class="flex flex-col sm:flex-row gap-2 mb-4"
              >
                <input
                  type="email"
                  name="email"
                  placeholder={gettext("Email del usuario")}
                  required
                  class="flex-1 min-w-0 border border-slate-300 rounded-lg px-3 py-2 text-sm"
                />
                <select
                  name="role"
                  class="border border-slate-300 rounded-lg px-3 py-2 text-sm bg-white"
                >
                  <option value="viewer">{gettext("Viewer")}</option>

                  <option value="editor">{gettext("Editor")}</option>
                </select>
                <button
                  type="submit"
                  phx-disable-with={gettext("Invitando...")}
                  class="px-4 py-2 bg-cyan-600 hover:bg-cyan-700 text-white rounded-lg text-sm font-medium shrink-0"
                >
                  {gettext("Invitar")}
                </button>
              </.form>

              <%= if @team_members == [] do %>
                <p class="text-sm text-slate-500">
                  {gettext("Solo tú tienes acceso. Invita colaboradores.")}
                </p>
              <% else %>
                <div class="overflow-x-auto rounded-lg border border-slate-200">
                  <table class="min-w-full divide-y divide-slate-200">
                    <thead>
                      <tr class="bg-slate-50/80">
                        <th class="px-3 sm:px-4 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                          {gettext("Usuario")}
                        </th>

                        <th class="px-3 sm:px-4 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                          {gettext("Rol")}
                        </th>

                        <th class="px-3 sm:px-4 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                          {gettext("Estado")}
                        </th>

                        <th class="px-3 sm:px-4 py-2 text-right text-xs font-semibold text-slate-600 uppercase">
                          {gettext("Acciones")}
                        </th>
                      </tr>
                    </thead>

                    <tbody class="divide-y divide-slate-100">
                      <%= for m <- @team_members do %>
                        <tr class="hover:bg-slate-50/50 transition">
                          <td class="px-3 sm:px-4 py-2 text-sm text-slate-700 font-mono truncate max-w-[10rem] sm:max-w-none">
                            {String.slice(m.user_id, 0, 8)}...
                          </td>

                          <td class="px-3 sm:px-4 py-2">
                            <span class={"px-2 py-0.5 rounded text-xs font-medium #{member_role_class(m.role)}"}>
                              {m.role}
                            </span>
                          </td>

                          <td class="px-3 sm:px-4 py-2">
                            <span class={"px-2 py-0.5 rounded text-xs font-medium #{member_status_class(m.status)}"}>
                              {m.status}
                            </span>
                          </td>

                          <td class="px-3 sm:px-4 py-2 text-right">
                            <%= if m.role != "owner" do %>
                              <div class="flex flex-col sm:flex-row sm:justify-end gap-1">
                                <%= if m.role == "viewer" do %>
                                  <button
                                    phx-click="update_member_role"
                                    phx-value-id={m.id}
                                    phx-value-role="editor"
                                    class="text-indigo-600 hover:text-indigo-700 text-xs font-medium"
                                  >
                                    {gettext("Promover")}
                                  </button>
                                <% end %>

                                <button
                                  phx-click="remove_member"
                                  phx-value-id={m.id}
                                  data-confirm={gettext("¿Remover este miembro?")}
                                  class="text-red-600 hover:text-red-700 text-xs font-medium"
                                >
                                  {gettext("Remover")}
                                </button>
                              </div>
                            <% end %>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              <% end %>
            </section>
            <%!-- Audit Log --%>
            <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 overflow-hidden">
              <div class="flex items-center gap-2 mb-4">
                <.icon name="hero-clipboard-document-list" class="w-5 h-5 text-slate-600" />
                <h2 class="text-lg font-semibold text-slate-900">
                  {gettext("Registro de actividad")}
                </h2>
              </div>

              <%= if @audit_logs == [] do %>
                <p class="text-sm text-slate-500">{gettext("Sin actividad registrada.")}</p>
              <% else %>
                <div class="space-y-2 max-h-80 overflow-y-auto">
                  <%= for log <- @audit_logs do %>
                    <div class="flex items-start gap-3 py-2 border-b border-slate-100 last:border-0">
                      <div class="mt-0.5 shrink-0">
                        <.icon name={Audit.action_icon(log.action)} class="w-4 h-4 text-slate-400" />
                      </div>

                      <div class="min-w-0 flex-1">
                        <p class="text-sm text-slate-800">{audit_action_label(log.action)}</p>

                        <p class="text-[11px] text-slate-400">{format_dt(log.inserted_at)}</p>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </section>

            <%!-- Job form modal: backdrop and modal are siblings so clicking inside modal doesn't close --%>
            <%= if @job_modal do %>
              <div
                class="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6"
                id="job-modal-container"
              >
                <div
                  class="absolute inset-0 bg-slate-900/60 backdrop-blur-sm transition-opacity"
                  phx-click="close_job_modal"
                  id="job-modal-backdrop"
                  aria-hidden="true"
                >
                </div>

                <div
                  class="relative z-10 w-full max-w-3xl max-h-[90vh] overflow-hidden bg-white rounded-2xl shadow-2xl flex flex-col border border-slate-200/50"
                  id="job-modal-content"
                  role="dialog"
                  aria-modal="true"
                  aria-labelledby="job-modal-title"
                >
                  <div class="flex-shrink-0 px-4 sm:px-6 py-4 sm:py-5 border-b border-slate-200 bg-slate-50/80 flex justify-between items-center">
                    <h2 id="job-modal-title" class="text-lg sm:text-xl font-semibold text-slate-900">
                      {if @job_modal == :new, do: gettext("Nuevo job"), else: gettext("Editar job")}
                    </h2>

                    <button
                      type="button"
                      phx-click="close_job_modal"
                      class="p-2 -m-2 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-200/60 transition"
                      aria-label={gettext("Cerrar")}
                    >
                      <.icon name="hero-x-mark" class="w-5 h-5" />
                    </button>
                  </div>

                  <.form
                    for={@job_form}
                    id="job-form"
                    phx-submit="save_job"
                    class="flex-1 overflow-y-auto"
                  >
                    <%= if @job_modal != :new do %>
                      <input type="hidden" name="job_id" value={elem(@job_modal, 1)} />
                    <% end %>
                    <% p = @job_form.params || %{} %>
                    <div class="p-4 sm:p-6 space-y-5 sm:space-y-6">
                      <div>
                        <label class="block text-sm font-medium text-slate-700 mb-1.5">
                          {gettext("Nombre")}
                        </label>
                        <input
                          type="text"
                          name="name"
                          value={p["name"]}
                          required
                          class="w-full border border-slate-300 rounded-xl px-3 sm:px-4 py-2 sm:py-2.5 text-slate-900 placeholder-slate-400 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 transition text-sm sm:text-base"
                          placeholder={gettext("Ej: Reporte diario")}
                        />
                      </div>

                      <div class="border-t border-slate-200 pt-6">
                        <h3 class="text-sm font-semibold text-slate-800 mb-4">
                          {gettext("Programación")}
                        </h3>

                        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                          <div>
                            <label class="block text-sm font-medium text-slate-600 mb-1.5">
                              {gettext("Tipo")}
                            </label>
                            <select
                              name="schedule_type"
                              class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 bg-white focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                            >
                              <option value="daily" selected={p["schedule_type"] == "daily"}>
                                {gettext("Diario")}
                              </option>

                              <option value="weekly" selected={p["schedule_type"] == "weekly"}>
                                {gettext("Semanal")}
                              </option>

                              <option value="monthly" selected={p["schedule_type"] == "monthly"}>
                                {gettext("Mensual")}
                              </option>

                              <option value="cron" selected={p["schedule_type"] == "cron"}>
                                {gettext("Cron")}
                              </option>
                            </select>
                          </div>

                          <div>
                            <label class="block text-sm font-medium text-slate-600 mb-1.5">
                              {gettext("Hora (0-23)")}
                            </label>
                            <input
                              type="number"
                              name="schedule_hour"
                              value={p["schedule_hour"]}
                              min="0"
                              max="23"
                              class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                            />
                          </div>

                          <div>
                            <label class="block text-sm font-medium text-slate-600 mb-1.5">
                              {gettext("Minuto")}
                            </label>
                            <input
                              type="number"
                              name="schedule_minute"
                              value={p["schedule_minute"]}
                              min="0"
                              max="59"
                              class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                            />
                          </div>

                          <div>
                            <label class="block text-sm font-medium text-slate-600 mb-1.5">
                              {gettext("Día semana (1-7, 1=Lun)")}
                            </label>
                            <input
                              type="number"
                              name="schedule_day_of_week"
                              value={p["schedule_day_of_week"]}
                              min="1"
                              max="7"
                              class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                            />
                          </div>

                          <div>
                            <label class="block text-sm font-medium text-slate-600 mb-1.5">
                              {gettext("Día del mes (1-31)")}
                            </label>
                            <input
                              type="number"
                              name="schedule_day_of_month"
                              value={p["schedule_day_of_month"]}
                              min="1"
                              max="31"
                              class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                            />
                          </div>

                          <div>
                            <label class="block text-sm font-medium text-slate-600 mb-1.5">
                              {gettext("Expresión cron")}
                            </label>
                            <div class="flex gap-2">
                              <input
                                type="text"
                                name="schedule_cron"
                                id="cron-expr-input"
                                value={p["schedule_cron"]}
                                placeholder="0 0 * * *"
                                class="flex-1 border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 font-mono text-sm focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                              />
                              <button
                                type="button"
                                phx-click="preview_cron"
                                phx-value-expression={p["schedule_cron"]}
                                class="px-3 py-2 text-xs font-medium text-indigo-600 bg-indigo-50 hover:bg-indigo-100 rounded-xl transition shrink-0"
                              >
                                {gettext("Preview")}
                              </button>
                            </div>

                            <%= if @cron_preview != [] do %>
                              <div class="mt-2 p-3 bg-slate-50 rounded-lg border border-slate-200">
                                <p class="text-xs font-medium text-slate-500 mb-1">
                                  {gettext("Próximas ejecuciones")}:
                                </p>

                                <ul class="space-y-0.5">
                                  <%= for dt <- @cron_preview do %>
                                    <li class="text-xs font-mono text-slate-600">{dt}</li>
                                  <% end %>
                                </ul>
                              </div>
                            <% end %>
                          </div>
                        </div>
                      </div>

                      <div class="border-t border-slate-200 pt-6">
                        <h3 class="text-sm font-semibold text-slate-800 mb-4">{gettext("Acción")}</h3>

                        <div class="space-y-4">
                          <div>
                            <label class="block text-sm font-medium text-slate-600 mb-1.5">
                              {gettext("Tipo de acción")}
                            </label>
                            <select
                              name="action_type"
                              class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 bg-white focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                            >
                              <option value="emit_event" selected={p["action_type"] == "emit_event"}>
                                {gettext("Emitir evento")}
                              </option>

                              <option value="post_url" selected={p["action_type"] == "post_url"}>
                                {gettext("POST URL")}
                              </option>
                            </select>
                          </div>

                          <div>
                            <label class="block text-sm font-medium text-slate-600 mb-1.5">
                              {gettext("Topic (emit_event)")}
                            </label>
                            <input
                              type="text"
                              name="action_topic"
                              value={p["action_topic"]}
                              class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 placeholder-slate-400 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                              placeholder="mi.topic"
                            />
                          </div>

                          <div>
                            <label class="block text-sm font-medium text-slate-600 mb-1.5">
                              {gettext("Payload JSON (emit_event)")}
                            </label>
                            <textarea
                              name="action_payload"
                              rows="4"
                              class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 font-mono text-sm placeholder-slate-400 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                            >{p["action_payload"]}</textarea>
                          </div>

                          <div>
                            <label class="block text-sm font-medium text-slate-600 mb-1.5">
                              {gettext("URL (post_url)")}
                            </label>
                            <input
                              type="url"
                              name="action_url"
                              value={p["action_url"]}
                              class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 placeholder-slate-400 focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                              placeholder="https://..."
                            />
                          </div>

                          <div>
                            <label class="block text-sm font-medium text-slate-600 mb-1.5">
                              {gettext("Método HTTP")}
                            </label>
                            <select
                              name="action_method"
                              class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 bg-white focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                            >
                              <option value="POST" selected={p["action_method"] == "POST"}>
                                POST
                              </option>

                              <option value="GET">GET</option>

                              <option value="PUT">PUT</option>

                              <option value="PATCH">PATCH</option>
                            </select>
                          </div>

                          <%= if @job_modal != :new do %>
                            <div>
                              <label class="block text-sm font-medium text-slate-600 mb-1.5">
                                {gettext("Estado")}
                              </label>
                              <select
                                name="status"
                                class="w-full border border-slate-300 rounded-xl px-4 py-2.5 text-slate-900 bg-white focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                              >
                                <option value="active" selected={p["status"] == "active"}>
                                  {gettext("Activo")}
                                </option>

                                <option value="inactive" selected={p["status"] == "inactive"}>
                                  {gettext("Inactivo")}
                                </option>
                              </select>
                            </div>
                          <% end %>
                        </div>
                      </div>

                      <div class="flex flex-wrap justify-end gap-3 pt-4 border-t border-slate-200">
                        <button
                          type="button"
                          phx-click="close_job_modal"
                          class="px-5 py-2.5 border border-slate-300 rounded-xl text-slate-700 hover:bg-slate-50 font-medium transition"
                        >
                          {gettext("Cancelar")}
                        </button>
                        <button
                          type="submit"
                          phx-disable-with={gettext("Guardando...")}
                          class="px-5 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl font-medium shadow-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
                        >
                          {gettext("Guardar")}
                        </button>
                      </div>
                    </div>
                  </.form>
                </div>
              </div>
            <% end %>
            <%!-- Job runs modal: backdrop and modal siblings --%>
            <%= if @job_runs_modal do %>
              <div
                class="fixed inset-0 z-50 flex items-center justify-center p-4"
                id="job-runs-modal-container"
              >
                <div
                  class="absolute inset-0 bg-slate-900/60 backdrop-blur-sm"
                  phx-click="close_job_runs_modal"
                  aria-hidden="true"
                >
                </div>

                <div
                  class="relative z-10 w-full max-w-2xl max-h-[80vh] overflow-hidden bg-white rounded-2xl shadow-2xl flex flex-col border border-slate-200/50 mx-4"
                  role="dialog"
                  aria-modal="true"
                >
                  <div class="p-4 border-b flex justify-between items-center">
                    <h2 class="text-lg font-semibold text-slate-900">
                      {gettext("Runs: %{name}", name: @job_runs_modal.job.name)}
                    </h2>

                    <button
                      type="button"
                      phx-click="close_job_runs_modal"
                      class="text-slate-400 hover:text-slate-600"
                    >
                      <.icon name="hero-x-mark" class="w-6 h-6" />
                    </button>
                  </div>

                  <div class="overflow-y-auto flex-1 p-4">
                    <table class="min-w-full">
                      <thead>
                        <tr class="bg-slate-50 border-b">
                          <th class="px-4 py-2 text-left text-sm font-medium text-slate-700">
                            {gettext("Ejecutado")}
                          </th>

                          <th class="px-4 py-2 text-left text-sm font-medium text-slate-700">
                            {gettext("Estado")}
                          </th>

                          <th class="px-4 py-2 text-left text-sm font-medium text-slate-700">
                            {gettext("Resultado")}
                          </th>
                        </tr>
                      </thead>

                      <tbody>
                        <%= for r <- @job_runs_modal.runs do %>
                          <tr class="border-b border-slate-100">
                            <td class="px-4 py-2 text-sm text-slate-600">
                              {format_dt(r.executed_at)}
                            </td>

                            <td class="px-4 py-2">
                              <span class={[
                                "px-2 py-0.5 rounded text-xs",
                                if(r.status == "success",
                                  do: "bg-green-100 text-green-800",
                                  else: "bg-red-100 text-red-800"
                                )
                              ]}>
                                {r.status}
                              </span>
                            </td>

                            <td class="px-4 py-2 text-sm text-slate-600">
                              {if r.result, do: Jason.encode!(r.result), else: "—"}
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>

                    <%= if @job_runs_modal.runs == [] do %>
                      <p class="text-slate-500 py-4">{gettext("Sin ejecuciones aún.")}</p>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <p class="text-slate-600">{gettext("No hay proyecto para tu cuenta. Contacta soporte.")}</p>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp to_str(n) when is_integer(n), do: Integer.to_string(n)
  defp to_str(s) when is_binary(s), do: s
  defp to_str(_), do: "0"

  defp build_schedule_config(params) do
    type = params["schedule_type"] || "daily"

    case type do
      "daily" ->
        %{
          "hour" => parse_int(params["schedule_hour"], 0),
          "minute" => parse_int(params["schedule_minute"], 0)
        }

      "weekly" ->
        %{
          "day_of_week" => parse_int(params["schedule_day_of_week"], 1),
          "hour" => parse_int(params["schedule_hour"], 0),
          "minute" => parse_int(params["schedule_minute"], 0)
        }

      "monthly" ->
        %{
          "day_of_month" => parse_int(params["schedule_day_of_month"], 1),
          "hour" => parse_int(params["schedule_hour"], 0),
          "minute" => parse_int(params["schedule_minute"], 0)
        }

      "cron" ->
        %{"expr" => params["schedule_cron"] || "0 0 * * *"}

      _ ->
        %{}
    end
  end

  defp build_action_config(params) do
    type = params["action_type"] || "emit_event"

    case type do
      "emit_event" ->
        payload =
          case Jason.decode(params["action_payload"] || "{}") do
            {:ok, m} -> m
            _ -> %{}
          end

        %{"topic" => params["action_topic"] || "", "payload" => payload}

      "post_url" ->
        %{"url" => params["action_url"] || "", "method" => params["action_method"] || "POST"}

      _ ->
        %{}
    end
  end

  defp parse_int(s, d) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} -> n
      _ -> d
    end
  end

  defp parse_int(_, d), do: d

  defp format_dt(nil), do: "—"
  defp format_dt(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")

  # Health Score helpers
  defp health_class(:healthy), do: "bg-green-100 text-green-800"
  defp health_class(:degraded), do: "bg-yellow-100 text-yellow-800"
  defp health_class(:critical), do: "bg-red-100 text-red-800"
  defp health_class(:no_data), do: "bg-slate-100 text-slate-600"
  defp health_class(_), do: "bg-slate-100 text-slate-600"

  defp health_dot(:healthy), do: "bg-green-500"
  defp health_dot(:degraded), do: "bg-yellow-500"
  defp health_dot(:critical), do: "bg-red-500"
  defp health_dot(_), do: "bg-slate-400"

  defp health_label(:healthy), do: "OK"
  defp health_label(:degraded), do: gettext("Degradado")
  defp health_label(:critical), do: gettext("Crítico")
  defp health_label(:no_data), do: gettext("Sin datos")
  defp health_label(_), do: "—"

  # Notification i18n helpers — translate based on type + metadata
  defp notification_title(%{type: "webhook_failing"}), do: gettext("Webhook fallando")
  defp notification_title(%{type: "job_failed"}), do: gettext("Job fallido")
  defp notification_title(%{type: "dlq_entry"}), do: gettext("Entrega movida a DLQ")
  defp notification_title(%{type: "replay_completed"}), do: gettext("Replay completado")
  defp notification_title(notif), do: notif.title

  defp notification_message(%{type: "webhook_failing", metadata: %{"webhook_url" => url}}) do
    gettext("%{url} tiene múltiples fallos consecutivos", url: url)
  end

  defp notification_message(%{type: "job_failed", metadata: %{"job_name" => name}}) do
    gettext("El job programado \"%{name}\" falló al ejecutarse", name: name)
  end

  defp notification_message(%{type: "dlq_entry", metadata: %{"webhook_url" => url}}) do
    gettext("Una entrega a %{url} agotó todos los reintentos", url: url)
  end

  defp notification_message(%{type: "replay_completed", metadata: %{"event_count" => count}}) do
    gettext("Se re-enviaron %{count} eventos exitosamente", count: count)
  end

  defp notification_message(notif), do: notif.message

  defp load_analytics(project_id) do
    %{
      events_per_day: Platform.events_per_day(project_id),
      deliveries_per_day: Platform.deliveries_per_day(project_id),
      top_topics: Platform.top_topics(project_id),
      webhook_stats: Platform.delivery_stats_by_webhook(project_id)
    }
  end

  defp replay_status_class("pending"), do: "bg-slate-100 text-slate-700"
  defp replay_status_class("running"), do: "bg-blue-100 text-blue-800"
  defp replay_status_class("completed"), do: "bg-emerald-100 text-emerald-800"
  defp replay_status_class("failed"), do: "bg-red-100 text-red-800"
  defp replay_status_class("cancelled"), do: "bg-amber-100 text-amber-800"
  defp replay_status_class(_), do: "bg-slate-100 text-slate-600"

  defp replay_status_label("pending"), do: gettext("Pendiente")
  defp replay_status_label("running"), do: gettext("Ejecutando")
  defp replay_status_label("completed"), do: gettext("Completado")
  defp replay_status_label("failed"), do: gettext("Fallido")
  defp replay_status_label("cancelled"), do: gettext("Cancelado")
  defp replay_status_label(s), do: s

  defp audit_action_label("webhook.created"), do: gettext("Webhook creado")
  defp audit_action_label("webhook.updated"), do: gettext("Webhook actualizado")
  defp audit_action_label("webhook.deleted"), do: gettext("Webhook eliminado")
  defp audit_action_label("event.created"), do: gettext("Evento enviado")
  defp audit_action_label("job.created"), do: gettext("Job creado")
  defp audit_action_label("job.updated"), do: gettext("Job actualizado")
  defp audit_action_label("job.deactivated"), do: gettext("Job desactivado")
  defp audit_action_label("api_key.regenerated"), do: gettext("Token regenerado")
  defp audit_action_label("project.updated"), do: gettext("Proyecto actualizado")
  defp audit_action_label("delivery.retried"), do: gettext("Entrega reintentada")
  defp audit_action_label("dead_letter.retried"), do: gettext("DLQ reintentado")
  defp audit_action_label("dead_letter.resolved"), do: gettext("DLQ resuelto")
  defp audit_action_label("replay.started"), do: gettext("Replay iniciado")
  defp audit_action_label("replay.cancelled"), do: gettext("Replay cancelado")
  defp audit_action_label("sandbox.created"), do: gettext("Sandbox creado")
  defp audit_action_label(action), do: action

  defp sandbox_url(endpoint) do
    "/sandbox/#{endpoint.slug}"
  end

  defp method_color("GET"), do: "bg-blue-100 text-blue-800"
  defp method_color("POST"), do: "bg-green-100 text-green-800"
  defp method_color("PUT"), do: "bg-amber-100 text-amber-800"
  defp method_color("PATCH"), do: "bg-amber-100 text-amber-800"
  defp method_color("DELETE"), do: "bg-red-100 text-red-800"
  defp method_color(_), do: "bg-slate-100 text-slate-700"

  defp member_role_class("owner"), do: "bg-indigo-100 text-indigo-800"
  defp member_role_class("editor"), do: "bg-emerald-100 text-emerald-800"
  defp member_role_class("viewer"), do: "bg-slate-100 text-slate-700"
  defp member_role_class(_), do: "bg-slate-100 text-slate-600"

  defp member_status_class("active"), do: "bg-green-100 text-green-800"
  defp member_status_class("pending"), do: "bg-amber-100 text-amber-800"
  defp member_status_class("removed"), do: "bg-red-100 text-red-800"
  defp member_status_class(_), do: "bg-slate-100 text-slate-600"
end
