defmodule StreamflixWebWeb.PlatformDashboard.Helpers do
  @moduledoc """
  Formatting, styling, permission, and utility helpers for the Platform Dashboard.
  """
  use StreamflixWebWeb, :verified_routes
  use Gettext, backend: StreamflixWebWeb.Gettext
  use Phoenix.Component

  alias StreamflixCore.{Platform, Teams, Uptime}

  # ── Formatting ──────────────────────────────────────────────────────

  # Rendered as <.local_time>: shown in the viewer's timezone, UTC in the tooltip
  def format_dt(nil), do: "—"

  def format_dt(dt) do
    assigns = %{dt: dt}

    ~H"""
    <StreamflixWebWeb.CoreComponents.local_time value={@dt} />
    """
  end

  def to_str(v) when is_binary(v), do: v
  def to_str(v) when is_integer(v), do: Integer.to_string(v)
  def to_str(v) when is_float(v), do: Float.to_string(v)
  def to_str(nil), do: ""
  def to_str(v), do: inspect(v)

  def parse_int(v, _default) when is_integer(v), do: v

  def parse_int(v, default) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      _ -> default
    end
  end

  def parse_int(_, d), do: d

  def format_changeset_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join("; ", fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
  end

  def format_changeset_errors(_), do: gettext("Error desconocido")

  # ── Health Score ────────────────────────────────────────────────────

  def health_class(:healthy), do: "bg-green-100 text-green-800"
  def health_class(:degraded), do: "bg-yellow-100 text-yellow-800"
  def health_class(:critical), do: "bg-red-100 text-red-800"
  def health_class(:no_data), do: "bg-slate-100 text-slate-600"
  def health_class(_), do: "bg-slate-100 text-slate-600"

  def health_dot(:healthy), do: "bg-green-500"
  def health_dot(:degraded), do: "bg-yellow-500"
  def health_dot(:critical), do: "bg-red-500"
  def health_dot(_), do: "bg-slate-400"

  def health_label(:healthy), do: gettext("OK")
  def health_label(:degraded), do: gettext("Degradado")
  def health_label(:critical), do: gettext("Crítico")
  def health_label(:no_data), do: gettext("Sin datos")
  def health_label(_), do: "—"

  # ── Delivery & Replay ──────────────────────────────────────────────

  def delivery_dot_color("success"), do: "bg-emerald-500"
  def delivery_dot_color("pending"), do: "bg-amber-400"
  def delivery_dot_color("failed"), do: "bg-red-500"
  def delivery_dot_color(_), do: "bg-slate-400"

  def delivery_status_class("success"), do: "bg-emerald-100 text-emerald-800"
  def delivery_status_class("pending"), do: "bg-amber-100 text-amber-800"
  def delivery_status_class("failed"), do: "bg-red-100 text-red-800"
  def delivery_status_class(_), do: "bg-slate-100 text-slate-600"

  def format_json_preview(nil), do: ""

  def format_json_preview(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> Jason.encode!(decoded, pretty: true)
      _ -> body
    end
  end

  def format_json_preview(body), do: inspect(body)

  @doc "Translated label for a stored status value (they are English enums)."
  def status_label("active"), do: gettext("Activo")
  def status_label("inactive"), do: gettext("Inactivo")
  def status_label("pending"), do: gettext("Pendiente")
  def status_label("success"), do: gettext("Exitoso")
  def status_label("failed"), do: gettext("Fallido")
  def status_label("circuit_open"), do: gettext("Circuito abierto")
  def status_label("running"), do: gettext("Ejecutando")
  def status_label("completed"), do: gettext("Completado")
  def status_label("cancelled"), do: gettext("Cancelado")
  def status_label("removed"), do: gettext("Eliminado")
  def status_label("healthy"), do: gettext("Saludable")
  def status_label("degraded"), do: gettext("Degradado")
  def status_label("unhealthy"), do: gettext("Con fallos")
  def status_label(nil), do: "—"
  def status_label(other), do: other

  def oban_state_label("available"), do: gettext("Disponible")
  def oban_state_label("scheduled"), do: gettext("Programado")
  def oban_state_label("executing"), do: gettext("Ejecutando")
  def oban_state_label("retryable"), do: gettext("Por reintentar")
  def oban_state_label("completed"), do: gettext("Completado")
  def oban_state_label("discarded"), do: gettext("Descartado")
  def oban_state_label("cancelled"), do: gettext("Cancelado")
  def oban_state_label(other), do: other

  def alert_type_label("webhook_failing"), do: gettext("Webhook fallando")
  def alert_type_label("circuit_open"), do: gettext("Circuito abierto")
  def alert_type_label("circuit_closed"), do: gettext("Circuito cerrado")
  def alert_type_label("dlq_entry"), do: gettext("Entrega movida a DLQ")
  def alert_type_label("job_failed"), do: gettext("Job fallido")
  def alert_type_label("replay_completed"), do: gettext("Replay completado")
  def alert_type_label(other), do: other

  def role_label("owner"), do: gettext("Propietario")
  def role_label("editor"), do: gettext("Editor")
  def role_label("viewer"), do: gettext("Viewer")
  def role_label(nil), do: "—"
  def role_label(other), do: other

  def schedule_type_label("daily"), do: gettext("Diario")
  def schedule_type_label("weekly"), do: gettext("Semanal")
  def schedule_type_label("monthly"), do: gettext("Mensual")
  def schedule_type_label("cron"), do: gettext("Cron")
  def schedule_type_label(other), do: other

  def action_type_label("emit_event"), do: gettext("Emitir evento")
  def action_type_label("post_url"), do: gettext("Llamar URL")
  def action_type_label(other), do: other

  def replay_status_class("pending"), do: "bg-slate-100 text-slate-700"
  def replay_status_class("running"), do: "bg-blue-100 text-blue-800"
  def replay_status_class("completed"), do: "bg-emerald-100 text-emerald-800"
  def replay_status_class("failed"), do: "bg-red-100 text-red-800"
  def replay_status_class("cancelled"), do: "bg-amber-100 text-amber-800"
  def replay_status_class(_), do: "bg-slate-100 text-slate-600"

  def replay_status_label("pending"), do: gettext("Pendiente")
  def replay_status_label("running"), do: gettext("Ejecutando")
  def replay_status_label("completed"), do: gettext("Completado")
  def replay_status_label("failed"), do: gettext("Fallido")
  def replay_status_label("cancelled"), do: gettext("Cancelado")
  def replay_status_label(s), do: s

  # ── Audit Log ──────────────────────────────────────────────────────

  def audit_action_label("webhook.created"), do: gettext("Webhook creado")
  def audit_action_label("webhook.updated"), do: gettext("Webhook actualizado")
  def audit_action_label("webhook.deleted"), do: gettext("Webhook desactivado")
  def audit_action_label("event.created"), do: gettext("Evento enviado")
  def audit_action_label("job.created"), do: gettext("Job creado")
  def audit_action_label("job.updated"), do: gettext("Job actualizado")
  def audit_action_label("job.deactivated"), do: gettext("Job desactivado")
  def audit_action_label("api_key.regenerated"), do: gettext("Token regenerado")
  def audit_action_label("project.updated"), do: gettext("Proyecto actualizado")
  def audit_action_label("delivery.retried"), do: gettext("Entrega reintentada")
  def audit_action_label("dead_letter.retried"), do: gettext("DLQ reintentado")
  def audit_action_label("dead_letter.resolved"), do: gettext("DLQ resuelto")
  def audit_action_label("replay.started"), do: gettext("Replay iniciado")
  def audit_action_label("replay.cancelled"), do: gettext("Replay cancelado")
  def audit_action_label("sandbox.created"), do: gettext("Sandbox creado")
  def audit_action_label(action), do: action

  # ── Notification i18n ──────────────────────────────────────────────

  def notification_title(%{type: "webhook_failing"}), do: gettext("Webhook fallando")
  def notification_title(%{type: "job_failed"}), do: gettext("Job fallido")
  def notification_title(%{type: "dlq_entry"}), do: gettext("Entrega movida a DLQ")
  def notification_title(%{type: "replay_completed"}), do: gettext("Replay completado")
  def notification_title(%{type: "team_invite"}), do: gettext("Invitación a proyecto")
  def notification_title(notif), do: notif.title

  def notification_message(%{type: "webhook_failing", metadata: %{"webhook_url" => url}}) do
    gettext("%{url} tiene múltiples fallos consecutivos", url: url)
  end

  def notification_message(%{type: "job_failed", metadata: %{"job_name" => name}}) do
    gettext("El job programado \"%{name}\" falló al ejecutarse", name: name)
  end

  def notification_message(%{type: "dlq_entry", metadata: %{"webhook_url" => url}}) do
    gettext("Una entrega a %{url} agotó todos los reintentos", url: url)
  end

  def notification_message(%{type: "replay_completed", metadata: %{"event_count" => count}}) do
    gettext("Se re-enviaron %{count} eventos exitosamente", count: count)
  end

  def notification_message(%{type: "team_invite", metadata: %{"project_id" => _pid}}) do
    gettext("Has sido invitado a un proyecto.")
  end

  def notification_message(notif), do: notif.message

  # ── Sandbox ────────────────────────────────────────────────────────

  def sandbox_url(endpoint), do: StreamflixWebWeb.Endpoint.url() <> "/sandbox/#{endpoint.slug}"

  # ── HTTP Method Colors ─────────────────────────────────────────────

  def method_color("GET"), do: "bg-blue-100 text-blue-800"
  def method_color("POST"), do: "bg-green-100 text-green-800"
  def method_color("PUT"), do: "bg-amber-100 text-amber-800"
  def method_color("PATCH"), do: "bg-amber-100 text-amber-800"
  def method_color("DELETE"), do: "bg-red-100 text-red-800"
  def method_color(_), do: "bg-slate-100 text-slate-700"

  # ── Team ───────────────────────────────────────────────────────────

  def member_role_class("owner"), do: "bg-indigo-100 text-indigo-800"
  def member_role_class("editor"), do: "bg-emerald-100 text-emerald-800"
  def member_role_class("viewer"), do: "bg-slate-100 text-slate-700"
  def member_role_class(_), do: "bg-slate-100 text-slate-600"

  def member_status_class("active"), do: "bg-green-100 text-green-800"
  def member_status_class("pending"), do: "bg-amber-100 text-amber-800"
  def member_status_class("removed"), do: "bg-red-100 text-red-800"
  def member_status_class(_), do: "bg-slate-100 text-slate-600"

  def can_manage_team?(role), do: role in ["owner", "editor"]
  def can_admin_team?(role), do: role == "owner"

  # ── Tab Navigation ─────────────────────────────────────────────────

  def tab_classes(active_tab, tab) do
    if active_tab == tab do
      "border-indigo-600 dark:border-indigo-400 text-indigo-700 dark:text-indigo-300 font-semibold"
    else
      "border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300 hover:border-slate-300 dark:hover:border-slate-600"
    end
  end

  # ── KPI ────────────────────────────────────────────────────────────

  @doc "Project members with a human-readable label (name/email) instead of the raw user id."
  def list_team_members(project_id) do
    members = Teams.list_members(project_id)

    users =
      members
      |> Enum.map(& &1.user_id)
      |> StreamflixAccounts.list_users_by_ids()
      |> Map.new(&{&1.id, &1})

    Enum.map(members, fn m ->
      label =
        case users[m.user_id] do
          %{name: name, email: email} when is_binary(name) and name != "" -> "#{name} (#{email})"
          %{email: email} when is_binary(email) -> email
          _ -> String.slice(m.user_id, 0, 8) <> "..."
        end

      m |> Map.from_struct() |> Map.put(:label, label)
    end)
  end

  # KPIs are computed in the database over the last 24h. The loaded event and
  # delivery lists are capped (20/30 rows), so counting them under-reports.
  def assign_kpis(socket, nil), do: socket

  def assign_kpis(socket, project) do
    since = DateTime.utc_now() |> DateTime.add(-24, :hour)

    socket
    |> Phoenix.Component.assign(:kpi_events_today, Platform.count_events_since(project.id, since))
    |> Phoenix.Component.assign(:kpi_success_rate, Platform.success_rate_since(project.id, since))
  end

  # ── Uptime ─────────────────────────────────────────────────────────

  def uptime_dot_color(%{status: "healthy"}), do: "bg-emerald-500"
  def uptime_dot_color(%{status: "degraded"}), do: "bg-amber-500"
  def uptime_dot_color(%{status: "unhealthy"}), do: "bg-red-500"
  def uptime_dot_color(_), do: "bg-slate-400"

  def uptime_badge_color(%{status: "healthy"}), do: "bg-emerald-100 text-emerald-800"
  def uptime_badge_color(%{status: "degraded"}), do: "bg-amber-100 text-amber-800"
  def uptime_badge_color(%{status: "unhealthy"}), do: "bg-red-100 text-red-800"
  def uptime_badge_color(_), do: "bg-slate-100 text-slate-600"

  def uptime_label(%{status: "healthy"}), do: gettext("Saludable")
  def uptime_label(%{status: "degraded"}), do: gettext("Degradado")
  def uptime_label(%{status: "unhealthy"}), do: gettext("No saludable")
  def uptime_label(_), do: gettext("Desconocido")

  def load_uptime_status do
    case Uptime.latest_check() do
      nil -> %{status: "unknown", checks: %{}}
      check -> check
    end
  end

  def load_uptime_stats do
    case Cachex.fetch(:platform_cache, :uptime_stats, fn _ ->
           tasks = [
             Task.async(fn -> {:last_24h, Uptime.calculate_uptime(:last_24h)} end),
             Task.async(fn -> {:last_7d, Uptime.calculate_uptime(:last_7d)} end),
             Task.async(fn -> {:last_30d, Uptime.calculate_uptime(:last_30d)} end)
           ]

           stats = safe_await_many(tasks) |> Enum.reject(&is_nil/1) |> Map.new()
           {:commit, stats, expire: :timer.minutes(5)}
         end) do
      {:ok, stats} -> stats
      {:commit, stats} -> stats
      _ -> %{}
    end
  end

  # ── Permissions ────────────────────────────────────────────────────

  def authorize(socket, :write) do
    if socket.assigns.current_user_role in ["owner", "editor"],
      do: :ok,
      else: {:error, gettext("No tienes permisos para esta acción.")}
  end

  def authorize(socket, :admin) do
    if socket.assigns.current_user_role == "owner",
      do: :ok,
      else: {:error, gettext("Solo el dueño del proyecto puede hacer esto.")}
  end

  def with_permission(socket, level, fun) do
    case authorize(socket, level) do
      :ok -> fun.()
      {:error, msg} -> {:noreply, Phoenix.LiveView.put_flash(socket, :error, msg)}
    end
  end

  def with_superadmin(socket, fun) do
    if StreamflixAccounts.Schemas.User.superadmin?(socket.assigns.current_user) do
      fun.()
    else
      {:noreply,
       Phoenix.LiveView.put_flash(socket, :error, gettext("No tienes permisos para esta acción."))}
    end
  end

  def compute_user_role(nil, _user), do: nil

  def compute_user_role(project, user) do
    if project.user_id == user.id do
      "owner"
    else
      Teams.get_member_role(project.id, user.id) || "viewer"
    end
  end

  # ── Data Loading ───────────────────────────────────────────────────

  @doc """
  Awaits multiple tasks, returning a keyword list of `{key, result}` tuples.
  If any task crashes (e.g. DB connection lost), its result is replaced with
  a safe default so the dashboard renders with partial data instead of a 500.
  """
  def safe_await_many(tasks, timeout \\ 10_000) do
    require Logger

    tasks
    |> Task.yield_many(timeout)
    |> Enum.map(fn
      {_task, {:ok, result}} ->
        result

      {task, {:exit, reason}} ->
        Logger.error("Dashboard task failed: #{inspect(reason)}")
        Task.shutdown(task, :brutal_kill)
        nil

      {task, nil} ->
        Logger.error("Dashboard task timed out")
        Task.shutdown(task, :brutal_kill)
        nil
    end)
  end

  def load_analytics(project_id) do
    case Cachex.fetch(:platform_cache, {:analytics, project_id}, fn _ ->
           tasks = [
             Task.async(fn -> {:events_per_day, Platform.events_per_day(project_id)} end),
             Task.async(fn ->
               {:deliveries_per_day, Platform.deliveries_per_day(project_id)}
             end),
             Task.async(fn -> {:top_topics, Platform.top_topics(project_id)} end),
             Task.async(fn ->
               {:webhook_stats, Platform.delivery_stats_by_webhook(project_id)}
             end)
           ]

           data =
             safe_await_many(tasks)
             |> Enum.reject(&is_nil/1)
             |> Map.new()

           {:commit, data, expire: :timer.minutes(5)}
         end) do
      {:ok, data} -> data
      {:commit, data} -> data
      _ -> %{}
    end
  end

  def load_project_data(socket, project) do
    user = socket.assigns.current_user

    tasks = [
      Task.async(fn -> Platform.get_api_key_for_project(project.id) end),
      Task.async(fn -> Platform.list_events(project.id, limit: 20) end),
      Task.async(fn -> Platform.list_webhooks(project.id, include_inactive: true) end),
      Task.async(fn -> Platform.list_deliveries(project_id: project.id, limit: 30) end),
      Task.async(fn -> Platform.list_pipelines(project.id) end)
    ]

    [api_key, events, webhooks, deliveries, pipelines] = safe_await_many(tasks)
    events = events || []
    webhooks = webhooks || []
    deliveries = deliveries || []
    pipelines = pipelines || []

    {new_token, token_source} =
      case socket.assigns[:fresh_api_key] do
        fresh_key when is_binary(fresh_key) and fresh_key != "" ->
          if api_key && String.starts_with?(fresh_key, api_key.prefix) do
            {fresh_key, :registration}
          else
            {nil, nil}
          end

        _ ->
          {nil, nil}
      end

    current_user_role = compute_user_role(project, user)

    socket
    |> Phoenix.Component.assign(:project, project)
    |> Phoenix.Component.assign(:api_key, api_key)
    |> Phoenix.Component.assign(:events, events)
    |> Phoenix.Component.assign(:webhooks, webhooks)
    |> Phoenix.Component.assign(:deliveries, deliveries)
    |> Phoenix.Component.assign(:current_user_role, current_user_role)
    |> assign_kpis(project)
    |> Phoenix.Component.assign(:new_token, new_token)
    |> Phoenix.Component.assign(:token_source, token_source)
    |> Phoenix.Component.assign(:pipelines, pipelines)
  end

  def save_last_project(user, project_id) do
    Task.start(fn ->
      StreamflixAccounts.update_user(user, %{last_project_id: project_id})
    end)
  end

  # ── Job Config Builders ────────────────────────────────────────────

  def build_schedule_config(params) do
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

  def build_action_config(params) do
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

  # ── Oban Queue ─────────────────────────────────────────────────────

  def oban_state_badge("available"), do: "bg-emerald-100 text-emerald-800"
  def oban_state_badge("scheduled"), do: "bg-blue-100 text-blue-800"
  def oban_state_badge("executing"), do: "bg-amber-100 text-amber-800"
  def oban_state_badge("retryable"), do: "bg-orange-100 text-orange-800"
  def oban_state_badge("completed"), do: "bg-slate-100 text-slate-600"
  def oban_state_badge("discarded"), do: "bg-red-100 text-red-800"
  def oban_state_badge("cancelled"), do: "bg-zinc-100 text-zinc-600"
  def oban_state_badge(_), do: "bg-slate-100 text-slate-600"

  def pipeline_step_color("filter"), do: "bg-amber-100 text-amber-800"
  def pipeline_step_color("transform"), do: "bg-purple-100 text-purple-800"
  def pipeline_step_color("delay"), do: "bg-blue-100 text-blue-800"
  def pipeline_step_color(_), do: "bg-slate-100 text-slate-600"

  def refresh_oban_data(socket) do
    jobs =
      Platform.oban_list_jobs(
        state: socket.assigns.oban_filter_state,
        queue: socket.assigns.oban_filter_queue,
        limit: 50
      )

    socket
    |> Phoenix.Component.assign(:oban_queue_stats, Platform.oban_queue_stats())
    |> Phoenix.Component.assign(:oban_state_counts, Platform.oban_state_counts())
    |> Phoenix.Component.assign(:oban_jobs, jobs)
  end
end
