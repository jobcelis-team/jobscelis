defmodule StreamflixWebWeb.PlatformDashboardLive do
  @moduledoc """
  Main platform dashboard LiveView. Handles event routing, state management,
  and delegates rendering to TabComponents and ModalComponents.
  """
  use StreamflixWebWeb, :live_view

  alias StreamflixCore.Platform
  alias StreamflixCore.Notifications
  alias StreamflixCore.Audit
  alias StreamflixCore.Teams

  import StreamflixWebWeb.PlatformDashboard.Helpers

  @impl true
  def mount(_params, session, socket) do
    user = socket.assigns.current_user
    projects = Teams.list_all_accessible_projects(user.id)

    # Notifications are user-scoped (not project-scoped), load here
    {notifications, unread_count} =
      if connected?(socket) do
        tasks = [
          Task.async(fn -> Notifications.list_for_user(user.id, limit: 10) end),
          Task.async(fn -> Notifications.unread_count(user.id) end)
        ]

        [notifs, unread] = Task.await_many(tasks, 10_000)
        {notifs, unread}
      else
        {[], 0}
      end

    socket =
      assign(socket, %{
        projects: projects,
        project: nil,
        show_project_selector: false,
        switching_project: false,
        api_key: nil,
        events: [],
        webhooks: [],
        webhook_health: %{},
        simulation_result: nil,
        dead_letters: [],
        replays: [],
        replay_modal: false,
        sandbox_endpoints: [],
        sandbox_active: nil,
        sandbox_requests: [],
        audit_logs: [],
        event_schemas: [],
        team_members: [],
        current_user_role: nil,
        analytics: %{
          events_per_day: [],
          deliveries_per_day: [],
          top_topics: [],
          webhook_stats: []
        },
        active_tab: "overview",
        kpi_events_today: 0,
        kpi_success_rate: 0.0,
        notifications: notifications,
        unread_count: unread_count,
        show_notifications: false,
        pending_invitations: [],
        jobs: [],
        deliveries: [],
        test_topic: "",
        test_payload: "{}",
        new_token: nil,
        token_source: nil,
        token_visible: true,
        editing_project_name: false,
        job_modal: nil,
        job_runs_modal: nil,
        job_form: nil,
        job_form_errors: [],
        job_step: 1,
        cron_preview: [],
        page_title: gettext("Dashboard"),
        active_page: :dashboard,
        webhook_modal: nil,
        webhook_step: 1,
        webhook_form: %{"url" => "", "topics" => "", "secret" => ""},
        webhook_form_errors: [],
        confirm_regenerate_token: false,
        uptime_status: %{status: "unknown", checks: %{}},
        uptime_stats: %{
          last_24h: %{uptime_percent: 0.0},
          last_7d: %{uptime_percent: 0.0},
          last_30d: %{uptime_percent: 0.0}
        },
        fresh_api_key: session["fresh_api_key"],
        event_detail: nil,
        event_deliveries: [],
        search_query: "",
        search_results: nil,
        selected_dead_letters: [],
        onboarding_step: nil,
        pipelines: [],
        pipeline_modal: nil,
        pipeline_form: %{"name" => "", "topics" => "", "description" => "", "steps" => "[]"},
        oban_queue_stats: [],
        oban_state_counts: %{},
        oban_jobs: [],
        oban_filter_state: nil,
        oban_filter_queue: nil
      })

    if connected?(socket), do: Notifications.subscribe(user.id)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    projects = socket.assigns.projects
    current_project = socket.assigns.project
    user = socket.assigns.current_user
    url_has_project = is_binary(params["project"]) and params["project"] != ""

    # Resolve target project: URL param → user's last_project_id → default
    target_project =
      if url_has_project do
        Enum.find(projects, fn p -> p.id == params["project"] end)
      else
        nil
      end

    # If no URL param, try the user's last selected project (server-side, secure)
    target_project =
      target_project ||
        case user.last_project_id do
          id when is_binary(id) and id != "" ->
            Enum.find(projects, fn p -> p.id == id end)

          _ ->
            nil
        end

    target_project =
      target_project || Enum.find(projects, & &1.is_default) || List.first(projects)

    cond do
      # No project available at all
      target_project == nil ->
        {:noreply, socket}

      # Same project — no reload needed
      current_project && current_project.id == target_project.id ->
        # Ensure URL has project param (e.g. navigated back without it)
        if not url_has_project and connected?(socket) do
          {:noreply,
           push_patch(socket, to: ~p"/platform?project=#{target_project.id}", replace: true)}
        else
          {:noreply, socket}
        end

      # First load (mount) — load data directly
      current_project == nil ->
        socket = load_project_data(socket, target_project)

        if connected?(socket) do
          send(self(), :load_deferred)
          Platform.subscribe(target_project.id)
          # Persist selection server-side (async, non-blocking)
          save_last_project(user, target_project.id)
        end

        # Update URL to include project param
        socket =
          if not url_has_project and connected?(socket) do
            push_patch(socket, to: ~p"/platform?project=#{target_project.id}", replace: true)
          else
            socket
          end

        {:noreply, socket}

      # Switching to a different project — show overlay, defer load
      true ->
        send(self(), {:do_switch_project, target_project.id})

        {:noreply,
         socket
         |> assign(:switching_project, true)
         |> assign(:show_project_selector, false)}
    end
  end

  @impl true
  def handle_event("apply_test_template", %{"template" => template}, socket) do
    {topic, payload} = test_event_template(template)
    {:noreply, socket |> assign(:test_topic, topic) |> assign(:test_payload, payload)}
  end

  @impl true
  def handle_event("apply_schema_template", %{"template" => template}, socket) do
    {topic, schema} = schema_template(template)
    {:noreply, socket |> assign(:schema_topic, topic) |> assign(:schema_body, schema)}
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
         |> assign(:job_form, form)
         |> assign(:job_step, 1)}
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
         |> assign(:job_form, form)
         |> assign(:job_step, 1)}
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
     |> assign(:job_form, nil)
     |> assign(:job_form_errors, [])
     |> assign(:job_step, 1)}
  end

  @impl true
  def handle_event("job_step", %{"step" => step}, socket) do
    {:noreply, assign(socket, :job_step, String.to_integer(step))}
  end

  @impl true
  def handle_event("job_form_change", params, socket) do
    current = if socket.assigns.job_form, do: socket.assigns.job_form.params || %{}, else: %{}
    merged = Map.merge(current, params)
    errors = validate_job_form(merged)

    {:noreply,
     socket
     |> assign(:job_form, to_form(merged))
     |> assign(:job_form_errors, errors)}
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
              |> assign(:job_step, 1)

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

    notifications =
      Enum.map(socket.assigns.notifications, &Map.put(&1, :read, true))

    {:noreply,
     socket
     |> assign(:notifications, notifications)
     |> assign(:unread_count, 0)}
  end

  @impl true
  def handle_event("mark_notification_read", %{"id" => id}, socket) do
    Notifications.mark_as_read(id)

    notifications =
      Enum.map(socket.assigns.notifications, fn n ->
        if to_string(n.id) == id, do: Map.put(n, :read, true), else: n
      end)

    unread = max(socket.assigns.unread_count - 1, 0)

    {:noreply,
     socket
     |> assign(:notifications, notifications)
     |> assign(:unread_count, unread)}
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
       |> assign(:webhook_step, 1)
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
           |> assign(:webhook_step, 1)
           |> assign(:webhook_form, %{
             "url" => w.url,
             "topics" => Enum.join(w.topics || [], ", "),
             "secret" => ""
           })}
      end
    end)
  end

  def handle_event("close_webhook_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:webhook_modal, nil)
     |> assign(:webhook_form_errors, [])
     |> assign(:webhook_step, 1)}
  end

  def handle_event("webhook_step", %{"step" => step}, socket) do
    {:noreply, assign(socket, :webhook_step, String.to_integer(step))}
  end

  def handle_event("webhook_form_change", %{"webhook" => params}, socket) do
    current = socket.assigns.webhook_form
    merged = Map.merge(current, params)
    errors = validate_webhook_form(merged)

    {:noreply,
     socket
     |> assign(:webhook_form, merged)
     |> assign(:webhook_form_errors, errors)}
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
               |> assign(:webhook_step, 1)
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
               |> assign(:webhook_step, 1)
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
  def handle_event("switch_tab", %{"tab" => "queue"}, socket) do
    if StreamflixAccounts.Schemas.User.superadmin?(socket.assigns.current_user) do
      {:noreply, assign(socket, :active_tab, "queue")}
    else
      {:noreply, put_flash(socket, :error, gettext("No tienes permisos para esta sección."))}
    end
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket)
      when tab in ~w(overview events webhooks jobs pipelines settings) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  # ---------- Pipeline CRUD ----------

  @impl true
  def handle_event("new_pipeline", _, socket) do
    {:noreply,
     socket
     |> assign(:pipeline_modal, :new)
     |> assign(:pipeline_form, %{
       "name" => "",
       "topics" => "",
       "description" => "",
       "steps" => "[]"
     })}
  end

  @impl true
  def handle_event("edit_pipeline", %{"id" => id}, socket) do
    case Platform.get_pipeline(id) do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("Pipeline no encontrado."))}

      pipeline ->
        steps_json =
          case Jason.encode(pipeline.steps || [], pretty: true) do
            {:ok, json} -> json
            _ -> "[]"
          end

        {:noreply,
         socket
         |> assign(:pipeline_modal, pipeline.id)
         |> assign(:pipeline_form, %{
           "name" => pipeline.name,
           "topics" => Enum.join(pipeline.topics || [], ", "),
           "description" => pipeline.description || "",
           "steps" => steps_json
         })}
    end
  end

  @impl true
  def handle_event("save_pipeline", params, socket) do
    project = socket.assigns.project

    topics =
      params["topics"]
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    steps =
      case Jason.decode(params["steps"] || "[]") do
        {:ok, s} when is_list(s) -> s
        _ -> []
      end

    attrs = %{
      "name" => params["name"],
      "description" => params["description"],
      "topics" => topics,
      "steps" => steps
    }

    result =
      if socket.assigns.pipeline_modal == :new do
        Platform.create_pipeline(project.id, attrs)
      else
        case Platform.get_pipeline(params["pipeline_id"]) do
          nil -> {:error, :not_found}
          pipeline -> Platform.update_pipeline(pipeline, attrs)
        end
      end

    case result do
      {:ok, _} ->
        pipelines = Platform.list_pipelines(project.id)

        {:noreply,
         socket
         |> assign(:pipelines, pipelines)
         |> assign(:pipeline_modal, nil)
         |> put_flash(:info, gettext("Pipeline guardado."))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, put_flash(socket, :error, format_changeset_errors(changeset))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Error al guardar pipeline."))}
    end
  end

  @impl true
  def handle_event("deactivate_pipeline", %{"id" => id}, socket) do
    case Platform.get_pipeline(id) do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("Pipeline no encontrado."))}

      pipeline ->
        case Platform.set_pipeline_inactive(pipeline) do
          {:ok, _} ->
            pipelines = Platform.list_pipelines(socket.assigns.project.id)

            {:noreply,
             socket
             |> assign(:pipelines, pipelines)
             |> put_flash(:info, gettext("Pipeline desactivado."))}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, gettext("Error al desactivar pipeline."))}
        end
    end
  end

  @impl true
  def handle_event("close_pipeline_modal", _, socket) do
    {:noreply, assign(socket, :pipeline_modal, nil)}
  end

  @impl true
  def handle_event("pipeline_step_preset", %{"preset" => preset}, socket) do
    example =
      case preset do
        "filter" ->
          ~s([{"type": "filter", "field": "status", "operator": "eq", "value": "paid"}])

        "transform" ->
          ~s([{"type": "transform", "mapping": {"new_field": "payload.original_field"}}])

        "delay" ->
          ~s([{"type": "delay", "seconds": 60}])

        _ ->
          "[]"
      end

    form = Map.put(socket.assigns.pipeline_form, "steps", example)
    {:noreply, assign(socket, :pipeline_form, form)}
  end

  # ---------- Oban Monitor ----------

  @impl true
  def handle_event("oban_filter_state", %{"state" => state}, socket) do
    with_superadmin(socket, fn ->
      current = socket.assigns.oban_filter_state
      new_state = if current == state, do: nil, else: state

      jobs =
        Platform.oban_list_jobs(
          state: new_state,
          queue: socket.assigns.oban_filter_queue,
          limit: 50
        )

      {:noreply, socket |> assign(:oban_filter_state, new_state) |> assign(:oban_jobs, jobs)}
    end)
  end

  @impl true
  def handle_event("oban_filter_queue", %{"queue" => queue}, socket) do
    with_superadmin(socket, fn ->
      current = socket.assigns.oban_filter_queue
      new_queue = if current == queue, do: nil, else: queue

      jobs =
        Platform.oban_list_jobs(
          state: socket.assigns.oban_filter_state,
          queue: new_queue,
          limit: 50
        )

      {:noreply, socket |> assign(:oban_filter_queue, new_queue) |> assign(:oban_jobs, jobs)}
    end)
  end

  @impl true
  def handle_event("oban_clear_filters", _, socket) do
    with_superadmin(socket, fn ->
      jobs = Platform.oban_list_jobs(limit: 50)

      {:noreply,
       socket
       |> assign(:oban_filter_state, nil)
       |> assign(:oban_filter_queue, nil)
       |> assign(:oban_jobs, jobs)}
    end)
  end

  @impl true
  def handle_event("oban_refresh", _, socket) do
    with_superadmin(socket, fn ->
      jobs =
        Platform.oban_list_jobs(
          state: socket.assigns.oban_filter_state,
          queue: socket.assigns.oban_filter_queue,
          limit: 50
        )

      {:noreply,
       socket
       |> assign(:oban_queue_stats, Platform.oban_queue_stats())
       |> assign(:oban_state_counts, Platform.oban_state_counts())
       |> assign(:oban_jobs, jobs)}
    end)
  end

  @impl true
  def handle_event("oban_retry_job", %{"id" => id}, socket) do
    with_superadmin(socket, fn ->
      job_id = String.to_integer(id)
      Platform.oban_retry_job(job_id)

      {:noreply,
       socket
       |> put_flash(:info, gettext("Job reencolado."))
       |> refresh_oban_data()}
    end)
  end

  @impl true
  def handle_event("oban_cancel_job", %{"id" => id}, socket) do
    with_superadmin(socket, fn ->
      job_id = String.to_integer(id)
      Platform.oban_cancel_job(job_id)

      {:noreply,
       socket
       |> put_flash(:info, gettext("Job cancelado."))
       |> refresh_oban_data()}
    end)
  end

  @impl true
  def handle_event("oban_purge", _, socket) do
    with_superadmin(socket, fn ->
      {:ok, count} = Platform.oban_purge_jobs()

      {:noreply,
       socket
       |> put_flash(:info, gettext("%{count} jobs eliminados.", count: count))
       |> refresh_oban_data()}
    end)
  end

  # ---------- Event Detail Modal (#21) ----------

  @impl true
  def handle_event("show_event_detail", %{"id" => id}, socket) do
    case Platform.get_event(id) do
      nil ->
        {:noreply, put_flash(socket, :error, gettext("Evento no encontrado."))}

      event ->
        deliveries =
          Platform.list_deliveries(event_id: id, limit: 50)
          |> Enum.sort_by(& &1.inserted_at, {:asc, DateTime})

        {:noreply,
         socket
         |> assign(:event_detail, event)
         |> assign(:event_deliveries, deliveries)}
    end
  end

  @impl true
  def handle_event("close_event_detail", _, socket) do
    {:noreply, socket |> assign(:event_detail, nil) |> assign(:event_deliveries, [])}
  end

  # ---------- Search Bar (#24) ----------

  @impl true
  def handle_event("search_events", %{"q" => query}, socket) do
    query = String.trim(query)

    if query == "" do
      {:noreply, socket |> assign(:search_query, "") |> assign(:search_results, nil)}
    else
      project_id = socket.assigns.project.id
      # Search by topic first
      results =
        Platform.list_events(project_id, topic: query, limit: 50)

      # If no results by exact topic, try partial match via listing all and filtering
      results =
        if results == [] do
          Platform.list_events(project_id, limit: 100)
          |> Enum.filter(fn e ->
            (e.topic && String.contains?(String.downcase(e.topic), String.downcase(query))) ||
              String.contains?(e.id, query)
          end)
          |> Enum.take(50)
        else
          results
        end

      {:noreply,
       socket
       |> assign(:search_query, query)
       |> assign(:search_results, results)}
    end
  end

  @impl true
  def handle_event("clear_search", _, socket) do
    {:noreply, socket |> assign(:search_query, "") |> assign(:search_results, nil)}
  end

  # ---------- Bulk Dead Letter Actions (#25) ----------

  @impl true
  def handle_event("toggle_dl_select", %{"id" => id}, socket) do
    selected = socket.assigns.selected_dead_letters

    selected =
      if id in selected,
        do: List.delete(selected, id),
        else: [id | selected]

    {:noreply, assign(socket, :selected_dead_letters, selected)}
  end

  @impl true
  def handle_event("select_all_dl", _, socket) do
    all_ids = Enum.map(socket.assigns.dead_letters, & &1.id)
    {:noreply, assign(socket, :selected_dead_letters, all_ids)}
  end

  @impl true
  def handle_event("deselect_all_dl", _, socket) do
    {:noreply, assign(socket, :selected_dead_letters, [])}
  end

  @impl true
  def handle_event("bulk_retry_dl", _, socket) do
    with_permission(socket, :write, fn ->
      results =
        Enum.map(socket.assigns.selected_dead_letters, fn id ->
          Platform.retry_dead_letter(id)
        end)

      success_count = Enum.count(results, &match?({:ok, _}, &1))

      dead_letters = Platform.list_dead_letters(socket.assigns.project.id)

      {:noreply,
       socket
       |> assign(:dead_letters, dead_letters)
       |> assign(:selected_dead_letters, [])
       |> put_flash(
         :info,
         gettext("%{count} entregas reintentadas", count: success_count)
       )}
    end)
  end

  @impl true
  def handle_event("bulk_resolve_dl", _, socket) do
    with_permission(socket, :write, fn ->
      results =
        Enum.map(socket.assigns.selected_dead_letters, fn id ->
          Platform.resolve_dead_letter(id)
        end)

      success_count = Enum.count(results, &match?({:ok, _}, &1))

      dead_letters = Platform.list_dead_letters(socket.assigns.project.id)

      {:noreply,
       socket
       |> assign(:dead_letters, dead_letters)
       |> assign(:selected_dead_letters, [])
       |> put_flash(
         :info,
         gettext("%{count} entregas descartadas", count: success_count)
       )}
    end)
  end

  # ---------- Onboarding (#26) ----------

  @impl true
  def handle_event("start_onboarding", _, socket) do
    {:noreply, assign(socket, :onboarding_step, 1)}
  end

  @impl true
  def handle_event("next_onboarding", _, socket) do
    step = socket.assigns.onboarding_step

    if step >= 4 do
      {:noreply, assign(socket, :onboarding_step, nil)}
    else
      {:noreply, assign(socket, :onboarding_step, step + 1)}
    end
  end

  @impl true
  def handle_event("skip_onboarding", _, socket) do
    {:noreply, assign(socket, :onboarding_step, nil)}
  end

  # ---------- Project Selector (B11) ----------

  @impl true
  def handle_event("toggle_project_selector", _, socket) do
    {:noreply, assign(socket, :show_project_selector, !socket.assigns.show_project_selector)}
  end

  @impl true
  def handle_event("close_project_selector", _, socket) do
    {:noreply, assign(socket, :show_project_selector, false)}
  end

  @impl true
  def handle_event("switch_project", %{"id" => id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/platform?project=#{id}")}
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

  # ---------- Project switch (deferred via handle_params) ----------

  @impl true
  def handle_info({:do_switch_project, id}, socket) do
    old_project = socket.assigns.project
    projects = socket.assigns.projects
    project = Enum.find(projects, fn p -> p.id == id end) || Platform.get_project(id)

    if project do
      if old_project,
        do: Phoenix.PubSub.unsubscribe(StreamflixCore.PubSub, "project:#{old_project.id}")

      Platform.subscribe(project.id)

      # Run all project queries in parallel
      tasks = [
        Task.async(fn -> {:api_key, Platform.get_api_key_for_project(project.id)} end),
        Task.async(fn -> {:events, Platform.list_events(project.id, limit: 20)} end),
        Task.async(fn ->
          {:webhooks, Platform.list_webhooks(project.id, include_inactive: true)}
        end),
        Task.async(fn -> {:webhook_health, Platform.webhooks_health(project.id)} end),
        Task.async(fn -> {:jobs, Platform.list_jobs(project.id, include_inactive: true)} end),
        Task.async(fn ->
          {:deliveries, Platform.list_deliveries(project_id: project.id, limit: 30)}
        end),
        Task.async(fn -> {:dead_letters, Platform.list_dead_letters(project.id)} end),
        Task.async(fn -> {:replays, Platform.list_replays(project.id, limit: 10)} end),
        Task.async(fn -> {:audit_logs, Audit.list_for_project(project.id, limit: 20)} end),
        Task.async(fn -> {:sandbox_endpoints, Platform.list_sandbox_endpoints(project.id)} end),
        Task.async(fn -> {:event_schemas, Platform.list_event_schemas(project.id)} end),
        Task.async(fn -> {:pipelines, Platform.list_pipelines(project.id)} end),
        Task.async(fn -> {:team_members, Teams.list_members(project.id)} end),
        Task.async(fn -> {:analytics, load_analytics(project.id)} end),
        Task.async(fn -> {:uptime_status, load_uptime_status()} end),
        Task.async(fn -> {:uptime_stats, load_uptime_stats()} end),
        Task.async(fn ->
          {:pending_invitations, Teams.list_pending_invitations(socket.assigns.current_user.id)}
        end)
      ]

      data = Task.await_many(tasks, 10_000) |> Map.new()
      user_role = compute_user_role(project, socket.assigns.current_user)

      # Persist selection server-side (async, non-blocking)
      save_last_project(socket.assigns.current_user, project.id)

      {:noreply,
       socket
       |> assign(:switching_project, false)
       |> assign(:project, project)
       |> assign(:api_key, data.api_key)
       |> assign(:events, data.events)
       |> assign(:webhooks, data.webhooks)
       |> assign(:webhook_health, data.webhook_health)
       |> assign(:jobs, data.jobs)
       |> assign(:deliveries, data.deliveries)
       |> assign(:dead_letters, data.dead_letters)
       |> assign(:replays, data.replays)
       |> assign(:audit_logs, data.audit_logs)
       |> assign(:sandbox_endpoints, data.sandbox_endpoints)
       |> assign(:sandbox_active, nil)
       |> assign(:sandbox_requests, [])
       |> assign(:event_schemas, data.event_schemas)
       |> assign(:pipelines, data.pipelines)
       |> assign(:team_members, data.team_members)
       |> assign(:current_user_role, user_role)
       |> assign(:analytics, data.analytics)
       |> assign(:uptime_status, data.uptime_status)
       |> assign(:uptime_stats, data.uptime_stats)
       |> assign(:pending_invitations, data.pending_invitations)
       |> assign(:active_tab, "overview")
       |> assign(:kpi_events_today, compute_kpi_events_today(data.events))
       |> assign(:kpi_success_rate, compute_kpi_success_rate(data.deliveries))
       |> assign(:new_token, nil)
       |> assign(:token_source, nil)
       |> put_flash(:info, gettext("Proyecto cambiado a: %{name}", name: project.name))}
    else
      {:noreply,
       socket
       |> assign(:switching_project, false)
       |> put_flash(:error, gettext("Proyecto no encontrado."))}
    end
  end

  # ---------- Deferred loading (Phase 2 after connect) ----------

  @impl true
  def handle_info(:load_deferred, socket) do
    project = socket.assigns.project
    user = socket.assigns.current_user

    deferred_assigns =
      if project do
        # Run all deferred queries in parallel (~180ms instead of ~2700ms)
        tasks = [
          Task.async(fn -> {:webhook_health, Platform.webhooks_health(project.id)} end),
          Task.async(fn -> {:jobs, Platform.list_jobs(project.id, include_inactive: true)} end),
          Task.async(fn -> {:dead_letters, Platform.list_dead_letters(project.id)} end),
          Task.async(fn -> {:replays, Platform.list_replays(project.id, limit: 10)} end),
          Task.async(fn -> {:audit_logs, Audit.list_for_project(project.id, limit: 20)} end),
          Task.async(fn -> {:sandbox_endpoints, Platform.list_sandbox_endpoints(project.id)} end),
          Task.async(fn -> {:event_schemas, Platform.list_event_schemas(project.id)} end),
          Task.async(fn -> {:pipelines, Platform.list_pipelines(project.id)} end),
          Task.async(fn -> {:team_members, Teams.list_members(project.id)} end),
          Task.async(fn -> {:analytics, load_analytics(project.id)} end),
          Task.async(fn -> {:uptime_status, load_uptime_status()} end),
          Task.async(fn -> {:uptime_stats, load_uptime_stats()} end),
          Task.async(fn -> {:pending_invitations, Teams.list_pending_invitations(user.id)} end)
        ]

        # Only load queue data for superadmins
        tasks =
          if StreamflixAccounts.Schemas.User.superadmin?(user) do
            tasks ++
              [
                Task.async(fn -> {:oban_queue_stats, Platform.oban_queue_stats()} end),
                Task.async(fn -> {:oban_state_counts, Platform.oban_state_counts()} end),
                Task.async(fn -> {:oban_jobs, Platform.oban_list_jobs(limit: 50)} end)
              ]
          else
            tasks
          end

        Task.await_many(tasks, 10_000) |> Map.new()
      else
        %{}
      end

    {:noreply, assign(socket, deferred_assigns)}
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
        <%!-- ===== SWITCHING PROJECT OVERLAY ===== --%>
        <%= if @switching_project do %>
          <div class="fixed inset-0 bg-white/60 dark:bg-slate-900/60 backdrop-blur-sm z-40 flex items-center justify-center transition-opacity">
            <div class="flex flex-col items-center gap-3">
              <div class="w-8 h-8 border-[3px] border-indigo-600 border-t-transparent rounded-full animate-spin">
              </div>
              <p class="text-sm font-medium text-slate-600 dark:text-slate-400">
                {gettext("Cambiando proyecto...")}
              </p>
            </div>
          </div>
        <% end %>
        <%!-- ===== HEADER ===== --%>
        <div class="flex items-center justify-between mb-4 sm:mb-6 lg:mb-8">
          <div class="flex items-center gap-3 sm:gap-4">
            <h1 class="text-xl sm:text-2xl lg:text-3xl font-bold text-slate-900 dark:text-slate-100">
              {gettext("Dashboard")}
            </h1>
            <div class="relative">
              <button
                type="button"
                phx-click="toggle_project_selector"
                class="inline-flex items-center gap-1.5 px-3 py-1.5 bg-indigo-50 dark:bg-indigo-900/30 hover:bg-indigo-100 dark:hover:bg-indigo-900/50 text-indigo-700 dark:text-indigo-300 rounded-lg text-sm font-medium transition border border-indigo-200 dark:border-indigo-800/50"
              >
                <.icon name="hero-rectangle-stack" class="w-4 h-4" />
                <span class="hidden sm:inline truncate max-w-[10rem]">
                  {@project && @project.name}
                </span>
                <.icon name="hero-chevron-down" class="w-3.5 h-3.5" />
              </button>
              <%= if @show_project_selector do %>
                <div
                  phx-click-away="close_project_selector"
                  class="fixed inset-x-3 top-20 sm:absolute sm:inset-x-auto sm:top-auto sm:right-0 mt-1 sm:w-72 bg-white dark:bg-slate-800 rounded-xl shadow-xl border border-slate-200 dark:border-slate-700 z-50 max-h-80 overflow-y-auto"
                >
                  <div class="p-3 border-b border-slate-200 dark:border-slate-700">
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
                        class="flex-1 min-w-0 border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100 rounded-lg px-3 py-1.5 text-sm"
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
                      class={"flex items-center justify-between px-4 py-2.5 hover:bg-slate-50 dark:hover:bg-slate-700 cursor-pointer transition #{if @project && @project.id == p.id, do: "bg-indigo-50/50 dark:bg-indigo-900/20"}"}
                      phx-click="switch_project"
                      phx-value-id={p.id}
                    >
                      <div class="min-w-0">
                        <p class="text-sm font-medium text-slate-800 dark:text-slate-200 truncate">
                          {p.name}
                        </p>
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
          </div>
          <div class="flex items-center gap-1">
            <%!-- Onboarding button --%>
            <button
              type="button"
              phx-click="start_onboarding"
              class="p-2 text-slate-400 dark:text-slate-500 hover:text-indigo-600 dark:hover:text-indigo-400 hover:bg-indigo-50 dark:hover:bg-indigo-900/30 rounded-lg transition"
              title={gettext("Guía de inicio")}
            >
              <.icon name="hero-question-mark-circle" class="w-5 h-5" />
            </button>
            <div class="relative">
              <button
                type="button"
                phx-click="toggle_notifications"
                class="relative p-2 text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700 rounded-lg transition"
              >
                <.icon name="hero-bell" class="w-6 h-6" />
                <%= if @unread_count > 0 do %>
                  <span class="absolute -top-0.5 -right-0.5 flex items-center justify-center w-5 h-5 text-[10px] font-bold text-white bg-red-500 rounded-full">
                    {@unread_count}
                  </span>
                <% end %>
              </button>
              <%= if @show_notifications do %>
                <div class="fixed inset-x-3 top-16 sm:absolute sm:inset-x-auto sm:top-auto sm:right-0 mt-2 sm:w-96 bg-white dark:bg-slate-800 rounded-xl shadow-xl border border-slate-200 dark:border-slate-700 z-50 max-h-96 overflow-y-auto">
                  <div class="flex items-center justify-between px-4 py-3 border-b border-slate-200 dark:border-slate-700">
                    <h3 class="font-semibold text-slate-900 dark:text-slate-100 text-sm">
                      {gettext("Notificaciones")}
                    </h3>
                    <%= if @unread_count > 0 do %>
                      <button
                        phx-click="mark_all_read"
                        class="text-xs text-indigo-600 dark:text-indigo-400 hover:text-indigo-700 dark:hover:text-indigo-300 font-medium"
                      >
                        {gettext("Marcar todo leído")}
                      </button>
                    <% end %>
                  </div>
                  <%= if @notifications == [] do %>
                    <div class="px-4 py-8 text-center text-sm text-slate-400 dark:text-slate-500">
                      {gettext("Sin notificaciones")}
                    </div>
                  <% else %>
                    <%= for notif <- @notifications do %>
                      <div
                        class={"px-4 py-3 border-b border-slate-100 dark:border-slate-700 last:border-0 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition cursor-pointer #{if !notif.read, do: "bg-indigo-50/50 dark:bg-indigo-900/20"}"}
                        phx-click="mark_notification_read"
                        phx-value-id={notif.id}
                      >
                        <div class="flex items-start gap-2">
                          <span class={"mt-1 w-2 h-2 rounded-full shrink-0 #{if !notif.read, do: "bg-indigo-500", else: "bg-transparent"}"}>
                          </span>
                          <div class="min-w-0 flex-1">
                            <p class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate">
                              {notification_title(notif)}
                            </p>
                            <p class="text-xs text-slate-500 dark:text-slate-400 truncate">
                              {notification_message(notif)}
                            </p>
                            <p class="text-[10px] text-slate-400 dark:text-slate-500 mt-1">
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
                                    class="px-2 py-1 bg-red-100 hover:bg-red-200 dark:bg-red-900/30 dark:hover:bg-red-900/50 text-red-700 dark:text-red-400 rounded text-[11px] font-medium"
                                  >
                                    {gettext("Rechazar")}
                                  </button>
                                </div>
                              <% else %>
                                <p class="text-[10px] text-emerald-600 dark:text-emerald-400 mt-1 font-medium">
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
        </div>

        <%!-- ===== ONBOARDING WIZARD (#26) ===== --%>
        <%= if @onboarding_step do %>
          <div class="mb-6 bg-indigo-50 dark:bg-indigo-900/20 border border-indigo-200 dark:border-indigo-800 rounded-xl p-4 sm:p-6">
            <div class="flex items-start justify-between mb-3">
              <div class="flex items-center gap-2">
                <.icon name="hero-rocket-launch" class="w-5 h-5 text-indigo-600 dark:text-indigo-400" />
                <h3 class="font-semibold text-indigo-900 dark:text-indigo-100">
                  {gettext("Guía de inicio")}
                  <span class="text-sm font-normal text-indigo-600 dark:text-indigo-400 ml-2">
                    {gettext("Paso %{step} de 4", step: @onboarding_step)}
                  </span>
                </h3>
              </div>
              <button
                phx-click="skip_onboarding"
                class="text-xs text-indigo-500 hover:text-indigo-700 dark:text-indigo-400 dark:hover:text-indigo-300"
              >
                {gettext("Cerrar")}
              </button>
            </div>
            <div class="flex gap-1.5 mb-4">
              <%= for i <- 1..4 do %>
                <div class={"h-1.5 flex-1 rounded-full #{if i <= @onboarding_step, do: "bg-indigo-500", else: "bg-indigo-200 dark:bg-indigo-800"}"}>
                </div>
              <% end %>
            </div>
            <div class="text-sm text-indigo-800 dark:text-indigo-200">
              <%= case @onboarding_step do %>
                <% 1 -> %>
                  <p class="font-medium mb-1">{gettext("1. Copia tu API Token")}</p>
                  <p>
                    {gettext(
                      "En la pestaña Overview encontrarás tu token. Úsalo en el header Authorization: Bearer <token> o X-Api-Key."
                    )}
                  </p>
                <% 2 -> %>
                  <p class="font-medium mb-1">{gettext("2. Crea un Webhook")}</p>
                  <p>
                    {gettext(
                      "Ve a la pestaña Webhooks y crea uno con la URL de tu endpoint. Filtra por topics para recibir solo lo que necesitas."
                    )}
                  </p>
                <% 3 -> %>
                  <p class="font-medium mb-1">{gettext("3. Envía tu primer evento")}</p>
                  <p>
                    {gettext(
                      "Usa el formulario de Test Event en Overview, o haz un POST a /api/v1/events con tu API key."
                    )}
                  </p>
                <% 4 -> %>
                  <p class="font-medium mb-1">{gettext("4. Monitorea entregas")}</p>
                  <p>
                    {gettext(
                      "Revisa el estado de tus entregas en la pestaña Webhooks. Si algo falla, puedes reintentar o revisar el Dead Letter Queue."
                    )}
                  </p>
              <% end %>
            </div>
            <div class="flex justify-end mt-3">
              <button
                phx-click="next_onboarding"
                class="px-4 py-1.5 bg-indigo-600 hover:bg-indigo-700 dark:bg-indigo-500 dark:hover:bg-indigo-600 text-white rounded-lg text-sm font-medium transition"
              >
                {if @onboarding_step >= 4, do: gettext("Finalizar"), else: gettext("Siguiente")}
              </button>
            </div>
          </div>
        <% end %>

        <%= if @project do %>
          <%!-- ===== KPI CARDS ===== --%>
          <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4 lg:gap-6 mb-6 sm:mb-8">
            <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm p-3 sm:p-5 lg:p-6 border-l-4 border-l-indigo-500">
              <div class="flex items-center gap-2 mb-2">
                <.icon name="hero-bolt" class="w-5 h-5 text-indigo-500" />
                <span class="text-xs sm:text-sm font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wide">
                  {gettext("Eventos hoy")}
                </span>
              </div>
              <p class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-900 dark:text-slate-100">
                {@kpi_events_today}
              </p>
            </div>
            <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm p-3 sm:p-5 lg:p-6 border-l-4 border-l-emerald-500">
              <div class="flex items-center gap-2 mb-2">
                <.icon name="hero-check-circle" class="w-5 h-5 text-emerald-500" />
                <span class="text-xs sm:text-sm font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wide">
                  {gettext("Tasa de éxito")}
                </span>
              </div>
              <p class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-900 dark:text-slate-100">
                {@kpi_success_rate}%
              </p>
            </div>
            <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm p-3 sm:p-5 lg:p-6 border-l-4 border-l-blue-500">
              <div class="flex items-center gap-2 mb-2">
                <.icon name="hero-globe-alt" class="w-5 h-5 text-blue-500" />
                <span class="text-xs sm:text-sm font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wide">
                  {gettext("Webhooks activos")}
                </span>
              </div>
              <p class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-900 dark:text-slate-100">
                {Enum.count(@webhooks, &(&1.status == "active"))}
              </p>
            </div>
            <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm p-3 sm:p-5 lg:p-6 border-l-4 border-l-amber-500">
              <div class="flex items-center gap-2 mb-2">
                <.icon name="hero-clock" class="w-5 h-5 text-amber-500" />
                <span class="text-xs sm:text-sm font-medium text-slate-500 dark:text-slate-400 uppercase tracking-wide">
                  {gettext("Jobs activos")}
                </span>
              </div>
              <p class="text-2xl sm:text-3xl lg:text-4xl font-bold text-slate-900 dark:text-slate-100">
                {Enum.count(@jobs, &(&1.status == "active"))}
              </p>
            </div>
          </div>

          <%!-- ===== PENDING INVITATIONS BANNER ===== --%>
          <%= if @pending_invitations != [] do %>
            <div class="bg-indigo-50 dark:bg-indigo-900/20 border border-indigo-200 dark:border-indigo-800 rounded-xl p-3 sm:p-4 mb-6 sm:mb-8">
              <div class="flex items-center gap-2 mb-3">
                <.icon name="hero-envelope" class="w-5 h-5 text-indigo-600 dark:text-indigo-400" />
                <h3 class="text-sm sm:text-base font-semibold text-indigo-900 dark:text-indigo-100">
                  {gettext("Invitaciones pendientes")}
                </h3>
              </div>
              <div class="space-y-2">
                <%= for inv <- @pending_invitations do %>
                  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 bg-white dark:bg-slate-800 rounded-lg p-3 border border-indigo-100 dark:border-indigo-800">
                    <div class="text-sm text-slate-700 dark:text-slate-300">
                      <span class="font-medium">{inv.project_name}</span>
                      <span class="text-slate-400 dark:text-slate-500 mx-1">&middot;</span>
                      <span class="text-slate-500 dark:text-slate-400">
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
                        phx-click={show_confirm("confirm-reject-inv-#{inv.id}")}
                        class="px-3 py-1.5 bg-red-100 hover:bg-red-200 dark:bg-red-900/30 dark:hover:bg-red-900/50 text-red-700 dark:text-red-400 rounded-lg text-xs sm:text-sm font-medium"
                      >
                        {gettext("Rechazar")}
                      </button>
                      <.confirm_modal
                        id={"confirm-reject-inv-#{inv.id}"}
                        title={gettext("Confirmar rechazo")}
                        message={gettext("¿Rechazar esta invitación?")}
                        confirm_text={gettext("Rechazar")}
                        confirm_event="reject_invitation"
                        confirm_value={%{id: inv.id}}
                        variant="danger"
                      />
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

          <%!-- ===== TAB NAVIGATION ===== --%>
          <div class="border-b border-slate-200 dark:border-slate-700 mb-6 sm:mb-8 overflow-x-auto">
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
                phx-value-tab="pipelines"
                class={"whitespace-nowrap border-b-2 pb-2.5 sm:pb-4 px-1.5 sm:px-1 text-xs sm:text-sm lg:text-base transition #{tab_classes(@active_tab, "pipelines")}"}
              >
                {gettext("Pipelines")}
              </button>
              <%= if StreamflixAccounts.Schemas.User.superadmin?(@current_user) do %>
                <button
                  type="button"
                  phx-click="switch_tab"
                  phx-value-tab="queue"
                  class={"whitespace-nowrap border-b-2 pb-2.5 sm:pb-4 px-1.5 sm:px-1 text-xs sm:text-sm lg:text-base transition #{tab_classes(@active_tab, "queue")}"}
                >
                  {gettext("Colas")}
                </button>
              <% end %>
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
          {StreamflixWebWeb.PlatformDashboard.ModalComponents.render_modals(assigns)}
        <% else %>
          <p class="text-slate-600 dark:text-slate-400">
            {gettext("No hay proyecto para tu cuenta. Contacta soporte.")}
          </p>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  # ===== TAB DISPATCH =====
  alias StreamflixWebWeb.PlatformDashboard.TabComponents

  defp render_tab(%{active_tab: "overview"} = assigns),
    do: TabComponents.render_overview_tab(assigns)

  defp render_tab(%{active_tab: "events"} = assigns), do: TabComponents.render_events_tab(assigns)

  defp render_tab(%{active_tab: "webhooks"} = assigns),
    do: TabComponents.render_webhooks_tab(assigns)

  defp render_tab(%{active_tab: "jobs"} = assigns), do: TabComponents.render_jobs_tab(assigns)

  defp render_tab(%{active_tab: "pipelines"} = assigns),
    do: TabComponents.render_pipelines_tab(assigns)

  defp render_tab(%{active_tab: "queue"} = assigns), do: TabComponents.render_queue_tab(assigns)

  defp render_tab(%{active_tab: "settings"} = assigns),
    do: TabComponents.render_settings_tab(assigns)

  defp render_tab(assigns), do: TabComponents.render_overview_tab(assigns)

  defp validate_webhook_form(form) do
    url = String.trim(form["url"] || "")

    errors = []
    errors = if url == "", do: [gettext("La URL es obligatoria") | errors], else: errors

    errors =
      if url != "" and not String.starts_with?(url, "https://"),
        do: [gettext("La URL debe comenzar con https://") | errors],
        else: errors

    Enum.reverse(errors)
  end

  defp validate_job_form(params) do
    name = String.trim(params["name"] || "")
    schedule_type = params["schedule_type"] || "daily"
    cron = String.trim(params["schedule_cron"] || "")

    errors = []
    errors = if name == "", do: [gettext("El nombre es obligatorio") | errors], else: errors

    errors =
      if schedule_type == "cron" and cron != "" do
        parts = String.split(cron, ~r/\s+/)

        if length(parts) != 5,
          do: [gettext("La expresión cron debe tener 5 partes separadas por espacios") | errors],
          else: errors
      else
        errors
      end

    Enum.reverse(errors)
  end

  defp test_event_template("user_signup") do
    {"user.signup",
     Jason.encode!(
       %{
         user_id:
           "usr_#{:crypto.strong_rand_bytes(4) |> Base.hex_encode32(case: :lower) |> binary_part(0, 8)}",
         email: "jane@example.com",
         plan: "free",
         source: "web"
       },
       pretty: true
     )}
  end

  defp test_event_template("order_created") do
    {"order.created",
     Jason.encode!(
       %{
         order_id:
           "ord_#{:crypto.strong_rand_bytes(4) |> Base.hex_encode32(case: :lower) |> binary_part(0, 8)}",
         amount: 49.99,
         currency: "USD",
         items: 3
       },
       pretty: true
     )}
  end

  defp test_event_template("payment_completed") do
    {"payment.completed",
     Jason.encode!(
       %{
         payment_id:
           "pay_#{:crypto.strong_rand_bytes(4) |> Base.hex_encode32(case: :lower) |> binary_part(0, 8)}",
         amount: 149.00,
         currency: "USD",
         method: "card",
         status: "succeeded"
       },
       pretty: true
     )}
  end

  defp test_event_template("invoice_paid") do
    {"invoice.paid",
     Jason.encode!(
       %{
         invoice_id:
           "inv_#{:crypto.strong_rand_bytes(4) |> Base.hex_encode32(case: :lower) |> binary_part(0, 8)}",
         total: 299.00,
         currency: "USD",
         customer: "cus_abc123"
       },
       pretty: true
     )}
  end

  defp test_event_template(_), do: {"", "{}"}

  defp schema_template("order") do
    {"order.created",
     Jason.encode!(
       %{
         type: "object",
         required: ["order_id", "amount", "currency"],
         properties: %{
           order_id: %{type: "string"},
           amount: %{type: "number", minimum: 0},
           currency: %{type: "string", enum: ["USD", "EUR", "GBP"]},
           items: %{type: "integer", minimum: 1}
         }
       },
       pretty: true
     )}
  end

  defp schema_template("user") do
    {"user.signup",
     Jason.encode!(
       %{
         type: "object",
         required: ["user_id", "email"],
         properties: %{
           user_id: %{type: "string"},
           email: %{type: "string", format: "email"},
           plan: %{type: "string", enum: ["free", "pro", "enterprise"]},
           source: %{type: "string"}
         }
       },
       pretty: true
     )}
  end

  defp schema_template("payment") do
    {"payment.completed",
     Jason.encode!(
       %{
         type: "object",
         required: ["payment_id", "amount", "status"],
         properties: %{
           payment_id: %{type: "string"},
           amount: %{type: "number", minimum: 0},
           currency: %{type: "string"},
           method: %{type: "string", enum: ["card", "bank_transfer", "paypal"]},
           status: %{type: "string", enum: ["succeeded", "failed", "pending"]}
         }
       },
       pretty: true
     )}
  end

  defp schema_template(_), do: {"", "{}"}

  # Helpers imported from StreamflixWebWeb.PlatformDashboard.Helpers
end
