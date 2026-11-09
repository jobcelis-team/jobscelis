defmodule StreamflixCore.Platform.BreachDetectionTest do
  @moduledoc "Breach detection over encrypted audit IPs."
  use StreamflixCore.DataCase, async: false

  import Ecto.Query

  alias StreamflixCore.Platform.ObanBreachDetectionWorker, as: Worker
  alias StreamflixCore.Schemas.AuditLog

  defp audit(action, attrs) do
    %AuditLog{}
    |> AuditLog.changeset(Map.put(attrs, :action, action))
    |> Repo.insert!()
  end

  defp raw(%AuditLog{id: id}) do
    Repo.one(
      from(x in "audit_logs",
        where: x.id == ^Ecto.UUID.dump!(id),
        select: {x.ip_address, x.ip_hash}
      )
    )
  end

  defp anomaly_audit do
    Enum.find_value(1..50, fn _ ->
      case Repo.one(from(a in AuditLog, where: a.action == "security.anomaly_detected")) do
        nil ->
          Process.sleep(20)
          nil

        row ->
          row
      end
    end)
  end

  test "equal IPs share a blind index even though the encrypted values differ" do
    a = audit("user.login_failed", %{ip_address: "203.0.113.7"})
    b = audit("user.login_failed", %{ip_address: "203.0.113.7"})
    c = audit("user.login_failed", %{ip_address: "198.51.100.1"})

    {enc_a, hash_a} = raw(a)
    {enc_b, hash_b} = raw(b)
    {_, hash_c} = raw(c)

    assert enc_a != enc_b
    assert hash_a == hash_b
    assert hash_a != hash_c
  end

  test "flags brute force from one IP and records a JSON-safe anomaly" do
    for _ <- 1..25, do: audit("user.login_failed", %{ip_address: "203.0.113.7"})
    # Spread over many IPs: no single IP crosses the threshold
    for n <- 1..20, do: audit("user.login_failed", %{ip_address: "198.51.100.#{n}"})

    assert :ok = Worker.perform(%Oban.Job{})

    %AuditLog{metadata: %{"anomalies" => anomalies}} = anomaly_audit()
    brute = Enum.filter(anomalies, &(&1["type"] == "brute_force_ip"))

    assert [%{"ip" => "203.0.113.x", "count" => 25}] = brute
  end

  test "lockouts and exports do not crash the worker and carry readable ids" do
    user_id = Ecto.UUID.generate()
    audit("user.locked", %{user_id: user_id, ip_address: "2001:db8:85a3::8a2e:370:7334"})
    for _ <- 1..6, do: audit("gdpr.data_export", %{user_id: user_id})

    assert :ok = Worker.perform(%Oban.Job{})

    %AuditLog{metadata: %{"anomalies" => anomalies, "severity" => "critical"}} = anomaly_audit()

    assert %{"user_id" => ^user_id, "ip" => "2001:DB8:85A3::/48"} =
             Enum.find(anomalies, &(&1["type"] == "account_lockout"))

    assert %{"user_id" => ^user_id, "count" => 6} =
             Enum.find(anomalies, &(&1["type"] == "data_exfiltration"))
  end

  test "mask_ip hides the host part" do
    assert Worker.mask_ip("203.0.113.7") == "203.0.113.x"
    assert Worker.mask_ip("2001:db8:85a3::1") == "2001:DB8:85A3::/48"
    assert Worker.mask_ip("not an ip") == "unknown"
    assert Worker.mask_ip(nil) == nil
  end
end
