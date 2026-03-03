defmodule StreamflixCore.GDPR do
  @moduledoc """
  GDPR compliance: data erasure (right to be forgotten), consent management,
  and personal data export (DSAR).
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{AuditLog, Project, Consent}
  alias StreamflixCore.Schemas.ProjectMember

  @cache :platform_cache

  # ── Erasure (Right to be forgotten) ──────────────────────────────

  @doc """
  Completely erase a user and all associated data (GDPR Art. 17).

  Uses Ecto.Multi to ensure atomicity:
  1. Record erasure in audit log (system action)
  2. Pseudonymize existing audit logs for the user
  3. Delete project_members referencing this user
  4. Hard-delete all projects owned by user (cascades api_keys, webhooks, events, etc.)
  5. Delete user (cascades user_tokens and notifications automatically)
  6. Invalidate Cachex
  """
  def erase_user(user) do
    user_id = user.id

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:audit_erasure, AuditLog.changeset(%AuditLog{}, %{
      action: "gdpr.erasure",
      metadata: %{erased_email_hash: :crypto.hash(:sha256, user.email) |> Base.encode16(case: :lower)},
      ip_address: "[system]"
    }))
    |> Ecto.Multi.update_all(:pseudonymize_audit, fn _ ->
      from(a in AuditLog, where: a.user_id == ^user_id)
    end, set: [user_id: nil, ip_address: "[redacted]"])
    |> Ecto.Multi.delete_all(:delete_memberships, fn _ ->
      from(m in ProjectMember, where: m.user_id == ^user_id)
    end)
    |> Ecto.Multi.run(:delete_projects, fn repo, _ ->
      projects = repo.all(from(p in Project, where: p.user_id == ^user_id))

      Enum.each(projects, fn project ->
        repo.delete!(project)
      end)

      {:ok, length(projects)}
    end)
    |> Ecto.Multi.delete(:delete_user, user)
    |> Repo.transaction()
    |> case do
      {:ok, result} ->
        Cachex.clear(@cache)
        {:ok, result}

      {:error, step, reason, _changes} ->
        {:error, {step, reason}}
    end
  end

  # ── Consent management ───────────────────────────────────────────

  @purposes ~w(terms privacy data_processing marketing)

  @doc "Grant a consent for a specific purpose."
  def grant_consent(user_id, purpose, opts \\ []) when purpose in @purposes do
    %Consent{}
    |> Consent.changeset(%{
      user_id: user_id,
      purpose: purpose,
      granted_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
      ip_address: opts[:ip_address] || "[unknown]",
      version: opts[:version] || "1.0"
    })
    |> Repo.insert()
  end

  @doc "Revoke a consent (sets revoked_at)."
  def revoke_consent(consent_id) do
    case Repo.get(Consent, consent_id) do
      nil ->
        {:error, :not_found}

      %{revoked_at: revoked} when not is_nil(revoked) ->
        {:error, :already_revoked}

      consent ->
        consent
        |> Consent.revoke_changeset()
        |> Repo.update()
    end
  end

  @doc "List all consents for a user."
  def list_consents(user_id) do
    Consent
    |> where([c], c.user_id == ^user_id)
    |> order_by([c], desc: c.granted_at)
    |> Repo.all()
  end

  @doc "List only active (non-revoked) consents."
  def list_active_consents(user_id) do
    Consent
    |> where([c], c.user_id == ^user_id and is_nil(c.revoked_at))
    |> order_by([c], desc: c.granted_at)
    |> Repo.all()
  end

  @doc "Check if user has an active consent for a purpose."
  def has_consent?(user_id, purpose) do
    Consent
    |> where([c], c.user_id == ^user_id and c.purpose == ^purpose and is_nil(c.revoked_at))
    |> Repo.exists?()
  end

  @doc "Register initial consents on signup (terms, privacy, data_processing)."
  def register_signup_consents(user_id, opts \\ []) do
    ip = opts[:ip_address] || "[signup]"

    Enum.each(~w(terms privacy data_processing), fn purpose ->
      grant_consent(user_id, purpose, ip_address: ip)
    end)

    :ok
  end

  # ── Data export (DSAR) ───────────────────────────────────────────

  @doc """
  Collect all personal data for a user (GDPR Art. 15 — Subject Access Request).
  Returns a map with profile, projects, webhooks, events count, consents, audit entries, etc.
  """
  def collect_user_data(user) do
    user_id = user.id

    projects = Repo.all(from(p in Project, where: p.user_id == ^user_id))
    project_ids = Enum.map(projects, & &1.id)

    webhooks = if project_ids != [] do
      Repo.all(from(w in StreamflixCore.Schemas.Webhook, where: w.project_id in ^project_ids))
    else
      []
    end

    events_count = if project_ids != [] do
      Repo.one(from(e in StreamflixCore.Schemas.WebhookEvent, where: e.project_id in ^project_ids, select: count(e.id)))
    else
      0
    end

    deliveries_count = if project_ids != [] do
      Repo.one(
        from(d in StreamflixCore.Schemas.Delivery,
          join: e in StreamflixCore.Schemas.WebhookEvent, on: d.event_id == e.id,
          where: e.project_id in ^project_ids,
          select: count(d.id))
      )
    else
      0
    end

    jobs = if project_ids != [] do
      Repo.all(from(j in StreamflixCore.Schemas.Job, where: j.project_id in ^project_ids))
    else
      []
    end

    notifications = Repo.all(
      from(n in StreamflixCore.Schemas.Notification,
        where: n.user_id == ^user_id,
        order_by: [desc: n.inserted_at],
        limit: 100)
    )

    audit_entries = Repo.all(
      from(a in AuditLog,
        where: a.user_id == ^user_id,
        order_by: [desc: a.inserted_at],
        limit: 200)
    )

    consents = list_consents(user_id)

    memberships = Repo.all(
      from(m in ProjectMember, where: m.user_id == ^user_id)
    )

    %{
      exported_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      profile: %{
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
        status: user.status,
        mfa_enabled: user.mfa_enabled || false,
        email_verified_at: to_iso(user.email_verified_at),
        created_at: to_iso(user.inserted_at)
      },
      projects: Enum.map(projects, fn p ->
        %{id: p.id, name: p.name, status: p.status, is_default: p.is_default, created_at: to_iso(p.inserted_at)}
      end),
      webhooks: Enum.map(webhooks, fn w ->
        %{id: w.id, url: w.url, status: w.status, project_id: w.project_id, created_at: to_iso(w.inserted_at)}
      end),
      events_count: events_count,
      deliveries_count: deliveries_count,
      jobs: Enum.map(jobs, fn j ->
        %{id: j.id, name: j.name, status: j.status, schedule_type: j.schedule_type, project_id: j.project_id}
      end),
      notifications: Enum.map(notifications, fn n ->
        %{id: n.id, type: n.type, title: n.title, read: n.read, created_at: to_iso(n.inserted_at)}
      end),
      audit_entries: Enum.map(audit_entries, fn a ->
        %{id: a.id, action: a.action, resource_type: a.resource_type, ip_address: a.ip_address, created_at: to_iso(a.inserted_at)}
      end),
      consents: Enum.map(consents, fn c ->
        %{
          id: c.id,
          purpose: c.purpose,
          version: c.version,
          granted_at: to_iso(c.granted_at),
          revoked_at: to_iso(c.revoked_at)
        }
      end),
      memberships: Enum.map(memberships, fn m ->
        %{id: m.id, project_id: m.project_id, role: m.role, status: m.status}
      end)
    }
  end

  defp to_iso(nil), do: nil
  defp to_iso(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp to_iso(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt)
  defp to_iso(other), do: to_string(other)
end
