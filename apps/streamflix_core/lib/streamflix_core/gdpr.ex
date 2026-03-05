defmodule StreamflixCore.GDPR do
  @moduledoc """
  GDPR compliance: data erasure (right to be forgotten), consent management,
  processing restriction (Art. 18), objection (Art. 21), and personal data export (DSAR).
  """
  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Schemas.{AuditLog, Project, Consent}
  alias StreamflixCore.Schemas.ProjectMember

  @cache :platform_cache

  # ── Art. 18 — Restriction of processing ──────────────────────────

  @doc """
  Restrict processing for a user (GDPR Art. 18).
  Sets status to "restricted", records restricted_at and reason.
  """
  def restrict_processing(user, reason) do
    user
    |> Ecto.Changeset.change(%{
      status: "restricted",
      restricted_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
      restriction_reason: reason
    })
    |> Repo.update()
  end

  @doc """
  Lift processing restriction for a user.
  Restores status to "active" and clears restriction fields.
  """
  def lift_restriction(user) do
    user
    |> Ecto.Changeset.change(%{
      status: "active",
      restricted_at: nil,
      restriction_reason: nil
    })
    |> Repo.update()
  end

  # ── Art. 21 — Right to object ────────────────────────────────────

  @doc """
  Record a user's objection to data processing (GDPR Art. 21).
  Sets processing_consent to false.
  """
  def object_to_processing(user) do
    user
    |> Ecto.Changeset.change(%{processing_consent: false})
    |> Repo.update()
  end

  @doc """
  Restore a user's processing consent after objection withdrawal.
  """
  def restore_processing_consent(user) do
    user
    |> Ecto.Changeset.change(%{processing_consent: true})
    |> Repo.update()
  end

  # ── Erasure (Right to be forgotten) ──────────────────────────────

  @doc """
  Completely erase a user and all associated data (GDPR Art. 17).

  Uses Ecto.Multi to ensure atomicity:
  1. Record erasure in audit log (system action)
  2. Pseudonymize existing audit logs for the user
  3. Anonymize notifications (user_id=nil, title/message="[redacted]")
  4. Delete consents, user_sessions, password_history
  5. Delete project_members referencing this user
  6. Hard-delete all projects owned by user (cascades api_keys, webhooks, events, etc.)
  7. Delete user (cascades user_tokens and notifications automatically)
  8. Invalidate Cachex
  """
  def erase_user(user) do
    user_id = user.id
    project_ids = Repo.all(from(p in Project, where: p.user_id == ^user_id, select: p.id))

    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :audit_erasure,
      AuditLog.changeset(%AuditLog{}, %{
        action: "gdpr.erasure",
        metadata: %{
          erased_email_hash: :crypto.hash(:sha256, user.email) |> Base.encode16(case: :lower)
        },
        ip_address: "[system]"
      })
    )
    |> Ecto.Multi.update_all(
      :pseudonymize_audit,
      fn _ ->
        from(a in AuditLog, where: a.user_id == ^user_id)
      end,
      set: [user_id: nil, ip_address: "[redacted]"]
    )
    |> Ecto.Multi.update_all(
      :anonymize_notifications,
      fn _ ->
        from(n in "notifications", where: n.user_id == type(^user_id, :binary_id))
      end,
      set: [user_id: nil, title: "[redacted]", message: "[redacted]"]
    )
    |> Ecto.Multi.delete_all(:delete_consents, fn _ ->
      from(c in Consent, where: c.user_id == ^user_id)
    end)
    |> Ecto.Multi.delete_all(:delete_sessions, fn _ ->
      from(s in "user_sessions", where: s.user_id == type(^user_id, :binary_id))
    end)
    |> Ecto.Multi.delete_all(:delete_password_history, fn _ ->
      from(p in "password_history", where: p.user_id == type(^user_id, :binary_id))
    end)
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
        Cachex.del(@cache, {:user, user_id})

        Enum.each(project_ids, fn pid ->
          Cachex.del(@cache, {:active_webhooks, pid})
          Cachex.del(@cache, {:webhook_health, pid})
        end)

        {:ok, result}

      {:error, step, reason, _changes} ->
        {:error, {step, reason}}
    end
  end

  # ── Consent management ───────────────────────────────────────────

  @purposes ~w(terms privacy data_processing marketing)

  @doc "Grant a consent for a specific purpose. Idempotent: returns existing active consent if one exists."
  def grant_consent(user_id, purpose, opts \\ []) when purpose in @purposes do
    existing =
      Consent
      |> where([c], c.user_id == ^user_id and c.purpose == ^purpose and is_nil(c.revoked_at))
      |> limit(1)
      |> Repo.one()

    case existing do
      %Consent{} = consent ->
        {:ok, consent}

      nil ->
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
  Collect all personal data for a user (GDPR Art. 15 + Art. 20 — Subject Access Request).
  Returns a v2 format map with full events/deliveries lists, sessions, and GDPR fields.
  """
  def collect_user_data(user) do
    user_id = user.id

    projects = Repo.all(from(p in Project, where: p.user_id == ^user_id))
    project_ids = Enum.map(projects, & &1.id)

    # Run all independent queries in parallel
    tasks = [
      Task.async(fn ->
        {:webhooks,
         if(project_ids != [],
           do:
             Repo.all(
               from(w in StreamflixCore.Schemas.Webhook, where: w.project_id in ^project_ids)
             ),
           else: []
         )}
      end),
      Task.async(fn ->
        {:events,
         if(project_ids != [],
           do:
             Repo.all(
               from(e in StreamflixCore.Schemas.WebhookEvent,
                 where: e.project_id in ^project_ids,
                 order_by: [desc: e.inserted_at],
                 limit: 500
               )
             ),
           else: []
         )}
      end),
      Task.async(fn ->
        {:deliveries,
         if(project_ids != [],
           do:
             Repo.all(
               from(d in StreamflixCore.Schemas.Delivery,
                 join: e in StreamflixCore.Schemas.WebhookEvent,
                 on: d.event_id == e.id,
                 where: e.project_id in ^project_ids,
                 order_by: [desc: d.inserted_at],
                 limit: 500
               )
             ),
           else: []
         )}
      end),
      Task.async(fn ->
        {:jobs,
         if(project_ids != [],
           do:
             Repo.all(from(j in StreamflixCore.Schemas.Job, where: j.project_id in ^project_ids)),
           else: []
         )}
      end),
      Task.async(fn ->
        {:notifications,
         Repo.all(
           from(n in StreamflixCore.Schemas.Notification,
             where: n.user_id == ^user_id,
             order_by: [desc: n.inserted_at],
             limit: 100
           )
         )}
      end),
      Task.async(fn ->
        {:audit_entries,
         Repo.all(
           from(a in AuditLog,
             where: a.user_id == ^user_id,
             order_by: [desc: a.inserted_at],
             limit: 200
           )
         )}
      end),
      Task.async(fn -> {:consents, list_consents(user_id)} end),
      Task.async(fn ->
        {:memberships, Repo.all(from(m in ProjectMember, where: m.user_id == ^user_id))}
      end),
      Task.async(fn ->
        {:sessions,
         Repo.all(
           from(s in StreamflixAccounts.Schemas.UserSession,
             where: s.user_id == ^user_id,
             order_by: [desc: s.inserted_at],
             limit: 100,
             select: %{
               id: s.id,
               token_jti: s.token_jti,
               device_info: s.device_info,
               last_activity_at: s.last_activity_at,
               revoked_at: s.revoked_at,
               inserted_at: s.inserted_at
             }
           )
         )}
      end)
    ]

    data = Task.await_many(tasks, 15_000) |> Map.new()

    webhooks = data.webhooks
    events = data.events
    deliveries = data.deliveries
    jobs = data.jobs
    notifications = data.notifications
    audit_entries = data.audit_entries
    consents = data.consents
    memberships = data.memberships
    sessions = data.sessions

    %{
      format: "v2",
      schema_version: "2.0",
      exported_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      profile: %{
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
        status: user.status,
        processing_consent: Map.get(user, :processing_consent, true),
        restricted_at: to_iso(Map.get(user, :restricted_at)),
        mfa_enabled: user.mfa_enabled || false,
        email_verified_at: to_iso(user.email_verified_at),
        created_at: to_iso(user.inserted_at)
      },
      projects:
        Enum.map(projects, fn p ->
          %{
            id: p.id,
            name: p.name,
            status: p.status,
            is_default: p.is_default,
            created_at: to_iso(p.inserted_at)
          }
        end),
      webhooks:
        Enum.map(webhooks, fn w ->
          %{
            id: w.id,
            url: w.url,
            status: w.status,
            project_id: w.project_id,
            created_at: to_iso(w.inserted_at)
          }
        end),
      events:
        Enum.map(events, fn e ->
          %{
            id: e.id,
            topic: e.topic,
            project_id: e.project_id,
            created_at: to_iso(e.inserted_at)
          }
        end),
      deliveries:
        Enum.map(deliveries, fn d ->
          %{
            id: d.id,
            status: d.status,
            event_id: d.event_id,
            webhook_id: d.webhook_id,
            attempt_number: d.attempt_number,
            created_at: to_iso(d.inserted_at)
          }
        end),
      jobs:
        Enum.map(jobs, fn j ->
          %{
            id: j.id,
            name: j.name,
            status: j.status,
            schedule_type: j.schedule_type,
            project_id: j.project_id
          }
        end),
      notifications:
        Enum.map(notifications, fn n ->
          %{
            id: n.id,
            type: n.type,
            title: n.title,
            read: n.read,
            created_at: to_iso(n.inserted_at)
          }
        end),
      audit_entries:
        Enum.map(audit_entries, fn a ->
          %{
            id: a.id,
            action: a.action,
            resource_type: a.resource_type,
            ip_address: a.ip_address,
            created_at: to_iso(a.inserted_at)
          }
        end),
      consents:
        Enum.map(consents, fn c ->
          %{
            id: c.id,
            purpose: c.purpose,
            version: c.version,
            granted_at: to_iso(c.granted_at),
            revoked_at: to_iso(c.revoked_at)
          }
        end),
      memberships:
        Enum.map(memberships, fn m ->
          %{id: m.id, project_id: m.project_id, role: m.role, status: m.status}
        end),
      sessions:
        Enum.map(sessions, fn s ->
          %{
            id: s.id,
            token_jti: s.token_jti,
            device_info: s.device_info,
            last_activity_at: to_iso(s.last_activity_at),
            revoked_at: to_iso(s.revoked_at),
            created_at: to_iso(s.inserted_at)
          }
        end)
    }
  end

  defp to_iso(nil), do: nil
  defp to_iso(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp to_iso(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt)
  defp to_iso(other), do: to_string(other)
end
