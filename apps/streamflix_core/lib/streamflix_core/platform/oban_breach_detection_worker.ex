defmodule StreamflixCore.Platform.ObanBreachDetectionWorker do
  @moduledoc """
  Oban worker that detects security anomalies by analyzing audit logs.
  Runs every 5 minutes, checks for brute force, coordinated attacks,
  data exfiltration, and account lockouts within a 10-minute window.
  """
  use Oban.Worker, queue: :default, max_attempts: 1, unique: [period: 300]

  require Logger

  import Ecto.Query
  alias StreamflixCore.Repo
  alias StreamflixCore.Audit
  alias StreamflixCore.Notifications

  @window_minutes 10
  @brute_force_threshold 20
  @coordinated_attack_threshold 50
  @exfiltration_threshold 5

  @impl true
  def perform(_job) do
    since = DateTime.utc_now() |> DateTime.add(-@window_minutes * 60, :second)
    anomalies = []

    anomalies = anomalies ++ detect_brute_force_by_ip(since)
    anomalies = anomalies ++ detect_coordinated_attack(since)
    anomalies = anomalies ++ detect_data_exfiltration(since)
    anomalies = anomalies ++ detect_lockouts(since)

    if anomalies != [] do
      severity = classify_severity(anomalies)

      Audit.record("security.anomaly_detected",
        metadata: %{
          anomalies: anomalies,
          window_minutes: @window_minutes,
          severity: severity,
          breach_notification_required: severity in ["critical", "high"]
        }
      )

      notify_admins(anomalies)

      Logger.warning(
        "[BreachDetection] #{length(anomalies)} anomalies detected: #{inspect(anomalies)}"
      )
    end

    :ok
  end

  # >20 login failures from the same IP in the window
  defp detect_brute_force_by_ip(since) do
    results =
      from(a in "audit_logs",
        where: a.action == "user.login_failed" and a.inserted_at >= ^since,
        group_by: a.ip_address,
        having: count(a.id) > @brute_force_threshold,
        select: %{ip: a.ip_address, count: count(a.id)}
      )
      |> Repo.all()

    Enum.map(results, fn %{ip: ip, count: count} ->
      %{type: "brute_force_ip", ip: ip, count: count}
    end)
  end

  # >50 login failures globally in the window
  defp detect_coordinated_attack(since) do
    count =
      from(a in "audit_logs",
        where: a.action == "user.login_failed" and a.inserted_at >= ^since,
        select: count(a.id)
      )
      |> Repo.one()

    if count > @coordinated_attack_threshold do
      [%{type: "coordinated_attack", count: count}]
    else
      []
    end
  end

  # >5 data exports by the same user in the window
  defp detect_data_exfiltration(since) do
    results =
      from(a in "audit_logs",
        where: a.action == "gdpr.data_export" and a.inserted_at >= ^since,
        group_by: a.user_id,
        having: count(a.id) > @exfiltration_threshold,
        select: %{user_id: a.user_id, count: count(a.id)}
      )
      |> Repo.all()

    Enum.map(results, fn %{user_id: uid, count: count} ->
      %{type: "data_exfiltration", user_id: uid, count: count}
    end)
  end

  # Any account lockouts in the window
  defp detect_lockouts(since) do
    results =
      from(a in "audit_logs",
        where: a.action == "user.locked" and a.inserted_at >= ^since,
        select: %{user_id: a.user_id, ip: a.ip_address}
      )
      |> Repo.all()

    Enum.map(results, fn %{user_id: uid, ip: ip} ->
      %{type: "account_lockout", user_id: uid, ip: ip}
    end)
  end

  defp classify_severity(anomalies) do
    types = Enum.map(anomalies, & &1.type) |> MapSet.new()

    cond do
      "data_exfiltration" in types -> "critical"
      "coordinated_attack" in types -> "high"
      true -> "medium"
    end
  end

  defp notify_admins(anomalies) do
    admin_ids = get_admin_user_ids()
    summary = Enum.map(anomalies, & &1.type) |> Enum.frequencies() |> inspect()

    Enum.each(admin_ids, fn user_id ->
      Notifications.create(%{
        user_id: user_id,
        type: "security_anomaly",
        title: "Anomalía de seguridad detectada",
        message:
          "Se detectaron #{length(anomalies)} anomalías en los últimos #{@window_minutes} min: #{summary}",
        metadata: %{"anomalies" => anomalies}
      })
    end)
  end

  defp get_admin_user_ids do
    from(u in "users",
      where: u.role in ["admin", "superadmin"] and u.status == "active",
      select: u.id
    )
    |> Repo.all()
  end
end
