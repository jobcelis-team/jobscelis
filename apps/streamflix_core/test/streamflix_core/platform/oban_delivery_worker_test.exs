defmodule StreamflixCore.Platform.ObanDeliveryWorkerTest do
  @moduledoc """
  Tests for the ObanDeliveryWorker: backoff strategies and perform behavior.
  """
  use StreamflixCore.DataCase, async: true

  alias StreamflixCore.Platform.ObanDeliveryWorker

  describe "backoff/1 — exponential strategy" do
    test "attempt 1 returns ~base delay" do
      job = build_job("exponential", 10, 3600, 1)
      delay = ObanDeliveryWorker.backoff(job)
      # base * 3^0 = 10, with jitter ±20% → 8..12
      assert delay >= 6 and delay <= 14
    end

    test "attempt 3 returns ~base*9" do
      job = build_job("exponential", 10, 3600, 3)
      delay = ObanDeliveryWorker.backoff(job)
      # base * 3^2 = 90, with jitter ±20% → 72..108
      assert delay >= 60 and delay <= 120
    end

    test "attempt 5 returns ~base*81" do
      job = build_job("exponential", 10, 3600, 5)
      delay = ObanDeliveryWorker.backoff(job)
      # base * 3^4 = 810, with jitter ±20% → 648..972
      assert delay >= 600 and delay <= 1000
    end
  end

  describe "backoff/1 — linear strategy" do
    test "delay scales linearly with attempt" do
      for attempt <- 1..3 do
        job = build_job("linear", 10, 3600, attempt)
        delay = ObanDeliveryWorker.backoff(job)
        expected = 10 * attempt
        # With jitter ±20%
        assert delay >= trunc(expected * 0.7) and delay <= trunc(expected * 1.4)
      end
    end
  end

  describe "backoff/1 — fixed strategy" do
    test "delay is always ~base" do
      for attempt <- [1, 3, 5] do
        job = build_job("fixed", 30, 3600, attempt)
        delay = ObanDeliveryWorker.backoff(job)
        # 30 with jitter ±20% → 24..36
        assert delay >= 20 and delay <= 40
      end
    end
  end

  describe "backoff/1 — max_delay cap" do
    test "caps delay at max_delay" do
      # exponential attempt 10: 10 * 3^9 = 196830, but max is 100
      job = build_job("exponential", 10, 100, 10)
      delay = ObanDeliveryWorker.backoff(job)
      assert delay <= 130
    end
  end

  describe "backoff/1 — legacy backoff_seconds list" do
    test "uses list values by attempt index" do
      job = %Oban.Job{
        args: %{
          "delivery_id" => "test",
          "retry_config" => %{"backoff_seconds" => [5, 15, 60, 300]}
        },
        attempt: 1
      }

      assert ObanDeliveryWorker.backoff(job) == 5

      job2 = %{job | attempt: 3}
      assert ObanDeliveryWorker.backoff(job2) == 60
    end

    test "uses last value when attempt exceeds list" do
      job = %Oban.Job{
        args: %{
          "delivery_id" => "test",
          "retry_config" => %{"backoff_seconds" => [5, 15]}
        },
        attempt: 5
      }

      assert ObanDeliveryWorker.backoff(job) == 15
    end
  end

  describe "backoff/1 — jitter disabled" do
    test "returns exact delay when jitter is false" do
      job = %Oban.Job{
        args: %{
          "delivery_id" => "test",
          "retry_config" => %{
            "strategy" => "fixed",
            "base_delay_seconds" => 30,
            "jitter" => false
          }
        },
        attempt: 1
      }

      assert ObanDeliveryWorker.backoff(job) == 30
    end
  end

  describe "perform/1 — max_attempts exceeded" do
    test "returns :ok when attempt exceeds max" do
      job = %Oban.Job{
        args: %{
          "delivery_id" => Ecto.UUID.generate(),
          "retry_config" => %{"max_attempts" => 3}
        },
        attempt: 4
      }

      assert :ok = ObanDeliveryWorker.perform(job)
    end
  end

  defp build_job(strategy, base, max_delay, attempt) do
    %Oban.Job{
      args: %{
        "delivery_id" => "test",
        "retry_config" => %{
          "strategy" => strategy,
          "base_delay_seconds" => base,
          "max_delay_seconds" => max_delay
        }
      },
      attempt: attempt
    }
  end
end
