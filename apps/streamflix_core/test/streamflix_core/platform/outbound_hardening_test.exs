defmodule StreamflixCore.Platform.OutboundHardeningTest do
  @moduledoc """
  Delivery worker, scheduled "Call URL" jobs and worker timeouts against slow,
  huge or compressed responses.
  """
  use StreamflixCore.DataCase, async: false

  alias StreamflixCore.Platform.{
    DeliveryWorker,
    ObanDeliveryWorker,
    ObanScheduledJobWorker,
    ScheduledJobRunner
  }

  alias StreamflixCore.RawHttpServer
  alias StreamflixCore.Schemas.{Delivery, JobRun}

  defp huge_response(socket) do
    :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\ncontent-length: 3000000\r\n\r\n")
    chunk = :binary.copy("x", 100_000)
    for _ <- 1..30, do: :gen_tcp.send(socket, chunk)
  end

  test "workers have a hard timeout" do
    assert ObanDeliveryWorker.timeout(%Oban.Job{}) == 30_000
    assert ObanScheduledJobWorker.timeout(%Oban.Job{}) == 30_000
  end

  test "scheduled_job queue runs jobs concurrently" do
    queues = Application.get_env(:streamflix_core, Oban)[:queues]
    assert queues[:scheduled_job] >= 5
  end

  describe "DeliveryWorker" do
    test "stores a bounded response body and the pinned destination IP" do
      {port, ref} = RawHttpServer.start(&huge_response/1)
      project = insert(:project)
      webhook = insert(:webhook, project_id: project.id, url: "http://127.0.0.1:#{port}/hook")
      event = insert(:webhook_event, project_id: project.id)
      delivery = insert(:delivery, event_id: event.id, webhook_id: webhook.id)

      assert {:ok, %Delivery{status: "success"}} = DeliveryWorker.run(delivery.id)

      stored = Repo.get(Delivery, delivery.id)
      assert stored.destination_ip == "127.0.0.1"
      assert byte_size(stored.response_body) <= 10_003
      assert String.ends_with?(stored.response_body, "...")

      assert_receive {:raw_http_request, ^ref, head}
      assert head =~ ~r/accept-encoding: identity/i
      assert head =~ ~r/x-signature|content-type: application\/json/i
    end

    test "the signed body is the exact body sent" do
      {port, _ref} =
        RawHttpServer.start(fn socket ->
          :gen_tcp.send(
            socket,
            "HTTP/1.1 500 Internal Server Error\r\ncontent-length: 4\r\n\r\nboom"
          )
        end)

      project = insert(:project)
      webhook = insert(:webhook, project_id: project.id, url: "http://127.0.0.1:#{port}/hook")
      event = insert(:webhook_event, project_id: project.id)
      delivery = insert(:delivery, event_id: event.id, webhook_id: webhook.id)

      assert {:error, {:failed, d}} = DeliveryWorker.run(delivery.id)
      assert d.response_status == 500
      assert d.response_body == "boom"
    end
  end

  describe "ScheduledJobRunner post_url" do
    defp post_url_job(url) do
      project = insert(:project)

      insert(:job,
        project_id: project.id,
        action_type: "post_url",
        action_config: %{"url" => url, "method" => "POST", "payload" => %{"a" => 1}}
      )
    end

    test "huge responses do not matter, only the status" do
      {port, _ref} = RawHttpServer.start(&huge_response/1)
      job = post_url_job("http://127.0.0.1:#{port}/run")

      ScheduledJobRunner.run(job.id)

      assert %JobRun{status: "success", result: %{"response_status" => 200}} =
               Repo.get_by(JobRun, job_id: job.id)
    end

    test "internal destinations are blocked" do
      previous = Application.get_env(:streamflix_core, :allow_private_destinations)
      Application.put_env(:streamflix_core, :allow_private_destinations, false)

      on_exit(fn ->
        Application.put_env(:streamflix_core, :allow_private_destinations, previous)
      end)

      job = post_url_job("http://127.0.0.1:1/run")
      ScheduledJobRunner.run(job.id)

      assert %JobRun{status: "failed", result: %{"error" => "url must point to a public" <> _}} =
               Repo.get_by(JobRun, job_id: job.id)
    end
  end
end
