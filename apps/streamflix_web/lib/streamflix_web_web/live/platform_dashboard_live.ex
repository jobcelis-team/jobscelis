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

    webhooks =
      if project, do: Platform.list_webhooks(project.id, include_inactive: true), else: []

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
    current_user_role = compute_user_role(project, user)
    analytics = if project, do: load_analytics(project.id), else: %{}
    notifications = Notifications.list_for_user(user.id, limit: 10)
    unread_count = Notifications.unread_count(user.id)
    pending_invitations = Teams.list_pending_invitations(user.id)

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
      |> assign(:current_user_role, current_user_role)
      |> assign(:analytics, analytics)
      |> assign(:active_tab, "overview")
      |> assign(:kpi_events_today, compute_kpi_events_today(events))
      |> assign(:kpi_success_rate, compute_kpi_success_rate(deliveries))
      |> assign(:notifications, notifications)
      |> assign(:unread_count, unread_count)
      |> assign(:show_notifications, false)
      |> assign(:pending_invitations, pending_invitations)
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
      |> assign(:page_title, gettext("Dashboard"))
      |> assign(:active_page, :dashboard)
      |> assign(:webhook_modal, nil)
      |> assign(:webhook_form, %{"url" => "", "topics" => "", "secret" => ""})
      |> assign(:confirm_regenerate_token, false)
      |> assign(:uptime_status, load_uptime_status())
      |> assign(:uptime_stats, load_uptime_stats())

    if connected?(socket) do
      if project, do: Platform.subscribe(project.id)
      Notifications.subscribe(user.id)
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("send_test", %{"topic" => topic, "payload" => payload_str} = _params, socket) do
    with_permission(socket, :write, fn ->
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
            put_flash(socket, :info, gettext("Evento enviado. ID: %{id}", id: event.id))
            assign(socket, :events, events)

          {:error, _} ->
            put_flash(socket, :error, gettext("Error al enviar el evento"))
            socket
        end

      {:noreply, socket}
    end)
  end

  @impl true
  def handle_event("edit_project_name", _params, socket) do
    with_permission(socket, :admin, fn ->
      {:noreply, assign(socket, :editing_project_name, true)}
    end)
  end

  @impl true
  def handle_event("cancel_edit_project_name", _params, socket) do
    {:noreply, assign(socket, :editing_project_name, false)}
  end

  @impl true
  def handle_event("update_project_name", %{"name" => name}, socket) do
    with_permission(socket, :admin, fn ->
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
    end)
  end

  @impl true
  def handle_event("toggle_token_visibility", _params, socket) do
    {:noreply, assign(socket, :token_visible, !socket.assigns.token_visible)}
  end

  @impl true
  def handle_event("show_confirm_regenerate", _params, socket) do
    {:noreply, assign(socket, :confirm_regenerate_token, true)}
  end

  @impl true
  def handle_event("cancel_confirm_regenerate", _params, socket) do
    {:noreply, assign(socket, :confirm_regenerate_token, false)}
  end

  @impl true
  def handle_event("regenerate_token", _params, socket) do
    with_permission(socket, :admin, fn ->
      project = socket.assigns.project

      case Platform.regenerate_api_key(project.id) do
        {:ok, _api_key, raw_key} ->
          api_key = Platform.get_api_key_for_project(project.id)

          Audit.record("api_key.regenerated",
            user_id: socket.assigns.current_user.id,
            project_id: project.id,
            resource_type: "api_key"
          )

          socket =
            socket
            |> put_flash(:info, gettext("Token regenerado correctamente."))
            |> assign(:api_key, api_key)
            |> assign(:new_token, raw_key)
            |> assign(:token_source, :regenerated)
            |> assign(:token_visible, true)
            |> assign(:confirm_regenerate_token, false)

          {:noreply, socket}

        _ ->
          {:noreply,
           socket
           |> put_flash(:error, gettext("No se pudo regenerar el token."))
           |> assign(:confirm_regenerate_token, false)}
      end
    end)
  end

  # Jobs: open create modal
  @impl true
  def handle_event("new_job", _, socket) do
    with_permission(socket, :write, fn ->
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
    end)
  end

  @impl true
  def handle_event("edit_job", %{"id" => id}, socket) do
    with_permission(socket, :write, fn ->
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
    end)
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
    with_permission(socket, :write, fn ->
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
    end)
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
    with_permission(socket, :write, fn ->
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
    end)
  end

  @impl true
  def handle_event("retry_delivery", %{"id" => id}, socket) do
    with_permission(socket, :write, fn ->
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
    end)
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
    with_permission(socket, :write, fn ->
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
    end)
  end

  @impl true
  def handle_event("resolve_dead_letter", %{"id" => id}, socket) do
    with_permission(socket, :write, fn ->
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
    end)
  end

  # ── Webhook CRUD ───────────────────────────────────────────────────

  def handle_event("new_webhook", _, socket) do
    with_permission(socket, :write, fn ->
      {:noreply,
       socket
       |> assign(:webhook_modal, :new)
       |> assign(:webhook_form, %{"url" => "", "topics" => "", "secret" => ""})}
    end)
  end

  def handle_event("edit_webhook", %{"id" => id}, socket) do
    with_permission(socket, :write, fn ->
      case Platform.get_webhook(id) do
        nil ->
          {:noreply, put_flash(socket, :error, gettext("Webhook no encontrado."))}

        w ->
          {:noreply,
           socket
           |> assign(:webhook_modal, {:edit, w})
           |> assign(:webhook_form, %{
             "url" => w.url,
             "topics" => Enum.join(w.topics || [], ", "),
             "secret" => ""
           })}
      end
    end)
  end

  def handle_event("close_webhook_modal", _, socket) do
    {:noreply, assign(socket, :webhook_modal, nil)}
  end

  def handle_event("save_webhook", %{"webhook" => params}, socket) do
    with_permission(socket, :write, fn ->
      project = socket.assigns.project
      url = String.trim(params["url"] || "")

      topics =
        params["topics"]
        |> to_string()
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      secret = params["secret"] || ""

      attrs = %{
        "url" => url,
        "topics" => topics
      }

      attrs = if secret != "", do: Map.put(attrs, "secret_encrypted", secret), else: attrs

      case socket.assigns.webhook_modal do
        :new ->
          case Platform.create_webhook(project.id, attrs) do
            {:ok, _} ->
              webhooks = Platform.list_webhooks(project.id, include_inactive: true)
              webhook_health = Platform.webhooks_health(project.id)

              {:noreply,
               socket
               |> assign(:webhooks, webhooks)
               |> assign(:webhook_health, webhook_health)
               |> assign(:webhook_modal, nil)
               |> put_flash(:info, gettext("Webhook creado."))}

            {:error, changeset} ->
              msg = format_changeset_errors(changeset)
              {:noreply, put_flash(socket, :error, msg)}
          end

        {:edit, w} ->
          case Platform.update_webhook(w, attrs) do
            {:ok, _} ->
              webhooks = Platform.list_webhooks(project.id, include_inactive: true)
              webhook_health = Platform.webhooks_health(project.id)

              {:noreply,
               socket
               |> assign(:webhooks, webhooks)
               |> assign(:webhook_health, webhook_health)
               |> assign(:webhook_modal, nil)
               |> put_flash(:info, gettext("Webhook actualizado."))}

            {:error, changeset} ->
              msg = format_changeset_errors(changeset)
              {:noreply, put_flash(socket, :error, msg)}
          end

        _ ->
          {:noreply, socket}
      end
    end)
  end

  def handle_event("deactivate_webhook", %{"id" => id}, socket) do
    with_permission(socket, :write, fn ->
      project = socket.assigns.project

      case Platform.get_webhook(id) do
        nil ->
          {:noreply, put_flash(socket, :error, gettext("Webhook no encontrado."))}

        w ->
          {:ok, _} = Platform.set_webhook_inactive(w)
          webhooks = Platform.list_webhooks(project.id, include_inactive: true)
          webhook_health = Platform.webhooks_health(project.id)

          {:noreply,
           socket
           |> assign(:webhooks, webhooks)
           |> assign(:webhook_health, webhook_health)
           |> put_flash(:info, gettext("Webhook desactivado."))}
      end
    end)
  end

  def handle_event("activate_webhook", %{"id" => id}, socket) do
    with_permission(socket, :write, fn ->
      project = socket.assigns.project

      case Platform.get_webhook(id) do
        nil ->
          {:noreply, put_flash(socket, :error, gettext("Webhook no encontrado."))}

        w ->
          {:ok, _} = Platform.update_webhook(w, %{"status" => "active"})
          webhooks = Platform.list_webhooks(project.id, include_inactive: true)
          webhook_health = Platform.webhooks_health(project.id)

          {:noreply,
           socket
           |> assign(:webhooks, webhooks)
           |> assign(:webhook_health, webhook_health)
           |> put_flash(:info, gettext("Webhook activado."))}
      end
    end)
  end

  @impl true
  def handle_event("simulate_event", %{"topic" => topic, "payload" => payload_str}, socket) do
    with_permission(socket, :write, fn ->
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
    end)
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
    with_permission(socket, :write, fn ->
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
    end)
  end

  @impl true
  def handle_event("cancel_replay", %{"id" => id}, socket) do
    with_permission(socket, :write, fn ->
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
    end)
  end

  # ---------- Sandbox ----------

  @impl true
  def handle_event("create_sandbox", params, socket) do
    with_permission(socket, :write, fn ->
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
    end)
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
    with_permission(socket, :write, fn ->
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
    end)
  end

  # ---------- Tab navigation ----------

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket)
      when tab in ~w(overview events webhooks jobs settings) do
    {:noreply, assign(socket, :active_tab, tab)}
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
        webhooks = Platform.list_webhooks(project.id, include_inactive: true)
        webhook_health = Platform.webhooks_health(project.id)
        jobs = Platform.list_jobs(project.id, include_inactive: true)
        deliveries = Platform.list_deliveries(project_id: project.id, limit: 30)
        dead_letters = Platform.list_dead_letters(project.id)
        replays = Platform.list_replays(project.id, limit: 10)
        audit_logs = Audit.list_for_project(project.id, limit: 20)
        sandbox_endpoints = Platform.list_sandbox_endpoints(project.id)
        event_schemas = Platform.list_event_schemas(project.id)
        team_members = Teams.list_members(project.id)
        user_role = compute_user_role(project, socket.assigns.current_user)
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
         |> assign(:current_user_role, user_role)
         |> assign(:analytics, analytics)
         |> assign(:active_tab, "overview")
         |> assign(:kpi_events_today, compute_kpi_events_today(events))
         |> assign(:kpi_success_rate, compute_kpi_success_rate(deliveries))
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
    with_permission(socket, :admin, fn ->
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
    end)
  end

  # ---------- Event Schemas (B14) ----------

  @impl true
  def handle_event("create_event_schema", %{"topic" => topic, "schema" => schema_str}, socket) do
    with_permission(socket, :write, fn ->
      project = socket.assigns.project

      case Jason.decode(schema_str) do
        {:ok, schema_map} ->
          case Platform.create_event_schema(project.id, %{
                 "topic" => topic,
                 "schema" => schema_map
               }) do
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
    end)
  end

  @impl true
  def handle_event("delete_event_schema", %{"id" => id}, socket) do
    with_permission(socket, :write, fn ->
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
    end)
  end

  # ---------- Team Management (B20) ----------

  @impl true
  def handle_event("invite_member", %{"email" => email, "role" => role}, socket) do
    with_permission(socket, :write, fn ->
      project = socket.assigns.project
      user = socket.assigns.current_user

      case StreamflixAccounts.get_user_by_email(email) do
        nil ->
          {:noreply, put_flash(socket, :error, gettext("Usuario no encontrado con ese email."))}

        target_user ->
          if target_user.id == user.id do
            {:noreply, put_flash(socket, :error, gettext("No puedes invitarte a ti mismo."))}
          else
            case Teams.invite_member(project.id, target_user.id, role, user.id) do
              {:ok, member} ->
                Notifications.notify_team_invite(target_user.id, project.id, role, member.id)

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
    end)
  end

  @impl true
  def handle_event("remove_member", %{"id" => id}, socket) do
    with_permission(socket, :admin, fn ->
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
    end)
  end

  @impl true
  def handle_event("update_member_role", %{"id" => id, "role" => role}, socket) do
    with_permission(socket, :admin, fn ->
      case Teams.update_member_role(id, role) do
        {:ok, _} ->
          members = Teams.list_members(socket.assigns.project.id)

          {:noreply,
           socket
           |> assign(:team_members, members)
           |> put_flash(:info, gettext("Rol actualizado."))}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, gettext("Error al actualizar rol."))}
      end
    end)
  end

  @impl true
  def handle_event("accept_invitation", %{"id" => member_id}, socket) do
    user = socket.assigns.current_user

    case Teams.accept_invitation(member_id) do
      {:ok, _} ->
        Notifications.mark_invite_read(user.id, member_id)
        projects = Teams.list_all_accessible_projects(user.id)
        pending = Teams.list_pending_invitations(user.id)
        notifications = Notifications.list_for_user(user.id, limit: 10)
        unread_count = Notifications.unread_count(user.id)

        {:noreply,
         socket
         |> assign(:projects, projects)
         |> assign(:pending_invitations, pending)
         |> assign(:notifications, notifications)
         |> assign(:unread_count, unread_count)
         |> put_flash(:info, gettext("Invitación aceptada."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Error al aceptar invitación."))}
    end
  end

  @impl true
  def handle_event("reject_invitation", %{"id" => member_id}, socket) do
    user = socket.assigns.current_user

    case Teams.reject_invitation(member_id) do
      {:ok, _} ->
        Notifications.mark_invite_read(user.id, member_id)
        pending = Teams.list_pending_invitations(user.id)
        notifications = Notifications.list_for_user(user.id, limit: 10)
        unread_count = Notifications.unread_count(user.id)

        {:noreply,
         socket
         |> assign(:pending_invitations, pending)
         |> assign(:notifications, notifications)
         |> assign(:unread_count, unread_count)
         |> put_flash(:info, gettext("Invitación rechazada."))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Error al rechazar invitación."))}
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
  def handle_info({:new_notification, notif}, socket) do
    user = socket.assigns.current_user
    notifications = Notifications.list_for_user(user.id, limit: 10)
    unread_count = Notifications.unread_count(user.id)

    socket =
      socket
      |> assign(:notifications, notifications)
      |> assign(:unread_count, unread_count)

    socket =
      if is_map(notif) && Map.get(notif, :type) == "team_invite" do
        assign(socket, :pending_invitations, Teams.list_pending_invitations(user.id))
      else
        socket
      end

    {:noreply, socket}
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
      main_class="w-full max-w-[1920px] mx-auto px-4 sm:px-6 lg:px-10 xl:px-16 py-6 sm:py-8 flex-1"
    >
      <div>
        <%!-- ===== HEADER ===== --%>
        <div class="flex items-center justify-between mb-4 sm:mb-6 lg:mb-8">
          <div class="flex items-center gap-3 sm:gap-4">
            <h1 class="text-xl sm:text-2xl lg:text-3xl font-bold text-slate-900">
              {gettext("Dashboard")}
            </h1>
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
                          phx-disable-with={gettext("Creando...")}
                          class="px-3 py-1.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-xs font-medium disabled:opacity-50 disabled:cursor-not-allowed"
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
                        <div class="min-w-0 flex-1">
                          <p class="text-sm font-medium text-slate-900 truncate">
                            {notification_title(notif)}
                          </p>
                          <p class="text-xs text-slate-500 truncate">{notification_message(notif)}</p>
                          <p class="text-[10px] text-slate-400 mt-1">
                            {format_dt(notif.inserted_at)}
                          </p>
                          <%= if notif.type == "team_invite" && is_map(notif.metadata) && Map.get(notif.metadata, "member_id") do %>
                            <%= if !notif.read do %>
                              <div class="flex gap-2 mt-2">
                                <button
                                  phx-click="accept_invitation"
                                  phx-value-id={notif.metadata["member_id"]}
                                  class="px-2 py-1 bg-emerald-600 hover:bg-emerald-700 text-white rounded text-[11px] font-medium"
                                >
                                  {gettext("Aceptar")}
                                </button>
                                <button
                                  phx-click="reject_invitation"
                                  phx-value-id={notif.metadata["member_id"]}
                                  class="px-2 py-1 bg-red-100 hover:bg-red-200 text-red-700 rounded text-[11px] font-medium"
                                >
                                  {gettext("Rechazar")}
                                </button>
                              </div>
                            <% else %>
                              <p class="text-[10px] text-emerald-600 mt-1 font-medium">
                                {gettext("Respondida")}
                              </p>
                            <% end %>
                          <% end %>
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
          <%!-- ===== KPI CARDS ===== --%>
          <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4 lg:gap-6 mb-6 sm:mb-8">
            <div class="bg-white rounded-xl border border-slate-200 shadow-sm p-3 sm:p-5 lg:p-6 border-l-4 border-l-indigo-500">
              <div class="flex items-center gap-2 mb-2">
                <.icon name="hero-bolt" class="w-5 h-5 text-indigo-500" />
                <span class="text-xs sm:text-sm font-medium text-slate-500 uppercase tracking-wide">
                  {gettext("Eventos hoy")}
                </span>
              </div>
              <p class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-900">
                {@kpi_events_today}
              </p>
            </div>
            <div class="bg-white rounded-xl border border-slate-200 shadow-sm p-3 sm:p-5 lg:p-6 border-l-4 border-l-emerald-500">
              <div class="flex items-center gap-2 mb-2">
                <.icon name="hero-check-circle" class="w-5 h-5 text-emerald-500" />
                <span class="text-xs sm:text-sm font-medium text-slate-500 uppercase tracking-wide">
                  {gettext("Tasa de éxito")}
                </span>
              </div>
              <p class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-900">
                {@kpi_success_rate}%
              </p>
            </div>
            <div class="bg-white rounded-xl border border-slate-200 shadow-sm p-3 sm:p-5 lg:p-6 border-l-4 border-l-blue-500">
              <div class="flex items-center gap-2 mb-2">
                <.icon name="hero-globe-alt" class="w-5 h-5 text-blue-500" />
                <span class="text-xs sm:text-sm font-medium text-slate-500 uppercase tracking-wide">
                  {gettext("Webhooks activos")}
                </span>
              </div>
              <p class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-900">
                {Enum.count(@webhooks, &(&1.status == "active"))}
              </p>
            </div>
            <div class="bg-white rounded-xl border border-slate-200 shadow-sm p-3 sm:p-5 lg:p-6 border-l-4 border-l-amber-500">
              <div class="flex items-center gap-2 mb-2">
                <.icon name="hero-clock" class="w-5 h-5 text-amber-500" />
                <span class="text-xs sm:text-sm font-medium text-slate-500 uppercase tracking-wide">
                  {gettext("Jobs activos")}
                </span>
              </div>
              <p class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-900">
                {Enum.count(@jobs, &(&1.status == "active"))}
              </p>
            </div>
          </div>

          <%!-- ===== PENDING INVITATIONS BANNER ===== --%>
          <%= if @pending_invitations != [] do %>
            <div class="bg-indigo-50 border border-indigo-200 rounded-xl p-3 sm:p-4 mb-6 sm:mb-8">
              <div class="flex items-center gap-2 mb-3">
                <.icon name="hero-envelope" class="w-5 h-5 text-indigo-600" />
                <h3 class="text-sm sm:text-base font-semibold text-indigo-900">
                  {gettext("Invitaciones pendientes")}
                </h3>
              </div>
              <div class="space-y-2">
                <%= for inv <- @pending_invitations do %>
                  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 bg-white rounded-lg p-3 border border-indigo-100">
                    <div class="text-sm text-slate-700">
                      <span class="font-medium">{inv.project_name}</span>
                      <span class="text-slate-400 mx-1">&middot;</span>
                      <span class="text-slate-500">
                        {gettext("Rol: %{role}", role: inv.role)}
                      </span>
                    </div>
                    <div class="flex gap-2">
                      <button
                        phx-click="accept_invitation"
                        phx-value-id={inv.id}
                        class="px-3 py-1.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-lg text-xs sm:text-sm font-medium"
                      >
                        {gettext("Aceptar")}
                      </button>
                      <button
                        phx-click="reject_invitation"
                        phx-value-id={inv.id}
                        data-confirm={gettext("¿Rechazar esta invitación?")}
                        class="px-3 py-1.5 bg-red-100 hover:bg-red-200 text-red-700 rounded-lg text-xs sm:text-sm font-medium"
                      >
                        {gettext("Rechazar")}
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

          <%!-- ===== TAB NAVIGATION ===== --%>
          <div class="border-b border-slate-200 mb-6 sm:mb-8 overflow-x-auto">
            <nav
              class="-mb-px flex gap-1 sm:gap-6 lg:gap-8 min-w-max"
              aria-label={gettext("Pestañas")}
            >
              <button
                type="button"
                phx-click="switch_tab"
                phx-value-tab="overview"
                class={"whitespace-nowrap border-b-2 pb-2.5 sm:pb-4 px-1.5 sm:px-1 text-xs sm:text-sm lg:text-base transition #{tab_classes(@active_tab, "overview")}"}
              >
                {gettext("Vista general")}
              </button>
              <button
                type="button"
                phx-click="switch_tab"
                phx-value-tab="events"
                class={"whitespace-nowrap border-b-2 pb-2.5 sm:pb-4 px-1.5 sm:px-1 text-xs sm:text-sm lg:text-base transition #{tab_classes(@active_tab, "events")}"}
              >
                {gettext("Eventos")}
              </button>
              <button
                type="button"
                phx-click="switch_tab"
                phx-value-tab="webhooks"
                class={"whitespace-nowrap border-b-2 pb-2.5 sm:pb-4 px-1.5 sm:px-1 text-xs sm:text-sm lg:text-base transition #{tab_classes(@active_tab, "webhooks")}"}
              >
                {gettext("Webhooks")}
              </button>
              <button
                type="button"
                phx-click="switch_tab"
                phx-value-tab="jobs"
                class={"whitespace-nowrap border-b-2 pb-2.5 sm:pb-4 px-1.5 sm:px-1 text-xs sm:text-sm lg:text-base transition #{tab_classes(@active_tab, "jobs")}"}
              >
                {gettext("Jobs")}
              </button>
              <button
                type="button"
                phx-click="switch_tab"
                phx-value-tab="settings"
                class={"whitespace-nowrap border-b-2 pb-2.5 sm:pb-4 px-1.5 sm:px-1 text-xs sm:text-sm lg:text-base transition #{tab_classes(@active_tab, "settings")}"}
              >
                {gettext("Configuración")}
              </button>
            </nav>
          </div>

          <%!-- ===== TAB CONTENT ===== --%>
          <div class="space-y-6 sm:space-y-8">
            {render_tab(assigns)}
          </div>

          <%!-- ===== MODALS (always available) ===== --%>
          {render_modals(assigns)}
        <% else %>
          <p class="text-slate-600">{gettext("No hay proyecto para tu cuenta. Contacta soporte.")}</p>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  # ===== TAB DISPATCH =====
  defp render_tab(%{active_tab: "overview"} = assigns), do: render_overview_tab(assigns)
  defp render_tab(%{active_tab: "events"} = assigns), do: render_events_tab(assigns)
  defp render_tab(%{active_tab: "webhooks"} = assigns), do: render_webhooks_tab(assigns)
  defp render_tab(%{active_tab: "jobs"} = assigns), do: render_jobs_tab(assigns)
  defp render_tab(%{active_tab: "settings"} = assigns), do: render_settings_tab(assigns)
  defp render_tab(assigns), do: render_overview_tab(assigns)

  # ===== TAB: OVERVIEW =====
  defp render_overview_tab(assigns) do
    ~H"""
    <%!-- Row 1: API Token + Test Event (2 cols) --%>
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6 lg:gap-8">
      <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900 mb-1">{gettext("API Token")}</h2>
        <p class="text-slate-500 text-xs mb-3 break-words">
          {gettext("Header:")}
          <code class="bg-slate-100 px-1 rounded text-xs break-all">
            Authorization: Bearer &lt;token&gt;
          </code>
          {gettext("o")} <code class="bg-slate-100 px-1 rounded text-xs">X-Api-Key</code>
        </p>
        {render_token_section(assigns)}
      </section>

      <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900 mb-3">
          {gettext("Enviar evento de prueba")}
        </h2>
        <%= if can_manage_team?(@current_user_role) do %>
          <.form for={%{}} id="test-event-form" phx-submit="send_test" class="space-y-3">
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
            <div class="flex flex-col sm:flex-row gap-2">
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
                      <span class="font-medium">{if sim.matched_by_topics, do: "✓", else: "✗"}</span>
                      · {gettext("Filtros")}:
                      <span class="font-medium">{if sim.matched_by_filters, do: "✓", else: "✗"}</span>
                      <%= if sim.would_send_headers["x-signature"] do %>
                        · {gettext("HMAC")}:
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
        <% else %>
          <p class="text-sm text-slate-500 italic">
            {gettext("Solo lectura. No tienes permisos para enviar eventos.")}
          </p>
        <% end %>
      </section>
    </div>

    <%!-- System Health Status --%>
    <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div class="flex items-center gap-3">
          <span class={[
            "inline-block w-3 h-3 rounded-full",
            uptime_dot_color(@uptime_status)
          ]}>
          </span>
          <h2 class="text-base lg:text-lg font-semibold text-slate-900">
            {gettext("Estado del sistema")}
          </h2>
          <span class={[
            "px-2 py-0.5 rounded-full text-xs font-medium",
            uptime_badge_color(@uptime_status)
          ]}>
            {uptime_label(@uptime_status)}
          </span>
        </div>
        <div class="flex flex-wrap gap-2">
          <span class="px-3 py-1 bg-slate-100 rounded-full text-xs font-medium text-slate-700">
            {gettext("24h")}: {@uptime_stats.last_24h.uptime_percent}%
          </span>
          <span class="px-3 py-1 bg-slate-100 rounded-full text-xs font-medium text-slate-700">
            {gettext("7d")}: {@uptime_stats.last_7d.uptime_percent}%
          </span>
          <span class="px-3 py-1 bg-slate-100 rounded-full text-xs font-medium text-slate-700">
            {gettext("30d")}: {@uptime_stats.last_30d.uptime_percent}%
          </span>
        </div>
      </div>
    </section>

    <%!-- Row 2: Recent Events (full width) --%>
    <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
      <h2 class="text-base lg:text-lg font-semibold text-slate-900 mb-4">
        {gettext("Eventos recientes")}
      </h2>
      <div class="overflow-x-auto rounded-lg border border-slate-200">
        <table class="min-w-full">
          <thead>
            <tr class="bg-slate-50 border-b border-slate-200">
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                {gettext("ID")}
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
            <%= for e <- Enum.take(@events, 10) do %>
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

    <%!-- Row 3: Webhooks Health (full width, compact) --%>
    <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
      <h2 class="text-base lg:text-lg font-semibold text-slate-900 mb-4">{gettext("Webhooks")}</h2>
      <div class="overflow-x-auto rounded-lg border border-slate-200">
        <table class="min-w-full">
          <thead>
            <tr class="bg-slate-50 border-b border-slate-200">
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                {gettext("URL")}
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
                <td class="px-3 sm:px-4 py-2 sm:py-3 font-mono text-xs sm:text-sm text-slate-600 truncate max-w-[8rem] sm:max-w-[12rem] lg:max-w-none">
                  {w.url}
                </td>
                <td class="px-3 sm:px-4 py-2 sm:py-3">
                  <%= if health do %>
                    <span
                      title={"#{health.success_rate}% — #{health.total} #{gettext("entregas")} (24h)"}
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
    """
  end

  # ===== TAB: EVENTS =====
  defp render_events_tab(assigns) do
    ~H"""
    <%!-- Events table (full width with export) --%>
    <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-4">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900">
          {gettext("Eventos recientes")}
        </h2>
        <div class="flex flex-wrap gap-2">
          <a
            href="/export/events?format=csv"
            target="_blank"
            class="inline-flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-lg transition"
          >
            <.icon name="hero-arrow-down-tray" class="w-3.5 h-3.5" /> CSV
          </a>
          <a
            href="/export/events?format=json"
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
                {gettext("ID")}
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

    <%!-- Row 2: Event Schemas + Replay (2 cols) --%>
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6 lg:gap-8">
      <%!-- Event Schemas --%>
      <section class="bg-white rounded-xl border border-teal-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <div class="flex items-center gap-2 mb-4">
          <.icon name="hero-document-check" class="w-5 h-5 text-teal-600" />
          <h2 class="text-base lg:text-lg font-semibold text-slate-900">
            {gettext("Event Schemas")}
          </h2>
        </div>
        <%= if can_manage_team?(@current_user_role) do %>
          <.form
            for={%{}}
            id="event-schema-form"
            phx-submit="create_event_schema"
            class="flex flex-col gap-2 mb-4"
          >
            <input
              type="text"
              name="topic"
              placeholder={gettext("Topic (ej: order.created)")}
              required
              class="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm"
            />
            <textarea
              name="schema"
              rows="2"
              placeholder={
                gettext("JSON Schema (ej: {\"type\":\"object\",\"required\":[\"amount\"]})")
              }
              required
              class="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm font-mono"
            ></textarea>
            <button
              type="submit"
              phx-disable-with={gettext("Creando...")}
              class="px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white rounded-lg text-sm font-medium"
            >
              {gettext("Crear")}
            </button>
          </.form>
        <% end %>
        <%= if @event_schemas == [] do %>
          <p class="text-sm text-slate-500">
            {gettext("Sin schemas. Los eventos no serán validados.")}
          </p>
        <% else %>
          <div class="overflow-x-auto rounded-lg border border-slate-200">
            <table class="min-w-full divide-y divide-slate-200">
              <thead>
                <tr class="bg-slate-50/80">
                  <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                    {gettext("Topic")}
                  </th>
                  <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase hidden sm:table-cell">
                    {gettext("Versión")}
                  </th>
                  <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                    {gettext("Estado")}
                  </th>
                  <th class="px-3 py-2 text-right text-xs font-semibold text-slate-600 uppercase">
                    {gettext("Acciones")}
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <%= for s <- @event_schemas do %>
                  <tr class="hover:bg-slate-50/50 transition">
                    <td class="px-3 py-2 text-sm text-slate-700 font-mono">{s.topic}</td>
                    <td class="px-3 py-2 text-sm text-slate-600 hidden sm:table-cell">
                      v{s.version}
                    </td>
                    <td class="px-3 py-2">
                      <span class="px-2 py-0.5 rounded text-xs font-medium bg-teal-100 text-teal-800">
                        {s.status}
                      </span>
                    </td>
                    <%= if can_manage_team?(@current_user_role) do %>
                      <td class="px-3 py-2 text-right">
                        <button
                          phx-click="delete_event_schema"
                          phx-value-id={s.id}
                          phx-disable-with={gettext("Eliminando...")}
                          data-confirm={gettext("¿Eliminar este schema?")}
                          class="text-red-600 hover:text-red-700 text-xs font-medium disabled:opacity-50"
                        >
                          {gettext("Eliminar")}
                        </button>
                      </td>
                    <% end %>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </section>

      <%!-- Event Replay --%>
      <section class="bg-white rounded-xl border border-blue-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <div class="flex flex-wrap items-center justify-between gap-3 mb-4">
          <div class="flex items-center gap-2">
            <.icon name="hero-arrow-uturn-left" class="w-5 h-5 text-blue-600" />
            <h2 class="text-base lg:text-lg font-semibold text-slate-900">
              {gettext("Event Replay")}
            </h2>
          </div>
          <%= if can_manage_team?(@current_user_role) do %>
            <button
              type="button"
              phx-click="open_replay_modal"
              class="inline-flex items-center gap-2 px-3 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-medium text-sm shadow-sm transition"
            >
              <.icon name="hero-play" class="w-4 h-4" /> {gettext("Nuevo replay")}
            </button>
          <% end %>
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
                  <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                    {gettext("Estado")}
                  </th>
                  <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                    {gettext("Progreso")}
                  </th>
                  <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase hidden sm:table-cell">
                    {gettext("Fecha")}
                  </th>
                  <th class="px-3 py-2 text-right text-xs font-semibold text-slate-600 uppercase">
                    {gettext("Acciones")}
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <%= for r <- @replays do %>
                  <tr class="hover:bg-slate-50/50 transition">
                    <td class="px-3 py-2">
                      <span class={"inline-flex px-2 py-0.5 rounded text-xs font-medium #{replay_status_class(r.status)}"}>
                        {replay_status_label(r.status)}
                      </span>
                    </td>
                    <td class="px-3 py-2">
                      <div class="flex items-center gap-2">
                        <div class="flex-1 bg-slate-200 rounded-full h-2 max-w-[6rem] sm:max-w-[8rem]">
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
                    <td class="px-3 py-2 text-sm text-slate-600 hidden sm:table-cell">
                      {format_dt(r.inserted_at)}
                    </td>
                    <td class="px-3 py-2 text-right">
                      <%= if r.status in ["pending", "running"] && can_manage_team?(@current_user_role) do %>
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
    </div>
    """
  end

  # ===== TAB: WEBHOOKS =====
  defp render_webhooks_tab(assigns) do
    ~H"""
    <%!-- Webhooks table --%>
    <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-4">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900">{gettext("Webhooks")}</h2>
        <%= if can_manage_team?(@current_user_role) do %>
          <button
            type="button"
            phx-click="new_webhook"
            class="inline-flex items-center gap-1.5 px-3 py-2 text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 rounded-lg transition"
          >
            <.icon name="hero-plus" class="w-4 h-4" />
            {gettext("Crear webhook")}
          </button>
        <% end %>
      </div>
      <div class="overflow-x-auto rounded-lg border border-slate-200">
        <table class="min-w-full">
          <thead>
            <tr class="bg-slate-50 border-b border-slate-200">
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                {gettext("URL")}
              </th>
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700 hidden sm:table-cell">
                {gettext("Topics")}
              </th>
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                {gettext("Salud")}
              </th>
              <th class="px-3 sm:px-4 py-2 sm:py-3 text-left text-xs sm:text-sm font-medium text-slate-700">
                {gettext("Estado")}
              </th>
              <%= if can_manage_team?(@current_user_role) do %>
                <th class="px-3 sm:px-4 py-2 sm:py-3 text-right text-xs sm:text-sm font-medium text-slate-700">
                  {gettext("Acciones")}
                </th>
              <% end %>
            </tr>
          </thead>
          <tbody>
            <%= for w <- @webhooks do %>
              <% health = @webhook_health[w.id] %>
              <tr class={"border-b border-slate-100 last:border-0 #{if w.status == "inactive", do: "opacity-50"}"}>
                <td class="px-3 sm:px-4 py-2 sm:py-3 font-mono text-xs sm:text-sm text-slate-600 truncate max-w-[8rem] sm:max-w-[12rem] lg:max-w-none">
                  {w.url}
                </td>
                <td class="px-3 sm:px-4 py-2 sm:py-3 hidden sm:table-cell">
                  <%= if w.topics && w.topics != [] do %>
                    <div class="flex flex-wrap gap-1">
                      <%= for topic <- Enum.take(w.topics, 3) do %>
                        <span class="px-1.5 py-0.5 rounded text-xs bg-slate-100 text-slate-600">
                          {topic}
                        </span>
                      <% end %>
                      <%= if length(w.topics) > 3 do %>
                        <span class="text-xs text-slate-400">
                          +{length(w.topics) - 3}
                        </span>
                      <% end %>
                    </div>
                  <% else %>
                    <span class="text-xs text-slate-400">{gettext("Todos")}</span>
                  <% end %>
                </td>
                <td class="px-3 sm:px-4 py-2 sm:py-3">
                  <%= if health do %>
                    <span
                      title={"#{health.success_rate}% — #{health.total} #{gettext("entregas")} (24h)"}
                      class={"inline-flex items-center gap-1 px-2 py-0.5 rounded text-xs font-medium #{health_class(health.score)}"}
                    >
                      <span class={"w-2 h-2 rounded-full #{health_dot(health.score)}"}></span> {health_label(
                        health.score
                      )}
                    </span>
                  <% end %>
                </td>
                <td class="px-3 sm:px-4 py-2 sm:py-3">
                  <span class={[
                    "px-2 py-0.5 rounded text-xs font-medium",
                    if(w.status == "active",
                      do: "bg-emerald-100 text-emerald-700",
                      else: "bg-slate-100 text-slate-500"
                    )
                  ]}>
                    {w.status}
                  </span>
                </td>
                <%= if can_manage_team?(@current_user_role) do %>
                  <td class="px-3 sm:px-4 py-2 sm:py-3 text-right">
                    <div class="flex items-center justify-end gap-1">
                      <button
                        type="button"
                        phx-click="edit_webhook"
                        phx-value-id={w.id}
                        class="p-1.5 rounded-lg text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 transition"
                        title={gettext("Editar")}
                      >
                        <.icon name="hero-pencil-square" class="w-4 h-4" />
                      </button>
                      <%= if w.status == "active" do %>
                        <button
                          type="button"
                          phx-click="deactivate_webhook"
                          phx-value-id={w.id}
                          data-confirm={gettext("¿Desactivar este webhook?")}
                          class="p-1.5 rounded-lg text-slate-400 hover:text-red-600 hover:bg-red-50 transition"
                          title={gettext("Desactivar")}
                        >
                          <.icon name="hero-pause-circle" class="w-4 h-4" />
                        </button>
                      <% else %>
                        <button
                          type="button"
                          phx-click="activate_webhook"
                          phx-value-id={w.id}
                          class="p-1.5 rounded-lg text-slate-400 hover:text-emerald-600 hover:bg-emerald-50 transition"
                          title={gettext("Activar")}
                        >
                          <.icon name="hero-play-circle" class="w-4 h-4" />
                        </button>
                      <% end %>
                    </div>
                  </td>
                <% end %>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </section>

    <%!-- Webhook create/edit modal --%>
    <%= if @webhook_modal do %>
      <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div
          class="absolute inset-0 bg-black/50 backdrop-blur-sm"
          phx-click="close_webhook_modal"
          aria-hidden="true"
        >
        </div>
        <div
          class="relative z-10 bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-auto overflow-hidden"
          role="dialog"
          aria-modal="true"
        >
          <div class="px-6 pt-6 pb-4 flex items-start justify-between">
            <h2 class="text-lg font-semibold text-slate-900">
              {if @webhook_modal == :new,
                do: gettext("Crear webhook"),
                else: gettext("Editar webhook")}
            </h2>
            <button
              type="button"
              phx-click="close_webhook_modal"
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
          <form phx-submit="save_webhook" class="px-6 pb-6 space-y-4">
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1">{gettext("URL")}</label>
              <input
                type="url"
                name="webhook[url]"
                value={@webhook_form["url"]}
                required
                placeholder={gettext("https://ejemplo.com/webhook")}
                class="w-full px-3 py-2 rounded-lg border border-slate-300 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1">
                {gettext("Topics")}
                <span class="font-normal text-slate-400">
                  ({gettext("separados por coma, vacío = todos")})
                </span>
              </label>
              <input
                type="text"
                name="webhook[topics]"
                value={@webhook_form["topics"]}
                placeholder={gettext("user.created, order.paid")}
                class="w-full px-3 py-2 rounded-lg border border-slate-300 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1">
                {gettext("Secreto HMAC")}
                <span class="font-normal text-slate-400">
                  ({gettext("opcional, dejar vacío para mantener el actual")})
                </span>
              </label>
              <input
                type="password"
                name="webhook[secret]"
                value=""
                placeholder="whsec_..."
                autocomplete="off"
                class="w-full px-3 py-2 rounded-lg border border-slate-300 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500"
              />
            </div>
            <div class="flex flex-col-reverse sm:flex-row sm:justify-end gap-3 pt-2">
              <button
                type="button"
                phx-click="close_webhook_modal"
                class="w-full sm:w-auto px-4 py-2 rounded-lg border border-slate-300 bg-white hover:bg-slate-50 text-slate-700 text-sm font-medium transition"
              >
                {gettext("Cancelar")}
              </button>
              <button
                type="submit"
                phx-disable-with={gettext("Guardando...")}
                class="w-full sm:w-auto px-4 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium transition"
              >
                {if @webhook_modal == :new, do: gettext("Crear"), else: gettext("Guardar")}
              </button>
            </div>
          </form>
        </div>
      </div>
    <% end %>

    <%!-- Deliveries --%>
    <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 mb-4">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900">{gettext("Entregas")}</h2>
        <div class="flex flex-wrap gap-2">
          <a
            href="/export/deliveries?format=csv"
            target="_blank"
            class="inline-flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-lg transition"
          >
            <.icon name="hero-arrow-down-tray" class="w-3.5 h-3.5" /> CSV
          </a>
          <a
            href="/export/deliveries?format=json"
            target="_blank"
            class="inline-flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-lg transition"
          >
            <.icon name="hero-arrow-down-tray" class="w-3.5 h-3.5" /> JSON
          </a>
        </div>
      </div>
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
                  <%= if d.status != "success" and d.status != "pending" and can_manage_team?(@current_user_role) do %>
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
      <section class="bg-white rounded-xl border border-red-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <div class="flex items-center gap-2 mb-4">
          <span class="w-2.5 h-2.5 rounded-full bg-red-500 animate-pulse"></span>
          <h2 class="text-base font-semibold text-red-900">{gettext("Dead Letter Queue")}</h2>
          <span class="px-2 py-0.5 rounded-full bg-red-100 text-red-700 text-xs font-medium">
            {length(@dead_letters)}
          </span>
        </div>
        <p class="text-sm text-red-700 mb-4">
          {gettext("Entregas que agotaron todos los reintentos. Puedes reintentar o descartar.")}
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
                  <td class="px-3 sm:px-4 py-2 sm:py-3 font-mono text-xs text-slate-600 truncate max-w-[6rem] sm:max-w-[10rem] lg:max-w-none">
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
                    <%= if can_manage_team?(@current_user_role) do %>
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
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </section>
    <% end %>
    """
  end

  # ===== TAB: JOBS =====
  defp render_jobs_tab(assigns) do
    ~H"""
    <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
      <div class="flex flex-wrap items-center justify-between gap-3 sm:gap-4 mb-4 sm:mb-6">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900">{gettext("Jobs")}</h2>
        <div class="flex flex-wrap gap-2">
          <a
            href="/export/jobs?format=csv"
            target="_blank"
            class="inline-flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-lg transition"
          >
            <.icon name="hero-arrow-down-tray" class="w-3.5 h-3.5" /> CSV
          </a>
          <%= if can_manage_team?(@current_user_role) do %>
            <button
              type="button"
              phx-click="new_job"
              phx-disable-with={gettext("Cargando...")}
              class="inline-flex items-center gap-2 px-3 sm:px-4 py-2 sm:py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl font-medium text-sm shadow-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
            >
              <.icon name="hero-plus" class="w-4 h-4" /> {gettext("Nuevo job")}
            </button>
          <% end %>
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
                <td class="px-3 sm:px-5 py-3 sm:py-4 font-medium text-slate-800 text-sm">{j.name}</td>
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
                  <div class="flex flex-col sm:flex-row sm:inline-flex gap-1 sm:gap-2 items-start sm:items-center">
                    <%= if can_manage_team?(@current_user_role) do %>
                      <button
                        phx-click="edit_job"
                        phx-value-id={j.id}
                        phx-disable-with={gettext("Cargando...")}
                        class="text-indigo-600 hover:text-indigo-700 font-medium text-xs sm:text-sm disabled:opacity-70"
                      >
                        {gettext("Editar")}
                      </button>
                    <% end %>
                    <button
                      phx-click="show_job_runs"
                      phx-value-id={j.id}
                      phx-disable-with={gettext("Cargando...")}
                      class="text-slate-600 hover:text-slate-700 font-medium text-xs sm:text-sm disabled:opacity-70"
                    >
                      {gettext("Runs")}
                    </button>
                    <%= if j.status == "active" && can_manage_team?(@current_user_role) do %>
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
    """
  end

  # ===== TAB: SETTINGS =====
  defp render_settings_tab(assigns) do
    ~H"""
    <%!-- Row 1: Project + Analytics (2 cols) --%>
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6 lg:gap-8">
      <%!-- Project info --%>
      <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <h2 class="text-base lg:text-lg font-semibold text-slate-900 mb-2">{gettext("Proyecto")}</h2>
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
            <%= if can_admin_team?(@current_user_role) do %>
              <button
                type="button"
                phx-click="edit_project_name"
                class="ml-2 text-indigo-600 hover:text-indigo-700 text-sm font-medium"
              >
                {gettext("Editar nombre")}
              </button>
            <% end %>
          </p>
        <% end %>
        <p class="text-slate-500 text-sm font-mono mt-1 break-all">{@project.id}</p>
        <%!-- Delete project --%>
        <%= if @project.user_id == @current_user.id do %>
          <div class="mt-4 pt-4 border-t border-slate-200">
            <button
              phx-click="delete_project"
              phx-value-id={@project.id}
              phx-disable-with={gettext("Eliminando...")}
              data-confirm={gettext("¿Eliminar este proyecto? Esta acción no se puede deshacer.")}
              class="text-red-600 hover:text-red-700 text-xs font-medium disabled:opacity-50"
            >
              {gettext("Eliminar proyecto")}
            </button>
          </div>
        <% end %>
      </section>

      <%!-- Analytics (always visible) --%>
      <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <div class="flex items-center gap-2 mb-4">
          <.icon name="hero-chart-bar" class="w-5 h-5 text-indigo-600" />
          <h2 class="text-base lg:text-lg font-semibold text-slate-900">{gettext("Analíticas")}</h2>
        </div>
        <%= if @analytics != %{} do %>
          <div class="grid grid-cols-1 gap-4">
            <div class="border border-slate-200 rounded-lg p-3">
              <h3 class="text-sm font-semibold text-slate-700 mb-3">
                {gettext("Eventos por día (30d)")}
              </h3>
              <div class="h-32 sm:h-40">
                <canvas
                  id="events-chart"
                  phx-hook="Chart"
                  data-chart-type="line"
                  data-chart-labels={Jason.encode!(Enum.map(@analytics.events_per_day, & &1.date))}
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
            <div class="border border-slate-200 rounded-lg p-3">
              <h3 class="text-sm font-semibold text-slate-700 mb-3">
                {gettext("Entregas por día (30d)")}
              </h3>
              <div class="h-32 sm:h-40">
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
          </div>
        <% else %>
          <p class="text-sm text-slate-400 text-center py-8">{gettext("Sin datos")}</p>
        <% end %>
      </section>
    </div>

    <%!-- Row 2: Sandbox + Team (2 cols) --%>
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6 lg:gap-8">
      <%!-- Sandbox --%>
      <section class="bg-white rounded-xl border border-purple-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <div class="flex flex-wrap items-center justify-between gap-3 mb-4">
          <div class="flex items-center gap-2">
            <.icon name="hero-beaker" class="w-5 h-5 text-purple-600" />
            <h2 class="text-base lg:text-lg font-semibold text-slate-900">{gettext("Sandbox")}</h2>
          </div>
          <%= if can_manage_team?(@current_user_role) do %>
            <button
              type="button"
              phx-click="create_sandbox"
              class="inline-flex items-center gap-2 px-3 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded-xl font-medium text-sm shadow-sm transition"
            >
              <.icon name="hero-plus" class="w-4 h-4" /> {gettext("Crear endpoint")}
            </button>
          <% end %>
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
                <%= if can_manage_team?(@current_user_role) do %>
                  <button
                    type="button"
                    phx-click="delete_sandbox"
                    phx-value-id={ep.id}
                    phx-disable-with="..."
                    class="ml-1 text-slate-400 hover:text-red-500 disabled:opacity-50"
                    title={gettext("Eliminar")}
                  >
                    <.icon name="hero-x-mark" class="w-3.5 h-3.5" />
                  </button>
                <% end %>
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
                    <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                      {gettext("Método")}
                    </th>
                    <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase hidden sm:table-cell">
                      {gettext("Body")}
                    </th>
                    <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                      {gettext("Fecha")}
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-100">
                  <%= for req <- @sandbox_requests do %>
                    <tr class="hover:bg-slate-50/50 transition">
                      <td class="px-3 py-2">
                        <span class={"inline-flex px-2 py-0.5 rounded text-xs font-medium #{method_color(req.method)}"}>
                          {req.method}
                        </span>
                      </td>
                      <td class="px-3 py-2 text-xs text-slate-600 font-mono truncate max-w-[16rem] hidden sm:table-cell">
                        {if req.body && req.body != "", do: String.slice(req.body, 0, 80), else: "—"}
                      </td>
                      <td class="px-3 py-2 text-xs text-slate-600">{format_dt(req.inserted_at)}</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        <% end %>
      </section>

      <%!-- Team --%>
      <section class="bg-white rounded-xl border border-cyan-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
        <div class="flex items-center justify-between mb-4">
          <div class="flex items-center gap-2">
            <.icon name="hero-user-group" class="w-5 h-5 text-cyan-600" />
            <h2 class="text-base lg:text-lg font-semibold text-slate-900">{gettext("Equipo")}</h2>
          </div>
          <span class={"px-2 py-0.5 rounded text-xs font-medium #{member_role_class(@current_user_role)}"}>
            {gettext("Tu rol: %{role}", role: @current_user_role || "—")}
          </span>
        </div>
        <%= if can_manage_team?(@current_user_role) do %>
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
            <select name="role" class="border border-slate-300 rounded-lg px-3 py-2 text-sm bg-white">
              <option value="viewer">{gettext("Viewer")}</option>
              <%= if can_admin_team?(@current_user_role) do %>
                <option value="editor">{gettext("Editor")}</option>
              <% end %>
            </select>
            <button
              type="submit"
              phx-disable-with={gettext("Invitando...")}
              class="px-4 py-2 bg-cyan-600 hover:bg-cyan-700 text-white rounded-lg text-sm font-medium shrink-0"
            >
              {gettext("Invitar")}
            </button>
          </.form>
        <% end %>
        <%= if @team_members == [] do %>
          <p class="text-sm text-slate-500">
            {gettext("Solo tú tienes acceso. Invita colaboradores.")}
          </p>
        <% else %>
          <div class="overflow-x-auto rounded-lg border border-slate-200">
            <table class="min-w-full divide-y divide-slate-200">
              <thead>
                <tr class="bg-slate-50/80">
                  <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                    {gettext("Usuario")}
                  </th>
                  <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                    {gettext("Rol")}
                  </th>
                  <th class="px-3 py-2 text-left text-xs font-semibold text-slate-600 uppercase">
                    {gettext("Estado")}
                  </th>
                  <%= if can_admin_team?(@current_user_role) do %>
                    <th class="px-3 py-2 text-right text-xs font-semibold text-slate-600 uppercase">
                      {gettext("Acciones")}
                    </th>
                  <% end %>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <%= for m <- @team_members do %>
                  <tr class="hover:bg-slate-50/50 transition">
                    <td class="px-3 py-2 text-sm text-slate-700 font-mono truncate max-w-[6rem] sm:max-w-[10rem] lg:max-w-none">
                      {String.slice(m.user_id, 0, 8)}...
                    </td>
                    <td class="px-3 py-2">
                      <span class={"px-2 py-0.5 rounded text-xs font-medium #{member_role_class(m.role)}"}>
                        {m.role}
                      </span>
                    </td>
                    <td class="px-3 py-2">
                      <span class={"px-2 py-0.5 rounded text-xs font-medium #{member_status_class(m.status)}"}>
                        {m.status}
                      </span>
                    </td>
                    <%= if can_admin_team?(@current_user_role) do %>
                      <td class="px-3 py-2 text-right">
                        <%= if m.role != "owner" do %>
                          <div class="flex flex-col sm:flex-row sm:justify-end gap-1">
                            <%= if m.role == "viewer" do %>
                              <button
                                phx-click="update_member_role"
                                phx-value-id={m.id}
                                phx-value-role="editor"
                                phx-disable-with={gettext("Actualizando...")}
                                class="text-indigo-600 hover:text-indigo-700 text-xs font-medium disabled:opacity-50"
                              >
                                {gettext("Promover")}
                              </button>
                            <% end %>
                            <%= if m.role == "editor" do %>
                              <button
                                phx-click="update_member_role"
                                phx-value-id={m.id}
                                phx-value-role="viewer"
                                phx-disable-with={gettext("Actualizando...")}
                                class="text-amber-600 hover:text-amber-700 text-xs font-medium disabled:opacity-50"
                              >
                                {gettext("Degradar")}
                              </button>
                            <% end %>
                            <button
                              phx-click="remove_member"
                              phx-value-id={m.id}
                              phx-disable-with={gettext("Removiendo...")}
                              data-confirm={gettext("¿Remover este miembro?")}
                              class="text-red-600 hover:text-red-700 text-xs font-medium disabled:opacity-50"
                            >
                              {gettext("Remover")}
                            </button>
                          </div>
                        <% end %>
                      </td>
                    <% end %>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </section>
    </div>

    <%!-- Row 3: More analytics charts (full width, 2-col grid) --%>
    <%= if @analytics != %{} do %>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 sm:gap-6 lg:gap-8">
        <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6">
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
        </section>
        <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6">
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
                  <span class="text-emerald-700 font-medium text-xs shrink-0">{ws.success}</span>
                  <span class="text-slate-300 shrink-0">/</span>
                  <span class="text-red-600 font-medium text-xs shrink-0">{ws.failed}</span>
                </div>
              <% end %>
            </div>
          <% end %>
        </section>
      </div>
    <% end %>

    <%!-- Row 4: Audit Log (full width) --%>
    <section class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 sm:p-6 lg:p-8 overflow-hidden">
      <div class="flex items-center gap-2 mb-4">
        <.icon name="hero-clipboard-document-list" class="w-5 h-5 text-slate-600" />
        <h2 class="text-base lg:text-lg font-semibold text-slate-900">
          {gettext("Registro de actividad")}
        </h2>
      </div>
      <%= if @audit_logs == [] do %>
        <p class="text-sm text-slate-500">{gettext("Sin actividad registrada.")}</p>
      <% else %>
        <div class="space-y-2 max-h-48 sm:max-h-80 overflow-y-auto">
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
    """
  end

  # ===== MODALS (rendered outside tabs) =====
  defp render_modals(assigns) do
    ~H"""
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
              class="p-2 -m-2 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-100 transition"
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

    <%!-- Job form modal --%>
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
          <.form for={@job_form} id="job-form" phx-submit="save_job" class="flex-1 overflow-y-auto">
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
                <h3 class="text-sm font-semibold text-slate-800 mb-4">{gettext("Programación")}</h3>
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
                      placeholder={gettext("mi.topic")}
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
                      <option value="POST" selected={p["action_method"] == "POST"}>POST</option>
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

    <%!-- Job runs modal --%>
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
              class="p-2 -m-2 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-100 transition"
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
                    <td class="px-4 py-2 text-sm text-slate-600">{format_dt(r.executed_at)}</td>
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

    <%!-- Confirm regenerate token modal --%>
    <%= if @confirm_regenerate_token do %>
      <div class="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6">
        <div
          class="absolute inset-0 bg-slate-900/60 backdrop-blur-sm"
          phx-click="cancel_confirm_regenerate"
          aria-hidden="true"
        >
        </div>
        <div
          class="relative z-10 w-full max-w-md bg-white rounded-2xl shadow-2xl p-5 sm:p-6 border border-slate-200/50"
          role="dialog"
          aria-modal="true"
          aria-labelledby="confirm-regenerate-title"
        >
          <div class="flex items-start gap-4">
            <div class="flex-shrink-0 w-10 h-10 rounded-full bg-amber-100 flex items-center justify-center">
              <.icon name="hero-exclamation-triangle" class="w-5 h-5 text-amber-600" />
            </div>
            <div class="flex-1">
              <h3 id="confirm-regenerate-title" class="text-lg font-semibold text-slate-900">
                {gettext("¿Regenerar token?")}
              </h3>
              <p class="mt-2 text-sm text-slate-600">
                {gettext(
                  "El token actual dejará de funcionar inmediatamente. Asegúrate de actualizar tus integraciones con el nuevo token."
                )}
              </p>
            </div>
          </div>
          <div class="mt-6 flex justify-end gap-3">
            <button
              type="button"
              phx-click="cancel_confirm_regenerate"
              class="px-4 py-2 border border-slate-300 rounded-lg text-slate-700 hover:bg-slate-50 text-sm font-medium transition"
            >
              {gettext("Cancelar")}
            </button>
            <button
              type="button"
              phx-click="regenerate_token"
              phx-disable-with={gettext("Regenerando...")}
              class="px-4 py-2 bg-amber-600 hover:bg-amber-700 text-white rounded-lg text-sm font-medium transition disabled:opacity-70 disabled:cursor-not-allowed"
            >
              {gettext("Sí, regenerar")}
            </button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ===== TOKEN SECTION (deduplicated) =====
  defp render_token_section(assigns) do
    assigns =
      if assigns[:new_token] do
        if assigns[:token_source] == :registration do
          assigns
          |> Map.put(
            :token_wrapper_class,
            "rounded-lg border-2 border-emerald-300 bg-emerald-50 p-3 sm:p-4"
          )
          |> Map.put(:token_icon, "hero-check-circle")
          |> Map.put(:token_icon_class, "w-5 h-5 text-emerald-600")
          |> Map.put(:token_msg_class, "text-emerald-800 font-medium text-sm")
          |> Map.put(
            :token_msg,
            gettext("Tu API token ha sido creado. Cópialo y guárdalo ahora.")
          )
          |> Map.put(:token_input_border, "border-emerald-200")
        else
          assigns
          |> Map.put(
            :token_wrapper_class,
            "rounded-lg border-2 border-amber-300 bg-amber-50 p-3 sm:p-4"
          )
          |> Map.put(:token_icon, "hero-exclamation-triangle")
          |> Map.put(:token_icon_class, "w-5 h-5 text-amber-600")
          |> Map.put(:token_msg_class, "text-amber-800 font-medium text-sm")
          |> Map.put(
            :token_msg,
            gettext("El token anterior ha sido revocado. Copia y guarda el nuevo.")
          )
          |> Map.put(:token_input_border, "border-amber-200")
        end
      else
        assigns
      end

    ~H"""
    <%= if @new_token do %>
      <div class={@token_wrapper_class}>
        <div class="flex items-center gap-2 mb-3">
          <.icon name={@token_icon} class={@token_icon_class} />
          <span class={@token_msg_class}>{@token_msg}</span>
        </div>
        <div class={"flex items-stretch gap-0 overflow-hidden rounded-lg border #{@token_input_border} bg-white"}>
          <input
            id="token-input"
            type="text"
            readonly
            value={if @token_visible, do: @new_token, else: String.duplicate("•", 20)}
            data-real-value={@new_token}
            class="flex-1 min-w-0 font-mono text-sm px-4 py-3 bg-transparent border-0 text-slate-900 focus:ring-0"
            phx-no-feedback
          />
          <button
            type="button"
            phx-click="toggle_token_visibility"
            class={"p-3 border-l #{@token_input_border} bg-white hover:bg-slate-50 text-slate-500 hover:text-slate-700 transition"}
            title={if @token_visible, do: gettext("Ocultar"), else: gettext("Mostrar")}
            aria-label={
              if @token_visible, do: gettext("Ocultar token"), else: gettext("Mostrar token")
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
            class={"p-3 border-l #{@token_input_border} bg-white hover:bg-slate-50 text-slate-500 hover:text-emerald-600 transition"}
            title={gettext("Copiar token")}
            aria-label={gettext("Copiar token")}
          >
            <span data-copy-icon><.icon name="hero-clipboard-document" class="w-5 h-5" /></span>
            <span data-check-icon class="hidden">
              <.icon name="hero-check" class="w-5 h-5 text-emerald-600" />
            </span>
          </button>
        </div>
      </div>
      <%= if can_admin_team?(@current_user_role) do %>
        <div class="mt-3 flex items-center gap-3">
          <button
            phx-click="show_confirm_regenerate"
            type="button"
            class="px-4 py-2 bg-slate-200 hover:bg-slate-300 text-slate-800 rounded-lg font-medium text-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
          >
            {gettext("Regenerar token")}
          </button>
        </div>
      <% end %>
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
        <%= if can_admin_team?(@current_user_role) do %>
          <div class="flex flex-col sm:flex-row gap-2 mt-3">
            <button
              phx-click="show_confirm_regenerate"
              type="button"
              class="px-4 py-2 bg-slate-200 hover:bg-slate-300 text-slate-800 rounded-lg font-medium text-sm transition disabled:opacity-70 disabled:cursor-not-allowed"
            >
              {gettext("Regenerar token")}
            </button>
          </div>
        <% end %>
        <div class="mt-4 pt-4 border-t border-slate-200 space-y-2">
          <div class="flex items-center gap-2">
            <span class="text-xs font-medium text-slate-500 uppercase">{gettext("Scopes")}:</span>
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
              <span class="text-xs text-slate-400">{gettext("Sin restricción (cualquier IP)")}</span>
            <% end %>
          </div>
        </div>
      <% else %>
        <p class="text-slate-600 mb-3">{gettext("No hay API token. Genera uno para empezar.")}</p>
        <%= if can_admin_team?(@current_user_role) do %>
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

  defp health_label(:healthy), do: gettext("OK")
  defp health_label(:degraded), do: gettext("Degradado")
  defp health_label(:critical), do: gettext("Crítico")
  defp health_label(:no_data), do: gettext("Sin datos")
  defp health_label(_), do: "—"

  # Notification i18n helpers — translate based on type + metadata
  defp notification_title(%{type: "webhook_failing"}), do: gettext("Webhook fallando")
  defp notification_title(%{type: "job_failed"}), do: gettext("Job fallido")
  defp notification_title(%{type: "dlq_entry"}), do: gettext("Entrega movida a DLQ")
  defp notification_title(%{type: "replay_completed"}), do: gettext("Replay completado")
  defp notification_title(%{type: "team_invite"}), do: gettext("Invitación a proyecto")
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

  defp notification_message(%{type: "team_invite", metadata: %{"project_id" => _pid}} = _notif) do
    gettext("Has sido invitado a un proyecto.")
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

  # KPI helpers
  defp compute_kpi_events_today(events) do
    cutoff = DateTime.utc_now() |> DateTime.add(-24, :hour)

    Enum.count(events, fn e -> e.occurred_at && DateTime.compare(e.occurred_at, cutoff) == :gt end)
  end

  defp compute_kpi_success_rate(deliveries) do
    total = length(deliveries)

    if total > 0 do
      success = Enum.count(deliveries, &(&1.status == "success"))
      Float.round(success / total * 100, 1)
    else
      0.0
    end
  end

  defp tab_classes(active_tab, tab) do
    if active_tab == tab do
      "border-indigo-600 text-indigo-700 font-semibold"
    else
      "border-transparent text-slate-500 hover:text-slate-700 hover:border-slate-300"
    end
  end

  # Permission helpers: :write = editor+owner, :admin = owner only
  defp authorize(socket, :write) do
    if socket.assigns.current_user_role in ["owner", "editor"],
      do: :ok,
      else: {:error, gettext("No tienes permisos para esta acción.")}
  end

  defp authorize(socket, :admin) do
    if socket.assigns.current_user_role == "owner",
      do: :ok,
      else: {:error, gettext("Solo el dueño del proyecto puede hacer esto.")}
  end

  defp with_permission(socket, level, fun) do
    case authorize(socket, level) do
      :ok -> fun.()
      {:error, msg} -> {:noreply, put_flash(socket, :error, msg)}
    end
  end

  defp compute_user_role(nil, _user), do: nil

  defp compute_user_role(project, user) do
    if project.user_id == user.id do
      "owner"
    else
      Teams.get_member_role(project.id, user.id) || "viewer"
    end
  end

  defp can_manage_team?(role), do: role in ["owner", "editor"]
  defp can_admin_team?(role), do: role == "owner"

  defp format_changeset_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join("; ", fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
  end

  defp format_changeset_errors(_), do: gettext("Error desconocido")

  defp uptime_dot_color(%{status: "healthy"}), do: "bg-emerald-500"
  defp uptime_dot_color(%{status: "degraded"}), do: "bg-amber-500"
  defp uptime_dot_color(%{status: "unhealthy"}), do: "bg-red-500"
  defp uptime_dot_color(_), do: "bg-slate-400"

  defp uptime_badge_color(%{status: "healthy"}), do: "bg-emerald-100 text-emerald-800"
  defp uptime_badge_color(%{status: "degraded"}), do: "bg-amber-100 text-amber-800"
  defp uptime_badge_color(%{status: "unhealthy"}), do: "bg-red-100 text-red-800"
  defp uptime_badge_color(_), do: "bg-slate-100 text-slate-600"

  defp uptime_label(%{status: "healthy"}), do: gettext("Saludable")
  defp uptime_label(%{status: "degraded"}), do: gettext("Degradado")
  defp uptime_label(%{status: "unhealthy"}), do: gettext("No saludable")
  defp uptime_label(_), do: gettext("Desconocido")

  defp load_uptime_status do
    case StreamflixCore.Uptime.latest_check() do
      nil -> %{status: "unknown", checks: %{}}
      check -> check
    end
  end

  defp load_uptime_stats do
    %{
      last_24h: StreamflixCore.Uptime.calculate_uptime(:last_24h),
      last_7d: StreamflixCore.Uptime.calculate_uptime(:last_7d),
      last_30d: StreamflixCore.Uptime.calculate_uptime(:last_30d)
    }
  end
end
