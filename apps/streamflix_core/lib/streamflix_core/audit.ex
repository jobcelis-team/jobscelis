defmodule StreamflixCore.Audit do
  @moduledoc """
  Context for recording and querying audit log entries.
  All actions are immutable — once recorded, they cannot be modified.
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.AuditLog

  @doc """
  Record an audit log entry.

  ## Params
    - action: "webhook.created", "event.sent", "api_key.regenerated", etc.
    - opts: [user_id:, project_id:, resource_type:, resource_id:, metadata:, ip_address:, user_agent:]
  """
  def record(action, opts \\ []) do
    %AuditLog{}
    |> AuditLog.changeset(%{
      action: action,
      user_id: opts[:user_id],
      project_id: opts[:project_id],
      resource_type: opts[:resource_type],
      resource_id: opts[:resource_id],
      metadata: opts[:metadata] || %{},
      ip_address: opts[:ip_address],
      user_agent: opts[:user_agent]
    })
    |> Repo.insert()
  end

  @doc "List audit logs for a project with optional filters"
  def list_for_project(project_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    action = Keyword.get(opts, :action)
    resource_type = Keyword.get(opts, :resource_type)

    AuditLog
    |> where([a], a.project_id == ^project_id)
    |> maybe_filter_action(action)
    |> maybe_filter_resource_type(resource_type)
    |> order_by([a], desc: a.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "List audit logs for a user"
  def list_for_user(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    AuditLog
    |> where([a], a.user_id == ^user_id)
    |> order_by([a], desc: a.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "Get human-readable action label (type key for i18n)"
  def action_icon(action) do
    case action do
      "webhook.created" -> "hero-plus-circle"
      "webhook.updated" -> "hero-pencil-square"
      "webhook.deleted" -> "hero-trash"
      "event.created" -> "hero-bolt"
      "job.created" -> "hero-clock"
      "job.updated" -> "hero-pencil-square"
      "job.deactivated" -> "hero-pause-circle"
      "api_key.regenerated" -> "hero-key"
      "project.updated" -> "hero-cog-6-tooth"
      "delivery.retried" -> "hero-arrow-path"
      "dead_letter.retried" -> "hero-arrow-path"
      "dead_letter.resolved" -> "hero-check-circle"
      "replay.started" -> "hero-arrow-uturn-left"
      "replay.cancelled" -> "hero-x-circle"
      "sandbox.created" -> "hero-beaker"
      "user.login" -> "hero-arrow-right-on-rectangle"
      "user.login_failed" -> "hero-exclamation-triangle"
      "user.locked" -> "hero-lock-closed"
      "user.unlocked" -> "hero-lock-open"
      "user.mfa_enabled" -> "hero-shield-check"
      "user.mfa_disabled" -> "hero-shield-exclamation"
      "user.mfa_verified" -> "hero-check-badge"
      "user.mfa_failed" -> "hero-exclamation-triangle"
      "user.mfa_backup_used" -> "hero-key"
      "system.backup_completed" -> "hero-circle-stack"
      "system.backup_failed" -> "hero-exclamation-circle"
      "gdpr.erasure" -> "hero-trash"
      "gdpr.consent_granted" -> "hero-check-circle"
      "gdpr.consent_revoked" -> "hero-x-circle"
      "gdpr.data_export" -> "hero-arrow-down-tray"
      "security.anomaly_detected" -> "hero-shield-exclamation"
      "user.session_revoked" -> "hero-arrow-left-on-rectangle"
      "user.all_sessions_revoked" -> "hero-arrow-left-on-rectangle"
      _ -> "hero-information-circle"
    end
  end

  defp maybe_filter_action(query, nil), do: query
  defp maybe_filter_action(query, action), do: where(query, [a], a.action == ^action)

  defp maybe_filter_resource_type(query, nil), do: query
  defp maybe_filter_resource_type(query, type), do: where(query, [a], a.resource_type == ^type)
end
