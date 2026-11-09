defmodule StreamflixCore.Platform.ObanPurgeWorkerTest do
  @moduledoc "Data retention: what the weekly purge deletes and what it keeps."
  use StreamflixCore.DataCase, async: false

  import Ecto.Query

  alias StreamflixCore.Platform.ObanPurgeWorker
  alias StreamflixCore.Schemas.{AuditLog, Delivery, UptimeCheck, WebhookEvent}

  defp days_ago(n),
    do: DateTime.utc_now() |> DateTime.add(-n, :day) |> DateTime.truncate(:microsecond)

  defp ids(schema), do: Repo.all(from(x in schema, select: x.id)) |> MapSet.new()

  defp event(project, n_days, status \\ "active"),
    do:
      insert(:webhook_event,
        project_id: project.id,
        status: status,
        inserted_at: days_ago(n_days)
      )

  defp delivery(event, webhook, status, n_days),
    do:
      insert(:delivery,
        event_id: event.id,
        webhook_id: webhook.id,
        status: status,
        inserted_at: days_ago(n_days)
      )

  defp audit(project, n_days) do
    %AuditLog{}
    |> Ecto.Changeset.change(%{
      project_id: project.id,
      action: "test",
      inserted_at: days_ago(n_days)
    })
    |> Repo.insert!()
  end

  test "deliveries and events follow the project retention; inactive events too" do
    project = insert(:project, retention_policy: %{"events_days" => 30, "deliveries_days" => 30})
    webhook = insert(:webhook, project_id: project.id)

    old_event = event(project, 40)
    old_inactive = event(project, 40, "inactive")
    recent_event = event(project, 5)

    old_ok = delivery(recent_event, webhook, "success", 40)
    old_failed = delivery(recent_event, webhook, "failed", 40)
    recent_ok = delivery(recent_event, webhook, "success", 5)

    :ok = ObanPurgeWorker.perform(%Oban.Job{})

    events = ids(WebhookEvent)
    refute MapSet.member?(events, old_event.id)
    refute MapSet.member?(events, old_inactive.id)
    assert MapSet.member?(events, recent_event.id)

    deliveries = ids(Delivery)
    refute MapSet.member?(deliveries, old_ok.id)
    # failed deliveries are kept for inspection
    assert MapSet.member?(deliveries, old_failed.id)
    assert MapSet.member?(deliveries, recent_ok.id)
  end

  test "audit logs follow audit_logs_days (default 365, 0 keeps them forever)" do
    short = insert(:project, retention_policy: %{"audit_logs_days" => 10})
    default = insert(:project)
    forever = insert(:project, retention_policy: %{"audit_logs_days" => 0})

    short_old = audit(short, 20)
    short_new = audit(short, 2)
    default_old = audit(default, 400)
    default_new = audit(default, 100)
    forever_old = audit(forever, 1000)

    :ok = ObanPurgeWorker.perform(%Oban.Job{})

    kept = ids(AuditLog)
    refute MapSet.member?(kept, short_old.id)
    assert MapSet.member?(kept, short_new.id)
    refute MapSet.member?(kept, default_old.id)
    assert MapSet.member?(kept, default_new.id)
    assert MapSet.member?(kept, forever_old.id)
  end

  test "uptime checks older than 30 days are deleted" do
    insert_check = fn n ->
      %UptimeCheck{}
      |> Ecto.Changeset.change(%{
        status: "healthy",
        inserted_at: days_ago(n) |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)
      })
      |> Repo.insert!()
    end

    old = insert_check.(45)
    recent = insert_check.(3)

    :ok = ObanPurgeWorker.perform(%Oban.Job{})

    kept = ids(UptimeCheck)
    refute MapSet.member?(kept, old.id)
    assert MapSet.member?(kept, recent.id)
  end
end
