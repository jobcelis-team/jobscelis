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
  alias StreamflixCore.Schemas.AuditLog

  @window_minutes 10
  @brute_force_threshold 20
  @coordinated_attack_threshold 50
  @exfiltration_threshold 5

  @impl true
  def perform(_job) do
    since = DateTime.utc_now() |> DateTime.add(-@window_minutes * 60, :second)

    anomalies =
      [
        Task.async(fn -> detect_brute_force_by_ip(since) end),
        Task.async(fn -> detect_coordinated_attack(since) end),
        Task.async(fn -> detect_data_exfiltration(since) end),
        Task.async(fn -> detect_lockouts(since) end)
      ]
      |> Task.await_many(10_000)
      |> List.flatten()

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

      Logger.warning("Security anomalies detected",
        worker: "BreachDetection",
        anomaly_count: length(anomalies),
        severity: severity,
        anomalies: inspect(anomalies)
      )
    end

    :ok
  end

  # >20 login failures from the same IP in the window. ip_address is encrypted
  # with a random IV (equal IPs never compare equal), so rows are grouped by
  # ip_hash, its keyed blind index.
  defp detect_brute_force_by_ip(since) do
    from(a in AuditLog,
      where: a.action == "user.login_failed" and a.inserted_at >= ^since,
      where: not is_nil(a.ip_hash),
      group_by: a.ip_hash,
      having: count(a.id) > @brute_force_threshold,
      select: {a.ip_hash, count(a.id)}
    )
    |> Repo.all()
    |> Enum.map(fn {ip_hash, count} ->
      %{type: "brute_force_ip", ip: ip_for_hash(ip_hash, since), count: count}
    end)
  end

  defp ip_for_hash(ip_hash, since) do
    from(a in AuditLog,
      where: fragment("? = ?", a.ip_hash, ^ip_hash) and a.inserted_at >= ^since,
      limit: 1,
      select: a.ip_address
    )
    |> Repo.one()
    |> mask_ip()
  end

  # >50 login failures globally in the window
  defp detect_coordinated_attack(since) do
    count =
      from(a in AuditLog,
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
    from(a in AuditLog,
      where: a.action == "gdpr.data_export" and a.inserted_at >= ^since,
      group_by: a.user_id,
      having: count(a.id) > @exfiltration_threshold,
      select: {a.user_id, count(a.id)}
    )
    |> Repo.all()
    |> Enum.map(fn {uid, count} -> %{type: "data_exfiltration", user_id: uid, count: count} end)
  end

  # Any account lockouts in the window
  defp detect_lockouts(since) do
    from(a in AuditLog,
      where: a.action == "user.locked" and a.inserted_at >= ^since,
      select: {a.user_id, a.ip_address}
    )
    |> Repo.all()
    |> Enum.map(fn {uid, ip} -> %{type: "account_lockout", user_id: uid, ip: mask_ip(ip)} end)
  end

  # Anomalies are stored in audit metadata and notifications as plain JSON:
  # the address is masked (IPv4 /24, IPv6 /48) so it is not kept in clear,
  # while still identifying the network to block.
  @doc false
  def mask_ip(ip) when is_binary(ip) do
    case :inet.parse_address(String.to_charlist(ip)) do
      {:ok, {a, b, c, _}} ->
        "#{a}.#{b}.#{c}.x"

      {:ok, {a, b, c, _, _, _, _, _}} ->
        Enum.map_join([a, b, c], ":", &Integer.to_string(&1, 16)) <> "::/48"

      _ ->
        "unknown"
    end
  end

  def mask_ip(_), do: nil

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
        title: "Security anomaly detected",
        message:
          "#{length(anomalies)} anomalies detected in the last #{@window_minutes} min: #{summary}",
        metadata: %{"anomalies" => anomalies}
      })
    end)
  end

  defp get_admin_user_ids do
    from(u in "users",
      where: u.role in ["admin", "superadmin"] and u.status == "active",
      select: type(u.id, :string)
    )
    |> Repo.all()
  end
end
